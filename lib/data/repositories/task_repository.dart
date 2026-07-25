import 'package:drift/drift.dart';
import '../../core/enums/app_enums.dart';
import '../database/database.dart';
import '../database/daos/task_dao.dart';
import '../services/task_sync_service.dart';
import '../services/deficiency_service.dart';

/// مستودع إدارة المهام اليومية، دورة الحياة الموحدة، النواقص، والخط الزمني (TaskRepository)
class TaskRepository {
  final TaskDao _taskDao;
  final TaskSyncService _taskSyncService;
  final DeficiencyService _deficiencyService;

  TaskRepository(this._taskDao, this._taskSyncService, this._deficiencyService);

  Stream<List<DailyTask>> watchTasksByDate(DateTime date) => _taskDao.watchTasksByDate(date);
  Stream<List<DailyTask>> watchTasksByStatus(LifecycleStatus status) => _taskDao.watchTasksByStatus(status.index);

  Future<int> createManualTask(DailyTasksCompanion task) => _taskDao.insertTask(task);

  /// إتمام مهمة أو جلسة قضائية ونقلها لحالة completed
  Future<void> completeTask(int taskId, String userRef) async {
    await _taskDao.updateTaskStatus(taskId, LifecycleStatus.completed.index);
    await _taskDao.insertTaskHistory(
      TaskHistoryCompanion.insert(
        taskId: taskId,
        action: 'completed',
        notes: Value('تم إنجاز المهمة بنجاح بواسطة $userRef'),
      ),
    );
  }

  Future<void> postponeTask({
    required int taskId,
    required DateTime newDate,
    required String reason,
    required String userRef,
  }) async {
    await _taskSyncService.postponeTask(
      taskId: taskId,
      newDate: newDate,
      reason: reason,
      userRef: userRef,
    );
  }

  Future<void> cancelTask({
    required int taskId,
    required String reason,
    required String userRef,
  }) async {
    await _taskSyncService.cancelTask(
      taskId: taskId,
      reason: reason,
      userRef: userRef,
    );
  }

  /// تعيين مكلف بمهمة الغد وإضافة ملاحظة تحضير، مع تسجيل الحركة في سجل المهمة.
  Future<void> assignTask({
    required int taskId,
    String? assignedTo,
    String? preparationNotes,
    required String userRef,
  }) async {
    await _taskDao.assignTask(taskId, assignedTo: assignedTo, notes: preparationNotes);
    final who = (assignedTo ?? '').trim();
    await _taskDao.insertTaskHistory(
      TaskHistoryCompanion.insert(
        taskId: taskId,
        action: 'assigned',
        notes: Value(
          who.isEmpty
              ? 'تحديث تحضير المهمة بواسطة $userRef'
              : 'تعيين المكلف: $who بواسطة $userRef',
        ),
      ),
    );
  }

  Stream<List<Deficiency>> watchOpenDeficiencies({EntityType? entityType, int? entityId}) {
    return _taskDao.watchOpenDeficiencies(
      entityType: entityType?.index,
      entityId: entityId,
    );
  }

  /// إضافة نقص يدوي على كيان (يرصده المحامي بنفسه لا النظام).
  Future<int> addManualDeficiency({
    required EntityType entityType,
    required int entityId,
    required String fieldName,
    required String description,
    int severity = 0,
  }) {
    return _taskDao.insertDeficiency(
      DeficienciesCompanion.insert(
        entityType: entityType.index,
        entityId: entityId,
        fieldName: fieldName,
        description: description,
        severity: Value(severity),
      ),
    );
  }

  Future<void> resolveDeficiency(int id) => _taskDao.resolveDeficiency(id);
  Future<void> ignoreDeficiency(int id, String reason, String userRef) => _deficiencyService.ignoreDeficiency(id, reason, userRef);

  Stream<List<TimelineEvent>> watchTimelineEvents(EntityType entityType, int entityId) {
    return _taskDao.watchTimelineEvents(entityType.index, entityId);
  }
}
