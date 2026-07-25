// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_dao.dart';

// ignore_for_file: type=lint
mixin _$PersonDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonsTable get persons => attachedDatabase.persons;
  $LegalEntitiesTable get legalEntities => attachedDatabase.legalEntities;
  $PersonRolesTable get personRoles => attachedDatabase.personRoles;
  $TeamMembersTable get teamMembers => attachedDatabase.teamMembers;
  $OpponentLawyersTable get opponentLawyers => attachedDatabase.opponentLawyers;
  $NotariesTable get notaries => attachedDatabase.notaries;
  $PowersOfAttorneyTable get powersOfAttorney =>
      attachedDatabase.powersOfAttorney;
  $PoaPartiesTable get poaParties => attachedDatabase.poaParties;
  $CourtsTable get courts => attachedDatabase.courts;
  $CasesTable get cases => attachedDatabase.cases;
  $CasePoaLinksTable get casePoaLinks => attachedDatabase.casePoaLinks;
  PersonDaoManager get managers => PersonDaoManager(this);
}

class PersonDaoManager {
  final _$PersonDaoMixin _db;
  PersonDaoManager(this._db);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db.attachedDatabase, _db.persons);
  $$LegalEntitiesTableTableManager get legalEntities =>
      $$LegalEntitiesTableTableManager(_db.attachedDatabase, _db.legalEntities);
  $$PersonRolesTableTableManager get personRoles =>
      $$PersonRolesTableTableManager(_db.attachedDatabase, _db.personRoles);
  $$TeamMembersTableTableManager get teamMembers =>
      $$TeamMembersTableTableManager(_db.attachedDatabase, _db.teamMembers);
  $$OpponentLawyersTableTableManager get opponentLawyers =>
      $$OpponentLawyersTableTableManager(
          _db.attachedDatabase, _db.opponentLawyers);
  $$NotariesTableTableManager get notaries =>
      $$NotariesTableTableManager(_db.attachedDatabase, _db.notaries);
  $$PowersOfAttorneyTableTableManager get powersOfAttorney =>
      $$PowersOfAttorneyTableTableManager(
          _db.attachedDatabase, _db.powersOfAttorney);
  $$PoaPartiesTableTableManager get poaParties =>
      $$PoaPartiesTableTableManager(_db.attachedDatabase, _db.poaParties);
  $$CourtsTableTableManager get courts =>
      $$CourtsTableTableManager(_db.attachedDatabase, _db.courts);
  $$CasesTableTableManager get cases =>
      $$CasesTableTableManager(_db.attachedDatabase, _db.cases);
  $$CasePoaLinksTableTableManager get casePoaLinks =>
      $$CasePoaLinksTableTableManager(_db.attachedDatabase, _db.casePoaLinks);
}
