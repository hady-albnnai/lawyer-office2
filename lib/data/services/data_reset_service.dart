import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../database/database.dart';
import 'storage_location_service.dart';

/// نتيجة عملية التصفير، لعرض تقرير دقيق للمستخدم.
class ResetReport {
  final int deletedFiles;
  final int deletedFolders;
  final bool databaseCleared;
  final List<String> warnings;

  const ResetReport({
    required this.deletedFiles,
    required this.deletedFolders,
    required this.databaseCleared,
    this.warnings = const [],
  });

  String get summary {
    final parts = <String>[];
    if (databaseCleared) parts.add('أُفرغت قاعدة البيانات');
    if (deletedFiles > 0) parts.add('حُذف $deletedFiles ملف');
    if (deletedFolders > 0) parts.add('و $deletedFolders مجلد');
    return parts.isEmpty ? 'لا توجد بيانات لحذفها' : parts.join(' • ');
  }
}

/// تصفير بيانات المكتب بالكامل: السجلات والمرفقات والعدّادات.
///
/// `clearOperationalData` في قاعدة البيانات تحذف الصفوف وتصفّر
/// `sqlite_sequence`، لكنها **لا تحذف المرفقات المشفّرة من القرص**،
/// فتبقى ملفات يتيمة تستهلك المساحة ولا يشير إليها أي سجل.
class DataResetService {
  DataResetService(this._db);

  final AppDatabase _db;

  /// تصفير كامل: قاعدة البيانات + ملفات المرفقات + العدّادات.
  ///
  /// [keepBackups] يُبقي مجلد النسخ الاحتياطية، فحذفه مع البيانات
  /// يزيل آخر وسيلة للتراجع عن الخطأ.
  Future<ResetReport> resetAll({bool keepBackups = true}) async {
    final warnings = <String>[];

    // 1) إفراغ الجداول وتصفير العدّادات التسلسلية.
    var dbCleared = false;
    try {
      await _db.clearOperationalData();
      dbCleared = true;
    } catch (e) {
      warnings.add('تعذّر إفراغ بعض الجداول: $e');
    }

    // 2) تصفير عدّادات ملفات المكتب صراحةً.
    //    هذه الجداول تُنشأ بـ SQL مخصص، وقد لا تشملها القائمة أعلاه.
    for (final table in const [
      'office_file_sequences',
      'yearly_sequences',
    ]) {
      try {
        await _db.customStatement('DELETE FROM $table;');
        await _db.customStatement(
          "DELETE FROM sqlite_sequence WHERE name = '$table';",
        );
      } catch (e) {
        warnings.add('تعذّر تصفير عدّاد $table: $e');
      }
    }

    // 3) حذف المرفقات والقوالب والملفات المولّدة من القرص.
    var files = 0;
    var folders = 0;
    final root = StorageLocationService.activeRoot;

    final targets = <String>[
      p.join(root, AppConstants.filesDirectoryName),
      p.join(root, AppConstants.templatesFolder),
      p.join(root, 'reports'),
      if (!keepBackups) p.join(root, AppConstants.backupsDirectoryName),
    ];

    for (final path in targets) {
      final dir = Directory(path);
      if (!await dir.exists()) continue;
      try {
        await for (final e in dir.list(recursive: true, followLinks: false)) {
          if (e is File) files++;
          if (e is Directory) folders++;
        }
        await dir.delete(recursive: true);
        // إعادة إنشاء المجلد فارغاً ليبقى الهيكل صالحاً للاستخدام.
        await dir.create(recursive: true);
      } catch (e) {
        warnings.add('تعذّر حذف $path: $e');
        debugPrint('فشل حذف مجلد أثناء التصفير: $path — $e');
      }
    }

    // 4) استرجاع مساحة القرص فعلياً بعد الحذف.
    try {
      await _db.customStatement('VACUUM;');
    } catch (e) {
      warnings.add('تعذّر ضغط قاعدة البيانات: $e');
    }

    return ResetReport(
      deletedFiles: files,
      deletedFolders: folders,
      databaseCleared: dbCleared,
      warnings: warnings,
    );
  }

  /// نقل بيانات المكتب إلى مسار جديد.
  ///
  /// النسخ أولاً ثم التحقق ثم الحذف: القطع في المنتصف يترك نسختين
  /// لا صفر نسخة. لا تُحذف المصدر إلا بعد التأكد من اكتمال النقل.
  static Future<List<String>> migrateData({
    required String fromRoot,
    required String toRoot,
    required bool deleteSource,
  }) async {
    final warnings = <String>[];
    final source = Directory(fromRoot);
    if (!await source.exists()) return ['مجلد المصدر غير موجود'];

    await Directory(toRoot).create(recursive: true);

    var copied = 0;
    var expected = 0;

    await for (final entity
        in source.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: fromRoot);
      final target = p.join(toRoot, relative);

      if (entity is Directory) {
        await Directory(target).create(recursive: true);
        continue;
      }
      if (entity is! File) continue;

      expected++;
      try {
        await Directory(p.dirname(target)).create(recursive: true);
        await entity.copy(target);

        // التحقق بالحجم: نسخة مبتورة أسوأ من فشل صريح.
        final srcLen = await entity.length();
        final dstLen = await File(target).length();
        if (srcLen != dstLen) {
          warnings.add('حجم مختلف بعد النسخ: $relative');
          continue;
        }
        copied++;
      } catch (e) {
        warnings.add('تعذّر نسخ $relative: $e');
      }
    }

    if (copied != expected) {
      warnings.add(
        'نُسخ $copied من أصل $expected ملف. لم يُحذف المصدر حفاظاً على البيانات.',
      );
      return warnings;
    }

    if (deleteSource) {
      try {
        await source.delete(recursive: true);
      } catch (e) {
        warnings.add(
          'اكتمل النسخ لكن تعذّر حذف المجلد القديم: $e\n'
          'يمكنك حذفه يدوياً من: $fromRoot',
        );
      }
    }

    return warnings;
  }
}
