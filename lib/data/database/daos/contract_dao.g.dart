// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contract_dao.dart';

// ignore_for_file: type=lint
mixin _$ContractDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonsTable get persons => attachedDatabase.persons;
  $CompaniesTable get companies => attachedDatabase.companies;
  $CourtsTable get courts => attachedDatabase.courts;
  $CasesTable get cases => attachedDatabase.cases;
  $ContractsTable get contracts => attachedDatabase.contracts;
  $NotariesTable get notaries => attachedDatabase.notaries;
  $PowersOfAttorneyTable get powersOfAttorney =>
      attachedDatabase.powersOfAttorney;
  $ContractPartiesTable get contractParties => attachedDatabase.contractParties;
  $ContractRemindersTable get contractReminders =>
      attachedDatabase.contractReminders;
  $ContractInstallmentsTable get contractInstallments =>
      attachedDatabase.contractInstallments;
  $ContractTemplatesTable get contractTemplates =>
      attachedDatabase.contractTemplates;
  $ContractVersionsTable get contractVersions =>
      attachedDatabase.contractVersions;
  ContractDaoManager get managers => ContractDaoManager(this);
}

class ContractDaoManager {
  final _$ContractDaoMixin _db;
  ContractDaoManager(this._db);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db.attachedDatabase, _db.persons);
  $$CompaniesTableTableManager get companies =>
      $$CompaniesTableTableManager(_db.attachedDatabase, _db.companies);
  $$CourtsTableTableManager get courts =>
      $$CourtsTableTableManager(_db.attachedDatabase, _db.courts);
  $$CasesTableTableManager get cases =>
      $$CasesTableTableManager(_db.attachedDatabase, _db.cases);
  $$ContractsTableTableManager get contracts =>
      $$ContractsTableTableManager(_db.attachedDatabase, _db.contracts);
  $$NotariesTableTableManager get notaries =>
      $$NotariesTableTableManager(_db.attachedDatabase, _db.notaries);
  $$PowersOfAttorneyTableTableManager get powersOfAttorney =>
      $$PowersOfAttorneyTableTableManager(
        _db.attachedDatabase,
        _db.powersOfAttorney,
      );
  $$ContractPartiesTableTableManager get contractParties =>
      $$ContractPartiesTableTableManager(
        _db.attachedDatabase,
        _db.contractParties,
      );
  $$ContractRemindersTableTableManager get contractReminders =>
      $$ContractRemindersTableTableManager(
        _db.attachedDatabase,
        _db.contractReminders,
      );
  $$ContractInstallmentsTableTableManager get contractInstallments =>
      $$ContractInstallmentsTableTableManager(
        _db.attachedDatabase,
        _db.contractInstallments,
      );
  $$ContractTemplatesTableTableManager get contractTemplates =>
      $$ContractTemplatesTableTableManager(
        _db.attachedDatabase,
        _db.contractTemplates,
      );
  $$ContractVersionsTableTableManager get contractVersions =>
      $$ContractVersionsTableTableManager(
        _db.attachedDatabase,
        _db.contractVersions,
      );
}
