import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/settings_repository.dart';
import 'package:lawyer_office/data/services/backup_service.dart';

/// تعديل/تعطيل/حذف المحاكم كان يجري في الذاكرة فقط.
/// المحاكم قائمة مرجعية تعتمد عليها الدعاوى، فحذف محكمة مستخدمة يترك
/// الدعوى تشير إلى مرجع محذوف.
void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SettingsRepository(db.settingsDao, BackupService());
  });

  tearDown(() async {
    await db.close();
  });

  test('Updating a court persists the new values', () async {
    final id = await repo.addCourt(name: 'بداية مدنية', type: 'مدني', city: 'دمشق');

    await repo.updateCourt(id: id, name: 'بداية مدنية ثانية', type: 'مدني', city: 'حمص');

    final courts = await repo.getAllCourtsIncludingInactive();
    final court = courts.firstWhere((c) => c.id == id);
    expect(court.name, 'بداية مدنية ثانية');
    expect(court.city, 'حمص');
  });

  test('Disabling a court keeps it stored but hides it from active lists', () async {
    final id = await repo.addCourt(name: 'محكمة معطّلة');

    await repo.setCourtActive(id: id, active: false, name: 'محكمة معطّلة');

    // لا تظهر في القائمة الفعّالة المستخدمة عند إنشاء الدعاوى
    final active = await repo.getCourts();
    expect(active.any((c) => c.id == id), isFalse);

    // لكنها ما زالت محفوظة وتظهر في شاشة القوائم المرجعية
    final all = await repo.getAllCourtsIncludingInactive();
    final court = all.firstWhere((c) => c.id == id);
    expect(court.isActive, isFalse);
  });

  test('Re-enabling a court brings it back to the active list', () async {
    final id = await repo.addCourt(name: 'محكمة');
    await repo.setCourtActive(id: id, active: false);
    await repo.setCourtActive(id: id, active: true);

    final active = await repo.getCourts();
    expect(active.any((c) => c.id == id), isTrue);
  });

  test('Unused court is deleted successfully', () async {
    final id = await repo.addCourt(name: 'محكمة غير مستخدمة');

    final error = await repo.deleteCourt(id: id, name: 'محكمة غير مستخدمة');

    expect(error, isNull);
    final all = await repo.getAllCourtsIncludingInactive();
    expect(all.any((c) => c.id == id), isFalse);
  });

  test('Court used by a case is protected from deletion', () async {
    final id = await repo.addCourt(name: 'بداية دمشق');
    await db.into(db.cases).insert(CasesCompanion.insert(
          internalNumber: 'دعوى/2026/0001',
          year: 2026,
          caseType: 'مدني',
          courtId: Value(id),
        ));

    final error = await repo.deleteCourt(id: id, name: 'بداية دمشق');

    expect(error, isNotNull, reason: 'يجب رفض حذف محكمة مرتبطة بدعوى');
    expect(error, contains('دعوى'));

    // المحكمة ما زالت موجودة فعلياً
    final all = await repo.getAllCourtsIncludingInactive();
    expect(all.any((c) => c.id == id), isTrue);
  });

  test('Court operations are written to the activity log', () async {
    final id = await repo.addCourt(name: 'محكمة للسجل');
    await repo.updateCourt(id: id, name: 'محكمة للسجل ٢');
    await repo.setCourtActive(id: id, active: false);

    final log = await repo.getActivityLog();
    final courtActions = log.where((e) => e.affectedTable == 'courts').map((e) => e.action).toList();
    expect(courtActions, contains('insert'));
    expect(courtActions, contains('update'));
    expect(courtActions, contains('disable'));
  });
}
