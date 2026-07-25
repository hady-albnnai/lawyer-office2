import 'dart:convert';
import 'package:crypto/crypto.dart';

/// أدوات الأمان والتشفير لكلمات المرور وأسئلة استعادة الحساب
class CryptoUtils {
  /// تشفير سلسلة نصية (كلمة مرور أو إجابة أمان) باستخدام SHA-256 مع ملح آمن
  static String hashPassword(String rawPassword, {String salt = 'syr_law_office_2026'}) {
    final bytes = utf8.encode(rawPassword + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// التحقق من تطابق كلمة المرور المدخلة مع الهاش المحفوظ
  static bool verifyPassword(String rawPassword, String savedHash, {String salt = 'syr_law_office_2026'}) {
    final computedHash = hashPassword(rawPassword, salt: salt);
    return computedHash == savedHash;
  }
}
