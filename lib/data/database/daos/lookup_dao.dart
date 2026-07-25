import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'lookup_dao.g.dart';

/// كائن الوصول لبيانات القوائم السورية المرجعية والفرز السريع (LookupDao)
@DriftAccessor(tables: [
  Courts,
  CaseSubjects,
  PartyRolesLookup,
  ContractTypesLookup,
  CompanyTypesLookup,
])
class LookupDao extends DatabaseAccessor<AppDatabase> with _$LookupDaoMixin {
  LookupDao(super.db);

  // ---------------------------------------------------------------------------
  // إدارة قائمة المحاكم والدوائر القضائية (Courts)
  // ---------------------------------------------------------------------------

  /// مراقبة المحاكم النشطة مع فلترة اختيارية حسب نوع المحكمة (صلح، بداية، استئناف...)
  Stream<List<Court>> watchActiveCourts({String? type}) {
    final query = select(courts)..where((t) => t.isActive.equals(true));
    if (type != null && type.isNotEmpty) {
      query.where((t) => t.type.equals(type));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.watch();
  }

  /// إضافة محكمة أو دائرة قضائية جديدة للقائمة
  Future<int> insertCourt(CourtsCompanion companion) {
    return into(courts).insert(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة قائمة مواضيع الدعاوى (CaseSubjects)
  // ---------------------------------------------------------------------------

  /// مراقبة مواضيع الدعاوى الجاهزة حسب التصنيف (مدني، جزائي، شرعي، تجاري)
  Stream<List<CaseSubject>> watchActiveCaseSubjects({String? category}) {
    final query = select(caseSubjects)..where((t) => t.isActive.equals(true));
    if (category != null && category.isNotEmpty) {
      query.where((t) => t.category.equals(category));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.watch();
  }

  /// إضافة موضوع دعوى جديد للقائمة الدائمة
  Future<int> insertCaseSubject(CaseSubjectsCompanion companion) {
    return into(caseSubjects).insert(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة قائمة صفات الأطراف (PartyRolesLookup)
  // ---------------------------------------------------------------------------

  /// مراقبة صفات الأطراف المتاحة حسب التصنيف القضائي
  Stream<List<PartyRolesLookupData>> watchPartyRoles({required String category}) {
    return (select(partyRolesLookup)
          ..where((t) => t.isActive.equals(true) & t.category.equals(category))
          ..orderBy([(t) => OrderingTerm(expression: t.roleName)]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // إدارة قائمة أنواع العقود والشركات (Contracts & Companies Lookups)
  // ---------------------------------------------------------------------------

  /// مراقبة أنواع العقود المتاحة في النظام
  Stream<List<ContractTypesLookupData>> watchContractTypes() {
    return (select(contractTypesLookup)..where((t) => t.isActive.equals(true))).watch();
  }

  /// مراقبة أنواع الشركات (أشخاص / أموال)
  Stream<List<CompanyTypesLookupData>> watchCompanyTypes({String? category}) {
    final query = select(companyTypesLookup)..where((t) => t.isActive.equals(true));
    if (category != null) {
      query.where((t) => t.category.equals(category));
    }
    return query.watch();
  }
}
