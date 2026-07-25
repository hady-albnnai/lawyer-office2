// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_dao.dart';

// ignore_for_file: type=lint
mixin _$CompanyDaoMixin on DatabaseAccessor<AppDatabase> {
  $CompaniesTable get companies => attachedDatabase.companies;
  $CompanyPhasesTable get companyPhases => attachedDatabase.companyPhases;
  $CompanyManagementTable get companyManagement =>
      attachedDatabase.companyManagement;
  $PersonsTable get persons => attachedDatabase.persons;
  $CompanyPartnersTable get companyPartners => attachedDatabase.companyPartners;
  $CompanyDirectorsTable get companyDirectors =>
      attachedDatabase.companyDirectors;
  CompanyDaoManager get managers => CompanyDaoManager(this);
}

class CompanyDaoManager {
  final _$CompanyDaoMixin _db;
  CompanyDaoManager(this._db);
  $$CompaniesTableTableManager get companies =>
      $$CompaniesTableTableManager(_db.attachedDatabase, _db.companies);
  $$CompanyPhasesTableTableManager get companyPhases =>
      $$CompanyPhasesTableTableManager(_db.attachedDatabase, _db.companyPhases);
  $$CompanyManagementTableTableManager get companyManagement =>
      $$CompanyManagementTableTableManager(
          _db.attachedDatabase, _db.companyManagement);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db.attachedDatabase, _db.persons);
  $$CompanyPartnersTableTableManager get companyPartners =>
      $$CompanyPartnersTableTableManager(
          _db.attachedDatabase, _db.companyPartners);
  $$CompanyDirectorsTableTableManager get companyDirectors =>
      $$CompanyDirectorsTableTableManager(
          _db.attachedDatabase, _db.companyDirectors);
}
