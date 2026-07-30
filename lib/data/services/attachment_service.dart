import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import 'file_storage_service.dart';

/// نتيجة محاولة فتح مرفق، لعرض رسالة دقيقة للمستخدم بدل الفشل الصامت.
class AttachmentOpenResult {
  final bool success;
  final String? message;

  const AttachmentOpenResult._(this.success, this.message);

  const AttachmentOpenResult.ok() : this._(true, null);
  const AttachmentOpenResult.failure(String message) : this._(false, message);
}

/// نتيجة اختيار مرفق بعد التحقق من الصيغة والحجم.
class AttachmentPickResult {
  final File? file;
  final String? rejectionReason;

  const AttachmentPickResult({this.file, this.rejectionReason});

  bool get isAccepted => file != null;
}

/// إدارة اختيار المرفقات وفتحها.
///
/// المرفقات تُخزَّن مشفّرة (AES) بلاحقة `.enc`، لذا لا يمكن فتحها
/// مباشرة من مسارها؛ يجب فكّ تشفيرها إلى ملف مؤقت أولاً.
class AttachmentService {
  AttachmentService(this._storage);

  final FileStorageService _storage;

  /// اختيار مرفق مع رفض الصيغ التي لا يستطيع التطبيق قراءتها.
  ///
  /// التحقق يجري بعد الاختيار أيضاً ولا يُكتفى بفلتر نافذة النظام،
  /// لأن بعض المنصات تسمح بتجاوز الفلتر.
  Future<AttachmentPickResult> pickAttachment({bool allowMultiple = false}) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedAttachmentExtensions,
    );

    final picked = result?.files.firstOrNull;
    final path = picked?.path;
    if (picked == null || path == null || path.isEmpty) {
      return const AttachmentPickResult();
    }

    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (!AppConstants.allowedAttachmentExtensions.contains(ext)) {
      return AttachmentPickResult(
        rejectionReason: 'صيغة غير مدعومة (.$ext).\n'
            'الصيغ المقبولة: ${AppConstants.allowedAttachmentExtensions.join('، ')}',
      );
    }

    final file = File(path);
    final size = await file.length();
    if (size > AppConstants.maxAttachmentSizeBytes) {
      final limitMb =
          AppConstants.maxAttachmentSizeBytes ~/ (1024 * 1024);
      final actualMb = (size / (1024 * 1024)).toStringAsFixed(1);
      return AttachmentPickResult(
        rejectionReason:
            'حجم الملف $actualMb ميجابايت ويتجاوز الحد المسموح ($limitMb ميجابايت).',
      );
    }

    if (size == 0) {
      return const AttachmentPickResult(rejectionReason: 'الملف فارغ.');
    }

    return AttachmentPickResult(file: file);
  }

  /// فتح مرفق مخزَّن بمسار نسبي داخل مخزن التطبيق.
  ///
  /// يفكّ التشفير إلى ملف مؤقت ثم يسلّمه لتطبيق النظام الافتراضي.
  Future<AttachmentOpenResult> openStoredAttachment(String? relativePath) async {
    if (relativePath == null || relativePath.trim().isEmpty) {
      return const AttachmentOpenResult.failure('لا يوجد ملف مرتبط بهذا السجل.');
    }

    try {
      final decrypted = await _storage.getFileFromRelativePath(relativePath);
      if (decrypted == null) {
        return const AttachmentOpenResult.failure(
            'الملف غير موجود في مساره. قد يكون حُذف أو نُقل خارج التطبيق.');
      }
      return _openLocalFile(decrypted.path);
    } catch (e) {
      debugPrint('فشل فتح المرفق: $e');
      return const AttachmentOpenResult.failure(
          'تعذّر فتح الملف. قد يكون تالفاً أو مشفّراً بمفتاح مختلف.');
    }
  }

  /// فتح ملف موجود على القرص بمساره المطلق (قبل التخزين مثلاً).
  Future<AttachmentOpenResult> openLocalFile(String absolutePath) =>
      _openLocalFile(absolutePath);

  Future<AttachmentOpenResult> _openLocalFile(String absolutePath) async {
    if (!await File(absolutePath).exists()) {
      return const AttachmentOpenResult.failure('الملف غير موجود في مساره.');
    }

    final result = await OpenFilex.open(absolutePath);
    switch (result.type) {
      case ResultType.done:
        return const AttachmentOpenResult.ok();
      case ResultType.noAppToOpen:
        final ext = p.extension(absolutePath);
        return AttachmentOpenResult.failure(
            'لا يوجد تطبيق على الجهاز يفتح ملفات $ext.');
      case ResultType.permissionDenied:
        return const AttachmentOpenResult.failure(
            'لا توجد صلاحية لفتح هذا الملف.');
      case ResultType.fileNotFound:
        return const AttachmentOpenResult.failure('الملف غير موجود.');
      case ResultType.error:
        return AttachmentOpenResult.failure(
            'تعذّر فتح الملف: ${result.message}');
    }
  }

  /// إظهار الملف في مستكشف الملفات (ويندوز/ماك/لينكس).
  Future<AttachmentOpenResult> revealInFolder(String? relativePath) async {
    if (relativePath == null || relativePath.trim().isEmpty) {
      return const AttachmentOpenResult.failure('لا يوجد ملف مرتبط.');
    }
    try {
      final absolute = await _storage.getAbsolutePath(relativePath);
      final file = File(absolute);
      if (!await file.exists()) {
        return const AttachmentOpenResult.failure('الملف غير موجود في مساره.');
      }
      final dir = p.dirname(absolute);

      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', absolute]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', absolute]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir]);
      } else {
        return const AttachmentOpenResult.failure('غير مدعوم على هذه المنصة.');
      }
      return const AttachmentOpenResult.ok();
    } catch (e) {
      debugPrint('فشل إظهار الملف: $e');
      return const AttachmentOpenResult.failure('تعذّر فتح مجلد الملف.');
    }
  }

  /// هل يمكن عرض هذه الصيغة داخل التطبيق دون تطبيق خارجي؟
  static bool isPreviewable(String? fileNameOrExt) {
    if (fileNameOrExt == null || fileNameOrExt.isEmpty) return false;
    final ext = fileNameOrExt.contains('.')
        ? p.extension(fileNameOrExt).replaceFirst('.', '').toLowerCase()
        : fileNameOrExt.toLowerCase();
    return AppConstants.internallyPreviewableExtensions.contains(ext);
  }

  /// وصف مختصر للصيغ المقبولة، لعرضه في الواجهات.
  static String get allowedExtensionsLabel =>
      AppConstants.allowedAttachmentExtensions.join('، ');
}
