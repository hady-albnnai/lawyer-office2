import 'dart:io';

import 'package:drift/drift.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/crypto_utils.dart';
import '../database/database.dart';
import '../database/daos/settings_dao.dart';
import '../services/backup_service.dart';

/// مستودع الإعدادات والأمان والنسخ — SQLite + BackupService الحقيقي.
class SettingsRepository {
  final SettingsDao _dao;
  final BackupService _backupService;

  SettingsRepository(this._dao, this._backupService);

  Future<Map<String, String?>> getAllSettings() => _dao.getAllSettings();

  Future<String?> getSetting(String key) => _dao.getSetting(key);

  Future<void> setSetting(String key, String? value) => _dao.setSetting(key, value);

  Future<SecurityData?> getSecurity() => _dao.getSecurity();

  Stream<List<ActivityLogData>> watchActivityLog() => _dao.watchActivityLog();
  Future<List<ActivityLogData>> getActivityLog() => _dao.getActivityLog();

  Stream<List<Backup>> watchBackups() => _dao.watchBackups();
  Future<List<Backup>> getBackups() => _dao.getBackups();

  Stream<List<Court>> watchCourts() => _dao.watchCourts();
  Future<List<Court>> getCourts() => _dao.getCourts();

  Future<void> logActivity({
    required String table,
    required int recordId,
    required String action,
    String? userRef,
    String? details,
  }) {
    return _dao.insertActivity(
      ActivityLogCompanion.insert(
        affectedTable: table,
        recordId: recordId,
        action: action,
        userRef: Value(userRef),
        details: Value(details),
      ),
    );
  }

  Future<void> saveOfficeSettings({
    required String title,
    required String lawyer,
    required String address,
    required String phone,
    String email = '',
    String logoPath = '',
    String signaturePath = '',
    String uiFont = 'Cairo',
    String printFont = 'Amiri',
    int woPriority = 1,
    bool libraryAutoFav = true,
    String externalBackupPath = '',
    String? userRef,
  }) async {
    await _dao.setSetting(AppConstants.keyOfficeTitle, title);
    await _dao.setSetting(AppConstants.keyLawyerName, lawyer);
    await _dao.setSetting(AppConstants.keyOfficeAddress, address);
    await _dao.setSetting(AppConstants.keyOfficePhone, phone);
    await _dao.setSetting('office_email', email);
    await _dao.setSetting(AppConstants.keyOfficeLogoPath, logoPath);
    await _dao.setSetting('office_signature_path', signaturePath);
    await _dao.setSetting('ui_font', uiFont);
    await _dao.setSetting('print_font', printFont);
    await _dao.setSetting('wo_default_priority', '$woPriority');
    await _dao.setSetting('library_auto_favorite_principles', libraryAutoFav ? '1' : '0');
    await _dao.setSetting('external_backup_path', externalBackupPath);
    await logActivity(
      table: 'app_settings',
      recordId: 0,
      action: 'update',
      userRef: userRef ?? lawyer,
      details: 'تحديث بيانات المكتب والترويسة',
    );
  }

  Future<String?> updateSecurity({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
    required String securityQuestion,
    required String securityAnswer,
    int lockTimeoutMinutes = 10,
    String? userRef,
  }) async {
    final existing = await _dao.getSecurity();
    final currentHash = existing?.passwordHash ?? CryptoUtils.hashPassword('Office@2026');
    if (!CryptoUtils.verifyPassword(currentPassword, currentHash)) {
      return 'كلمة المرور الحالية غير صحيحة';
    }
    if (newPassword.length < 6) return 'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف';
    if (newPassword != confirmPassword) return 'تأكيد كلمة المرور غير مطابق';
    if (securityQuestion.trim().isEmpty || securityAnswer.trim().isEmpty) {
      return 'سؤال الأمان وإجابته إلزاميان';
    }

    await _dao.upsertSecurity(
      SecurityCompanion(
        passwordHash: Value(CryptoUtils.hashPassword(newPassword)),
        securityQuestion: Value(securityQuestion.trim()),
        answerHash: Value(CryptoUtils.hashPassword(securityAnswer.trim())),
        lockTimeoutMinutes: Value(lockTimeoutMinutes),
      ),
    );
    await logActivity(
      table: 'security',
      recordId: existing?.id ?? 0,
      action: 'update',
      userRef: userRef,
      details: 'تحديث كلمة المرور/سؤال الأمان/مهلة القفل',
    );
    return null;
  }

  Future<String> createBackup({
    bool includeAttachments = true,
    String type = 'manual',
    String? customPath,
    String? userRef,
  }) async {
    final path = await _backupService.triggerBackgroundBackup(
      includeAttachments: includeAttachments,
      customExternalPath: customPath,
    );

    double sizeMb = 0;
    try {
      final file = File(path);
      if (await file.exists()) {
        sizeMb = (await file.length()) / (1024 * 1024);
      }
    } catch (_) {}

    final id = await _dao.insertBackup(
      BackupsCompanion.insert(
        path: path,
        type: type,
        sizeMb: Value(sizeMb),
        includesAttachments: Value(includeAttachments),
        status: const Value('success'),
      ),
    );
    await _dao.setSetting('last_backup_at', DateTime.now().toIso8601String());
    await logActivity(
      table: 'backups',
      recordId: id,
      action: 'export',
      userRef: userRef,
      details: 'نسخ احتياطي ($type): $path',
    );
    return path;
  }

  /// تمرّر RestoreException للأعلى: فشل الاستعادة يجب أن يصل للمستخدم
  /// برسالة محددة، لا كـ false مبهم.
  Future<bool> restoreBackup(String path, {String? userRef}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw RestoreException('ملف النسخة الاحتياطية غير موجود: $path');
    }
    final ok = await _backupService.restoreFromBackup(file);
    if (ok) {
      await logActivity(
        table: 'backups',
        recordId: 0,
        action: 'import',
        userRef: userRef,
        details: 'استعادة من $path',
      );
    }
    return ok;
  }

  Future<int> addCourt({
    required String name,
    String? type,
    String? city,
    String? userRef,
  }) async {
    final id = await _dao.insertCourt(
      CourtsCompanion.insert(
        name: name,
        type: Value(type),
        city: Value(city),
      ),
    );
    await logActivity(
      table: 'courts',
      recordId: id,
      action: 'insert',
      userRef: userRef,
      details: 'إضافة محكمة: $name',
    );
    return id;
  }

  /// كل المحاكم بما فيها المعطّلة (شاشة القوائم المرجعية).
  Future<List<Court>> getAllCourtsIncludingInactive() => _dao.getAllCourtsIncludingInactive();

  Future<void> updateCourt({
    required int id,
    required String name,
    String? type,
    String? city,
    String? userRef,
  }) async {
    await _dao.updateCourt(id, name: name, type: type, city: city);
    await logActivity(
      table: 'courts',
      recordId: id,
      action: 'update',
      userRef: userRef,
      details: 'تعديل محكمة: $name',
    );
  }

  Future<void> setCourtActive({
    required int id,
    required bool active,
    String? name,
    String? userRef,
  }) async {
    await _dao.setCourtActive(id, active);
    await logActivity(
      table: 'courts',
      recordId: id,
      action: active ? 'enable' : 'disable',
      userRef: userRef,
      details: '${active ? 'تفعيل' : 'تعطيل'} محكمة: ${name ?? id}',
    );
  }

  /// حذف محكمة غير مستخدمة.
  ///
  /// يُرفض الحذف إذا كانت مرتبطة بدعاوى، وإلا بقيت تلك الدعاوى تشير إلى
  /// مرجع محذوف. الرسالة المعادة غير فارغة تعني الرفض.
  Future<String?> deleteCourt({
    required int id,
    String? name,
    String? userRef,
  }) async {
    final usage = await _dao.countCasesUsingCourt(id);
    if (usage > 0) {
      return 'لا يمكن حذف المحكمة لأنها مرتبطة بـ $usage دعوى. يمكنك تعطيلها بدل حذفها.';
    }
    await _dao.deleteCourt(id);
    await logActivity(
      table: 'courts',
      recordId: id,
      action: 'delete',
      userRef: userRef,
      details: 'حذف محكمة غير مستخدمة: ${name ?? id}',
    );
    return null;
  }

  Future<void> setSecurityDirect({
    required String password,
    required String securityQuestion,
    required String securityAnswer,
    int lockTimeoutMinutes = 10,
    String? userRef,
  }) async {
    await _dao.upsertSecurity(
      SecurityCompanion.insert(
        passwordHash: CryptoUtils.hashPassword(password),
        securityQuestion: securityQuestion.trim(),
        answerHash: CryptoUtils.hashPassword(securityAnswer.trim()),
        lockTimeoutMinutes: Value(lockTimeoutMinutes),
      ),
    );
    await logActivity(
      table: 'security',
      recordId: 0,
      action: 'update',
      userRef: userRef,
      details: 'تعيين كلمة المرور من معالج أول تشغيل',
    );
  }

  Future<void> ensureDefaults() async {
    final security = await _dao.getSecurity();
    if (security == null) {
      await _dao.upsertSecurity(
        SecurityCompanion.insert(
          passwordHash: CryptoUtils.hashPassword('Office@2026'),
          securityQuestion: 'ما اسم مدرستك الابتدائية؟',
          answerHash: CryptoUtils.hashPassword('المجد'),
          lockTimeoutMinutes: const Value(10),
        ),
      );
    }

    final title = await _dao.getSetting(AppConstants.keyOfficeTitle);
    if (title == null || title.isEmpty) {
      await _dao.setSetting(AppConstants.keyOfficeTitle, AppConstants.defaultOfficeTitle);
      await _dao.setSetting(AppConstants.keyLawyerName, AppConstants.defaultLawyerName);
      await _dao.setSetting(AppConstants.keyOfficeAddress, AppConstants.defaultAddress);
      await _dao.setSetting(AppConstants.keyOfficePhone, AppConstants.defaultPhone);
    }
  }
}
