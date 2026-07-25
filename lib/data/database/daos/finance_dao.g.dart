// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_dao.dart';

// ignore_for_file: type=lint
mixin _$FinanceDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonsTable get persons => attachedDatabase.persons;
  $FeeAgreementsTable get feeAgreements => attachedDatabase.feeAgreements;
  $FeePaymentsTable get feePayments => attachedDatabase.feePayments;
  $ExpensesTable get expenses => attachedDatabase.expenses;
  FinanceDaoManager get managers => FinanceDaoManager(this);
}

class FinanceDaoManager {
  final _$FinanceDaoMixin _db;
  FinanceDaoManager(this._db);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db.attachedDatabase, _db.persons);
  $$FeeAgreementsTableTableManager get feeAgreements =>
      $$FeeAgreementsTableTableManager(_db.attachedDatabase, _db.feeAgreements);
  $$FeePaymentsTableTableManager get feePayments =>
      $$FeePaymentsTableTableManager(_db.attachedDatabase, _db.feePayments);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db.attachedDatabase, _db.expenses);
}
