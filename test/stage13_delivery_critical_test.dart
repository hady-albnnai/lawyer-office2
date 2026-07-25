import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/work_order_repository.dart';
import 'package:lawyer_office/data/repositories/settings_repository.dart';
import 'package:lawyer_office/data/services/backup_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Work order full lifecycle persists statuses', () async {
    final repo = WorkOrderRepository(db.workOrderDao);
    final id = await repo.create(
      assignedToName: 'معقب تجريبي',
      assignedToPhone: '0999',
      orderType: 'court_attendance',
      priority: 'high',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      instructions: 'مراجعة ديوان',
      createdBy: 'أستاذ',
    );
    expect(id, greaterThan(0));

    await repo.markPrinted(id, userRef: 'مكتب');
    expect((await repo.getById(id))!.status, 'printed');

    await repo.markWhatsAppSent(id, userRef: 'مكتب');
    expect((await repo.getById(id))!.status, 'waiting_for_result');

    await repo.enterResult(
      id: id,
      resultStatus: 'completed',
      resultText: 'تم التنفيذ',
      nextDate: DateTime.now().add(const Duration(days: 7)),
      userRef: 'مكتب',
    );
    expect((await repo.getById(id))!.status, 'result_entered');

    await repo.approve(id, userRef: 'أستاذ');
    final finalWo = await repo.getById(id);
    expect(finalWo!.status, 'approved');
    expect(finalWo.approvedAt, isNotNull);

    final logs = await db.select(db.activityLog).get();
    expect(logs, isNotEmpty);

    // أتمتة الاعتماد: مهمة متابعة عند nextDate
    final tasks = await db.select(db.dailyTasks).get();
    expect(tasks.any((t) => t.taskType == 'work_order_followup'), isTrue);
    final events = await db.select(db.timelineEvents).get();
    expect(events.any((e) => e.eventType == 'work_order_approved'), isTrue);
  });

  test('First-run security direct set works', () async {
    final repo = SettingsRepository(db.settingsDao, BackupService());
    await repo.setSecurityDirect(
      password: 'Client@123',
      securityQuestion: 'مدينة؟',
      securityAnswer: 'السويداء',
      userRef: 'زبون',
    );
    final sec = await repo.getSecurity();
    expect(sec, isNotNull);
    expect(sec!.securityQuestion, 'مدينة؟');
  });
}
