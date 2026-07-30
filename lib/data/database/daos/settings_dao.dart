import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [
  AppSettings,
  Security,
  ActivityLog,
  Backups,
  Courts,
  Cases,
])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  // AppSettings key-value
  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String? value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion(
        key: Value(key),
        value: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Map<String, String?>> getAllSettings() async {
    final rows = await select(appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }

  // Security
  Future<SecurityData?> getSecurity() {
    return (select(security)..limit(1)).getSingleOrNull();
  }

  Future<int> upsertSecurity(SecurityCompanion companion) async {
    final existing = await getSecurity();
    if (existing == null) {
      return into(security).insert(companion);
    }
    await (update(security)..where((t) => t.id.equals(existing.id))).write(companion);
    return existing.id;
  }

  // Activity log
  Stream<List<ActivityLogData>> watchActivityLog({int limit = 200}) {
    return (select(activityLog)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
          ..limit(limit))
        .watch();
  }

  Future<List<ActivityLogData>> getActivityLog({int limit = 200}) {
    return (select(activityLog)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  Future<int> insertActivity(ActivityLogCompanion companion) {
    return into(activityLog).insert(companion);
  }

  // Backups
  Stream<List<Backup>> watchBackups() {
    return (select(backups)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Backup>> getBackups() {
    return (select(backups)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> insertBackup(BackupsCompanion companion) {
    return into(backups).insert(companion);
  }

  // Courts
  Stream<List<Court>> watchCourts() {
    return (select(courts)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<List<Court>> getCourts() {
    return (select(courts)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Future<int> insertCourt(CourtsCompanion companion) {
    return into(courts).insert(companion);
  }

  /// كل المحاكم بما فيها المعطّلة (لشاشة الإعدادات المرجعية).
  Future<List<Court>> getAllCourtsIncludingInactive() {
    return (select(courts)..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  Future<void> updateCourt(int id,
      {required String name, String? type, String? city, String? courtKind}) {
    return (update(courts)..where((t) => t.id.equals(id))).write(
      CourtsCompanion(
        name: Value(name),
        type: Value(type),
        city: Value(city),
        courtKind: Value(courtKind),
      ),
    );
  }

  Future<void> setCourtActive(int id, bool active) {
    return (update(courts)..where((t) => t.id.equals(id))).write(
      CourtsCompanion(isActive: Value(active)),
    );
  }

  /// عدد الدعاوى المرتبطة بمحكمة. يُستخدم لمنع حذف محكمة مستعملة
  /// حتى لا تبقى الدعوى تشير إلى مرجع محذوف.
  Future<int> countCasesUsingCourt(int courtId) async {
    final rows = await (select(cases)..where((t) => t.courtId.equals(courtId))).get();
    return rows.length;
  }

  Future<int> deleteCourt(int id) {
    return (delete(courts)..where((t) => t.id.equals(id))).go();
  }
}
