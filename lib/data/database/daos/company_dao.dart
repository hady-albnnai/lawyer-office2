import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'company_dao.g.dart';

/// كائن الوصول لبيانات تأسيس وإدارة الشركات (CompanyDao)
@DriftAccessor(tables: [
  Companies,
  CompanyPhases,
  CompanyManagement,
  CompanyPartners,
  CompanyDirectors,
  Persons,
])
class CompanyDao extends DatabaseAccessor<AppDatabase> with _$CompanyDaoMixin {
  CompanyDao(super.db);

  // ---------------------------------------------------------------------------
  // إدارة ملفات الشركات (Companies)
  // ---------------------------------------------------------------------------

  /// مراقبة كافة ملفات الشركات في النظام مرتبة حسب تاريخ التأسيس
  Stream<List<Company>> watchAllCompanies() {
    return (select(companies)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// جلب ملف شركة واحد بالمعرف
  Future<Company?> getCompanyById(int id) {
    return (select(companies)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// إدخال ملف شركة جديد وإرجاع معرفه
  Future<int> insertCompany(CompaniesCompanion companion) {
    return into(companies).insert(companion);
  }

  /// تحديث بيانات شركة قائمة
  Future<bool> updateCompany(CompaniesCompanion companion) {
    return update(companies).replace(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة مراحل التأسيس (CompanyPhases - دورة الحياة الموحدة)
  // ---------------------------------------------------------------------------

  /// مراقبة مراحل تأسيس شركة مرتبة حسب التسلسل
  Stream<List<CompanyPhase>> watchCompanyPhases(int companyId) {
    return (select(companyPhases)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm(expression: t.phaseOrder)]))
        .watch();
  }

  /// إدراج مرحلة تأسيس جديدة
  Future<int> insertCompanyPhase(CompanyPhasesCompanion companion) {
    return into(companyPhases).insert(companion);
  }

  /// تحديث حالة أو تاريخ مرحلة تأسيس
  Future<bool> updateCompanyPhase(CompanyPhasesCompanion companion) {
    return update(companyPhases).replace(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة ما بعد التأسيس (CompanyManagement - اجتماعات وتعديلات وتجديدات)
  // ---------------------------------------------------------------------------

  /// مراقبة أنشطة إدارة ما بعد التأسيس لشركة معينة
  Stream<List<CompanyManagementData>> watchCompanyManagement(int companyId) {
    return (select(companyManagement)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm(expression: t.actionDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// إضافة محضر اجتماع، تعديل هيكلي، أو تجديد سنوي
  Future<int> insertCompanyManagement(CompanyManagementCompanion companion) {
    return into(companyManagement).insert(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة الشركاء والمديرين (Partners & Directors)
  // ---------------------------------------------------------------------------

  /// مراقبة قائمة الشركاء في شركة
  Stream<List<CompanyPartner>> watchCompanyPartners(int companyId) {
    return (select(companyPartners)..where((t) => t.companyId.equals(companyId))).watch();
  }

  /// إضافة شريك جديد للشركة
  Future<int> insertCompanyPartner(CompanyPartnersCompanion companion) {
    return into(companyPartners).insert(companion);
  }

  /// مراقبة مجلس الإدارة والمديرين والمفوضين
  Stream<List<CompanyDirector>> watchCompanyDirectors(int companyId) {
    return (select(companyDirectors)..where((t) => t.companyId.equals(companyId))).watch();
  }

  /// تعيين مدير أو مفوض بالتوقيع في الشركة
  Future<int> insertCompanyDirector(CompanyDirectorsCompanion companion) {
    return into(companyDirectors).insert(companion);
  }
}
