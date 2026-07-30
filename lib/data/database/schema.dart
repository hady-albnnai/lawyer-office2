import 'package:drift/drift.dart';

// ============================================================================
// 1. جداول النظام والإعدادات (System & Core Tables)
// ============================================================================

/// جدول إعدادات ومتغيرات النظام (اسم المكتب، المحامي، الشعار، إلخ)
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// جدول الأمان والحماية (كلمة المرور المشفرة، سؤال الأمان، ومهلة القفل التلقائي)
class Security extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get passwordHash => text()();
  TextColumn get securityQuestion => text()();
  TextColumn get answerHash => text()();
  IntColumn get lockTimeoutMinutes => integer().withDefault(const Constant(10))();
  DateTimeColumn get lastUnlockedAt => dateTime().nullable()();
  DateTimeColumn get rememberDeviceUntil => dateTime().nullable()();
}

/// جدول سجل حركات وأنشطة النظام (Audit Log)
class ActivityLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get affectedTable => text().named('table_name')();
  IntColumn get recordId => integer()();
  TextColumn get action => text()(); // insert, update, delete, login, export
  TextColumn get userRef => text().nullable()(); // اسم المحامي الأستاذ أو المتمرن أو الموظفة
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get details => text().nullable()(); // بصيغة JSON لتفاصيل التغيير
}

/// جدول إدارة وسجل النسخ الاحتياطية (Backups Log)
class Backups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  TextColumn get type => text()(); // auto, manual
  RealColumn get sizeMb => real().nullable()();
  BoolColumn get includesAttachments => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('success'))(); // success, failed
}

/// جدول الترقيم السنوي الآمن للمكتب (Yearly Sequences - مثلاً: 2026/001)
class YearlySequences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get year => integer().unique()();
  IntColumn get lastNumber => integer().withDefault(const Constant(0))();
  TextColumn get prefix => text().withDefault(const Constant(''))();
}

// ============================================================================
// 2. جداول الأشخاص، الكيانات الاعتبارية، والأدوار (Persons & Roles)
// ============================================================================

/// الجدول المركزي للأشخاص (طبيعيين أو اعتباريين)
@DataClassName('PersonEntity')
class Persons extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get type => integer().withDefault(const Constant(0))(); // 0: natural, 1: legal
  TextColumn get fullName => text()();
  TextColumn get fatherName => text().nullable()();
  TextColumn get motherName => text().nullable()();
  TextColumn get nationalId => text().nullable()();
  TextColumn get registryPlace => text().nullable()();
  TextColumn get registryNumber => text().nullable()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get birthPlace => text().nullable()();
  TextColumn get nationality => text().withDefault(const Constant('عربي سوري'))();
  TextColumn get maritalStatus => text().nullable()();
  TextColumn get profession => text().nullable()();
  TextColumn get permanentAddress => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get district => text().nullable()();
  TextColumn get phone1 => text().nullable()();
  TextColumn get phone2 => text().nullable()();
  TextColumn get whatsapp => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get workPlace => text().nullable()();
  TextColumn get workAddress => text().nullable()();
  TextColumn get howMet => text().nullable()();
  TextColumn get referralSource => text().nullable()();
  DateTimeColumn get firstContactDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, inactive, ended
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول الكيانات الاعتبارية (الشركات والجهات العامة والجمعيات)
class LegalEntities extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer().unique().references(Persons, #id, onDelete: KeyAction.cascade)();
  TextColumn get legalEntityName => text().named('entity_name')();
  TextColumn get entityType => text().nullable()(); // شركة تضامن، مساهمة، جمعية...
  IntColumn get representativeId => integer().nullable().references(Persons, #id)();
  TextColumn get representativeCapacity => text().nullable()(); // مدير عام، مفوض بالتوقيع
  TextColumn get representationDocPath => text().nullable()(); // مسار سند التمثيل
  TextColumn get registrationNumber => text().nullable()();
  TextColumn get taxNumber => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}

/// جدول أدوار الأشخاص في النظام (موكل، خصم، شريك، مفوض...)
class PersonRoles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer().references(Persons, #id, onDelete: KeyAction.cascade)();
  IntColumn get roleType => integer()();
  TextColumn get roleDetails => text().nullable()(); // JSON
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// جدول أعضاء فريق مكتب المحاماة
class TeamMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer().unique().references(Persons, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  DateTimeColumn get joinDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get notes => text().nullable()();
}

/// جدول المحامين الخصوم (أو الوكلاء عن الطرف الخصم)
class OpponentLawyers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get barAssociation => text().nullable()(); // فرع النقابة (دمشق، حلب...)
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// جدول كتاب العدل ومندوبي النقابة لتوثيق الوكالات
class Notaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get branch => text().nullable()(); // فرع النقابة أو دائرة الكاتب بالعدل
  TextColumn get type => text()(); // public_notary, delegate
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// ============================================================================
// 3. الوكالات القضائية (Powers of Attorney)
// ============================================================================

/// جدول سندات التوكيل (عامة، خاصة، خاصة شرعية)
class PowersOfAttorney extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get poaNumber => text().nullable()();
  DateTimeColumn get poaDate => dateTime().nullable()();
  TextColumn get sourceType => text()(); // notary: كاتب عدل, delegate: مندوب نقابة
  IntColumn get notaryId => integer().nullable().references(Notaries, #id)();
  IntColumn get delegateId => integer().nullable().references(Notaries, #id)();
  TextColumn get delegateBranch => text().nullable()(); // فرع النقابة الـ 14
  IntColumn get poaType => integer()();
  // === حقول خطة ملف الوكالة (البندان 3 و7) ===
  /// التصنيف الرئيسي: judicial / notarial / foreign / delegation / other
  TextColumn get category => text().withDefault(const Constant('judicial'))();
  /// التصنيف الفرعي حسب النوع (سند توكيل عام، وكالة إدارية...).
  TextColumn get subType => text().nullable()();
  /// رقم سجل الوكالة.
  TextColumn get registryNumber => text().nullable()();
  /// الرقم الأبيض.
  TextColumn get whiteNumber => text().nullable()();
  /// اسم مندوب فرع النقابة.
  TextColumn get delegateName => text().nullable()();
  /// هاتف المندوب.
  TextColumn get delegatePhone => text().nullable()();
  TextColumn get scopeText => text().nullable()(); // وصف نطاق الوكالة الخاصة
  TextColumn get filePath => text().nullable()(); // مسار صورة سند التوكيل
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, expired, revoked
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول أطراف التوكيل (الموكل والوكيل)
class PoaParties extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get poaId => integer().references(PowersOfAttorney, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(Persons, #id)();
  TextColumn get partyRole => text().withDefault(const Constant('principal'))(); // principal: موكل, agent: وكيل
  BoolColumn get isPrimary => boolean().withDefault(const Constant(true))();
}

/// جدول ربط الوكالات بملفات الدعاوى القضائية
class CasePoaLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(Cases, #id, onDelete: KeyAction.cascade)();
  IntColumn get poaId => integer().references(PowersOfAttorney, #id, onDelete: KeyAction.cascade)();

  @override
  List<Set<Column>> get uniqueKeys => [{caseId, poaId}];
}

// ============================================================================
// 4. الجداول المرجعية للقوائم السورية الجاهزة (Lookups)
// ============================================================================

/// جدول قائمة المحاكم والدوائر القضائية في سوريا
class Courts extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// اسم المحكمة = اسم المحافظة فقط (دمشق، حماة، حلب...).
  /// لا تُدمج الدرجة ولا رقم الغرفة في الاسم.
  TextColumn get name => text()();
  /// مهجور: الدرجة (صلح/بداية/استئناف/نقض) تُدار عبر JudicialPhases.
  /// يبقى العمود لعدم كسر السجلات التاريخية ولا يُعرض في الواجهات.
  TextColumn get type => text().nullable()();
  TextColumn get city => text().nullable()(); // دمشق، السويداء، حلب...
  TextColumn get district => text().nullable()();
  /// رقم الغرفة: 1..16 اعتيادياً، ويُسمح بما فوقها عند استحداث غرف.
  IntColumn get chamberNumber => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// جدول قائمة مواضيع الدعاوى القانونية
class CaseSubjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // مطالبة مالية، إخلاء، تثبيت زواج، فسخ عقد...
  TextColumn get category => text().nullable()(); // مدني، جزائي، شرعي، تجاري
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// جدول قائمة صفات الأطراف في الدعاوى (مدعي، مدعى عليه، طاعن...)
class PartyRolesLookup extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get roleName => text()();
  TextColumn get category => text()(); // civil, criminal, commercial, sharia
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// جدول قائمة أنواع العقود النمطية
class ContractTypesLookup extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // عقد بيع، إيجار، عمل، شراكة...
  TextColumn get category => text().nullable()(); // عقاري، تجاري، مهني
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// جدول قائمة أنواع الشركات التجارية والمدنية
class CompanyTypesLookup extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // تضامن، محدودة المسؤولية، مساهمة...
  TextColumn get category => text().nullable()(); // persons: أشخاص, capital: أموال
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// ============================================================================
// 5. الدعاوى، المراحل القضائية، الجلسات، والإجراءات (Litigation System)
// ============================================================================

/// الجدول الرئيسي لملفات الدعاوى القضائية
class Cases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get internalNumber => text().unique()(); // رقم الملف الداخلي السنوي: 2026/001
  IntColumn get year => integer()();
  TextColumn get caseType => text()(); // مدني، جزائي، تجاري، إداري، شرعي
  TextColumn get subType => text().nullable()(); // صلح، بداية، استئناف...
  TextColumn get status => text().withDefault(const Constant('preparing'))(); // preparing, pending_registration, registered, closed
  IntColumn get currentPhaseId => integer().nullable()(); // معرف المرحلة القضائية الحالية
  IntColumn get courtId => integer().nullable().references(Courts, #id)();
  TextColumn get baseNumber => text().nullable()(); // رقم الأساس في المحكمة
  TextColumn get subject => text().nullable()();
  TextColumn get subjectDetails => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isUrgent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get nextSessionDate => dateTime().nullable()(); // Cached للبحث السريع
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول أطراف الدعوى (الموكلون والخصوم)
@TableIndex(name: "idx_case_parties_case", columns: {#caseId})
class CaseParties extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(Cases, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(Persons, #id)();
  TextColumn get partyRole => text()(); // مدعي، مدعى عليه، متدخل، مستأنف...
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))(); // موكل رئيسي أو خصم رئيسي
  BoolColumn get isClient => boolean().withDefault(const Constant(false))(); // 1: موكل منا، 0: خصم

  @override
  List<Set<Column>> get uniqueKeys => [{caseId, personId, partyRole}];
}

/// جدول المراحل القضائية (تسلسل التقاضي من الصلح/البداية حتى النقض)
@TableIndex(name: "idx_case_phases_case", columns: {#caseId})
class CasePhases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(Cases, #id, onDelete: KeyAction.cascade)();
  IntColumn get phaseOrder => integer().withDefault(const Constant(1))();
  TextColumn get phaseType => text()(); // بداية، استئناف، نقض، إعادة محاكمة
  IntColumn get courtId => integer().nullable().references(Courts, #id)();
  TextColumn get baseNumber => text().nullable()();
  IntColumn get year => integer().nullable()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get decisionText => text().nullable()(); // ملخص القرار القضائي الصادر
  TextColumn get decisionDocPath => text().nullable()(); // مسار صورة القرار
  BoolColumn get isTransferred => boolean().withDefault(const Constant(false))(); // هل انتقلت للمرحلة الأعلى؟
  IntColumn get nextPhaseId => integer().nullable()(); // Self-reference للمرحلة التالية
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول جلسات المرافعة والمحاكمة
@TableIndex(name: "idx_case_sessions_case", columns: {#caseId})
class CaseSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(Cases, #id, onDelete: KeyAction.cascade)();
  IntColumn get phaseId => integer().nullable().references(CasePhases, #id)();
  DateTimeColumn get sessionDate => dateTime()();
  TextColumn get sessionTime => text().nullable()();
  TextColumn get sessionType => text().nullable()(); // مرافعة، تدقيق، سماع شهود، خبرة، تفهيم حكم
  TextColumn get decision => text().nullable()(); // قرار المحكمة في الجلسة
  BoolColumn get clientAttended => boolean().withDefault(const Constant(false))();
  BoolColumn get opponentAttended => boolean().withDefault(const Constant(false))();
  IntColumn get opponentLawyerId => integer().nullable().references(OpponentLawyers, #id)();
  TextColumn get nextAction => text().nullable()(); // المطلوب للجلسة القادمة
  DateTimeColumn get nextSessionDate => dateTime().nullable()(); // تاريخ الجلسة القادمة
  TextColumn get notes => text().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول إجراءات الملف القضائي الخارجية (غير الجلسات - تبليغ، كشف، مراجعة)
class CaseActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get caseId => integer().references(Cases, #id, onDelete: KeyAction.cascade)();
  TextColumn get actionType => text()(); // تبليغ، مراجعة نيابة، دفع رسم، كشف ومعاينة
  DateTimeColumn get actionDate => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get assignedTo => text().nullable()(); // المسند إليه من فريق المكتب
  TextColumn get notes => text().nullable()();
  DateTimeColumn get nextDate => dateTime().nullable()();
  RealColumn get expenseAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// 6. تأسيس وإدارة الشركات (Companies Management)
// ============================================================================

/// جدول ملفات الشركات (شركات أشخاص وشركات أموال)
class Companies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get internalNumber => text().unique()();
  TextColumn get companyType => text()(); // تضامن، توصية، محدودة، مساهمة...
  TextColumn get legalStatus => text().withDefault(const Constant('under_establishment'))(); // under_establishment, active, dissolved
  TextColumn get name => text()();
  TextColumn get activity => text().nullable()(); // الغاية / نشاط الشركة
  RealColumn get capitalDeclared => real().nullable()(); // رأس المال المكتتب به
  RealColumn get capitalPaid => real().nullable()(); // رأس المال المدفوع
  TextColumn get durationType => text().nullable()(); // fixed, unlimited
  IntColumn get durationYears => integer().nullable()();
  TextColumn get mainAddress => text().nullable()();
  TextColumn get propertyDetails => text().nullable()(); // بيانات مقر الشركة أو العقار
  TextColumn get taxStatus => text().nullable()();
  DateTimeColumn get registrationDate => dateTime().nullable()();
  TextColumn get registrationNumber => text().nullable()(); // رقم السجل التجاري
  TextColumn get nationalNumber => text().nullable()(); // الرقم الوطني للشركة
  TextColumn get currentPhase => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول مراحل تأسيس الشركة (دورة الحياة الكاملة من العقد حتى الجريدة الرسمية والغرفة)
class CompanyPhases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get phaseName => text()(); // صياغة العقد، النقابة، السجل، المالية، التأمينات...
  IntColumn get phaseOrder => integer()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get scheduledDate => dateTime().nullable()();
  DateTimeColumn get completedDate => dateTime().nullable()();
  TextColumn get refNumber => text().nullable()();
  TextColumn get assignedTo => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول إدارة ما بعد التأسيس (اجتماعات، تعديلات هيكلية، تجديدات، انحلال)
class CompanyManagement extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get actionCategory => text()(); // meeting, structure_change, renewal, contract, dissolution
  TextColumn get actionType => text()(); // اجتماع هيئة عامة، تعديل نظام، تجديد غرفة تجارة...
  DateTimeColumn get actionDate => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()(); // مسار محضر الاجتماع أو السند
  TextColumn get notes => text().nullable()();
  TextColumn get assignedTo => text().nullable()();
  DateTimeColumn get nextDueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول الشركاء وحصصهم في رأس المال
class CompanyPartners extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(Persons, #id)();
  TextColumn get partnerType => text().nullable()(); // متضامن، موصي، مساهم
  TextColumn get shareType => text().nullable()(); // cash: نقدية, in_kind: عينية, effort: جهد
  RealColumn get shareValue => real().nullable()();
  RealColumn get sharePercentage => real().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get exitDate => dateTime().nullable()();
  TextColumn get disclosurePath => text().nullable()(); // إقرار الذمة المالية

  @override
  List<Set<Column>> get uniqueKeys => [{companyId, personId}];
}

/// جدول المديرين والمفوضين ومجلس الإدارة
class CompanyDirectors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(Persons, #id)();
  TextColumn get roleType => text().nullable()(); // مدير عام، مفوض بالتوقيع، عضو مجلس إدارة
  TextColumn get authorityScope => text().nullable()(); // نطاق الصلاحيات والتفويض
  DateTimeColumn get appointmentDate => dateTime().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// ============================================================================
// 7. العقود ونماذج Word (Contracts System)
// ============================================================================

/// جدول ملفات العقود (عقارية، تجارية، مهنية، شراكة، صلح)
class Contracts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get internalNumber => text().unique()();
  TextColumn get title => text()();
  TextColumn get contractType => text()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, expired, cancelled, disputed, suspended
  DateTimeColumn get dateSigned => dateTime().nullable()();
  DateTimeColumn get dateStart => dateTime().nullable()();
  DateTimeColumn get dateEnd => dateTime().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get notarizationType => text().nullable()(); // notary, court, chamber, informal
  TextColumn get notarizationNumber => text().nullable()();
  RealColumn get financialValue => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('ل.س'))();
  TextColumn get paymentMethod => text().nullable()();
  BoolColumn get isRenewable => boolean().withDefault(const Constant(false))();
  TextColumn get renewalType => text().nullable()(); // تلقائي، اتفاق، قرار
  BoolColumn get needsFollowup => boolean().withDefault(const Constant(false))();
  IntColumn get linkedClientId => integer().nullable().references(Persons, #id)();
  IntColumn get linkedCompanyId => integer().nullable().references(Companies, #id)();
  IntColumn get linkedCaseId => integer().nullable().references(Cases, #id)();
  TextColumn get summary => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول أطراف العقد (الطرف الأول، الثاني، الكفلاء...)
class ContractParties extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contractId => integer().references(Contracts, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(Persons, #id)();
  TextColumn get partyRole => text().nullable()(); // طرف أول (بائع/مؤجر)، طرف ثاني (مشتري/مستأجر)
  IntColumn get partyOrder => integer().withDefault(const Constant(1))();
}

/// جدول تنبيهات ومواعيد انتهاء وتجديد العقود
class ContractReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contractId => integer().references(Contracts, #id, onDelete: KeyAction.cascade)();
  TextColumn get reminderType => text()(); // expiry, renewal, manual
  DateTimeColumn get reminderDate => dateTime()();
  IntColumn get daysBefore => integer().nullable()(); // التنبيه قبل X يوم
  TextColumn get contactPhone => text().nullable()();
  TextColumn get reminderNote => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('upcoming'))(); // upcoming, notified, passed, cancelled
  IntColumn get autoTaskId => integer().nullable()(); // ربط بمهمة جدول الأعمال اليومية
}

/// جدول قوالب نماذج Word للعقود
class ContractTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get contractType => text()(); // نوع العقد
  TextColumn get templateName => text()(); // اسم القالب (مثال: عقد بيع شقة سكنية)
  TextColumn get templateSubtype => text().nullable()();
  TextColumn get filePath => text()(); // مسار ملف Word (.docx)
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  /// مصدر النموذج: ready (جاهز) / imported (مستورد) / generated (مولد من ملف).
  TextColumn get templateSource => text().withDefault(const Constant('ready'))();
  /// ملف المكتب الذي وُلّد منه النموذج، إن وُجد.
  IntColumn get sourceOfficeFileId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول نسخ التعديلات السابقة للعقد
class ContractVersions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contractId => integer().references(Contracts, #id, onDelete: KeyAction.cascade)();
  IntColumn get versionNumber => integer()();
  TextColumn get filePath => text().nullable()();
  DateTimeColumn get editDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get editedBy => text().nullable()();
  TextColumn get notes => text().nullable()();
}

// ============================================================================
// 8. الإجراءات الإدارية والمعاملات (Admin Procedures)
// ============================================================================

/// جدول المعاملات والإجراءات الإدارية (أحوال شخصية، عقارية، تجارية)
class AdminProcedures extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get internalNumber => text().unique()();
  TextColumn get procedureType => text()(); // أحوال شخصية، عقاري، تجاري
  TextColumn get subType => text().nullable()(); // حصر إرث، فراغ عقاري، تسجيل علامة...
  IntColumn get clientId => integer().references(Persons, #id)();
  TextColumn get title => text()();
  DateTimeColumn get startDate => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(1))(); // inProgress
  TextColumn get transactionNumber => text().nullable()(); // رقم المعاملة أو الطلب
  DateTimeColumn get regDate => dateTime().nullable()();
  TextColumn get department => text().nullable()(); // الدائرة أو السجل المدني / العقاري
  TextColumn get currentStep => text().nullable()();
  DateTimeColumn get nextDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول خطوات تنفيذ الإجراء الإداري
class AdminSteps extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get procedureId => integer().references(AdminProcedures, #id, onDelete: KeyAction.cascade)();
  TextColumn get stepTitle => text()();
  DateTimeColumn get stepDate => dateTime().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get result => text().nullable()();
  TextColumn get assignedTo => text().nullable()();
  DateTimeColumn get nextDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))();
}

/// جدول القوائم الجاهزة ونماذج الـ Checklist للإجراءات الإدارية
class AdminProcedureTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get checklistJson => text().nullable()(); // قائمة المستندات المطلوبة (JSON)
  TextColumn get defaultStepsJson => text().nullable()(); // قائمة الخطوات التلقائية (JSON)
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// ============================================================================
// 9. الأعمال اليومية والمهام الموحدة (Daily Tasks & Agenda)
// ============================================================================

/// جدول مهام وأعمال اليوم الموحد (يتغذى من الجلسات، التذكيرات، المعاملات، أو يدوياً)
@TableIndex(name: "idx_tasks_date", columns: {#taskDate})
class DailyTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskType => text()(); // session, action, contract_reminder, admin_step, company_phase, manual
  TextColumn get title => text()();
  DateTimeColumn get taskDate => dateTime()();
  TextColumn get taskTime => text().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get assignedTo => text().nullable()(); // المكلف بالتنفيذ
  IntColumn get priority => integer().withDefault(const Constant(1))(); // normal
  TextColumn get sourceType => text().nullable()(); // cases, contracts, companies, admin_procedures, manual
  IntColumn get sourceId => integer().nullable()();
  BoolColumn get isAutoGenerated => boolean().withDefault(const Constant(false))(); // 1 إذا كان مولداً تلقائياً
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول تاريخ وسجل تأجيل وإلغاء المهام
class TaskHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().references(DailyTasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get action => text()(); // postponed, cancelled, completed
  DateTimeColumn get actionDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get reason => text().nullable()(); // سبب التأجيل أو الإلغاء
  TextColumn get notes => text().nullable()();
}

// ============================================================================
// 10. المستندات والمرفقات المستقلة (Decoupled Documents & Links)
// ============================================================================

/// جدول المستندات والمبرزات القانونية
class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get docName => text()();
  TextColumn get docType => text().nullable()(); // هوية، سند توكيل، إخراج قيد، حكم، مذكرة...
  DateTimeColumn get dateIssued => dateTime().nullable()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  TextColumn get issuer => text().nullable()(); // الجهة المصدرة
  TextColumn get filePath => text().nullable()(); // مسار نسبي داخل AppData/LawOffice/files/
  TextColumn get fileType => text().nullable()(); // pdf, image, word, other
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get physicalLocation => integer().withDefault(const Constant(0))();
  TextColumn get summary => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول ربط المستندات بالكيانات (فصل الربط لتجنب ضعف Polymorphic FK)
class DocumentLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId => integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get entityType => integer()();
  IntColumn get entityId => integer()();
  TextColumn get linkType => text().nullable()(); // general, phase_attachment, session_attachment

  @override
  List<Set<Column>> get uniqueKeys => [{documentId, entityType, entityId}];
}

// ============================================================================
// 11. المالية الموحدة (Unified Finances)
// ============================================================================

/// جدول اتفاقيات وعقود الأتعاب (منفصل لكل موكل حتى في نفس الدعوى)
class FeeAgreements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entityType => integer()(); // case, contract, company
  IntColumn get entityId => integer()();
  IntColumn get partyId => integer().references(Persons, #id)(); // الموكل صاحب الأتعاب
  TextColumn get agreementType => text().withDefault(const Constant('fixed'))(); // fixed: مقطوع, percentage: نسبة, per_session: بالجلسة, free: مجاني
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('ل.س'))();
  TextColumn get contractPath => text().nullable()(); // صورة عقد الأتعاب
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول سندات القبض والدفعات المستلمة من الموكلين
class FeePayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get agreementId => integer().references(FeeAgreements, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get method => text().nullable()(); // نقد، تحويل بنكي، شيك
  TextColumn get notes => text().nullable()();
  TextColumn get receiptPath => text().nullable()(); // صورة الإيصال
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول مصاريف ورسوم الملفات (رسوم محكمة، طوابع، مواصلات، خبرة، تصوير)
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entityType => integer()(); // case, contract, company, admin_procedure
  IntColumn get entityId => integer()();
  TextColumn get expenseType => text()(); // رسم محكمة، طوابع، أتعاب خبرة، مواصلات، تصوير...
  RealColumn get amount => real()();
  DateTimeColumn get expenseDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// 12. النواقص القضائية والخط الزمني (Deficiencies & Timeline)
// ============================================================================

/// جدول النواقص التلقائي (غياب موعد الجلسة، رقم الأساس، سند التوكيل...)
class Deficiencies extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entityType => integer()();
  IntColumn get entityId => integer()();
  TextColumn get fieldName => text()(); // اسم الحقل الناقص (مثلاً: next_session_date, base_number, poa)
  TextColumn get description => text()(); // وصف النقص المعروض للمحامي
  IntColumn get severity => integer().withDefault(const Constant(0))(); // required, warning
  TextColumn get status => text().withDefault(const Constant('open'))(); // open: مفتوح, resolved: مكتمل, ignored: متجاهل
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}

/// جدول الخط الزمني الشامل لكل حركات وتواريخ النظام (Chrono Log)
class TimelineEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entityType => integer()();
  IntColumn get entityId => integer()();
  TextColumn get eventType => text()(); // created, session_scheduled, session_held, document_added, payment_received, phase_transferred...
  DateTimeColumn get eventDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get description => text()();
  TextColumn get userRef => text().nullable()(); // المحامي أو الموظف الذي قام بالحركة
  TextColumn get metadataJson => text().nullable()(); // تفاصيل إضافية (JSON)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// 13. المكتبة القانونية السورية (Legal Library)
// ============================================================================

/// مواد المكتبة القانونية (قوانين، اجتهادات، مجلة، مذكرات...)
class LegalLibraryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemType => text()(); // law, precedent, bar_journal, memo, research, book, template, other
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get filePath => text().nullable()();
  TextColumn get fileName => text().nullable()();
  TextColumn get extractedText => text().nullable()();
  IntColumn get year => integer().withDefault(const Constant(0))();
  TextColumn get tags => text().nullable()(); // comma-separated
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isPrinciple => boolean().withDefault(const Constant(false))();
  // قانون
  TextColumn get lawNumber => text().nullable()();
  TextColumn get lawKind => text().nullable()();
  TextColumn get lastAmendment => text().nullable()();
  // اجتهاد
  TextColumn get court => text().nullable()();
  TextColumn get chamber => text().nullable()();
  TextColumn get decisionNumber => text().nullable()();
  TextColumn get baseNumber => text().nullable()();
  DateTimeColumn get decisionDate => dateTime().nullable()();
  TextColumn get principle => text().nullable()();
  // مجلة
  IntColumn get journalYear => integer().nullable()();
  TextColumn get journalIssue => text().nullable()();
  TextColumn get page => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// ربط مادة مكتبية بملف في المكتب
class LegalLibraryLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get libraryItemId => integer().references(LegalLibraryItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get entityType => integer()();
  IntColumn get entityId => integer()();
  TextColumn get entityTitle => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get linkedAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// 14. أوامر العمل للمعقب (Work Orders Offline)
// ============================================================================

class WorkOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get internalNumber => text().unique()();
  IntColumn get linkedEntityType => integer().withDefault(const Constant(0))();
  IntColumn get linkedEntityId => integer().withDefault(const Constant(0))();
  /// ربط أمر العمل مباشرة بملف المكتب (المرحلة السادسة من خارطة التنفيذ).
  IntColumn get officeFileId => integer().nullable()();
  TextColumn get assignedToName => text()();
  TextColumn get assignedToPhone => text().nullable()();
  TextColumn get orderType => text()(); // court_attendance, document_photocopy, ...
  TextColumn get priority => text().withDefault(const Constant('medium'))(); // high, medium, low
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get instructions => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get printedAt => dateTime().nullable()();
  DateTimeColumn get whatsappSentAt => dateTime().nullable()();
  TextColumn get resultStatus => text().nullable()();
  TextColumn get resultText => text().nullable()();
  DateTimeColumn get resultDate => dateTime().nullable()();
  DateTimeColumn get nextDate => dateTime().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
