import 'package:flutter/material.dart';

/// ثوابت التطبيق الأساسية لنظام إدارة وأرشفة مكتب محاماة سوري (V6.2)
class AppConstants {
  // ---------------------------------------------------------------------------
  // بيانات المكتب الأساسية (قابلة للتعديل ديناميكياً من شاشة الإعدادات)
  // ---------------------------------------------------------------------------
  static const String appDisplayName = 'ميزان';
  static const String appTagline = 'المنصة الرقمية للمحامي';
  static const String appWindowTitle = 'ميزان - المنصة الرقمية للمحامي';
  static const String appIconAsset = 'assets/icons/app_icon.png';
  static const String appBrandLockupAsset = 'assets/icons/mezan_brand_lockup.png';

  static const String defaultOfficeTitle = 'مكتب المحامي';
  static const String defaultLawyerName = 'هادي فيصل البني';
  static const String defaultCountry = 'الجمهورية العربية السورية';
  static const String defaultCurrency = 'ل.س'; // الليرة السورية
  static const String defaultPhone = '';
  static const String defaultAddress = 'سوريا - السويداء / دمشق';

  // مفاتيح الحفظ في الإعدادات (AppSettings / SharedPreferences)
  static const String keyOfficeTitle = 'office_title';
  static const String keyLawyerName = 'lawyer_name';
  static const String keyOfficeAddress = 'office_address';
  static const String keyOfficePhone = 'office_phone';
  static const String keyOfficeEmail = 'office_email';
  static const String keyOfficeLogoPath = 'office_logo_path';
  static const String keyLockTimeout = 'lock_timeout_minutes';
  static const String keyBackupFolder = 'backup_folder_path';

  // ---------------------------------------------------------------------------
  // مسارات النظام والتخزين المحلي (Offline Filesystem)
  // ---------------------------------------------------------------------------
  static const String appDataDirectoryName = 'LawOffice';
  static const String filesDirectoryName = 'files';
  static const String backupsDirectoryName = 'LawOffice_Backups';
  static const String defaultDatabaseName = 'law_office_encrypted.db';
  
  // مجلدات المرفقات المنظمة
  static const String casesFolder = 'cases';
  static const String contractsFolder = 'contracts';
  static const String companiesFolder = 'companies';
  static const String adminProceduresFolder = 'admin_procedures';
  static const String poaFolder = 'powers_of_attorney';
  static const String templatesFolder = 'templates';

  // ---------------------------------------------------------------------------
  // الألوان الرسمية المعتمدة للمكتب القانوني السوري
  // ---------------------------------------------------------------------------
  static const Color primaryNavy = Color(0xFF0F2027);      // أزرق كحلي داكن للمحاماة
  static const Color secondaryNavy = Color(0xFF203A43);    // أزرق بترولي
  static const Color accentGold = Color(0xFFC5A059);       // ذهبي قانوني كلاسيكي
  static const Color accentGoldDark = Color(0xFF9E7D3B);   // ذهبي داكن للحدود
  
  static const Color backgroundLight = Color(0xFFF8F9FA);  // خلفية ناصعة ومريحة للعامين على Windows
  static const Color surfaceWhite = Color(0xFFFFFFFF);     // لون البطاقات
  static const Color textDark = Color(0xFF1A1A1A);         // لون نصوص القراءة الحادة
  static const Color textMuted = Color(0xFF6C757D);        // لون النصوص الفرعية
  
  // ألوان الحالات والنواقص
  static const Color statusSuccess = Color(0xFF28A745);    // تمت / نشط
  static const Color statusWarning = Color(0xFFFFC107);    // مؤجل / تنبيه
  static const Color statusDanger = Color(0xFFDC3545);     // نقص إلزامي / ملغى / طارئ
  static const Color statusInfo = Color(0xFF17A2B8);       // قيد التنفيذ / جاري

  // ---------------------------------------------------------------------------
  // إعدادات الطباعة القانونية وتصدير PDF
  // ---------------------------------------------------------------------------
  static const String defaultPrintFont = 'Cairo'; // أو Amiri للعقود والمذكرات القضائية
  static const double defaultPageMarginMm = 20.0;
}
