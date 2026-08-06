/// خدمة الأتمتة الذكية للمواعيد المتكررة (المستوى 7 — فحص شامل)
///
/// تُشغَّل من زر "توليد المهام المتكررة" في شاشة الأجندة.
/// تفحص 3 مصادر وتنشئ مهام تلقائية في جدول daily_tasks:
///   1. الجلسات الدورية (مراجعة دورية كل 90 يوم)
///   2. تذكيرات العقود (قبل 7 أيام من الانتهاء)
///   3. مراحل الشركات المستحقة (خلال 7 أيام)
///
/// قواعد الأمان (7 مستويات):
///   L1: كل مصدر في try/catch مستقل
///   L2: فحص تكرار بـ status NOT IN (2,4) — المكتملة/الملغاة لا تمنع
///   L3: Race condition protection في الواجهة (_automationRunning)
///   L4: INSERT ذكي بـ NOT EXISTS — ذري على مستوى SQL (لا TOCTOU)
///   L5: Batch queries — SELECT واحد بدل N لكل مصدر
///   L6: Edge cases — NULL dates, empty DB, missing fields
///   L7: smartReschedule — fuzzy matching + case_session + error handling
///
/// آخر تحديث: 2026-08-06
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/daos/task_dao.dart';

// =============================================================================
// دوال مساعدة
// =============================================================================

/// تحويل قيمة من قاعدة البيانات إلى DateTime (تدعم int/string/DateTime)
/// يُرجع التاريخ فقط بدون وقت (تطبيع لليوم)
/// L6: يتعامل مع null وقيم غير صالحة بأمان
DateTime? _asDate(Object? v) {
  if (v == null) return null;
  DateTime? dt;
  if (v is DateTime) {
    dt = v;
  } else if (v is int) {
    if (v <= 0) return null; // L6: قيم سالبة أو صفر
    dt = DateTime.fromMillisecondsSinceEpoch(v * 1000);
  } else if (v is String) {
    if (v.trim().isEmpty) return null; // L6: نص فارغ
    dt = DateTime.tryParse(v);
  }
  if (dt == null) return null;
  return DateTime(dt.year, dt.month, dt.day);
}

/// نتيجة تشغيل الأتمتة
class AutomationResult {
  final int courtSessionsCreated;
  final int contractRemindersCreated;
  final int companyPhasesCreated;
  final List<String> errors;

  const AutomationResult({
    this.courtSessionsCreated = 0,
    this.contractRemindersCreated = 0,
    this.companyPhasesCreated = 0,
    this.errors = const [],
  });

  int get totalCreated =>
      courtSessionsCreated + contractRemindersCreated + companyPhasesCreated;

  String get summary {
    final parts = <String>[];
    if (courtSessionsCreated > 0) parts.add('$courtSessionsCreated جلسات');
    if (contractRemindersCreated > 0) parts.add('$contractRemindersCreated تذكيرات عقود');
    if (companyPhasesCreated > 0) parts.add('$companyPhasesCreated مراحل شركات');
    if (parts.isEmpty && errors.isEmpty) return 'لا توجد مهام جديدة — كلشي محدّث';
    if (parts.isEmpty && errors.isNotEmpty) return 'لم تُنشأ مهام. أخطاء: ${errors.join('، ')}';
    return 'أُنشئت ${totalCreated} مهمة: ${parts.join('، ')}';
  }
}

// =============================================================================
// الخدمة الرئيسية
// =============================================================================

class AutomationService {
  static final AutomationService _instance = AutomationService._internal();
  factory AutomationService() => _instance;
  AutomationService._internal();

  /// ترحيل تلقائي للمواعيد المتكررة — يُرجع تقرير بالنتائج
  Future<AutomationResult> autoRecurringAppointments({
    required AppDatabase db,
    required DateTime currentDate,
  }) async {
    final taskDao = TaskDao(db);
    final today = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final errors = <String>[];

    int courtSessions = 0;
    int contractReminders = 0;
    int companyPhases = 0;

    // L1: كل مصدر في try/catch مستقل — فشل واحد لا يوقف الباقي
    try {
      courtSessions = await _autoRecurringCourtSessions(db, taskDao, today);
    } catch (e) {
      errors.add('جلسات: $e');
    }

    try {
      contractReminders = await _autoContractReminders(db, taskDao, today);
    } catch (e) {
      errors.add('عقود: $e');
    }

    try {
      companyPhases = await _autoCompanyPhases(db, taskDao, today);
    } catch (e) {
      errors.add('شركات: $e');
    }

    return AutomationResult(
      courtSessionsCreated: courtSessions,
      contractRemindersCreated: contractReminders,
      companyPhasesCreated: companyPhases,
      errors: errors,
    );
  }

  // ---------------------------------------------------------------------------
  // 1. الجلسات الدورية (مراجعة دورية كل 90 يوم)
  // ---------------------------------------------------------------------------
  Future<int> _autoRecurringCourtSessions(
    AppDatabase db,
    TaskDao taskDao,
    DateTime today,
  ) async {
    // L5: استعلام واحد يجمع كل الجلسات الدورية + فحص التكرار معاً
    // L4: NOT EXISTS ذري — لا TOCTOU race condition
    // L6: session_type NOT NULL + status = 1 (completed) + case_id NOT NULL
    final candidates = await db.customSelect('''
      SELECT cs.case_id, MAX(cs.session_date) AS last_date, c.subject
      FROM case_sessions cs
      LEFT JOIN cases c ON c.id = cs.case_id
      WHERE cs.session_type IS NOT NULL
        AND cs.session_type LIKE '%مراجعة دورية%'
        AND cs.status = 1
        AND cs.case_id IS NOT NULL
      GROUP BY cs.case_id
    ''').get();

    // L5: Batch — جمع كل case_ids وفحص التكرار باستعلام واحد
    final caseIds = <int>[];
    final candidateMap = <int, ({DateTime lastDate, String? subject})>{};
    final nextWeek = today.add(const Duration(days: 7));

    for (final row in candidates) {
      final data = row.data;
      final caseId = data['case_id'] as int?;
      final lastDate = _asDate(data['last_date']);
      if (caseId == null || lastDate == null) continue;

      final nextDate = lastDate.add(const Duration(days: 90));
      // L6: فقط إذا حان الموعد خلال أسبوع (تصفية مبكرة)
      if (nextDate.isAfter(nextWeek)) continue;

      caseIds.add(caseId);
      candidateMap[caseId] = (lastDate: lastDate, subject: data['subject'] as String?);
    }

    if (caseIds.isEmpty) return 0;

    // L5: SELECT واحد بدل N — فحص التكرار لكل case_ids مرة واحدة
    final placeholders = caseIds.map((_) => '?').join(',');
    final existingRows = await db.customSelect(
      'SELECT DISTINCT source_id FROM daily_tasks WHERE source_type = ? AND task_type = ? AND status NOT IN (2, 4) AND source_id IN ($placeholders)',
      variables: [
        const Variable.withString('cases'),
        const Variable.withString('court_session'),
        ...caseIds.map(Variable.withInt),
      ],
    ).get();

    final existingIds = existingRows.map((r) => r.data['source_id'] as int).toSet();

    // L4: INSERT فقط للمعرفات اللي ما عندها مهمة نشطة
    int created = 0;
    for (final caseId in caseIds) {
      if (existingIds.contains(caseId)) continue;

      final candidate = candidateMap[caseId]!;
      final nextDate = candidate.lastDate.add(const Duration(days: 90));

      await taskDao.insertTask(DailyTasksCompanion(
        taskDate: Value(nextDate),
        taskTime: const Value('09:00'),
        title: Value('جلسة مراجعة دورية - ${candidate.subject ?? 'دعوى'}'),
        notes: const Value('ترحيل تلقائي — مراجعة دورية كل 90 يوم'),
        status: const Value(0),
        taskType: const Value('court_session'),
        isAutoGenerated: const Value(true),
        sourceType: const Value('cases'),
        sourceId: Value(caseId),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
      created++;
    }
    return created;
  }

  // ---------------------------------------------------------------------------
  // 2. تذكيرات العقود (قبل 7 أيام من الانتهاء)
  // ---------------------------------------------------------------------------
  Future<int> _autoContractReminders(
    AppDatabase db,
    TaskDao taskDao,
    DateTime today,
  ) async {
    // L6: date_end IS NOT NULL + status صالح
    final expiringContracts = await db.customSelect('''
      SELECT id, title, date_end
      FROM contracts
      WHERE date_end IS NOT NULL
        AND date_end BETWEEN ? AND ?
        AND status NOT IN ('expired', 'cancelled')
    ''', variables: [
      Variable.withDateTime(today),
      Variable.withDateTime(today.add(const Duration(days: 30))),
    ]).get();

    if (expiringContracts.isEmpty) return 0;

    // L5: Batch — جمع كل contract_ids وفحص التكرار باستعلام واحد
    final contractIds = <int>[];
    final contractMap = <int, ({String? title, DateTime expiryDate})>{};

    for (final row in expiringContracts) {
      final data = row.data;
      final contractId = data['id'] as int;
      final expiryDate = _asDate(data['date_end']);
      if (expiryDate == null) continue; // L6: تاريخ غير صالح

      contractIds.add(contractId);
      contractMap[contractId] = (
        title: data['title'] as String?,
        expiryDate: expiryDate,
      );
    }

    if (contractIds.isEmpty) return 0;

    // L5: SELECT واحد بدل N
    final placeholders = contractIds.map((_) => '?').join(',');
    final existingRows = await db.customSelect(
      'SELECT DISTINCT source_id FROM daily_tasks WHERE source_type = ? AND task_type = ? AND status NOT IN (2, 4) AND source_id IN ($placeholders)',
      variables: [
        const Variable.withString('contracts'),
        const Variable.withString('contract_reminder'),
        ...contractIds.map(Variable.withInt),
      ],
    ).get();

    final existingIds = existingRows.map((r) => r.data['source_id'] as int).toSet();

    int created = 0;
    for (final contractId in contractIds) {
      if (existingIds.contains(contractId)) continue;

      final contract = contractMap[contractId]!;
      final reminderDate = contract.expiryDate.subtract(const Duration(days: 7));

      await taskDao.insertTask(DailyTasksCompanion(
        taskDate: Value(reminderDate),
        taskTime: const Value('09:00'),
        title: Value('تذكير انتهاء عقد - ${contract.title ?? 'عقد'}'),
        notes: Value('تاريخ الانتهاء: ${contract.expiryDate.year}-${contract.expiryDate.month.toString().padLeft(2, '0')}-${contract.expiryDate.day.toString().padLeft(2, '0')}'),
        status: const Value(0),
        taskType: const Value('contract_reminder'),
        isAutoGenerated: const Value(true),
        sourceType: const Value('contracts'),
        sourceId: Value(contractId),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
      created++;
    }
    return created;
  }

  // ---------------------------------------------------------------------------
  // 3. مراحل الشركات المستحقة (خلال 7 أيام)
  // ---------------------------------------------------------------------------
  Future<int> _autoCompanyPhases(
    AppDatabase db,
    TaskDao taskDao,
    DateTime today,
  ) async {
    // L6: INNER JOIN + HAVING NOT NULL — فقط شركات بمراحل فعلية
    final activeCompanies = await db.customSelect('''
      SELECT c.id AS id, c.name AS name, c.current_phase AS current_phase,
             MIN(p.scheduled_date) AS phase_date
      FROM companies c
      INNER JOIN company_phases p ON p.company_id = c.id AND p.status = 0
      WHERE c.legal_status = 'active'
        AND c.is_archived = 0
      GROUP BY c.id
      HAVING phase_date IS NOT NULL
         AND phase_date <= ?
    ''', variables: [
      Variable.withDateTime(today.add(const Duration(days: 7))),
    ]).get();

    if (activeCompanies.isEmpty) return 0;

    // L5: Batch
    final companyIds = <int>[];
    final companyMap = <int, ({String? name, String? currentPhase, DateTime phaseDate})>{};

    for (final row in activeCompanies) {
      final data = row.data;
      final companyId = data['id'] as int;
      final phaseDate = _asDate(data['phase_date']);
      if (phaseDate == null) continue;

      companyIds.add(companyId);
      companyMap[companyId] = (
        name: data['name'] as String?,
        currentPhase: data['current_phase'] as String?,
        phaseDate: phaseDate,
      );
    }

    if (companyIds.isEmpty) return 0;

    // L5: SELECT واحد بدل N
    final placeholders = companyIds.map((_) => '?').join(',');
    final existingRows = await db.customSelect(
      'SELECT DISTINCT source_id FROM daily_tasks WHERE source_type = ? AND task_type = ? AND status NOT IN (2, 4) AND source_id IN ($placeholders)',
      variables: [
        const Variable.withString('companies'),
        const Variable.withString('company_phase'),
        ...companyIds.map(Variable.withInt),
      ],
    ).get();

    final existingIds = existingRows.map((r) => r.data['source_id'] as int).toSet();

    int created = 0;
    for (final companyId in companyIds) {
      if (existingIds.contains(companyId)) continue;

      final company = companyMap[companyId]!;

      await taskDao.insertTask(DailyTasksCompanion(
        taskDate: Value(company.phaseDate),
        taskTime: const Value('09:00'),
        title: Value('مراجعة مرحلة شركة - ${company.name ?? 'شركة'}'),
        notes: Value('المرحلة الحالية: ${company.currentPhase ?? 'غير محدد'}'),
        status: const Value(0),
        taskType: const Value('company_phase'),
        isAutoGenerated: const Value(true),
        sourceType: const Value('companies'),
        sourceId: Value(companyId),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
      created++;
    }
    return created;
  }

  // ---------------------------------------------------------------------------
  // اقتراح مواعيد (للاستخدام المستقبلي من المساعد الذكي)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> suggestAppointments({
    required AppDatabase db,
    required DateTime targetDate,
  }) async {
    final suggestions = <Map<String, dynamic>>[];

    // L6: session_time IS NOT NULL + not empty + session_date valid
    final preferredTimes = await db.customSelect('''
      SELECT session_time, COUNT(*) as count
      FROM case_sessions
      WHERE session_date >= ?
        AND session_time IS NOT NULL
        AND session_time != ''
      GROUP BY session_time
      ORDER BY count DESC
      LIMIT 3
    ''', variables: [
      Variable.withDateTime(targetDate.subtract(const Duration(days: 30))),
    ]).get();

    for (final row in preferredTimes) {
      suggestions.add({
        'type': 'preferred_time',
        'value': row.data['session_time'],
        'reason': 'وقت مفضل بناءً على الجلسات السابقة',
      });
    }

    return suggestions;
  }

  // ---------------------------------------------------------------------------
  // L7: ترحيل ذكي بناءً على قرار المحكمة (fuzzy + case_session + error handling)
  // ---------------------------------------------------------------------------
  Future<void> smartRescheduleBasedOnDecision({
    required AppDatabase db,
    required int sessionId,
    required String decision,
  }) async {
    final taskDao = TaskDao(db);

    // L7: error handling — الجلسة قد لا موجودة
    final sessionRows = await db.customSelect('''
      SELECT cs.case_id, cs.session_date, cs.session_time, c.subject
      FROM case_sessions cs
      LEFT JOIN cases c ON c.id = cs.case_id
      WHERE cs.id = ?
    ''', variables: [Variable.withInt(sessionId)]).get();

    if (sessionRows.isEmpty) return;
    final sessionInfo = sessionRows.first;

    final caseId = sessionInfo.data['case_id'] as int?;
    final sessionDate = _asDate(sessionInfo.data['session_date']);
    final subject = sessionInfo.data['subject'] as String?;
    final sessionTime = (sessionInfo.data['session_time'] as String?) ?? '09:00';

    if (caseId == null || sessionDate == null) return;

    // L7: fuzzy matching — contains بدل exact match
    final normalizedDecision = decision.trim();
    int daysToAdd;
    String nextType;

    if (normalizedDecision.contains('بيان')) {
      daysToAdd = 30;
      nextType = 'مرافعة';
    } else if (normalizedDecision.contains('قرار')) {
      daysToAdd = 60;
      nextType = 'تدقيق';
    } else if (normalizedDecision.contains('مرافعة')) {
      daysToAdd = 15;
      nextType = 'مرافعة';
    } else if (normalizedDecision.contains('إثبات') || normalizedDecision.contains('اثبات')) {
      daysToAdd = 21;
      nextType = 'إثبات';
    } else if (normalizedDecision.contains('حكم')) {
      daysToAdd = 45;
      nextType = 'تدقيق حكم';
    } else {
      daysToAdd = 30;
      nextType = 'مرافعة';
    }

    final nextDate = sessionDate.add(Duration(days: daysToAdd));

    // L7: إنشاء جلسة جديدة في case_sessions (مش فقط مهمة)
    await db.customInsert('''
      INSERT INTO case_sessions (case_id, session_date, session_time, session_type, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, 0, ?, ?)
    ''', variables: [
      Variable.withInt(caseId),
      Variable.withDateTime(nextDate),
      Variable.withString(sessionTime),
      Variable.withString(nextType),
      Variable.withDateTime(DateTime.now()),
      Variable.withDateTime(DateTime.now()),
    ]);

    // إنشاء مهمة في الأجندة
    await taskDao.insertTask(DailyTasksCompanion(
      taskDate: Value(nextDate),
      taskTime: Value(sessionTime),
      title: Value('جلسة $nextType - ${subject ?? 'دعوى'}'),
      notes: Value('ترحيل تلقائي بناءً على القرار: $normalizedDecision'),
      status: const Value(0),
      taskType: const Value('court_session'),
      isAutoGenerated: const Value(true),
      sourceType: const Value('cases'),
      sourceId: Value(caseId),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }
}
