import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'contract_dao.g.dart';

/// كائن الوصول لبيانات العقود، التذكيرات، القوالب، ونسخ Word (ContractDao)
@DriftAccessor(tables: [
  Contracts,
  ContractParties,
  ContractReminders,
  ContractTemplates,
  ContractVersions,
  Persons,
  Companies,
])
class ContractDao extends DatabaseAccessor<AppDatabase> with _$ContractDaoMixin {
  ContractDao(super.db);

  // ---------------------------------------------------------------------------
  // إدارة ملفات العقود (Contracts)
  // ---------------------------------------------------------------------------

  /// مراقبة كافة العقود في النظام مرتبة حسب تاريخ الإبرام
  Stream<List<Contract>> watchAllContracts() {
    return (select(contracts)
          ..orderBy([(t) => OrderingTerm(expression: t.dateSigned, mode: OrderingMode.desc)]))
        .watch();
  }

  /// جلب عقد واحد بالمعرف
  Future<Contract?> getContractById(int id) {
    return (select(contracts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// إضافة عقد جديد وإرجاع معرفه
  Future<int> insertContract(ContractsCompanion companion) {
    return into(contracts).insert(companion);
  }

  /// تحديث بيانات عقد (مثل تجديده أو تغيير حالته)
  Future<bool> updateContract(ContractsCompanion companion) {
    return update(contracts).replace(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة أطراف العقد (ContractParties)
  // ---------------------------------------------------------------------------

  /// مراقبة الأطراف المتعاقدة في العقد
  Stream<List<ContractParty>> watchContractParties(int contractId) {
    return (select(contractParties)
          ..where((t) => t.contractId.equals(contractId))
          ..orderBy([(t) => OrderingTerm(expression: t.partyOrder)]))
        .watch();
  }

  /// إضافة طرف متعاقد (طرف أول / ثاني / كفيل)
  Future<int> insertContractParty(ContractPartiesCompanion companion) {
    return into(contractParties).insert(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة التذكيرات والمتابعة الزمنية (ContractReminders)
  // ---------------------------------------------------------------------------

  /// مراقبة تنبيهات وتذكيرات عقد معين
  Stream<List<ContractReminder>> watchContractReminders(int contractId) {
    return (select(contractReminders)
          ..where((t) => t.contractId.equals(contractId))
          ..orderBy([(t) => OrderingTerm(expression: t.reminderDate)]))
        .watch();
  }

  /// إضافة تذكير انتهاء أو تجديد لعقد
  Future<int> insertContractReminder(ContractRemindersCompanion companion) {
    return into(contractReminders).insert(companion);
  }

  // ---------------------------------------------------------------------------
  // إدارة نماذج وقوالب Word للعقود (ContractTemplates)
  // ---------------------------------------------------------------------------

  /// مراقبة القوالب المتاحة في النظام مع فلترة اختيارية حسب نوع العقد
  Stream<List<ContractTemplate>> watchContractTemplates({String? contractType}) {
    final query = select(contractTemplates);
    if (contractType != null && contractType.isNotEmpty) {
      query.where((t) => t.contractType.equals(contractType));
    }
    return query.watch();
  }

  /// إضافة قالب Word جديد للمكتب
  Future<int> insertContractTemplate(ContractTemplatesCompanion companion) {
    return into(contractTemplates).insert(companion);
  }

  /// تعيين قالب كافتراضي لنوع عقد، وإلغاء الافتراضي السابق لنفس النوع.
  ///
  /// يجري في معاملة واحدة: بقاء قالبين افتراضيين لنوع واحد يجعل
  /// اختيار القالب عند إنشاء العقد غير محدد.
  Future<void> setDefaultTemplate(int templateId) async {
    await transaction(() async {
      final target = await (select(contractTemplates)
            ..where((t) => t.id.equals(templateId)))
          .getSingleOrNull();
      if (target == null) return;

      await (update(contractTemplates)
            ..where((t) => t.contractType.equals(target.contractType)))
          .write(const ContractTemplatesCompanion(isDefault: Value(false)));

      await (update(contractTemplates)..where((t) => t.id.equals(templateId)))
          .write(const ContractTemplatesCompanion(isDefault: Value(true)));
    });
  }

  /// حذف قالب من المكتب.
  Future<int> deleteContractTemplate(int templateId) {
    return (delete(contractTemplates)..where((t) => t.id.equals(templateId)))
        .go();
  }

  /// جلب قالب واحد بمعرّفه.
  Future<ContractTemplate?> getTemplateById(int id) {
    return (select(contractTemplates)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // إدارة سجل النسخ والتعديلات (ContractVersions)
  // ---------------------------------------------------------------------------

  /// مراقبة نسخ التعديلات السابقة لعقد معين
  Stream<List<ContractVersion>> watchContractVersions(int contractId) {
    return (select(contractVersions)
          ..where((t) => t.contractId.equals(contractId))
          ..orderBy([(t) => OrderingTerm(expression: t.versionNumber, mode: OrderingMode.desc)]))
        .watch();
  }

  /// حفظ نسخة معدلة جديدة من العقد
  Future<int> insertContractVersion(ContractVersionsCompanion companion) {
    return into(contractVersions).insert(companion);
  }
}
