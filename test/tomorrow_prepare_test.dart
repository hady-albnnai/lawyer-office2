import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/task_repository.dart';
import 'package:lawyer_office/data/services/deficiency_service.dart';
import 'package:lawyer_office/data/services/task_sync_service.dart';

/// اختبارات تحضير الغد (البند 22 من خطة مكتب العمل):
/// تعيين المكلف وملاحظة التحضير يجب أن يُحفظا فعلياً ويُسجَّلا في تاريخ المهمة.
void main() {
  late AppDatabase db;
  late TaskRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TaskRepository(db.taskDao, TaskSyncService(db), DeficiencyService(db));
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> newTask({String? assignedTo, String? notes}) {
    return db.into(db.dailyTasks).insert(DailyTasksCompanion.insert(
          taskType: 'manual',
          title: 'تجهيز ملف جلسة الغد',
          taskDate: DateTime(2026, 7, 25),
          assignedTo: Value(assignedTo),
          notes: Value(notes),
        ));
  }

  Future<DailyTask> readTask(int id) =>
      (db.select(db.dailyTasks)..where((t) => t.id.equals(id))).getSingle();

  test('Assigning a task persists assignee and preparation notes', () async {
    final id = await newTask();

    await repo.assignTask(
      taskId: id,
      assignedTo: 'المعقب سامر',
      preparationNotes: 'إحضار صورة السجل العقاري',
      userRef: 'هادي',
    );

    final task = await readTask(id);
    expect(task.assignedTo, 'المعقب سامر');
    expect(task.notes, 'إحضار صورة السجل العقاري');
  });

  test('Assignment is recorded in task history with the acting user', () async {
    final id = await newTask();

    await repo.assignTask(taskId: id, assignedTo: 'أحمد', userRef: 'هادي');

    final history = await (db.select(db.taskHistory)..where((h) => h.taskId.equals(id))).get();
    expect(history, hasLength(1));
    expect(history.first.action, 'assigned');
    expect(history.first.notes, contains('أحمد'));
    expect(history.first.notes, contains('هادي'));
  });

  test('Omitting a field leaves the previous value untouched', () async {
    final id = await newTask(assignedTo: 'سامر', notes: 'ملاحظة قديمة');

    // تحديث الملاحظة فقط
    await repo.assignTask(taskId: id, preparationNotes: 'ملاحظة جديدة', userRef: 'هادي');

    final task = await readTask(id);
    expect(task.assignedTo, 'سامر', reason: 'المكلف يجب ألا يُمسح عند تحديث الملاحظة فقط');
    expect(task.notes, 'ملاحظة جديدة');
  });

  test('Reassigning a task overwrites the previous assignee', () async {
    final id = await newTask(assignedTo: 'سامر');

    await repo.assignTask(taskId: id, assignedTo: 'خالد', userRef: 'هادي');

    final task = await readTask(id);
    expect(task.assignedTo, 'خالد');

    final history = await (db.select(db.taskHistory)..where((h) => h.taskId.equals(id))).get();
    expect(history.first.notes, contains('خالد'));
  });

  test('Clearing the assignee is logged as a preparation update', () async {
    final id = await newTask(assignedTo: 'سامر');

    await repo.assignTask(taskId: id, assignedTo: '', userRef: 'هادي');

    final task = await readTask(id);
    expect(task.assignedTo, '');

    final history = await (db.select(db.taskHistory)..where((h) => h.taskId.equals(id))).get();
    expect(history.first.notes, contains('تحديث تحضير المهمة'));
  });
}
