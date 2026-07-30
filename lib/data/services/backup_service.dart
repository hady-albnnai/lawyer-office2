import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';

/// محرك النسخ الاحتياطي الذكي والاستعادة (BackupService)
/// ينفذ النسخ في الخلفية (Isolate) لعدم تجميد الواجهة، مع فحص أسبوعي ذكي عند الإغلاق ودعم الأقراص الخارجية.
class BackupService {
  /// فحص ذكي عند إغلاق التطبيق: هل مر أسبوع (7 أيام) على آخر نسخة ناجحة؟
  bool shouldRunWeeklyBackup(DateTime? lastBackupDate) {
    if (lastBackupDate == null) return true;
    final difference = DateTime.now().difference(lastBackupDate);
    return difference.inDays >= 7;
  }

  /// تشغيل النسخ الاحتياطي في الخلفية (Isolate) وضغط قاعدة البيانات والمرفقات في ملف Zip
  Future<String> triggerBackgroundBackup({
    bool includeAttachments = true,
    String? customExternalPath,
  }) async {
    final receivePort = ReceivePort();

    final docsDir = await getApplicationDocumentsDirectory();
    final sourcePath = p.join(docsDir.path, AppConstants.appDataDirectoryName);
    
    // تحديد مسار الحفظ (إما مجلد النسخ التلقائي أو القرص الخارجي USB / هارد)
    final String backupPath = customExternalPath ?? p.join(docsDir.path, AppConstants.backupsDirectoryName);

    await Isolate.spawn(_backupIsolateWorker, {
      'sendPort': receivePort.sendPort,
      'sourcePath': sourcePath,
      'backupPath': backupPath,
      'includeAttachments': includeAttachments,
    });

    final result = await receivePort.first as Map<String, dynamic>;
    if (result['success'] == true) {
      return result['filePath'] as String;
    } else {
      throw Exception(result['error']);
    }
  }

  /// دالة العامل (Worker) المنفصلة التي تعمل في Isolate مستقل لضغط الملفات
  static void _backupIsolateWorker(Map<String, dynamic> args) async {
    final SendPort sendPort = args['sendPort'];
    final String sourcePath = args['sourcePath'];
    final String backupPath = args['backupPath'];
    final bool includeAttachments = args['includeAttachments'];

    try {
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final String zipFileName = 'SyrLawOffice_Backup_$timestamp.zip';
      final String fullDestPath = p.join(backupPath, zipFileName);

      var encoder = ZipFileEncoder();
      encoder.create(fullDestPath);

      final sourceDir = Directory(sourcePath);
      if (await sourceDir.exists()) {
        await for (var entity in sourceDir.list(recursive: false)) {
          if (entity is File && entity.path.endsWith('.db')) {
            // await إلزامي: addFile ترجع Future، وبدونها قد يُغلق
            // الأرشيف قبل اكتمال الكتابة فتنتج نسخة احتياطية ناقصة.
            await encoder.addFile(entity);
          } else if (entity is Directory && entity.path.endsWith(AppConstants.filesDirectoryName) && includeAttachments) {
            await encoder.addDirectory(entity);
          }
        }
      }

      await encoder.close();
      sendPort.send({'success': true, 'filePath': fullDestPath});
    } catch (e) {
      sendPort.send({'success': false, 'error': e.toString()});
    }
  }

  /// قائمة بالنسخ الاحتياطية المتاحة للاستعادة
  Future<List<File>> listAvailableBackups({String? customPath}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupPath = customPath ?? p.join(docsDir.path, AppConstants.backupsDirectoryName);
    final backupDir = Directory(backupPath);

    if (!await backupDir.exists()) return [];

    final List<File> zipFiles = [];
    await for (var entity in backupDir.list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        zipFiles.add(entity);
      }
    }

    // ترتيب النسخ من الأحدث إلى الأقدم
    zipFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return zipFiles;
  }

  /// استعادة النظام من ملف نسخة احتياطية (.zip)
  ///
  /// ترمي [RestoreException] عند الفشل بدل إرجاع false، لأن الاستعادة
  /// عملية مدمِّرة تكتب فوق بيانات المكتب؛ فشلها الصامت يترك المستخدم
  /// يظن أن بياناته استُعيدت.
  Future<bool> restoreFromBackup(File zipFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final destRoot = p.join(docsDir.path, AppConstants.appDataDirectoryName);
    final normalizedRoot = p.normalize(destRoot);

    late final Archive archive;
    try {
      final bytes = await zipFile.readAsBytes();
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw RestoreException('تعذّر قراءة ملف النسخة الاحتياطية: قد يكون تالفاً.');
    }

    if (archive.isEmpty) {
      throw RestoreException('ملف النسخة الاحتياطية فارغ.');
    }

    final skipped = <String>[];

    for (final file in archive) {
      final filename = file.name;

      // حماية من Zip Slip: مدخل يحوي ../ يمكنه الكتابة خارج مجلد التطبيق.
      final target = p.normalize(p.join(normalizedRoot, filename));
      if (!p.isWithin(normalizedRoot, target) && target != normalizedRoot) {
        skipped.add(filename);
        continue;
      }

      if (!file.isFile) {
        Directory(target).createSync(recursive: true);
        continue;
      }

      // في archive 4.x يُرجع content مصفوفة فارغة عند تعذّر فكّ الضغط
      // بدل رمي خطأ، فالكتابة المباشرة تُنتج ملفاً فارغاً بصمت.
      final data = file.readBytes();
      if (data == null) {
        throw RestoreException(
            'تعذّر فكّ ضغط "$filename". النسخة الاحتياطية تالفة، ولم تُستكمل الاستعادة.');
      }

      // ملف بحجم صفر مشروع فقط إن كان أصله كذلك.
      if (data.isEmpty && file.size > 0) {
        throw RestoreException(
            'الملف "$filename" فارغ رغم أن حجمه المسجّل ${file.size} بايت. الاستعادة متوقفة لتفادي فقدان البيانات.');
      }

      File(target)
        ..createSync(recursive: true)
        ..writeAsBytesSync(data);
    }

    if (skipped.isNotEmpty) {
      debugPrint('تم تجاهل مسارات غير آمنة أثناء الاستعادة: $skipped');
    }

    return true;
  }
}

/// فشل استعادة نسخة احتياطية برسالة صالحة للعرض للمستخدم.
class RestoreException implements Exception {
  final String message;
  const RestoreException(this.message);

  @override
  String toString() => message;
}
