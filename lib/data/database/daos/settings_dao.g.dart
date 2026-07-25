// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_dao.dart';

// ignore_for_file: type=lint
mixin _$SettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AppSettingsTable get appSettings => attachedDatabase.appSettings;
  $SecurityTable get security => attachedDatabase.security;
  $ActivityLogTable get activityLog => attachedDatabase.activityLog;
  $BackupsTable get backups => attachedDatabase.backups;
  $CourtsTable get courts => attachedDatabase.courts;
  $CasesTable get cases => attachedDatabase.cases;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db.attachedDatabase, _db.appSettings);
  $$SecurityTableTableManager get security =>
      $$SecurityTableTableManager(_db.attachedDatabase, _db.security);
  $$ActivityLogTableTableManager get activityLog =>
      $$ActivityLogTableTableManager(_db.attachedDatabase, _db.activityLog);
  $$BackupsTableTableManager get backups =>
      $$BackupsTableTableManager(_db.attachedDatabase, _db.backups);
  $$CourtsTableTableManager get courts =>
      $$CourtsTableTableManager(_db.attachedDatabase, _db.courts);
  $$CasesTableTableManager get cases =>
      $$CasesTableTableManager(_db.attachedDatabase, _db.cases);
}
