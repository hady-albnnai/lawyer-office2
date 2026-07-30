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

  /// مراقبة المحاكم النشطة مع فلترة اختيارية حسب العمود المهجور `type`.
  ///
  /// يبقى للتوافق مع الشاشات القديمة. للاختيار حسب درجة التقاضي
  /// استعمل [watchCourtsOfKind] التي تعتمد `court_kind`.
  Stream<List<Court>> watchActiveCourts({String? type}) {
    final query = select(courts)..where((t) => t.isActive.equals(true));
    if (type != null && type.isNotEmpty) {
      query.where((t) => t.type.equals(type));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.watch();
  }

  /// المحاكم النشطة من نوع محدد (`CourtCatalog.appealCivil` مثلاً).
  ///
  /// تُستثنى السجلات بلا `court_kind` لأنها بقايا الإصدار الخامس
  /// التي تحمل اسم محافظة مجرداً؛ عرضها يعيد الالتباس الذي أُصلح.
  Stream<List<Court>> watchCourtsOfKind(String kindId) {
    final query = select(courts)
      ..where((t) => t.isActive.equals(true) & t.courtKind.equals(kindId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.watch();
  }

  /// محكمة بعينها من نوعها ومحافظتها، أو `null` إن لم توجد.
  ///
  /// تُستعمل عند النقل لمرحلة أعلى: يختار المحامي النوع والمحافظة
  /// فيُستخرج `courtId` الحقيقي بدل تمرير فهرس قائمة.
  Future<Court?> findCourt({
    required String kindId,
    required String governorate,
  }) {
    return (select(courts)
          ..where((t) =>
              t.courtKind.equals(kindId) & t.name.equals(governorate))
          ..limit(1))
        .getSingleOrNull();
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
