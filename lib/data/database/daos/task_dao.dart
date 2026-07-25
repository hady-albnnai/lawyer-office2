import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'task_dao.g.dart';

/// كائن الوصول لبيانات الأعمال اليومية، النواقص، والخط الزمني (TaskDao)
@DriftAccessor(tables: [
  DailyTasks,
  TaskHistory,
  TimelineEvents,
  Deficiencies,
])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  // ---------------------------------------------------------------------------
  // إدارة الأعمال والمهام اليومية (DailyTasks)
  // ---------------------------------------------------------------------------

  /// مراقبة مهام يوم محدد
  Stream<List<DailyTask>> watchTasksByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (select(dailyTasks)
          ..where((t) => t.taskDate.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([
            (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.taskTime),
          ]))
        .watch();
  }

  /// مراقبة المهام حسب الحالة (مثل المهام المعلقة أو المجدولة)
  Stream<List<DailyTask>> watchTasksByStatus(int status) {
    return (select(dailyTasks)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm(expression: t.taskDate)]))
        .watch();
  }

  /// إضافة مهمة جديدة إلى جدول الأعمال
  Future<int> insertTask(DailyTasksCompanion companion) {
    return into(dailyTasks).insert(companion);
  }

  /// تحديث حالة مهمة (إتمام / تأجيل / إلغاء)
  Future<void> updateTaskStatus(int taskId, int newStatus) {
    return (update(dailyTasks)..where((t) => t.id.equals(taskId))).write(
      DailyTasksCompanion(
        status: Value(newStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// تعيين المكلف بالمهمة وإضافة ملاحظة تحضير (تبويب الغد)
  Future<void> assignTask(int taskId, {String? assignedTo, String? notes}) {
    return (update(dailyTasks)..where((t) => t.id.equals(taskId))).write(
      DailyTasksCompanion(
        assignedTo: assignedTo == null ? const Value.absent() : Value(assignedTo),
        notes: notes == null ? const Value.absent() : Value(notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// إدراج حركة في سجل تاريخ المهام (عند التأجيل أو الإلغاء)
  Future<int> insertTaskHistory(TaskHistoryCompanion companion) {
    return into(taskHistory).insert(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة النواقص القضائية والإدارية (Deficiencies)
  // ---------------------------------------------------------------------------

  /// مراقبة النواقص المفتوحة في المكتب (مع فلترة اختيارية بكيان معين)
  Stream<List<Deficiency>> watchOpenDeficiencies({int? entityType, int? entityId}) {
    final query = select(deficiencies)..where((t) => t.status.equals('open'));
    if (entityType != null) {
      query.where((t) => t.entityType.equals(entityType));
    }
    if (entityId != null) {
      query.where((t) => t.entityId.equals(entityId));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.severity, mode: OrderingMode.desc)]);
    return query.watch();
  }

  /// إدراج نقص جديد عند رصد غياب حقل إلزامي
  Future<int> insertDeficiency(DeficienciesCompanion companion) {
    return into(deficiencies).insert(companion);
  }

  /// إغلاق النقص وتحويل حالته إلى resolved
  Future<void> resolveDeficiency(int id) {
    return (update(deficiencies)..where((t) => t.id.equals(id))).write(
      DeficienciesCompanion(
        status: const Value('resolved'),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // إدارة الخط الزمني الشامل (TimelineEvents)
  // ---------------------------------------------------------------------------

  /// مراقبة شجرة الأحداث والخط الزمني لكيان محدد (دعوى، شركة، عقد...)
  Stream<List<TimelineEvent>> watchTimelineEvents(int entityType, int entityId) {
    return (select(timelineEvents)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId))
          ..orderBy([(t) => OrderingTerm(expression: t.eventDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// تسجيل حدث جديد في الخط الزمني للمكتب
  Future<int> insertTimelineEvent(TimelineEventsCompanion companion) {
    return into(timelineEvents).insert(companion);
  }
}
