import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
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
            encoder.addFile(entity);
          } else if (entity is Directory && entity.path.endsWith(AppConstants.filesDirectoryName) && includeAttachments) {
            encoder.addDirectory(entity);
          }
        }
      }

      encoder.close();
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
  Future<bool> restoreFromBackup(File zipFile) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final destPath = p.join(docsDir.path, AppConstants.appDataDirectoryName);

      // فك الضغط فوق المجلد الحالي
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File(p.join(destPath, filename))
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory(p.join(destPath, filename)).createSync(recursive: true);
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
