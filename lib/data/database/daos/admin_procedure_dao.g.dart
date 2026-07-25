// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_procedure_dao.dart';

// ignore_for_file: type=lint
mixin _$AdminProcedureDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonsTable get persons => attachedDatabase.persons;
  $AdminProceduresTable get adminProcedures => attachedDatabase.adminProcedures;
  $AdminStepsTable get adminSteps => attachedDatabase.adminSteps;
  $AdminProcedureTypesTable get adminProcedureTypes =>
      attachedDatabase.adminProcedureTypes;
  AdminProcedureDaoManager get managers => AdminProcedureDaoManager(this);
}

class AdminProcedureDaoManager {
  final _$AdminProcedureDaoMixin _db;
  AdminProcedureDaoManager(this._db);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db.attachedDatabase, _db.persons);
  $$AdminProceduresTableTableManager get adminProcedures =>
      $$AdminProceduresTableTableManager(
          _db.attachedDatabase, _db.adminProcedures);
  $$AdminStepsTableTableManager get adminSteps =>
      $$AdminStepsTableTableManager(_db.attachedDatabase, _db.adminSteps);
  $$AdminProcedureTypesTableTableManager get adminProcedureTypes =>
      $$AdminProcedureTypesTableTableManager(
          _db.attachedDatabase, _db.adminProcedureTypes);
}
