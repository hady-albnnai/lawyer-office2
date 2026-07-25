import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'person_dao.g.dart';

/// كائن الوصول لبيانات الأشخاص، الشركات الاعتبارية، فريق المكتب، والوكالات (PersonDao)
@DriftAccessor(tables: [
  Persons,
  LegalEntities,
  PersonRoles,
  TeamMembers,
  OpponentLawyers,
  Notaries,
  PowersOfAttorney,
  PoaParties,
  CasePoaLinks,
])
class PersonDao extends DatabaseAccessor<AppDatabase> with _$PersonDaoMixin {
  PersonDao(super.db);

  // ---------------------------------------------------------------------------
  // إدارة الأشخاص (Persons & LegalEntities)
  // ---------------------------------------------------------------------------

  /// مراقبة جميع الأشخاص في النظام مع فلترة اختيارية حسب النوع (طبيعي / اعتباري)
  Future<List<PersonEntity>> getAllPersons({int? type}) {
    final query = select(persons);
    if (type != null) query.where((t) => t.type.equals(type));
    return query.get();
  }

  Stream<List<PersonEntity>> watchAllPersons({int? type}) {
    final query = select(persons);
    if (type != null) {
      query.where((t) => t.type.equals(type));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.fullName)]);
    return query.watch();
  }

  /// جلب بيانات شخص بالمعرف
  Future<PersonEntity?> getPersonById(int id) {
    return (select(persons)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// إضافة شخص جديد إلى النظام
  Future<int> insertPerson(PersonsCompanion companion) {
    return into(persons).insert(companion);
  }

  /// تحديث بيانات شخص قائمة
  Future<bool> updatePerson(PersonsCompanion companion) {
    return update(persons).replace(companion);
  }

  /// إدخال بيانات الكيان الاعتباري (الشركة / الجهة)
  Future<int> insertLegalEntity(LegalEntitiesCompanion companion) {
    return into(legalEntities).insert(companion);
  }

  /// جلب تفاصيل الكيان الاعتباري المرتبط بشخص
  Future<LegalEntity?> getLegalEntityByPersonId(int personId) {
    return (select(legalEntities)..where((t) => t.personId.equals(personId))).getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // إدارة الأدوار وفريق المكتب (Roles & Team)
  // ---------------------------------------------------------------------------

  /// مراقبة أدوار الشخص (موكل، خصم، شريك...)
  Future<List<PersonRole>> getPersonRoles(int personId) {
    return (select(personRoles)..where((t) => t.personId.equals(personId))).get();
  }

  Stream<List<PersonRole>> watchPersonRoles(int personId) {

    return (select(personRoles)..where((t) => t.personId.equals(personId))).watch();
  }

  /// إضافة دور جديد لشخص
  Future<int> insertPersonRole(PersonRolesCompanion companion) {
    return into(personRoles).insert(companion);
  }

  /// مراقبة أعضاء فريق المكتب (أستاذ، متمرن، معقب، موظفة)
  Stream<List<TeamMember>> watchTeamMembers() {
    return select(teamMembers).watch();
  }

  /// إضافة عضو إلى فريق المكتب
  Future<int> insertTeamMember(TeamMembersCompanion companion) {
    return into(teamMembers).insert(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة المحامين الأخصام وكتاب العدل (Opponent Lawyers & Notaries)
  // ---------------------------------------------------------------------------

  /// مراقبة دليل المحامين الأخصام
  Stream<List<OpponentLawyer>> watchOpponentLawyers() {
    return (select(opponentLawyers)..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  /// إضافة محامي خصم جديد
  Future<int> insertOpponentLawyer(OpponentLawyersCompanion companion) {
    return into(opponentLawyers).insert(companion);
  }

  /// مراقبة كتاب العدل ومندوبي النقابة الـ 14
  Stream<List<Notary>> watchNotaries() {
    return (select(notaries)..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  // ---------------------------------------------------------------------------
  // إدارة الوكالات القضائية (Powers of Attorney)
  // ---------------------------------------------------------------------------

  /// مراقبة سندات التوكيل في المكتب
  Future<List<PowersOfAttorneyData>> getAllPoas() {
    return (select(powersOfAttorney)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Stream<List<PowersOfAttorneyData>> watchAllPoas() {

    return (select(powersOfAttorney)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// إضافة سند توكيل جديد
  Future<int> insertPoa(PowersOfAttorneyCompanion companion) {
    return into(powersOfAttorney).insert(companion);
  }

  /// ربط موكل أو وكيل بسند توكيل
  Future<int> insertPoaParty(PoaPartiesCompanion companion) {
    return into(poaParties).insert(companion);
  }

  /// ربط سند توكيل بملف دعوى قضائية
  Future<int> linkPoaToCase(int caseId, int poaId) {
    return into(casePoaLinks).insert(
      CasePoaLinksCompanion.insert(caseId: caseId, poaId: poaId),
    );
  }
}
