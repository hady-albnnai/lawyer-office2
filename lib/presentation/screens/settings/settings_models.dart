/// نماذج وحالة المرحلة 10: الإعدادات والأمان والنسخ الاحتياطي.
///
/// طبقة واجهة seed قابلة للاختبار فوق SharedPreferences/CryptoUtils،
/// مع سجل نشاط ونسخ احتياطي ومهلة قفل وقوائم مرجعية.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/crypto_utils.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';

/// عنصر سجل نشاط.
class ActivityLogEntry {
  final String id;
  final String action;
  final String tableName;
  final String details;
  final String userRef;
  final DateTime timestamp;

  const ActivityLogEntry({
    required this.id,
    required this.action,
    required this.tableName,
    required this.details,
    required this.userRef,
    required this.timestamp,
  });
}

/// سجل نسخة احتياطية.
class BackupRecord {
  final String id;
  final String path;
  final String type;
  final double sizeMb;
  final bool includesAttachments;
  final DateTime createdAt;
  final String status;

  const BackupRecord({
    required this.id,
    required this.path,
    required this.type,
    required this.sizeMb,
    required this.includesAttachments,
    required this.createdAt,
    this.status = 'success',
  });
}

/// محكمة مرجعية (قائمة سورية).
class SettingsCourtItem {
  final String id;
  final String name;
  final String type;
  final String city;
  final bool isActive;

  const SettingsCourtItem({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    this.isActive = true,
  });

  SettingsCourtItem copyWith({String? name, String? type, String? city, bool? isActive}) {
    return SettingsCourtItem(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      city: city ?? this.city,
      isActive: isActive ?? this.isActive,
    );
  }
}


/// عنصر قائمة مرجعية عام.
class SettingsLookupItem {
  final String id;
  final String name;
  final String category;
  final String notes;
  final bool isActive;

  const SettingsLookupItem({
    required this.id,
    required this.name,
    this.category = '',
    this.notes = '',
    this.isActive = true,
  });

  SettingsLookupItem copyWith({String? name, String? category, String? notes, bool? isActive}) {
    return SettingsLookupItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// إعدادات الأمان المحلية.
class SecuritySettings {
  final String passwordHash;
  final String securityQuestion;
  final String answerHash;
  final int lockTimeoutMinutes;
  final bool isConfigured;

  const SecuritySettings({
    required this.passwordHash,
    required this.securityQuestion,
    required this.answerHash,
    this.lockTimeoutMinutes = 10,
    this.isConfigured = false,
  });

  SecuritySettings copyWith({
    String? passwordHash,
    String? securityQuestion,
    String? answerHash,
    int? lockTimeoutMinutes,
    bool? isConfigured,
  }) {
    return SecuritySettings(
      passwordHash: passwordHash ?? this.passwordHash,
      securityQuestion: securityQuestion ?? this.securityQuestion,
      answerHash: answerHash ?? this.answerHash,
      lockTimeoutMinutes: lockTimeoutMinutes ?? this.lockTimeoutMinutes,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }
}

/// تفضيلات المكتب الإضافية.
class OfficePreferences {
  final String officeTitle;
  final String lawyerName;
  final String officeAddress;
  final String officePhone;
  final String officeEmail;
  final String logoPath;
  final String signaturePath;
  final String uiFont;
  final String printFont;
  final String backupFolderPath;
  final String externalBackupPath;
  final int workOrderDefaultPriority; // 0 low 1 med 2 high
  final bool libraryAutoFavoritePrinciples;
  final DateTime? lastBackupAt;

  const OfficePreferences({
    required this.officeTitle,
    required this.lawyerName,
    required this.officeAddress,
    required this.officePhone,
    this.officeEmail = '',
    this.logoPath = '',
    this.signaturePath = '',
    this.uiFont = 'Cairo',
    this.printFont = 'Amiri',
    this.backupFolderPath = '',
    this.externalBackupPath = '',
    this.workOrderDefaultPriority = 1,
    this.libraryAutoFavoritePrinciples = true,
    this.lastBackupAt,
  });

  OfficePreferences copyWith({
    String? officeTitle,
    String? lawyerName,
    String? officeAddress,
    String? officePhone,
    String? officeEmail,
    String? logoPath,
    String? signaturePath,
    String? uiFont,
    String? printFont,
    String? backupFolderPath,
    String? externalBackupPath,
    int? workOrderDefaultPriority,
    bool? libraryAutoFavoritePrinciples,
    DateTime? lastBackupAt,
    bool clearLastBackup = false,
  }) {
    return OfficePreferences(
      officeTitle: officeTitle ?? this.officeTitle,
      lawyerName: lawyerName ?? this.lawyerName,
      officeAddress: officeAddress ?? this.officeAddress,
      officePhone: officePhone ?? this.officePhone,
      officeEmail: officeEmail ?? this.officeEmail,
      logoPath: logoPath ?? this.logoPath,
      signaturePath: signaturePath ?? this.signaturePath,
      uiFont: uiFont ?? this.uiFont,
      printFont: printFont ?? this.printFont,
      backupFolderPath: backupFolderPath ?? this.backupFolderPath,
      externalBackupPath: externalBackupPath ?? this.externalBackupPath,
      workOrderDefaultPriority: workOrderDefaultPriority ?? this.workOrderDefaultPriority,
      libraryAutoFavoritePrinciples:
          libraryAutoFavoritePrinciples ?? this.libraryAutoFavoritePrinciples,
      lastBackupAt: clearLastBackup ? null : lastBackupAt ?? this.lastBackupAt,
    );
  }
}

/// حالة شاشة الإعدادات.
class SettingsHubState {
  final OfficePreferences preferences;
  final SecuritySettings security;
  final List<ActivityLogEntry> activityLog;
  final List<BackupRecord> backups;
  final List<SettingsCourtItem> courts;
  final Map<String, List<SettingsLookupItem>> referenceLists;
  final String activityFilter;
  final bool isBusy;
  final String? lastMessage;

  const SettingsHubState({
    required this.preferences,
    required this.security,
    required this.activityLog,
    required this.backups,
    required this.courts,
    this.referenceLists = const {},
    this.activityFilter = '',
    this.isBusy = false,
    this.lastMessage,
  });

  List<ActivityLogEntry> get filteredActivity {
    final q = activityFilter.trim().toLowerCase();
    if (q.isEmpty) return activityLog;
    return activityLog
        .where(
          (e) =>
              e.action.toLowerCase().contains(q) ||
              e.details.toLowerCase().contains(q) ||
              e.tableName.toLowerCase().contains(q) ||
              e.userRef.toLowerCase().contains(q),
        )
        .toList();
  }

  bool get needsWeeklyBackup {
    final last = preferences.lastBackupAt;
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= 7;
  }

  SettingsHubState copyWith({
    OfficePreferences? preferences,
    SecuritySettings? security,
    List<ActivityLogEntry>? activityLog,
    List<BackupRecord>? backups,
    List<SettingsCourtItem>? courts,
    Map<String, List<SettingsLookupItem>>? referenceLists,
    String? activityFilter,
    bool? isBusy,
    String? lastMessage,
    bool clearMessage = false,
  }) {
    return SettingsHubState(
      preferences: preferences ?? this.preferences,
      security: security ?? this.security,
      activityLog: activityLog ?? this.activityLog,
      backups: backups ?? this.backups,
      courts: courts ?? this.courts,
      referenceLists: referenceLists ?? this.referenceLists,
      activityFilter: activityFilter ?? this.activityFilter,
      isBusy: isBusy ?? this.isBusy,
      lastMessage: clearMessage ? null : lastMessage ?? this.lastMessage,
    );
  }
}

final settingsHubProvider =
    StateNotifierProvider<SettingsHubNotifier, SettingsHubState>((ref) {
  return SettingsHubNotifier(repository: ref.watch(settingsRepositoryProvider))..bootstrapDb();
});

class SettingsHubNotifier extends StateNotifier<SettingsHubState> {
  SettingsHubNotifier({SettingsRepository? repository})
      : _repository = repository,
        super(_seedState()) {
    if (repository == null) {
      _hydrateFromPrefs();
    }
  }

  final SettingsRepository? _repository;
  bool _dbReady = false;

  Future<void> bootstrapDb() async {
    final repo = _repository;
    if (repo == null || _dbReady) return;
    _dbReady = true;
    try {
      await repo.ensureDefaults();
      await _loadFromDb();
      await _loadLookups();
    } catch (_) {
      await _hydrateFromPrefs();
    }
  }

  Future<void> _loadFromDb() async {
    try {
    final repo = _repository;
    if (repo == null) return;
    final settings = await repo.getAllSettings();
    final security = await repo.getSecurity();
    final backups = await repo.getBackups();
    final courts = await repo.getAllCourtsIncludingInactive();
    final logs = await repo.getActivityLog();
    final lastBackupRaw = settings['last_backup_at'];
    state = state.copyWith(
      preferences: state.preferences.copyWith(
        officeTitle: settings[AppConstants.keyOfficeTitle] ?? state.preferences.officeTitle,
        lawyerName: settings[AppConstants.keyLawyerName] ?? state.preferences.lawyerName,
        officeAddress: settings[AppConstants.keyOfficeAddress] ?? state.preferences.officeAddress,
        officePhone: settings[AppConstants.keyOfficePhone] ?? state.preferences.officePhone,
        officeEmail: settings['office_email'] ?? state.preferences.officeEmail,
        logoPath: settings[AppConstants.keyOfficeLogoPath] ?? state.preferences.logoPath,
        signaturePath: settings['office_signature_path'] ?? state.preferences.signaturePath,
        uiFont: settings['ui_font'] ?? state.preferences.uiFont,
        printFont: settings['print_font'] ?? state.preferences.printFont,
        externalBackupPath: settings['external_backup_path'] ?? '',
        workOrderDefaultPriority: int.tryParse(settings['wo_default_priority'] ?? '') ?? state.preferences.workOrderDefaultPriority,
        libraryAutoFavoritePrinciples: (settings['library_auto_favorite_principles'] ?? '1') == '1',
        lastBackupAt: lastBackupRaw != null ? DateTime.tryParse(lastBackupRaw) : state.preferences.lastBackupAt,
      ),
      security: security == null
          ? state.security
          : SecuritySettings(
              passwordHash: security.passwordHash,
              securityQuestion: security.securityQuestion,
              answerHash: security.answerHash,
              lockTimeoutMinutes: security.lockTimeoutMinutes,
              isConfigured: true,
            ),
      backups: backups
          .map(
            (b) => BackupRecord(
              id: '${b.id}',
              path: b.path,
              type: b.type,
              sizeMb: b.sizeMb ?? 0,
              includesAttachments: b.includesAttachments,
              createdAt: b.createdAt,
              status: b.status,
            ),
          )
          .toList(),
      courts: courts
          .map(
            (c) => SettingsCourtItem(
              id: '${c.id}',
              name: c.name,
              type: c.type ?? '',
              city: c.city ?? '',
              isActive: c.isActive,
            ),
          )
          .toList(),
      activityLog: logs
          .map(
            (e) => ActivityLogEntry(
              id: '${e.id}',
              action: e.action,
              tableName: e.affectedTable,
              details: e.details ?? '',
              userRef: e.userRef ?? '',
              timestamp: e.timestamp,
            ),
          )
          .toList(),
    );
    } catch (_) {
      // تبقى الحالة الحالية كما هي عند تعذر تحميل بيانات الإعدادات من قاعدة البيانات.
    }
  }

  static const _kEmail = 'office_email';
  static const _kLogo = 'office_logo_path';
  static const _kSignature = 'office_signature_path';
  static const _kUiFont = 'ui_font';
  static const _kPrintFont = 'print_font';
  static const _kBackupFolder = 'backup_folder_path';
  static const _kExternalBackup = 'external_backup_path';
  static const _kWoPriority = 'wo_default_priority';
  static const _kLibFav = 'library_auto_favorite_principles';
  static const _kLastBackup = 'last_backup_at';
  static const _kPwdHash = 'security_password_hash';
  static const _kQuestion = 'security_question';
  static const _kAnswerHash = 'security_answer_hash';
  static const _kLockTimeout = 'lock_timeout_minutes';

  static SettingsHubState _seedState() {
    final now = DateTime(2026, 7, 10);
    return SettingsHubState(
      preferences: OfficePreferences(
        officeTitle: AppConstants.defaultOfficeTitle,
        lawyerName: AppConstants.defaultLawyerName,
        officeAddress: AppConstants.defaultAddress,
        officePhone: AppConstants.defaultPhone,
        officeEmail: 'office@example.sy',
        uiFont: 'Cairo',
        printFont: 'Amiri',
        workOrderDefaultPriority: 1,
        libraryAutoFavoritePrinciples: true,
        lastBackupAt: now.subtract(const Duration(days: 3)),
      ),
      security: SecuritySettings(
        passwordHash: CryptoUtils.hashPassword('Office@2026'),
        securityQuestion: 'ما اسم مدرستك الابتدائية؟',
        answerHash: CryptoUtils.hashPassword('المجد'),
        lockTimeoutMinutes: 10,
        isConfigured: true,
      ),
      activityLog: [
        ActivityLogEntry(
          id: 'act_1',
          action: 'login',
          tableName: 'security',
          details: 'تسجيل دخول ناجح للمحامي الأستاذ',
          userRef: AppConstants.defaultLawyerName,
          timestamp: now.subtract(const Duration(hours: 2)),
        ),
        ActivityLogEntry(
          id: 'act_2',
          action: 'update',
          tableName: 'app_settings',
          details: 'تحديث بيانات الترويسة',
          userRef: AppConstants.defaultLawyerName,
          timestamp: now.subtract(const Duration(hours: 5)),
        ),
        ActivityLogEntry(
          id: 'act_3',
          action: 'export',
          tableName: 'backups',
          details: 'إنشاء نسخة احتياطية يدوية',
          userRef: AppConstants.defaultLawyerName,
          timestamp: now.subtract(const Duration(days: 3)),
        ),
      ],
      backups: [
        BackupRecord(
          id: 'bk_1',
          path: 'LawOffice_Backups/SyrLawOffice_Backup_2026-07-07.zip',
          type: 'manual',
          sizeMb: 12.4,
          includesAttachments: true,
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        BackupRecord(
          id: 'bk_2',
          path: 'LawOffice_Backups/SyrLawOffice_Backup_2026-06-30.zip',
          type: 'auto',
          sizeMb: 11.8,
          includesAttachments: true,
          createdAt: now.subtract(const Duration(days: 10)),
        ),
      ],
      courts: const [
        SettingsCourtItem(
          id: 'c1',
          name: 'محكمة البداية المدنية الأولى بدمشق',
          type: 'بداية',
          city: 'دمشق',
        ),
        SettingsCourtItem(
          id: 'c2',
          name: 'محكمة الاستئناف المدنية بدمشق',
          type: 'استئناف',
          city: 'دمشق',
        ),
        SettingsCourtItem(
          id: 'c3',
          name: 'محكمة النقض السورية - الغرفة المدنية',
          type: 'نقض',
          city: 'دمشق',
        ),
        SettingsCourtItem(
          id: 'c4',
          name: 'محكمة البداية المدنية بالسويداء',
          type: 'بداية',
          city: 'السويداء',
        ),
        SettingsCourtItem(
          id: 'c5',
          name: 'المحكمة الشرعية بالسويداء',
          type: 'شرعية',
          city: 'السويداء',
        ),
      ],
      referenceLists: const {
        'case_types': [
          SettingsLookupItem(id: 'case_civil', name: 'مدني'),
          SettingsLookupItem(id: 'case_criminal', name: 'جزائي'),
          SettingsLookupItem(id: 'case_sharia', name: 'شرعي'),
          SettingsLookupItem(id: 'case_commercial', name: 'تجاري'),
          SettingsLookupItem(id: 'case_admin', name: 'إداري'),
        ],
        'party_roles': [
          SettingsLookupItem(id: 'party_claimant', name: 'مدعي'),
          SettingsLookupItem(id: 'party_defendant', name: 'مدعى عليه'),
          SettingsLookupItem(id: 'party_appellant', name: 'مستأنف'),
          SettingsLookupItem(id: 'party_respondent', name: 'مستأنف عليه'),
        ],
        'contract_types': [
          SettingsLookupItem(id: 'contract_sale', name: 'بيع'),
          SettingsLookupItem(id: 'contract_lease', name: 'إيجار'),
          SettingsLookupItem(id: 'contract_work', name: 'عمل / خدمات'),
          SettingsLookupItem(id: 'contract_partnership', name: 'شراكة'),
          SettingsLookupItem(id: 'contract_settlement', name: 'صلح / تسوية'),
        ],
        'company_types': [
          SettingsLookupItem(id: 'company_llc', name: 'محدودة المسؤولية'),
          SettingsLookupItem(id: 'company_one_person', name: 'شخص واحد محدودة المسؤولية'),
          SettingsLookupItem(id: 'company_joint_stock', name: 'مساهمة مغفلة'),
          SettingsLookupItem(id: 'company_partnership', name: 'تضامن'),
        ],
        'procedure_types': [
          SettingsLookupItem(id: 'proc_personal', name: 'أحوال شخصية'),
          SettingsLookupItem(id: 'proc_real_estate', name: 'عقاري'),
          SettingsLookupItem(id: 'proc_commercial', name: 'تجاري'),
          SettingsLookupItem(id: 'proc_civil', name: 'مدني'),
        ],
        'bar_branches': [
          SettingsLookupItem(id: 'bar_central', name: 'نقابة المحامين المركزية'),
          SettingsLookupItem(id: 'bar_damascus', name: 'دمشق'),
          SettingsLookupItem(id: 'bar_rif_damascus', name: 'ريف دمشق'),
          SettingsLookupItem(id: 'bar_aleppo', name: 'حلب'),
          SettingsLookupItem(id: 'bar_homs', name: 'حمص'),
          SettingsLookupItem(id: 'bar_hama', name: 'حماة'),
          SettingsLookupItem(id: 'bar_lattakia', name: 'اللاذقية'),
          SettingsLookupItem(id: 'bar_tartous', name: 'طرطوس'),
          SettingsLookupItem(id: 'bar_idlib', name: 'إدلب'),
          SettingsLookupItem(id: 'bar_raqqa', name: 'الرقة'),
          SettingsLookupItem(id: 'bar_deir_ezzor', name: 'دير الزور'),
          SettingsLookupItem(id: 'bar_hasaka', name: 'الحسكة'),
          SettingsLookupItem(id: 'bar_suwayda', name: 'السويداء'),
          SettingsLookupItem(id: 'bar_daraa', name: 'درعا'),
          SettingsLookupItem(id: 'bar_quneitra', name: 'القنيطرة'),
        ],
        'expense_types': [
          SettingsLookupItem(id: 'expense_court_fee', name: 'رسم محكمة'),
          SettingsLookupItem(id: 'expense_stamps', name: 'طوابع'),
          SettingsLookupItem(id: 'expense_photocopy', name: 'تصوير'),
          SettingsLookupItem(id: 'expense_expert', name: 'خبرة'),
          SettingsLookupItem(id: 'expense_expediter', name: 'معقب'),
        ],
      },
    );
  }

  Future<void> _hydrateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = state.preferences;
      final s = state.security;
      final lastBackupRaw = prefs.getString(_kLastBackup);
      state = state.copyWith(
        preferences: p.copyWith(
          officeTitle: prefs.getString(AppConstants.keyOfficeTitle) ?? p.officeTitle,
          lawyerName: prefs.getString(AppConstants.keyLawyerName) ?? p.lawyerName,
          officeAddress: prefs.getString(AppConstants.keyOfficeAddress) ?? p.officeAddress,
          officePhone: prefs.getString(AppConstants.keyOfficePhone) ?? p.officePhone,
          officeEmail: prefs.getString(_kEmail) ?? p.officeEmail,
          logoPath: prefs.getString(_kLogo) ?? p.logoPath,
          signaturePath: prefs.getString(_kSignature) ?? p.signaturePath,
          uiFont: prefs.getString(_kUiFont) ?? p.uiFont,
          printFont: prefs.getString(_kPrintFont) ?? p.printFont,
          backupFolderPath: prefs.getString(_kBackupFolder) ?? p.backupFolderPath,
          externalBackupPath: prefs.getString(_kExternalBackup) ?? p.externalBackupPath,
          workOrderDefaultPriority: prefs.getInt(_kWoPriority) ?? p.workOrderDefaultPriority,
          libraryAutoFavoritePrinciples: prefs.getBool(_kLibFav) ?? p.libraryAutoFavoritePrinciples,
          lastBackupAt: lastBackupRaw != null ? DateTime.tryParse(lastBackupRaw) : p.lastBackupAt,
        ),
        security: s.copyWith(
          passwordHash: prefs.getString(_kPwdHash) ?? s.passwordHash,
          securityQuestion: prefs.getString(_kQuestion) ?? s.securityQuestion,
          answerHash: prefs.getString(_kAnswerHash) ?? s.answerHash,
          lockTimeoutMinutes: prefs.getInt(_kLockTimeout) ?? s.lockTimeoutMinutes,
          isConfigured: (prefs.getString(_kPwdHash) ?? s.passwordHash).isNotEmpty,
        ),
      );
    } catch (_) {
      // تبقى القيم الافتراضية عند فشل prefs (اختبارات/بيئة بلا منصة).
    }
  }

  void setActivityFilter(String query) {
    state = state.copyWith(activityFilter: query);
  }

  void _log(String action, String table, String details) {
    final entry = ActivityLogEntry(
      id: 'act_${DateTime.now().microsecondsSinceEpoch}',
      action: action,
      tableName: table,
      details: details,
      userRef: state.preferences.lawyerName,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(activityLog: [entry, ...state.activityLog]);
  }

  Future<void> saveOfficePreferences(OfficePreferences next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyOfficeTitle, next.officeTitle);
      await prefs.setString(AppConstants.keyLawyerName, next.lawyerName);
      await prefs.setString(AppConstants.keyOfficeAddress, next.officeAddress);
      await prefs.setString(AppConstants.keyOfficePhone, next.officePhone);
      await prefs.setString(_kEmail, next.officeEmail);
      await prefs.setString(_kLogo, next.logoPath);
      await prefs.setString(_kSignature, next.signaturePath);
      await prefs.setString(_kUiFont, next.uiFont);
      await prefs.setString(_kPrintFont, next.printFont);
      await prefs.setString(_kBackupFolder, next.backupFolderPath);
      await prefs.setString(_kExternalBackup, next.externalBackupPath);
      await prefs.setInt(_kWoPriority, next.workOrderDefaultPriority);
      await prefs.setBool(_kLibFav, next.libraryAutoFavoritePrinciples);
      if (next.lastBackupAt != null) {
        await prefs.setString(_kLastBackup, next.lastBackupAt!.toIso8601String());
      }
    } catch (_) {}

    state = state.copyWith(
      preferences: next,
      lastMessage: 'تم حفظ إعدادات المكتب',
    );
    _log('update', 'app_settings', 'تحديث بيانات المكتب والترويسة والتفضيلات');
  }

  /// تحديث كلمة المرور وسؤال الأمان بعد التحقق من الحالية.
  Future<String?> updateSecurity({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
    required String securityQuestion,
    required String securityAnswer,
    int? lockTimeoutMinutes,
  }) async {
    if (!CryptoUtils.verifyPassword(currentPassword, state.security.passwordHash)) {
      return 'كلمة المرور الحالية غير صحيحة';
    }
    if (newPassword.length < 6) {
      return 'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف';
    }
    if (newPassword != confirmPassword) {
      return 'تأكيد كلمة المرور غير مطابق';
    }
    if (securityQuestion.trim().isEmpty || securityAnswer.trim().isEmpty) {
      return 'سؤال الأمان وإجابته إلزاميان';
    }

    final next = state.security.copyWith(
      passwordHash: CryptoUtils.hashPassword(newPassword),
      securityQuestion: securityQuestion.trim(),
      answerHash: CryptoUtils.hashPassword(securityAnswer.trim()),
      lockTimeoutMinutes: lockTimeoutMinutes ?? state.security.lockTimeoutMinutes,
      isConfigured: true,
    );

    final repo = _repository;
    if (repo != null) {
      final err = await repo.updateSecurity(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
        lockTimeoutMinutes: lockTimeoutMinutes ?? state.security.lockTimeoutMinutes,
        userRef: state.preferences.lawyerName,
      );
      if (err != null) return err;
      await _loadFromDb();
      state = state.copyWith(lastMessage: 'تم تحديث بيانات الأمان');
      return null;
    }

    // ignore: unawaited_futures
    _safePrefsWrite((prefs) async {
      await prefs.setString(_kPwdHash, next.passwordHash);
      await prefs.setString(_kQuestion, next.securityQuestion);
      await prefs.setString(_kAnswerHash, next.answerHash);
      await prefs.setInt(_kLockTimeout, next.lockTimeoutMinutes);
    });

    state = state.copyWith(security: next, lastMessage: 'تم تحديث بيانات الأمان');
    _log('update', 'security', 'تغيير كلمة المرور/سؤال الأمان/مهلة القفل');
    return null;
  }

  Future<void> _safePrefsWrite(Future<void> Function(SharedPreferences prefs) writer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await writer(prefs);
    } catch (_) {
      // بيئة اختبار أو منصة بلا prefs.
    }
  }

  bool verifySecurityAnswer(String answer) {
    return CryptoUtils.verifyPassword(answer.trim(), state.security.answerHash);
  }

  /// إنشاء نسخة احتياطية (BackupService الحقيقي عند توفر المستودع).
  Future<BackupRecord> createBackup({
    bool includeAttachments = true,
    String type = 'manual',
    String? customPath,
  }) async {
    state = state.copyWith(isBusy: true);
    final now = DateTime.now();
    final repo = _repository;
    if (repo != null) {
      try {
        final path = await repo.createBackup(
          includeAttachments: includeAttachments,
          type: type,
          customPath: customPath ?? (state.preferences.externalBackupPath.isEmpty ? null : state.preferences.externalBackupPath),
          userRef: state.preferences.lawyerName,
        );
        await _loadFromDb();
        state = state.copyWith(isBusy: false, lastMessage: 'تم إنشاء نسخة احتياطية: $path');
        return BackupRecord(
          id: 'bk_${now.microsecondsSinceEpoch}',
          path: path,
          type: type,
          sizeMb: 0,
          includesAttachments: includeAttachments,
          createdAt: now,
        );
      } catch (e) {
        state = state.copyWith(isBusy: false, lastMessage: 'فشل النسخ: $e');
        rethrow;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 10));
    final stamp = now.toIso8601String().replaceAll(':', '-').substring(0, 19);
    final folder = customPath?.isNotEmpty == true
        ? customPath!
        : (state.preferences.externalBackupPath.isNotEmpty
            ? state.preferences.externalBackupPath
            : 'LawOffice_Backups');
    final record = BackupRecord(
      id: 'bk_${now.microsecondsSinceEpoch}',
      path: '$folder/SyrLawOffice_Backup_$stamp.zip',
      type: type,
      sizeMb: includeAttachments ? 12.6 : 3.2,
      includesAttachments: includeAttachments,
      createdAt: now,
    );
    final prefs = state.preferences.copyWith(lastBackupAt: now);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kLastBackup, now.toIso8601String());
    } catch (_) {}
    state = state.copyWith(
      isBusy: false,
      backups: [record, ...state.backups],
      preferences: prefs,
      lastMessage: 'تم إنشاء نسخة احتياطية: ${record.path}',
    );
    _log('export', 'backups', 'نسخ احتياطي ($type) — ${record.path}');
    return record;
  }

  /// محاكاة استعادة نسخة.
  Future<bool> restoreBackup(String backupId) async {
    final exists = state.backups.any((b) => b.id == backupId);
    if (!exists) return false;
    _log('import', 'backups', 'استعادة النسخة $backupId');
    state = state.copyWith(lastMessage: 'تمت استعادة النسخة بنجاح');
    return true;
  }

  void setExternalBackupPath(String path) {
    final next = state.preferences.copyWith(externalBackupPath: path);
    state = state.copyWith(preferences: next, lastMessage: 'تم تعيين مسار النسخ الخارجي');
    // ignore: unawaited_futures
    _safePrefsWrite((p) => p.setString(_kExternalBackup, path));
    _log('update', 'backups', 'تعيين مسار خارجي: $path');
  }

  void addCourt(SettingsCourtItem court) {
    state = state.copyWith(courts: [court, ...state.courts], lastMessage: 'تمت إضافة محكمة');
    _log('insert', 'courts', 'إضافة محكمة: ${court.name}');
    // الحفظ الفعلي: المحاكم قائمة مرجعية تُستخدم في الدعاوى ونقل المراحل،
    // فبقاؤها في الذاكرة فقط يجعلها تختفي عند إعادة التشغيل.
    final repo = _repository;
    if (repo == null) return;
    repo
        .addCourt(
          name: court.name,
          type: court.type.isEmpty ? null : court.type,
          city: court.city.isEmpty ? null : court.city,
        )
        .then((_) => _reloadCourts())
        .catchError((_) => 0);
  }

  /// إعادة تحميل قائمة المحاكم من قاعدة البيانات بعد أي تعديل.
  Future<void> _reloadCourts() async {
    final repo = _repository;
    if (repo == null) return;
    try {
      final courts = await repo.getAllCourtsIncludingInactive();
      state = state.copyWith(
        courts: courts
            .map((c) => SettingsCourtItem(
                  id: '${c.id}',
                  name: c.name,
                  type: c.type ?? '',
                  city: c.city ?? '',
                  isActive: c.isActive,
                ))
            .toList(),
      );
    } catch (_) {
      // تُترك الحالة الحالية إن تعذّرت القراءة.
    }
  }

  void updateCourt(SettingsCourtItem court) {
    state = state.copyWith(
      courts: state.courts.map((c) => c.id == court.id ? court : c).toList(),
      lastMessage: 'تم تعديل المحكمة',
    );
    _log('update', 'courts', 'تعديل محكمة: ${court.name}');
    final repo = _repository;
    final id = int.tryParse(court.id);
    if (repo == null || id == null) return;
    repo
        .updateCourt(
          id: id,
          name: court.name,
          type: court.type.isEmpty ? null : court.type,
          city: court.city.isEmpty ? null : court.city,
        )
        .then((_) => _reloadCourts())
        .catchError((_) {});
  }

  void setCourtActive(String id, bool active) {
    final court = state.courts.where((c) => c.id == id).firstOrNull;
    if (court == null) return;
    state = state.copyWith(
      courts: state.courts.map((c) => c.id == id ? c.copyWith(isActive: active) : c).toList(),
      lastMessage: active ? 'تم تفعيل المحكمة' : 'تم تعطيل المحكمة',
    );
    _log(active ? 'enable' : 'disable', 'courts', active ? 'تفعيل محكمة: ${court.name}' : 'تعطيل محكمة: ${court.name}');
    final repo = _repository;
    final numericId = int.tryParse(id);
    if (repo == null || numericId == null) return;
    repo
        .setCourtActive(id: numericId, active: active, name: court.name)
        .then((_) => _reloadCourts())
        .catchError((_) {});
  }

  /// حذف محكمة. يُرفض الحذف إذا كانت مستخدمة في دعاوى، وتُعاد رسالة السبب.
  Future<String?> deleteCourt(String id) async {
    final court = state.courts.where((c) => c.id == id).firstOrNull;
    if (court == null) return null;
    final repo = _repository;
    final numericId = int.tryParse(id);

    if (repo != null && numericId != null) {
      final error = await repo.deleteCourt(id: numericId, name: court.name);
      if (error != null) {
        state = state.copyWith(lastMessage: error);
        return error;
      }
      await _reloadCourts();
      state = state.copyWith(lastMessage: 'تم حذف المحكمة من القائمة المرجعية');
      _log('delete', 'courts', 'حذف محكمة غير مستخدمة: ${court.name}');
      return null;
    }

    state = state.copyWith(
      courts: state.courts.where((c) => c.id != id).toList(),
      lastMessage: 'تم حذف المحكمة من القائمة المرجعية',
    );
    _log('delete', 'courts', 'حذف محكمة غير مستخدمة: ${court.name}');
    return null;
  }


  /// مفتاح تخزين القوائم المرجعية في جدول app_settings.
  static const String _lookupsSettingKey = 'reference_lookups_json';

  /// حفظ كل القوائم المرجعية كـ JSON.
  ///
  /// القوائم كانت ثابتة في الكود بلا أي تخزين، فأي إضافة أو حذف يجريه
  /// المكتب يختفي عند إعادة التشغيل.
  Future<void> _persistLookups() async {
    final repo = _repository;
    if (repo == null) return;
    try {
      final payload = state.referenceLists.map(
        (key, items) => MapEntry(
          key,
          items
              .map((e) => {
                    'id': e.id,
                    'name': e.name,
                    'category': e.category,
                    'notes': e.notes,
                    'isActive': e.isActive,
                  })
              .toList(),
        ),
      );
      await repo.setSetting(_lookupsSettingKey, jsonEncode(payload));
    } catch (_) {
      // تُترك الحالة الحالية إن تعذّرت الكتابة.
    }
  }

  /// قراءة القوائم المرجعية المحفوظة إن وُجدت.
  Future<void> _loadLookups() async {
    final repo = _repository;
    if (repo == null) return;
    try {
      final raw = await repo.getSetting(_lookupsSettingKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final restored = <String, List<SettingsLookupItem>>{};
      decoded.forEach((key, value) {
        restored[key] = (value as List)
            .map((e) => SettingsLookupItem(
                  id: e['id'] as String,
                  name: e['name'] as String,
                  category: (e['category'] as String?) ?? '',
                  notes: (e['notes'] as String?) ?? '',
                  isActive: (e['isActive'] as bool?) ?? true,
                ))
            .toList();
      });
      if (restored.isNotEmpty) {
        state = state.copyWith(referenceLists: restored);
      }
    } catch (_) {
      // تبقى القوائم الافتراضية إن فسدت البيانات المحفوظة.
    }
  }

  void upsertLookup(String listKey, SettingsLookupItem item) {
    final current = [...(state.referenceLists[listKey] ?? const <SettingsLookupItem>[])];
    final index = current.indexWhere((e) => e.id == item.id);
    if (index == -1) {
      current.insert(0, item);
      _log('insert', listKey, 'إضافة عنصر مرجعي: ${item.name}');
    } else {
      current[index] = item;
      _log('update', listKey, 'تعديل عنصر مرجعي: ${item.name}');
    }
    state = state.copyWith(
      referenceLists: {...state.referenceLists, listKey: current},
      lastMessage: 'تم حفظ القائمة المرجعية',
    );
    _persistLookups();
  }

  void setLookupActive(String listKey, String id, bool active) {
    final current = [...(state.referenceLists[listKey] ?? const <SettingsLookupItem>[])];
    final index = current.indexWhere((e) => e.id == id);
    if (index == -1) return;
    current[index] = current[index].copyWith(isActive: active);
    state = state.copyWith(referenceLists: {...state.referenceLists, listKey: current});
    _log(active ? 'enable' : 'disable', listKey, '${active ? 'تفعيل' : 'تعطيل'} عنصر مرجعي: ${current[index].name}');
    _persistLookups();
  }

  void deleteLookup(String listKey, String id) {
    final current = [...(state.referenceLists[listKey] ?? const <SettingsLookupItem>[])];
    final item = current.where((e) => e.id == id).firstOrNull;
    if (item == null) return;
    state = state.copyWith(
      referenceLists: {...state.referenceLists, listKey: current.where((e) => e.id != id).toList()},
      lastMessage: 'تم حذف العنصر المرجعي',
    );
    _log('delete', listKey, 'حذف عنصر مرجعي غير مستخدم: ${item.name}');
    _persistLookups();
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }
}

Color priorityColor(int priority) {
  switch (priority) {
    case 2:
      return AppColors.error;
    case 0:
      return AppColors.success;
    default:
      return AppColors.warning;
  }
}

String priorityLabel(int priority) {
  switch (priority) {
    case 2:
      return 'عالية';
    case 0:
      return 'منخفضة';
    default:
      return 'متوسطة';
  }
}


extension SettingsFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
