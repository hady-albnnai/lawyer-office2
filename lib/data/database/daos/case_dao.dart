import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'case_dao.g.dart';

/// كائن الوصول لبيانات الدعاوى، الجلسات، المراحل، والأطراف (CaseDao)
@DriftAccessor(tables: [
  Cases,
  CaseParties,
  CasePhases,
  CaseSessions,
  CaseActions,
  Courts,
  Persons,
  OpponentLawyers,
])
class CaseDao extends DatabaseAccessor<AppDatabase> with _$CaseDaoMixin {
  CaseDao(super.db);

  // ---------------------------------------------------------------------------
  // إدارة ملفات الدعاوى (Cases)
  // ---------------------------------------------------------------------------

  /// مراقبة جميع الدعاوى مرتبة تنازلياً حسب السنة والرقم الداخلي
  Stream<List<Case>> watchAllCases() {
    return (select(cases)
          ..orderBy([
            (t) => OrderingTerm(expression: t.year, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.internalNumber, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<Case>> getAllCases() {
    return (select(cases)
          ..orderBy([
            (t) => OrderingTerm(expression: t.year, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.internalNumber, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<List<CaseSession>> getSessionsForCase(int caseId) {
    return (select(caseSessions)..where((t) => t.caseId.equals(caseId))).get();
  }

  Future<List<CaseParty>> getPartiesForCase(int caseId) {
    return (select(caseParties)..where((t) => t.caseId.equals(caseId))).get();
  }

  Future<List<CasePhase>> getPhasesForCase(int caseId) {
    return (select(casePhases)..where((t) => t.caseId.equals(caseId))).get();
  }

  Future<Court?> getCourtById(int id) {
    return (select(courts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// جلب ملف دعوى واحد بالمعرف
  Future<Case?> getCaseById(int id) {
    return (select(cases)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// إدخال دعوى جديدة وإرجاع معرفها
  Future<int> insertCase(CasesCompanion companion) {
    return into(cases).insert(companion);
  }

  /// تحديث بيانات دعوى قائمة
  Future<bool> updateCase(CasesCompanion companion) {
    return update(cases).replace(companion);
  }

  /// تحديث تاريخ الجلسة القادمة (Cached) في الدعوى
  Future<void> updateNextSessionDate(int caseId, DateTime? nextDate) {
    return (update(cases)..where((t) => t.id.equals(caseId))).write(
      CasesCompanion(
        nextSessionDate: Value(nextDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // إدارة أطراف الدعوى (CaseParties)
  // ---------------------------------------------------------------------------

  /// مراقبة أطراف دعوى معينة
  Stream<List<CaseParty>> watchCaseParties(int caseId) {
    return (select(caseParties)..where((t) => t.caseId.equals(caseId))).watch();
  }

  /// إضافة طرف إلى الدعوى (موكل أو خصم)
  Future<int> insertCaseParty(CasePartiesCompanion companion) {
    return into(caseParties).insert(companion);
  }

  /// إزالة طرف من الدعوى
  Future<int> deleteCaseParty(int id) {
    return (delete(caseParties)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // إدارة المراحل القضائية (CasePhases)
  // ---------------------------------------------------------------------------

  /// مراقبة تسلسل المراحل القضائية لملف
  Stream<List<CasePhase>> watchCasePhases(int caseId) {
    return (select(casePhases)
          ..where((t) => t.caseId.equals(caseId))
          ..orderBy([(t) => OrderingTerm(expression: t.phaseOrder)]))
        .watch();
  }

  /// إضافة مرحلة قضائية جديدة
  Future<int> insertCasePhase(CasePhasesCompanion companion) {
    return into(casePhases).insert(companion);
  }

  /// تحديث المرحلة القضائية (مثل إضافة القرار أو نقل المرحلة)
  Future<bool> updateCasePhase(CasePhasesCompanion companion) {
    return update(casePhases).replace(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة الجلسات القضائية (CaseSessions)
  // ---------------------------------------------------------------------------

  /// مراقبة الجلسات التابعة لدعوى مرتبة زمنياً
  Stream<List<CaseSession>> watchCaseSessions(int caseId) {
    return (select(caseSessions)
          ..where((t) => t.caseId.equals(caseId))
          ..orderBy([(t) => OrderingTerm(expression: t.sessionDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// جلب أحدث جلسة في دعوى معينة
  Future<CaseSession?> getLatestSession(int caseId) {
    return (select(caseSessions)
          ..where((t) => t.caseId.equals(caseId))
          ..orderBy([(t) => OrderingTerm(expression: t.sessionDate, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// إضافة جلسة قضائية جديدة
  Future<int> insertCaseSession(CaseSessionsCompanion companion) {
    return into(caseSessions).insert(companion);
  }

  /// تحديث نتيجة جلسة (قرار أو حضور)
  Future<bool> updateCaseSession(CaseSessionsCompanion companion) {
    return update(caseSessions).replace(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة الإجراءات الخارجية للملف (CaseActions)
  // ---------------------------------------------------------------------------

  /// مراقبة الإجراءات الخارجية لدعوى
  Stream<List<CaseAction>> watchCaseActions(int caseId) {
    return (select(caseActions)
          ..where((t) => t.caseId.equals(caseId))
          ..orderBy([(t) => OrderingTerm(expression: t.actionDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// إضافة إجراء خارجي جديد
  Future<int> insertCaseAction(CaseActionsCompanion companion) {
    return into(caseActions).insert(companion);
  }
}
