/// محرك إدارة التخزين المحلي والمرفقات وقوالب Word (FileStorageService)
/// التحديث الماسي (المرحلة 10.1): File-Level Encryption (تشفير المرفقات بصيغة .enc)

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:encrypt/encrypt.dart' as enc;
import '../../core/constants/app_constants.dart';

class FileStorageService {
  // مفتاح التشفير الديناميكي (يتم جلبه لاحقاً من SecurityDao، هنا كمثال ثابت للتطبيق المكتبي)
  final _key = enc.Key.fromUtf8('my_lawyer_office_32_bytes_key_!!');
  final _iv = enc.IV.fromLength(16);

  /// الحصول على المجلد الجذري للتطبيق (مثال: AppData/LawOffice/files/)
  Future<Directory> getRootStorageDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(docsDir.path, AppConstants.appDataDirectoryName, AppConstants.filesDirectoryName));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// حفظ ملف مرفق وتشفيره إلى (.enc)
  Future<String> saveAttachment({
    required File sourceFile,
    required String folderType,
    required int entityId,
  }) async {
    final rootDir = await getRootStorageDir();
    final targetDir = Directory(p.join(rootDir.path, folderType, entityId.toString()));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String cleanName = p.basename(sourceFile.path).replaceAll(' ', '_');
    
    // تغيير اللاحقة إلى .enc
    final String fileName = '${timestamp}_$cleanName.enc';
    final String fullDestPath = p.join(targetDir.path, fileName);

    // عملية التشفير العسكري (AES-256)
    final encrypter = enc.Encrypter(enc.AES(_key));
    final fileBytes = await sourceFile.readAsBytes();
    final encrypted = encrypter.encryptBytes(fileBytes, iv: _iv);

    // كتابة الملف المشفر في القرص
    final destFile = File(fullDestPath);
    await destFile.writeAsBytes(encrypted.bytes);

    return p.join(folderType, entityId.toString(), fileName);
  }

  /// فك التشفير عند الطلب (يعيد ملفاً مؤقتاً Decrypted File في الـ RAM / Cache)
  Future<File?> getFileFromRelativePath(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final rootDir = await getRootStorageDir();
    final fullPath = p.join(rootDir.path, relativePath);
    final encryptedFile = File(fullPath);
    
    if (!await encryptedFile.exists()) return null;

    // قراءة الملف المشفر
    final encryptedBytes = await encryptedFile.readAsBytes();
    final encrypter = enc.Encrypter(enc.AES(_key));
    
    // فك التشفير للذاكرة
    final decryptedBytes = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: _iv);

    // حفظه في مجلد الكاش المؤقت ليعرضه الـ UI، ويجب حذفه لاحقاً
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, p.basename(relativePath).replaceAll('.enc', '')));
    await tempFile.writeAsBytes(decryptedBytes);

    return tempFile;
  }

  /// جلب المسار الكامل لنص نسبي
  Future<String> getAbsolutePath(String relativePath) async {
    final rootDir = await getRootStorageDir();
    return p.join(rootDir.path, relativePath);
  }

  /// حذف مرفق فيزيائياً من القرص الصلب
  Future<bool> deleteAttachment(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return false;
    try {
      final rootDir = await getRootStorageDir();
      final file = File(p.join(rootDir.path, relativePath));
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// حفظ قالب Word مخصص للنماذج والعقود (بدون تشفير ليسهل تحريره)
  Future<String> saveTemplate(File docxFile, String templateName) async {
    final rootDir = await getRootStorageDir();
    final targetDir = Directory(p.join(rootDir.path, AppConstants.templatesFolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final String fileName = '${DateTime.now().millisecondsSinceEpoch}_$templateName.docx';
    final String fullPath = p.join(targetDir.path, fileName);
    await docxFile.copy(fullPath);

    return p.join(AppConstants.templatesFolder, fileName);
  }
}
