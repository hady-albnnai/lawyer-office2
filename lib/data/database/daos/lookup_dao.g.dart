// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookup_dao.dart';

// ignore_for_file: type=lint
mixin _$LookupDaoMixin on DatabaseAccessor<AppDatabase> {
  $CourtsTable get courts => attachedDatabase.courts;
  $CaseSubjectsTable get caseSubjects => attachedDatabase.caseSubjects;
  $PartyRolesLookupTable get partyRolesLookup =>
      attachedDatabase.partyRolesLookup;
  $ContractTypesLookupTable get contractTypesLookup =>
      attachedDatabase.contractTypesLookup;
  $CompanyTypesLookupTable get companyTypesLookup =>
      attachedDatabase.companyTypesLookup;
  LookupDaoManager get managers => LookupDaoManager(this);
}

class LookupDaoManager {
  final _$LookupDaoMixin _db;
  LookupDaoManager(this._db);
  $$CourtsTableTableManager get courts =>
      $$CourtsTableTableManager(_db.attachedDatabase, _db.courts);
  $$CaseSubjectsTableTableManager get caseSubjects =>
      $$CaseSubjectsTableTableManager(_db.attachedDatabase, _db.caseSubjects);
  $$PartyRolesLookupTableTableManager get partyRolesLookup =>
      $$PartyRolesLookupTableTableManager(
          _db.attachedDatabase, _db.partyRolesLookup);
  $$ContractTypesLookupTableTableManager get contractTypesLookup =>
      $$ContractTypesLookupTableTableManager(
          _db.attachedDatabase, _db.contractTypesLookup);
  $$CompanyTypesLookupTableTableManager get companyTypesLookup =>
      $$CompanyTypesLookupTableTableManager(
          _db.attachedDatabase, _db.companyTypesLookup);
}
