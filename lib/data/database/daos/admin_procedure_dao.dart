import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'admin_procedure_dao.g.dart';

/// كائن الوصول لبيانات الإجراءات الإدارية والمعاملات وخطوات التنفيذ (AdminProcedureDao)
@DriftAccessor(tables: [
  AdminProcedures,
  AdminSteps,
  AdminProcedureTypes,
  Persons,
])
class AdminProcedureDao extends DatabaseAccessor<AppDatabase> with _$AdminProcedureDaoMixin {
  AdminProcedureDao(super.db);

  // ---------------------------------------------------------------------------
  // إدارة ملفات الإجراءات الإدارية (AdminProcedures)
  // ---------------------------------------------------------------------------

  /// مراقبة كافة الإجراءات الإدارية مرتبة حسب تاريخ التسجيل
  Stream<List<AdminProcedure>> watchAllProcedures() {
    return (select(adminProcedures)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// جلب إجراء إداري واحد بالمعرف
  Future<AdminProcedure?> getProcedureById(int id) {
    return (select(adminProcedures)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// إدخال معاملة أو إجراء إداري جديد
  Future<int> insertProcedure(AdminProceduresCompanion companion) {
    return into(adminProcedures).insert(companion);
  }

  /// تحديث بيانات إجراء إداري (مثل تحديث الخطوة الحالية أو الموعد القادم)
  Future<bool> updateProcedure(AdminProceduresCompanion companion) {
    return update(adminProcedures).replace(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة خطوات التنفيذ والـ Checklist (AdminSteps)
  // ---------------------------------------------------------------------------

  /// مراقبة خطوات تنفيذ إجراء إداري محدد
  Stream<List<AdminStep>> watchSteps(int procedureId) {
    return (select(adminSteps)
          ..where((t) => t.procedureId.equals(procedureId))
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .watch();
  }

  /// إضافة خطوة تنفيذ جديدة لمعاملة
  Future<int> insertStep(AdminStepsCompanion companion) {
    return into(adminSteps).insert(companion);
  }

  /// تحديث حالة أو نتيجة خطوة في المعاملة
  Future<bool> updateStep(AdminStepsCompanion companion) {
    return update(adminSteps).replace(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة القوائم الجاهزة ونماذج الـ Checklist (AdminProcedureTypes)
  // ---------------------------------------------------------------------------

  /// مراقبة أنواع الإجراءات المتاحة وقوائم المستندات والخطوات الجاهزة
  Stream<List<AdminProcedureType>> watchProcedureTypes({String? category}) {
    final query = select(adminProcedureTypes)..where((t) => t.isActive.equals(true));
    if (category != null && category.isNotEmpty) {
      query.where((t) => t.category.equals(category));
    }
    return query.watch();
  }

  /// إضافة نموذج checklist وإجراء جديد للقائمة الدائمة
  Future<int> insertProcedureType(AdminProcedureTypesCompanion companion) {
    return into(adminProcedureTypes).insert(companion);
  }
}
