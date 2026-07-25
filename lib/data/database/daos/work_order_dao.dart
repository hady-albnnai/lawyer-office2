import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'work_order_dao.g.dart';

@DriftAccessor(tables: [WorkOrders])
class WorkOrderDao extends DatabaseAccessor<AppDatabase> with _$WorkOrderDaoMixin {
  WorkOrderDao(super.db);

  Stream<List<WorkOrder>> watchAll() {
    return (select(workOrders)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<WorkOrder>> getAll() {
    return (select(workOrders)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> insertOrder(WorkOrdersCompanion companion) => into(workOrders).insert(companion);

  Future<bool> updateOrder(WorkOrdersCompanion companion) => update(workOrders).replace(companion);
}
