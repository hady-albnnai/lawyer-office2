// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_dao.dart';

// ignore_for_file: type=lint
mixin _$TaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $DailyTasksTable get dailyTasks => attachedDatabase.dailyTasks;
  $TaskHistoryTable get taskHistory => attachedDatabase.taskHistory;
  $TimelineEventsTable get timelineEvents => attachedDatabase.timelineEvents;
  $DeficienciesTable get deficiencies => attachedDatabase.deficiencies;
  TaskDaoManager get managers => TaskDaoManager(this);
}

class TaskDaoManager {
  final _$TaskDaoMixin _db;
  TaskDaoManager(this._db);
  $$DailyTasksTableTableManager get dailyTasks =>
      $$DailyTasksTableTableManager(_db.attachedDatabase, _db.dailyTasks);
  $$TaskHistoryTableTableManager get taskHistory =>
      $$TaskHistoryTableTableManager(_db.attachedDatabase, _db.taskHistory);
  $$TimelineEventsTableTableManager get timelineEvents =>
      $$TimelineEventsTableTableManager(
          _db.attachedDatabase, _db.timelineEvents);
  $$DeficienciesTableTableManager get deficiencies =>
      $$DeficienciesTableTableManager(_db.attachedDatabase, _db.deficiencies);
}
