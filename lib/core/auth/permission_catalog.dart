class PermissionGroup {
  final String key;
  final String label;
  const PermissionGroup(this.key, this.label);
}

class PermissionDefinition {
  final String key;
  final String label;
  final String group;
  final String description;
  final bool sensitive;
  const PermissionDefinition({
    required this.key,
    required this.label,
    required this.group,
    required this.description,
    this.sensitive = false,
  });
}

class PermissionKeys {
  static const settingsView = 'settings.view';
  static const settingsOfficeEdit = 'settings.office.edit';
  static const settingsSecurityEdit = 'settings.security.edit';
  static const settingsBackupCreate = 'settings.backup.create';
  static const settingsBackupRestore = 'settings.backup.restore';
  static const settingsLookupsManage = 'settings.lookups.manage';
  static const settingsUsersManage = 'settings.users.manage';
  static const auditView = 'audit.view';
  static const auditExport = 'audit.export';
  static const sessionsView = 'sessions.view';

  static const personsView = 'persons.view';
  static const personsCreate = 'persons.create';
  static const personsEdit = 'persons.edit';
  static const personsArchive = 'persons.archive';
  static const personsSensitiveView = 'persons.sensitive.view';

  static const poaView = 'poa.view';
  static const poaCreate = 'poa.create';
  static const poaEdit = 'poa.edit';
  static const poaArchive = 'poa.archive';
  static const poaFilesView = 'poa.files.view';

  static const casesView = 'cases.view';
  static const casesCreateNew = 'cases.create_new';
  static const casesArchiveOld = 'cases.archive_old';
  static const casesEdit = 'cases.edit';
  static const casesSessionsManage = 'cases.sessions.manage';
  static const casesResultEnter = 'cases.result.enter';
  static const casesClose = 'cases.close';
  static const casesArchive = 'cases.archive';

  static const contractsView = 'contracts.view';
  static const contractsCreate = 'contracts.create';
  static const contractsEdit = 'contracts.edit';
  static const contractsRemindersManage = 'contracts.reminders.manage';
  static const contractsArchive = 'contracts.archive';

  static const companiesView = 'companies.view';
  static const companiesCreate = 'companies.create';
  static const companiesEdit = 'companies.edit';
  static const companiesPhasesManage = 'companies.phases.manage';
  static const companiesArchive = 'companies.archive';

  static const proceduresView = 'procedures.view';
  static const proceduresCreate = 'procedures.create';
  static const proceduresEdit = 'procedures.edit';
  static const proceduresStepsManage = 'procedures.steps.manage';
  static const proceduresArchive = 'procedures.archive';

  static const documentsView = 'documents.view';
  static const documentsUpload = 'documents.upload';
  static const documentsOpen = 'documents.open';
  static const documentsEdit = 'documents.edit';
  static const documentsDelete = 'documents.delete';
  static const documentsExport = 'documents.export';

  static const financeView = 'finance.view';
  static const financeAgreementsCreate = 'finance.agreements.create';
  static const financeAgreementsEdit = 'finance.agreements.edit';
  static const financePaymentsCreate = 'finance.payments.create';
  static const financeExpensesCreate = 'finance.expenses.create';
  static const financeReportsView = 'finance.reports.view';
  static const financeDelete = 'finance.delete';

  static const workOrdersView = 'work_orders.view';
  static const workOrdersCreate = 'work_orders.create';
  static const workOrdersPrint = 'work_orders.print';
  static const workOrdersSend = 'work_orders.send';
  static const workOrdersResultEnter = 'work_orders.result.enter';
  static const workOrdersApprove = 'work_orders.approve';
  static const workOrdersAttachmentsUpload = 'work_orders.attachments.upload';
  static const workOrdersAttachmentsView = 'work_orders.attachments.view';
  static const workOrdersAttachmentsDelete = 'work_orders.attachments.delete';

  static const reportsView = 'reports.view';
  static const reportsExport = 'reports.export';
  static const searchView = 'search.view';

  static const libraryView = 'library.view';
  static const libraryAdd = 'library.add';
  static const libraryEdit = 'library.edit';
  static const libraryDelete = 'library.delete';
  static const libraryLink = 'library.link';

  static const templatesView = 'templates.view';
  static const templatesImport = 'templates.import';
  static const templatesCreate = 'templates.create';
  static const templatesEdit = 'templates.edit';
  static const templatesDisable = 'templates.disable';
  static const templatesGenerateDocument = 'templates.generate_document';

  static const archiveIntakeView = 'archive.intake.view';
  static const archiveIntakeCreate = 'archive.intake.create';
  static const archiveIntakeImportFiles = 'archive.intake.import_files';
  static const archiveIntakeImportExcel = 'archive.intake.import_excel';
  static const archiveIntakeReview = 'archive.intake.review';
  static const archiveIntakeApprove = 'archive.intake.approve';
  static const archiveInboxView = 'archive.inbox.view';
  static const archiveInboxLink = 'archive.inbox.link';
  static const archiveInboxReject = 'archive.inbox.reject';
  static const archiveDuplicatesView = 'archive.duplicates.view';
  static const archiveDuplicatesResolve = 'archive.duplicates.resolve';
  static const archiveQualityView = 'archive.quality.view';
  static const archiveQualityExport = 'archive.quality.export';

  static const tasksView = 'tasks.view';
  static const tasksCreate = 'tasks.create';
  static const tasksEdit = 'tasks.edit';
  static const tasksResultEnter = 'tasks.result.enter';
  static const tasksTemplatesManage = 'tasks.templates.manage';
  static const tasksAssign = 'tasks.assign';
  static const tasksDelete = 'tasks.delete';
  static const tasksPrint = 'tasks.print';
  static const calendarView = 'calendar.view';
  static const calendarManage = 'calendar.manage';
}

class PermissionCatalog {
  static const groups = <PermissionGroup>[
    PermissionGroup('settings', 'النظام والإعدادات'),
    PermissionGroup('persons', 'الأشخاص والجهات'),
    PermissionGroup('poa', 'الوكالات'),
    PermissionGroup('cases', 'الدعاوى والجلسات'),
    PermissionGroup('contracts', 'العقود'),
    PermissionGroup('companies', 'الشركات'),
    PermissionGroup('procedures', 'الإجراءات الإدارية'),
    PermissionGroup('documents', 'المستندات'),
    PermissionGroup('finance', 'المالية'),
    PermissionGroup('work_orders', 'أوامر العمل'),
    PermissionGroup('reports', 'التقارير والبحث'),
    PermissionGroup('library', 'المكتبة القانونية'),
    PermissionGroup('templates', 'النماذج القانونية'),
    PermissionGroup('archive', 'مركز إدخال الأرشيف'),
    PermissionGroup('tasks', 'مكتب العمل والمهام'),
  ];

  static const permissions = <PermissionDefinition>[
    PermissionDefinition(key: PermissionKeys.settingsView, label: 'عرض الإعدادات', group: 'settings', description: 'الدخول إلى شاشة الإعدادات'),
    PermissionDefinition(key: PermissionKeys.settingsOfficeEdit, label: 'تعديل بيانات المكتب', group: 'settings', description: 'تعديل اسم المكتب والترويسة'),
    PermissionDefinition(key: PermissionKeys.settingsSecurityEdit, label: 'تعديل الأمان', group: 'settings', description: 'تغيير كلمة المرور ومهلة القفل', sensitive: true),
    PermissionDefinition(key: PermissionKeys.settingsBackupCreate, label: 'إنشاء نسخة احتياطية', group: 'settings', description: 'تنفيذ نسخ احتياطي'),
    PermissionDefinition(key: PermissionKeys.settingsBackupRestore, label: 'استعادة نسخة', group: 'settings', description: 'استعادة نسخة احتياطية', sensitive: true),
    PermissionDefinition(key: PermissionKeys.settingsLookupsManage, label: 'إدارة القوائم المرجعية', group: 'settings', description: 'إضافة وتعديل المحاكم والقوائم'),
    PermissionDefinition(key: PermissionKeys.settingsUsersManage, label: 'إدارة المستخدمين والصلاحيات', group: 'settings', description: 'إنشاء مستخدمين وأدوار وتعديل الصلاحيات', sensitive: true),
    PermissionDefinition(key: PermissionKeys.auditView, label: 'عرض سجل المسؤولية', group: 'settings', description: 'عرض أحداث التدقيق', sensitive: true),
    PermissionDefinition(key: PermissionKeys.auditExport, label: 'تصدير سجل المسؤولية', group: 'settings', description: 'تصدير أحداث التدقيق', sensitive: true),
    PermissionDefinition(key: PermissionKeys.sessionsView, label: 'عرض جلسات المستخدمين', group: 'settings', description: 'عرض الدخول والخروج', sensitive: true),

    PermissionDefinition(key: PermissionKeys.personsView, label: 'عرض الأشخاص', group: 'persons', description: 'عرض دليل الأشخاص والجهات'),
    PermissionDefinition(key: PermissionKeys.personsCreate, label: 'إضافة شخص/جهة', group: 'persons', description: 'إضافة موكل أو خصم أو جهة'),
    PermissionDefinition(key: PermissionKeys.personsEdit, label: 'تعديل شخص/جهة', group: 'persons', description: 'تعديل بيانات الأشخاص'),
    PermissionDefinition(key: PermissionKeys.personsArchive, label: 'أرشفة شخص/جهة', group: 'persons', description: 'تعطيل أو أرشفة سجل'),
    PermissionDefinition(key: PermissionKeys.personsSensitiveView, label: 'عرض البيانات الحساسة', group: 'persons', description: 'عرض الهواتف والهويات والبيانات الحساسة', sensitive: true),

    PermissionDefinition(key: PermissionKeys.poaView, label: 'عرض الوكالات', group: 'poa', description: 'عرض الوكالات'),
    PermissionDefinition(key: PermissionKeys.poaCreate, label: 'إضافة وكالة', group: 'poa', description: 'إضافة وكالة جديدة'),
    PermissionDefinition(key: PermissionKeys.poaEdit, label: 'تعديل وكالة', group: 'poa', description: 'تعديل بيانات وكالة'),
    PermissionDefinition(key: PermissionKeys.poaArchive, label: 'أرشفة وكالة', group: 'poa', description: 'أرشفة وكالة'),
    PermissionDefinition(key: PermissionKeys.poaFilesView, label: 'عرض ملفات الوكالات', group: 'poa', description: 'فتح ملفات الوكالات'),

    PermissionDefinition(key: PermissionKeys.casesView, label: 'عرض الدعاوى', group: 'cases', description: 'عرض ملفات الدعاوى'),
    PermissionDefinition(key: PermissionKeys.casesCreateNew, label: 'إنشاء دعوى جديدة', group: 'cases', description: 'فتح دعوى جديدة'),
    PermissionDefinition(key: PermissionKeys.casesArchiveOld, label: 'أرشفة دعوى قديمة', group: 'cases', description: 'إدخال دعوى قائمة سابقاً'),
    PermissionDefinition(key: PermissionKeys.casesEdit, label: 'تعديل دعوى', group: 'cases', description: 'تعديل بيانات الدعوى'),
    PermissionDefinition(key: PermissionKeys.casesSessionsManage, label: 'إدارة الجلسات', group: 'cases', description: 'إضافة وتعديل الجلسات'),
    PermissionDefinition(key: PermissionKeys.casesResultEnter, label: 'إدخال نتيجة جلسة', group: 'cases', description: 'تسجيل نتيجة جلسة'),
    PermissionDefinition(key: PermissionKeys.casesClose, label: 'إغلاق دعوى', group: 'cases', description: 'إغلاق ملف دعوى', sensitive: true),
    PermissionDefinition(key: PermissionKeys.casesArchive, label: 'أرشفة دعوى', group: 'cases', description: 'أرشفة ملف دعوى', sensitive: true),

    PermissionDefinition(key: PermissionKeys.contractsView, label: 'عرض العقود', group: 'contracts', description: 'عرض العقود'),
    PermissionDefinition(key: PermissionKeys.contractsCreate, label: 'إنشاء عقد', group: 'contracts', description: 'تنظيم عقد'),
    PermissionDefinition(key: PermissionKeys.contractsEdit, label: 'تعديل عقد', group: 'contracts', description: 'تعديل بيانات عقد'),
    PermissionDefinition(key: PermissionKeys.contractsRemindersManage, label: 'إدارة تذكيرات العقود', group: 'contracts', description: 'إدارة مواعيد العقود'),
    PermissionDefinition(key: PermissionKeys.contractsArchive, label: 'أرشفة عقد', group: 'contracts', description: 'أرشفة عقد'),

    PermissionDefinition(key: PermissionKeys.companiesView, label: 'عرض الشركات', group: 'companies', description: 'عرض الشركات'),
    PermissionDefinition(key: PermissionKeys.companiesCreate, label: 'تأسيس شركة', group: 'companies', description: 'إنشاء شركة'),
    PermissionDefinition(key: PermissionKeys.companiesEdit, label: 'تعديل شركة', group: 'companies', description: 'تعديل بيانات شركة'),
    PermissionDefinition(key: PermissionKeys.companiesPhasesManage, label: 'إدارة مراحل الشركة', group: 'companies', description: 'إدارة مراحل التأسيس'),
    PermissionDefinition(key: PermissionKeys.companiesArchive, label: 'أرشفة شركة', group: 'companies', description: 'أرشفة شركة'),

    PermissionDefinition(key: PermissionKeys.proceduresView, label: 'عرض الإجراءات', group: 'procedures', description: 'عرض الإجراءات الإدارية'),
    PermissionDefinition(key: PermissionKeys.proceduresCreate, label: 'إنشاء إجراء', group: 'procedures', description: 'تسجيل إجراء إداري'),
    PermissionDefinition(key: PermissionKeys.proceduresEdit, label: 'تعديل إجراء', group: 'procedures', description: 'تعديل إجراء إداري'),
    PermissionDefinition(key: PermissionKeys.proceduresStepsManage, label: 'إدارة خطوات الإجراءات', group: 'procedures', description: 'إدارة Checklist'),
    PermissionDefinition(key: PermissionKeys.proceduresArchive, label: 'أرشفة إجراء', group: 'procedures', description: 'أرشفة إجراء'),

    PermissionDefinition(key: PermissionKeys.documentsView, label: 'عرض المستندات', group: 'documents', description: 'عرض أرشيف المستندات'),
    PermissionDefinition(key: PermissionKeys.documentsUpload, label: 'رفع مستند', group: 'documents', description: 'إضافة مستند'),
    PermissionDefinition(key: PermissionKeys.documentsOpen, label: 'فتح مستند', group: 'documents', description: 'معاينة المستندات'),
    PermissionDefinition(key: PermissionKeys.documentsEdit, label: 'تعديل مستند', group: 'documents', description: 'تعديل بيانات مستند'),
    PermissionDefinition(key: PermissionKeys.documentsDelete, label: 'حذف مستند', group: 'documents', description: 'حذف مستند', sensitive: true),
    PermissionDefinition(key: PermissionKeys.documentsExport, label: 'تصدير مستند', group: 'documents', description: 'تصدير أو تنزيل مستند'),

    PermissionDefinition(key: PermissionKeys.financeView, label: 'عرض المالية', group: 'finance', description: 'عرض المالية', sensitive: true),
    PermissionDefinition(key: PermissionKeys.financeAgreementsCreate, label: 'إضافة اتفاق أتعاب', group: 'finance', description: 'إنشاء اتفاق أتعاب', sensitive: true),
    PermissionDefinition(key: PermissionKeys.financeAgreementsEdit, label: 'تعديل اتفاق أتعاب', group: 'finance', description: 'تعديل اتفاق', sensitive: true),
    PermissionDefinition(key: PermissionKeys.financePaymentsCreate, label: 'إضافة قبض', group: 'finance', description: 'إضافة دفعة أو سند قبض', sensitive: true),
    PermissionDefinition(key: PermissionKeys.financeExpensesCreate, label: 'إضافة مصروف', group: 'finance', description: 'إضافة مصروف', sensitive: true),
    PermissionDefinition(key: PermissionKeys.financeReportsView, label: 'عرض التقارير المالية', group: 'finance', description: 'عرض التقارير المالية', sensitive: true),
    PermissionDefinition(key: PermissionKeys.financeDelete, label: 'حذف حركة مالية', group: 'finance', description: 'حذف حركة مالية', sensitive: true),

    PermissionDefinition(key: PermissionKeys.workOrdersView, label: 'عرض أوامر العمل', group: 'work_orders', description: 'عرض أوامر العمل'),
    PermissionDefinition(key: PermissionKeys.workOrdersCreate, label: 'إنشاء أمر عمل', group: 'work_orders', description: 'إنشاء أمر عمل'),
    PermissionDefinition(key: PermissionKeys.workOrdersPrint, label: 'طباعة أمر عمل', group: 'work_orders', description: 'طباعة PDF'),
    PermissionDefinition(key: PermissionKeys.workOrdersSend, label: 'إرسال أمر عمل', group: 'work_orders', description: 'إرسال واتساب'),
    PermissionDefinition(key: PermissionKeys.workOrdersResultEnter, label: 'إدخال نتيجة أمر', group: 'work_orders', description: 'تسجيل نتيجة أمر عمل'),
    PermissionDefinition(key: PermissionKeys.workOrdersApprove, label: 'اعتماد أمر عمل', group: 'work_orders', description: 'اعتماد نتيجة أمر عمل', sensitive: true),
    PermissionDefinition(key: PermissionKeys.workOrdersAttachmentsUpload, label: 'رفع مرفقات أمر عمل', group: 'work_orders', description: 'إرفاق ملفات وصور نتيجة أمر العمل'),
    PermissionDefinition(key: PermissionKeys.workOrdersAttachmentsView, label: 'عرض مرفقات أمر عمل', group: 'work_orders', description: 'عرض مرفقات أوامر العمل'),
    PermissionDefinition(key: PermissionKeys.workOrdersAttachmentsDelete, label: 'حذف مرفقات أمر عمل', group: 'work_orders', description: 'حذف مرفقات أوامر العمل', sensitive: true),

    PermissionDefinition(key: PermissionKeys.reportsView, label: 'عرض التقارير', group: 'reports', description: 'عرض التقارير'),
    PermissionDefinition(key: PermissionKeys.reportsExport, label: 'تصدير التقارير', group: 'reports', description: 'تصدير PDF/Excel'),
    PermissionDefinition(key: PermissionKeys.searchView, label: 'البحث', group: 'reports', description: 'استخدام البحث العام'),

    PermissionDefinition(key: PermissionKeys.libraryView, label: 'عرض المكتبة', group: 'library', description: 'عرض المكتبة القانونية'),
    PermissionDefinition(key: PermissionKeys.libraryAdd, label: 'إضافة للمكتبة', group: 'library', description: 'إضافة مادة قانونية'),
    PermissionDefinition(key: PermissionKeys.libraryEdit, label: 'تعديل المكتبة', group: 'library', description: 'تعديل مادة'),
    PermissionDefinition(key: PermissionKeys.libraryDelete, label: 'حذف من المكتبة', group: 'library', description: 'حذف مادة', sensitive: true),
    PermissionDefinition(key: PermissionKeys.libraryLink, label: 'ربط المكتبة بالملفات', group: 'library', description: 'ربط مادة بملف'),

    PermissionDefinition(key: PermissionKeys.templatesView, label: 'عرض النماذج القانونية', group: 'templates', description: 'عرض مكتبة النماذج القانونية'),
    PermissionDefinition(key: PermissionKeys.templatesImport, label: 'استيراد نموذج', group: 'templates', description: 'استيراد قالب Word/RTF/TXT/PDF'),
    PermissionDefinition(key: PermissionKeys.templatesCreate, label: 'إنشاء نموذج', group: 'templates', description: 'إنشاء قالب قانوني من داخل التطبيق'),
    PermissionDefinition(key: PermissionKeys.templatesEdit, label: 'تعديل نموذج', group: 'templates', description: 'تعديل بيانات النموذج القانوني'),
    PermissionDefinition(key: PermissionKeys.templatesDisable, label: 'تعطيل نموذج', group: 'templates', description: 'تعطيل نموذج قانوني'),
    PermissionDefinition(key: PermissionKeys.templatesGenerateDocument, label: 'إنشاء مستند من نموذج', group: 'templates', description: 'استخدام نموذج لإنشاء مستند وربطه بملف'),

    PermissionDefinition(key: PermissionKeys.archiveIntakeView, label: 'عرض مركز إدخال الأرشيف', group: 'archive', description: 'الدخول إلى مركز إدخال الأرشيف القديم'),
    PermissionDefinition(key: PermissionKeys.archiveIntakeCreate, label: 'إنشاء دفعة أرشيف', group: 'archive', description: 'إنشاء دفعة إدخال أرشيف جديدة'),
    PermissionDefinition(key: PermissionKeys.archiveIntakeImportFiles, label: 'استيراد ملفات أرشيف', group: 'archive', description: 'استيراد ملفات أو مجلدات إلكترونية'),
    PermissionDefinition(key: PermissionKeys.archiveIntakeImportExcel, label: 'استيراد Excel / CSV', group: 'archive', description: 'استيراد بيانات قديمة من جداول'),
    PermissionDefinition(key: PermissionKeys.archiveIntakeReview, label: 'مراجعة دفعات الأرشيف', group: 'archive', description: 'مراجعة نتائج الاستيراد والتصنيف'),
    PermissionDefinition(key: PermissionKeys.archiveIntakeApprove, label: 'اعتماد دفعات الأرشيف', group: 'archive', description: 'اعتماد الدفعة وتحويلها إلى ملفات فعلية', sensitive: true),
    PermissionDefinition(key: PermissionKeys.archiveInboxView, label: 'عرض صندوق غير مصنف', group: 'archive', description: 'عرض عناصر الأرشيف غير المصنفة'),
    PermissionDefinition(key: PermissionKeys.archiveInboxLink, label: 'ربط عناصر غير مصنفة', group: 'archive', description: 'ربط العناصر غير المصنفة بملفات المكتب'),
    PermissionDefinition(key: PermissionKeys.archiveInboxReject, label: 'رفض عنصر أرشيف', group: 'archive', description: 'رفض أو تجاهل عنصر من الأرشيف', sensitive: true),
    PermissionDefinition(key: PermissionKeys.archiveDuplicatesView, label: 'عرض المكررات', group: 'archive', description: 'عرض الملفات المكررة'),
    PermissionDefinition(key: PermissionKeys.archiveDuplicatesResolve, label: 'حل المكررات', group: 'archive', description: 'تحديد كيفية التعامل مع الملفات المكررة'),
    PermissionDefinition(key: PermissionKeys.archiveQualityView, label: 'عرض تقارير جودة الأرشيف', group: 'archive', description: 'عرض نتائج جودة الاستيراد'),
    PermissionDefinition(key: PermissionKeys.archiveQualityExport, label: 'تصدير تقارير جودة الأرشيف', group: 'archive', description: 'تصدير تقارير الجودة', sensitive: true),

    PermissionDefinition(key: PermissionKeys.tasksView, label: 'عرض المهام', group: 'tasks', description: 'عرض المهام المخصصة وعناصر مكتب العمل'),
    PermissionDefinition(key: PermissionKeys.tasksCreate, label: 'إضافة مهمة مخصصة', group: 'tasks', description: 'إنشاء مهمة يدوية أو مكتبية'),
    PermissionDefinition(key: PermissionKeys.tasksEdit, label: 'تعديل مهمة', group: 'tasks', description: 'تعديل بيانات مهمة مخصصة'),
    PermissionDefinition(key: PermissionKeys.tasksResultEnter, label: 'إدخال نتيجة مهمة', group: 'tasks', description: 'إكمال أو تأجيل أو إلغاء مهمة'),
    PermissionDefinition(key: PermissionKeys.tasksTemplatesManage, label: 'إدارة قوالب المهام', group: 'tasks', description: 'إنشاء وتعديل قوالب المهام ونتائجها'),
    PermissionDefinition(key: PermissionKeys.tasksAssign, label: 'توزيع المهام', group: 'tasks', description: 'تعيين مكلف داخلي أو خارجي للمهام'),
    PermissionDefinition(key: PermissionKeys.tasksDelete, label: 'حذف مهمة', group: 'tasks', description: 'حذف مهمة مخصصة', sensitive: true),
    PermissionDefinition(key: PermissionKeys.tasksPrint, label: 'طباعة لوائح العمل', group: 'tasks', description: 'طباعة لائحة اليوم أو الغد أو الأسبوع'),
    PermissionDefinition(key: PermissionKeys.calendarView, label: 'عرض التقويم', group: 'tasks', description: 'عرض تقويم الأعمال'),
    PermissionDefinition(key: PermissionKeys.calendarManage, label: 'إدارة التقويم', group: 'tasks', description: 'إضافة وتعديل عناصر التقويم'),
  ];

  static List<String> get allKeys => permissions.map((p) => p.key).toList(growable: false);
  static PermissionDefinition? byKey(String key) {
    for (final p in permissions) {
      if (p.key == key) return p;
    }
    return null;
  }

  static List<PermissionDefinition> byGroup(String group) =>
      permissions.where((p) => p.group == group).toList(growable: false);
}
