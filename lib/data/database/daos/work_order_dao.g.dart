// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_order_dao.dart';

// ignore_for_file: type=lint
mixin _$WorkOrderDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkOrdersTable get workOrders => attachedDatabase.workOrders;
  WorkOrderDaoManager get managers => WorkOrderDaoManager(this);
}

class WorkOrderDaoManager {
  final _$WorkOrderDaoMixin _db;
  WorkOrderDaoManager(this._db);
  $$WorkOrdersTableTableManager get workOrders =>
      $$WorkOrdersTableTableManager(_db.attachedDatabase, _db.workOrders);
}
