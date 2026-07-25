import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'finance_dao.g.dart';

/// كائن الوصول لبيانات المالية الموحدة (اتفاقيات الأتعاب، الدفعات، والمصاريف)
@DriftAccessor(tables: [
  FeeAgreements,
  FeePayments,
  Expenses,
  Persons,
])
class FinanceDao extends DatabaseAccessor<AppDatabase> with _$FinanceDaoMixin {
  FinanceDao(super.db);

  // ---------------------------------------------------------------------------
  // اتفاقيات الأتعاب
  // ---------------------------------------------------------------------------

  Stream<List<FeeAgreement>> watchAllAgreements() {
    return (select(feeAgreements)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<FeeAgreement>> getAllAgreements() {
    return (select(feeAgreements)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Stream<List<FeeAgreement>> watchAgreementsByEntity(int entityType, int entityId) {
    return (select(feeAgreements)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId)))
        .watch();
  }

  Future<List<FeeAgreement>> getAgreementsByEntity(int entityType, int entityId) {
    return (select(feeAgreements)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<FeeAgreement?> getAgreementById(int id) {
    return (select(feeAgreements)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertAgreement(FeeAgreementsCompanion companion) {
    return into(feeAgreements).insert(companion);
  }

  Future<bool> updateAgreement(FeeAgreementsCompanion companion) {
    return update(feeAgreements).replace(companion);
  }

  // ---------------------------------------------------------------------------
  // سندات القبض
  // ---------------------------------------------------------------------------

  Stream<List<FeePayment>> watchAllPayments() {
    return (select(feePayments)
          ..orderBy([(t) => OrderingTerm(expression: t.paymentDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<FeePayment>> getAllPayments() {
    return (select(feePayments)
          ..orderBy([(t) => OrderingTerm(expression: t.paymentDate, mode: OrderingMode.desc)]))
        .get();
  }

  Stream<List<FeePayment>> watchPaymentsByAgreement(int agreementId) {
    return (select(feePayments)
          ..where((t) => t.agreementId.equals(agreementId))
          ..orderBy([(t) => OrderingTerm(expression: t.paymentDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<FeePayment>> getPaymentsByAgreements(List<int> agreementIds) {
    if (agreementIds.isEmpty) return Future.value(const <FeePayment>[]);
    return (select(feePayments)
          ..where((t) => t.agreementId.isIn(agreementIds))
          ..orderBy([(t) => OrderingTerm(expression: t.paymentDate, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> insertPayment(FeePaymentsCompanion companion) {
    return into(feePayments).insert(companion);
  }

  // ---------------------------------------------------------------------------
  // المصاريف
  // ---------------------------------------------------------------------------

  Stream<List<Expense>> watchAllExpenses() {
    return (select(expenses)
          ..orderBy([(t) => OrderingTerm(expression: t.expenseDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Expense>> getAllExpenses() {
    return (select(expenses)
          ..orderBy([(t) => OrderingTerm(expression: t.expenseDate, mode: OrderingMode.desc)]))
        .get();
  }

  Stream<List<Expense>> watchExpensesByEntity(int entityType, int entityId) {
    return (select(expenses)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId))
          ..orderBy([(t) => OrderingTerm(expression: t.expenseDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Expense>> getExpensesByEntity(int entityType, int entityId) {
    return (select(expenses)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId))
          ..orderBy([(t) => OrderingTerm(expression: t.expenseDate, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> insertExpense(ExpensesCompanion companion) {
    return into(expenses).insert(companion);
  }

  Future<PersonEntity?> getPersonById(int id) {
    return (select(persons)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<PersonEntity>> getAllPersons() {
    return select(persons).get();
  }
}
