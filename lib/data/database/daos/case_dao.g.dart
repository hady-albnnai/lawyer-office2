// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'case_dao.dart';

// ignore_for_file: type=lint
mixin _$CaseDaoMixin on DatabaseAccessor<AppDatabase> {
  $CourtsTable get courts => attachedDatabase.courts;
  $CasesTable get cases => attachedDatabase.cases;
  $PersonsTable get persons => attachedDatabase.persons;
  $CasePartiesTable get caseParties => attachedDatabase.caseParties;
  $CasePhasesTable get casePhases => attachedDatabase.casePhases;
  $OpponentLawyersTable get opponentLawyers => attachedDatabase.opponentLawyers;
  $CaseSessionsTable get caseSessions => attachedDatabase.caseSessions;
  $CaseActionsTable get caseActions => attachedDatabase.caseActions;
  CaseDaoManager get managers => CaseDaoManager(this);
}

class CaseDaoManager {
  final _$CaseDaoMixin _db;
  CaseDaoManager(this._db);
  $$CourtsTableTableManager get courts =>
      $$CourtsTableTableManager(_db.attachedDatabase, _db.courts);
  $$CasesTableTableManager get cases =>
      $$CasesTableTableManager(_db.attachedDatabase, _db.cases);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db.attachedDatabase, _db.persons);
  $$CasePartiesTableTableManager get caseParties =>
      $$CasePartiesTableTableManager(_db.attachedDatabase, _db.caseParties);
  $$CasePhasesTableTableManager get casePhases =>
      $$CasePhasesTableTableManager(_db.attachedDatabase, _db.casePhases);
  $$OpponentLawyersTableTableManager get opponentLawyers =>
      $$OpponentLawyersTableTableManager(
          _db.attachedDatabase, _db.opponentLawyers);
  $$CaseSessionsTableTableManager get caseSessions =>
      $$CaseSessionsTableTableManager(_db.attachedDatabase, _db.caseSessions);
  $$CaseActionsTableTableManager get caseActions =>
      $$CaseActionsTableTableManager(_db.attachedDatabase, _db.caseActions);
}
