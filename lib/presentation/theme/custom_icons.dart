/// أيقونات مخصصة لتطبيق مكتب المحامي
/// 
/// هذا الملف يحدد الأيقونات المخصصة أو المختارة من FontAwesome/Material
/// حسب مواصفات PRODUCT_REDESIGN_MASTER_PLAN.md - القسم 2.1
/// 
/// آخر تحديث: 2026-07-09

import 'package:flutter/material.dart';

/// أيقونات Material المختارة (مضمونة مع Flutter)
class CustomIcons {
  // ===========================================================================
  // أيقونات التبويبات الرئيسية (11 تبويب)
  // ===========================================================================
  
  /// 1. لوحة اليوم
  static const IconData todayDashboard = Icons.dashboard;
  
  /// 2. الأجندة
  static const IconData agenda = Icons.calendar_today;
  
  /// 3. عمل جديد
  static const IconData newWork = Icons.add_circle_outline;
  
  /// 4. الملفات
  static const IconData files = Icons.folder;
  
  /// 5. الأشخاص والجهات
  static const IconData persons = Icons.people;
  
  /// 6. أوامر العمل للمعقب
  static const IconData workOrders = Icons.assignment;
  
  /// 7. المالية
  static const IconData finance = Icons.attach_money;
  
  /// 8. المستندات
  static const IconData documents = Icons.description;
  
  /// 9. المكتبة القانونية السورية
  static const IconData legalLibrary = Icons.library_books;
  
  /// 10. البحث والتقارير
  static const IconData searchReports = Icons.search;
  
  /// 11. الإعدادات
  static const IconData settings = Icons.settings;
  
  // ===========================================================================
  // أيقونات SideBar (بديل للأيقونات الرئيسية)
  // ===========================================================================
  
  /// لوحة اليوم (بديل)
  static const IconData todayDashboardAlt = Icons.dashboard_outlined;
  
  /// الأجندة (بديل)
  static const IconData agendaAlt = Icons.calendar_month;
  
  /// عمل جديد (بديل)
  static const IconData newWorkAlt = Icons.add_circle;
  
  /// الملفات (بديل)
  static const IconData filesAlt = Icons.folder_open;
  
  /// الأشخاص والجهات (بديل)
  static const IconData personsAlt = Icons.group;
  
  /// أوامر العمل (بديل)
  static const IconData workOrdersAlt = Icons.task;
  
  /// المالية (بديل)
  static const IconData financeAlt = Icons.account_balance_wallet;
  
  /// المستندات (بديل)
  static const IconData documentsAlt = Icons.article;
  
  /// المكتبة القانونية (بديل)
  static const IconData legalLibraryAlt = Icons.auto_stories;
  
  /// البحث والتقارير (بديل)
  static const IconData searchReportsAlt = Icons.manage_search;
  
  /// الإعدادات (بديل)
  static const IconData settingsAlt = Icons.settings_applications;
  
  // ===========================================================================
  // أيقونات لوحات التحكم (Dashboard)
  // ===========================================================================
  
  /// جلسات اليوم
  static const IconData todaySessions = Icons.gavel;
  
  /// مراجعات اليوم
  static const IconData todayReviews = Icons.rate_review;
  
  /// أوامر عمل بانتظار نتيجة
  static const IconData pendingWorkOrders = Icons.hourglass_empty;
  
  /// نتائج بانتظار اعتماد
  static const IconData pendingResults = Icons.pending;
  
  /// متأخرات
  static const IconData overdue = Icons.warning;
  
  /// نواقص حرجة
  static const IconData criticalDeficiencies = Icons.error;
  
  /// مصاريف اليوم
  static const IconData todayExpenses = Icons.money_off;
  
  // ===========================================================================
  // أيقونات الأجندة (Agenda)
  // ===========================================================================
  
  /// جدول المحكمة
  static const IconData courtSchedule = Icons.calendar_view_day;
  
  /// المراجعات الإدارية
  static const IconData adminReviews = Icons.assignment_ind;
  
  /// المتأخرات
  static const IconData overdueTasks = Icons.alarm;
  
  /// منجز اليوم
  static const IconData todayCompleted = Icons.check_circle;
  
  /// مصاريف اليوم
  static const IconData dailyExpenses = Icons.monetization_on;
  
  /// تحضير الغد
  static const IconData prepareTomorrow = Icons.date_range;
  
  // ===========================================================================
  // أيقونات عمل جديد (New Work)
  // ===========================================================================
  
  /// بدء عمل جديد
  static const IconData startNewWork = Icons.add;
  
  /// أرشفة عمل سابق
  static const IconData archivePreviousWork = Icons.archive;
  
  /// دعوى قضائية
  static const IconData litigation = Icons.gavel;
  
  /// عقد
  static const IconData contract = Icons.description;
  
  /// شركة
  static const IconData company = Icons.business;
  
  /// إجراء إداري
  static const IconData adminProcedure = Icons.assignment;
  
  /// وكالة
  static const IconData powerOfAttorney = Icons.verified_user;
  
  /// شخص أو جهة
  static const IconData personOrEntity = Icons.person;
  
  /// مستند مستقل
  static const IconData standaloneDocument = Icons.insert_drive_file;
  
  /// أمر عمل للمعقب
  static const IconData workOrderForFollower = Icons.assignment_ind;
  
  /// مهمة يدوية
  static const IconData manualTask = Icons.task;
  
  // ===========================================================================
  // أيقونات الملفات (Files)
  // ===========================================================================
  
  /// دعاوى
  static const IconData cases = Icons.gavel;
  
  /// عقود
  static const IconData contracts = Icons.description;
  
  /// شركات
  static const IconData companies = Icons.business;
  
  /// إجراءات إدارية
  static const IconData procedures = Icons.assignment;
  
  /// وكالات
  static const IconData agencies = Icons.verified_user;
  
  /// مستندات مرتبطة
  static const IconData linkedDocuments = Icons.attach_file;
  
  // ===========================================================================
  // أيقونات الأشخاص والجهات (Persons & Entities)
  // ===========================================================================
  
  /// موكلون
  static const IconData clients = Icons.person;
  
  /// خصوم
  static const IconData opponents = Icons.person_off;
  
  /// محامو خصوم
  static const IconData opponentLawyers = Icons.gavel;
  
  /// كتاب عدل
  static const IconData notaries = Icons.verified;
  
  /// مندوبو نقابة
  static const IconData barDelegates = Icons.people_alt;
  
  /// فريق المكتب
  static const IconData officeTeam = Icons.group;
  
  /// شركات وجهات اعتبارية
  static const IconData legalEntities = Icons.business;
  
  // ===========================================================================
  // أيقونات أوامر العمل (Work Orders)
  // ===========================================================================
  
  /// مراجعة ديوان
  static const IconData reviewOffice = Icons.folder_open;
  
  /// حضور جلسة
  static const IconData attendSession = Icons.gavel;
  
  /// تصوير ضبط
  static const IconData photographDocument = Icons.camera_alt;
  
  /// دفع رسم
  static const IconData payFee = Icons.payment;
  
  /// استخراج صورة طبق الأصل
  static const IconData extractCopy = Icons.copy;
  
  /// تنظيم وكالة
  static const IconData organizeAgency = Icons.verified_user;
  
  /// مراجعة كاتب عدل
  static const IconData reviewNotary = Icons.verified;
  
  /// متابعة تبليغ
  static const IconData followUpNotification = Icons.notifications;
  
  /// مراجعة تنفيذ
  static const IconData reviewExecution = Icons.check;
  
  /// مراجعة سجل تجاري
  static const IconData reviewCommercialRegistry = Icons.business;
  
  /// مراجعة مالية
  static const IconData reviewFinancial = Icons.monetization_on;
  
  // ===========================================================================
  // أيقونات المالية (Finance)
  // ===========================================================================
  
  /// اتفاقيات الأتعاب
  static const IconData feeAgreements = Icons.handshake;
  
  /// سندات القبض
  static const IconData receipts = Icons.receipt;
  
  /// مصاريف الملفات
  static const IconData caseExpenses = Icons.money_off;
  
  /// مصاريف المعقبين
  static const IconData followerExpenses = Icons.monetization_on;
  
  /// ذمم الموكلين
  static const IconData clientAccounts = Icons.account_balance;
  
  /// كشف مالي
  static const IconData financialReport = Icons.assessment;
  
  /// طباعة إيصال
  static const IconData printReceipt = Icons.print;
  
  // ===========================================================================
  // أيقونات المستندات (Documents)
  // ===========================================================================
  
  /// مستندات الدعاوى
  static const IconData caseDocuments = Icons.gavel;
  
  /// الوكالات
  static const IconData poaDocuments = Icons.verified_user;
  
  /// العقود
  static const IconData contractDocuments = Icons.description;
  
  /// الشركات
  static const IconData companyDocuments = Icons.business;
  
  /// الإجراءات
  static const IconData procedureDocuments = Icons.assignment;
  
  /// إيصالات
  static const IconData receiptDocuments = Icons.receipt;
  
  /// مذكرات
  static const IconData memoDocuments = Icons.note;
  
  /// قرارات
  static const IconData decisionDocuments = Icons.check;
  
  // ===========================================================================
  // أيقونات المكتبة القانونية (Legal Library)
  // ===========================================================================
  
  /// قوانين
  static const IconData laws = Icons.rule;
  
  /// اجتهادات محكمة النقض
  static const IconData precedents = Icons.balance;
  
  /// مجلة المحامون
  static const IconData lawyersJournal = Icons.auto_stories;
  
  /// مبادئ مختارة
  static const IconData selectedPrinciples = Icons.star;
  
  /// مفضلة المحامي
  static const IconData favorites = Icons.favorite;
  
  /// بحث قانوني
  static const IconData legalSearch = Icons.search;
  
  // ===========================================================================
  // أيقونات البحث والتقارير (Search & Reports)
  // ===========================================================================
  
  /// كشف جلسات
  static const IconData sessionReport = Icons.gavel;
  
  /// كشف متأخرات
  static const IconData overdueReport = Icons.warning;
  
  /// كشف ملفات ناقصة
  static const IconData deficiencyReport = Icons.error;
  
  /// كشف مالية
  static const IconData financialReportIcon = Icons.assessment;
  
  /// كشف أوامر عمل
  static const IconData workOrderReport = Icons.assignment;
  
  /// كشف مكتبة
  static const IconData libraryReport = Icons.library_books;
  
  /// مذكرات قانونية
  static const IconData legalMemoReport = Icons.note;
  
  // ===========================================================================
  // أيقونات الإعدادات (Settings)
  // ===========================================================================
  
  /// بيانات المكتب
  static const IconData officeData = Icons.home;
  
  /// الشعار
  static const IconData logo = Icons.image;
  
  /// التوقيع
  static const IconData signature = Icons.draw;
  
  /// الخطوط
  static const IconData fonts = Icons.font_download;
  
  /// النسخ الاحتياطي
  static const IconData backup = Icons.backup;
  
  /// الأمان
  static const IconData security = Icons.security;
  
  /// القوائم المرجعية
  static const IconData referenceLists = Icons.list;
  
  /// إعدادات أوامر العمل
  static const IconData workOrderSettings = Icons.assignment;
  
  /// إعدادات المكتبة
  static const IconData librarySettings = Icons.library_books;
  
  // ===========================================================================
  // أيقونات الأزرار (Action Buttons)
  // ===========================================================================
  
  /// إضافة
  static const IconData add = Icons.add;
  
  /// تعديل
  static const IconData edit = Icons.edit;
  
  /// حذف
  static const IconData delete = Icons.delete;
  
  /// حفظ
  static const IconData save = Icons.save;
  
  /// إلغاء
  static const IconData cancel = Icons.cancel;
  
  /// تأكيد
  static const IconData confirm = Icons.check;
  
  /// بحث
  static const IconData search = Icons.search;
  
  /// فلترة
  static const IconData filter = Icons.filter_alt;
  
  /// فرز
  static const IconData sort = Icons.sort;
  
  /// طباعة
  static const IconData print = Icons.print;
  
  /// تصدير PDF
  static const IconData exportPdf = Icons.picture_as_pdf;
  
  /// تصدير Excel
  static const IconData exportExcel = Icons.grid_view;
  
  /// إرفاق ملف
  static const IconData attachFile = Icons.attach_file;
  
  /// فتح ملف
  static const IconData openFile = Icons.open_in_new;
  
  /// نسخ
  static const IconData copy = Icons.copy;
  
  /// لصق
  static const IconData paste = Icons.paste;
  
  /// قص
  static const IconData cut = Icons.content_cut;
  
  /// استعادة
  static const IconData restore = Icons.restore;
  
  /// مسح
  static const IconData clear = Icons.clear;
  
  // ===========================================================================
  // أيقونات الحالة (Status Icons)
  // ===========================================================================
  
  /// نشط
  static const IconData active = Icons.check_circle;
  
  /// غير نشط
  static const IconData inactive = Icons.radio_button_unchecked;
  
  /// مكتمل
  static const IconData completed = Icons.check_circle_outline;
  
  /// قيد التنفيذ
  static const IconData inProgress = Icons.sync;
  
  /// مؤجل
  static const IconData postponed = Icons.pause_circle;
  
  /// ملغى
  static const IconData cancelled = Icons.cancel_outlined;
  
  /// متوقف
  static const IconData stopped = Icons.stop;
  
  /// يحتاج مراجعة
  static const IconData needsReview = Icons.warning;
  
  /// مهم
  static const IconData important = Icons.priority_high;
  
  /// عادي
  static const IconData normal = Icons.info;
  
  /// منخفض الأولوية
  static const IconData lowPriority = Icons.arrow_downward;
  
  // ===========================================================================
  // أيقونات التنقل (Navigation)
  // ===========================================================================
  
  /// رجوع
  static const IconData back = Icons.arrow_back;
  
  /// التقدم
  static const IconData forward = Icons.arrow_forward;
  
  /// إلى الأعلى
  static const IconData up = Icons.arrow_upward;
  
  /// إلى الأسفل
  static const IconData down = Icons.arrow_downward;
  
  /// إلى اليمين
  static const IconData right = Icons.arrow_forward;
  
  /// إلى اليسار
  static const IconData left = Icons.arrow_back;
  
  /// توسيع
  static const IconData expand = Icons.expand;
  
  /// طي
  static const IconData collapse = Icons.expand_less;
  
  /// قائمة
  static const IconData menu = Icons.menu;
  
  /// إغلاق
  static const IconData close = Icons.close;
  
  // ===========================================================================
  // أيقونات الاجتماعية (Social)
  // ===========================================================================
  
  /// واتساب
  static const IconData whatsapp = Icons.message;
  
  /// بريد إلكتروني
  static const IconData email = Icons.email;
  
  /// هاتف
  static const IconData phone = Icons.phone;
  
  /// موقع إلكتروني
  static const IconData website = Icons.language;
  
  // ===========================================================================
  /// الحصول على أيقونة حسب الاسم (Helper Function)
  // ===========================================================================
  
  static IconData? getIconByName(String name) {
    final iconMap = <String, IconData>{
      'todayDashboard': todayDashboard,
      'agenda': agenda,
      'newWork': newWork,
      'files': files,
      'persons': persons,
      'workOrders': workOrders,
      'finance': finance,
      'documents': documents,
      'legalLibrary': legalLibrary,
      'searchReports': searchReports,
      'settings': settings,
      'add': add,
      'edit': edit,
      'delete': delete,
      'save': save,
      'cancel': cancel,
      'search': search,
      'print': print,
      'exportPdf': exportPdf,
    };
    
    return iconMap[name];
  }
}
