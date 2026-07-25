import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../core/enums/app_enums.dart';

/// محرك إدارة النواقص القضائية والإدارية (DeficiencyService)
/// يراقب ملفات الدعاوى، الشركات، العقود، والإجراءات، ويولد سجلاً في جدول النواقص عند غياب المواعيد أو الثبوتيات.
class DeficiencyService {
  final AppDatabase db;
  DeficiencyService(this.db);

  // ---------------------------------------------------------------------------
  // 1. تدقيق نواقص الدعاوى القضائية (Case Deficiencies Audit)
  // ---------------------------------------------------------------------------

  /// فحص ملف الدعوى عند إنشائه أو تحديثه وإضافة الحقول المفقودة لتبويب "النواقص"
  Future<void> auditCaseDeficiencies({
    required int caseId,
    required CasesCompanion caseData,
    required bool hasPoa,
    required bool hasRepresentativeDoc,
    bool isLegalEntityClient = false,
  }) async {
    final List<DeficienciesCompanion> list = [];

    // 1. فحص موعد الجلسة / الإجراء القادم (إلزامي حسب القاعدة الذهبية V6.2)
    if (!caseData.nextSessionDate.present || caseData.nextSessionDate.value == null) {
      list.add(DeficienciesCompanion.insert(
        entityType: EntityType.caseEntity.index,
        entityId: caseId,
        fieldName: 'next_session_date',
        description: 'لم يتم تحديد موعد التنفيذ أو الجلسة القادمة للدعوى',
        severity: Value(DeficiencySeverity.required.index),
      ));
    }

    // 2. فحص رقم الأساس في المحكمة
    if (!caseData.baseNumber.present || caseData.baseNumber.value == null || caseData.baseNumber.value!.trim().isEmpty) {
      list.add(DeficienciesCompanion.insert(
        entityType: EntityType.caseEntity.index,
        entityId: caseId,
        fieldName: 'base_number',
        description: 'رقم الأساس القضائي غير مدخل بانتظار التسجيل في ديوان المحكمة',
        severity: Value(DeficiencySeverity.warning.index),
      ));
    }

    // 3. فحص إرفاق سند التوكيل (عام أو خاص)
    if (!hasPoa) {
      list.add(DeficienciesCompanion.insert(
        entityType: EntityType.caseEntity.index,
        entityId: caseId,
        fieldName: 'poa_attachment',
        description: 'صورة سند التوكيل العام/الخاص غير مرفقة في الملف',
        severity: Value(DeficiencySeverity.required.index),
      ));
    }

    // 4. فحص سند التمثيل إذا كان الموكل شخصاً اعتبارياً (شركة أو مؤسسة)
    if (isLegalEntityClient && !hasRepresentativeDoc) {
      list.add(DeficienciesCompanion.insert(
        entityType: EntityType.caseEntity.index,
        entityId: caseId,
        fieldName: 'representative_doc',
        description: 'سند تمثيل الشخص الاعتباري (سجل تجاري / تفويض) غير مرفق',
        severity: Value(DeficiencySeverity.required.index),
      ));
    }

    if (list.isNotEmpty) {
      await db.batch((b) => b.insertAll(db.deficiencies, list));
    }
  }

  // ---------------------------------------------------------------------------
  // 2. تدقيق نواقص الشركات (Company Deficiencies Audit)
  // ---------------------------------------------------------------------------

  /// فحص ملف الشركة ورصد غياب رقم السجل أو الرقم الوطني أو الشركاء
  Future<void> auditCompanyDeficiencies({
    required int companyId,
    required CompaniesCompanion companyData,
    required bool hasPartners,
    required bool hasDirectors,
  }) async {
    final List<DeficienciesCompanion> list = [];

    if (!companyData.registrationNumber.present || companyData.registrationNumber.value == null || companyData.registrationNumber.value!.isEmpty) {
      list.add(DeficienciesCompanion.insert(
        entityType: EntityType.company.index,
        entityId: companyId,
        fieldName: 'registration_number',
        description: 'رقم السجل التجاري النهائي غير مدخل بانتظار صدوره',
        severity: Value(DeficiencySeverity.warning.index),
      ));
    }

    if (!hasPartners) {
      list.add(DeficienciesCompanion.insert(
        entityType: EntityType.company.index,
        entityId: companyId,
        fieldName: 'partners_list',
        description: 'لم يتم إضافة الشركاء وتحديد حصصهم في رأس المال',
        severity: Value(DeficiencySeverity.required.index),
      ));
    }

    if (!hasDirectors) {
      list.add(DeficienciesCompanion.insert(
        entityType: EntityType.company.index,
        entityId: companyId,
        fieldName: 'directors_list',
        description: 'لم يتم تحديد المدير العام أو المفوضين بالتوقيع',
        severity: Value(DeficiencySeverity.required.index),
      ));
    }

    if (list.isNotEmpty) {
      await db.batch((b) => b.insertAll(db.deficiencies, list));
    }
  }

  // ---------------------------------------------------------------------------
  // 3. معالجة وإغلاق النواقص (Resolve & Ignore)
  // ---------------------------------------------------------------------------

  /// إغلاق النقص تلقائياً وتحويل حالته إلى resolved عند استكمال الحقل من قبل المستخدم
  Future<void> resolveDeficiency(EntityType entityType, int entityId, String fieldName) async {
    await (db.update(db.deficiencies)
          ..where((t) =>
              t.entityType.equals(entityType.index) &
              t.entityId.equals(entityId) &
              t.fieldName.equals(fieldName) &
              t.status.equals('open')))
        .write(
      DeficienciesCompanion(
        status: const Value('resolved'),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  /// تجاهل النقص يدوياً مع حفظ السبب في الخط الزمني
  Future<void> ignoreDeficiency(int deficiencyId, String reason, String userRef) async {
    await db.transaction(() async {
      final def = await (db.select(db.deficiencies)..where((t) => t.id.equals(deficiencyId))).getSingle();

      await (db.update(db.deficiencies)..where((t) => t.id.equals(deficiencyId))).write(
        const DeficienciesCompanion(status: Value('ignored')),
      );

      await db.into(db.timelineEvents).insert(
        TimelineEventsCompanion.insert(
          entityType: def.entityType,
          entityId: def.entityId,
          eventType: 'deficiency_ignored',
          eventDate: Value(DateTime.now()),
          description: 'تم تجاهل النقص [${def.description}] - السبب: $reason',
          userRef: Value(userRef),
        ),
      );
    });
  }
}
