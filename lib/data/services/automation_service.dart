/// خدمة الأتمتة الذكية للمواعيد المتكررة
///
/// تُشغَّل من زر "توليد المهام المتكررة" في شاشة الأجندة.
/// تفحص 3 مصادر وتنشئ مهام تلقائية في جدول daily_tasks:
///   1. الجلسات الدورية (مراجعة دورية كل 90 يوم)
///   2. تذكيرات العقود (قبل 7 أيام من الانتهاء)
///   3. مراحل الشركات المستحقة (خلال 7 أيام)
///
/// قواعد الأمان:
///   - كل مصدر يعمل في try/catch مستقل (فشل واحد لا يوقف الباقي)
///   - فحص التكرار قبل كل INSERT (لا مهام مكررة)
///   - إرجاع تقرير بعدد المهام المُنشأة لكل مصدر
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
DateTime? _asDate(Object? v) {
  if (v == null) return null;
  DateTime? dt;
  if (v is DateTime) {
    dt = v;
  } else if (v is int) {
    // Unix epoch seconds → DateTime
    dt = DateTime.fromMillisecondsSinceEpoch(v * 1000);
  } else if (v is String) {
    dt = DateTime.tryParse(v);
  }
  if (dt == null) return null;
  // تطبيع: تاريخ فقط بدون وقت
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

    // كل مصدر يعمل independently — فشل واحد لا يوقف الباقي
    int courtSessions = 0;
    int contractReminders = 0;
    int companyPhases = 0;

    // 1. الجلسات الدورية
    try {
      courtSessions = await _autoRecurringCourtSessions(db, taskDao, today);
    } catch (e) {
      errors.add('جلسات: $e');
    }

    // 2. تذكيرات العقود
    try {
      contractReminders = await _autoContractReminders(db, taskDao, today);
    } catch (e) {
      errors.add('عقود: $e');
    }

    // 3. مراحل الشركات
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
    // البحث عن آخر جلسة "مراجعة دورية" منجزة لكل دعوى
    final recurringSessions = await db.customSelect('''
      SELECT cs.case_id, MAX(cs.session_date) AS last_date, c.subject
      FROM case_sessions cs
      LEFT JOIN cases c ON c.id = cs.case_id
      WHERE cs.session_type LIKE '%مراجعة دورية%'
        AND cs.status = 1
      GROUP BY cs.case_id
    ''').get();

    int created = 0;
    final nextWeek = today.add(const Duration(days: 7));

    for (final row in recurringSessions) {
      final data = row.data;
      final caseId = data['case_id'] as int?;
      final lastDate = _asDate(data['last_date']);
      if (caseId == null || lastDate == null) continue;

      final nextDate = lastDate.add(const Duration(days: 90));

      // فقط إذا حان الموعد خلال أسبوع
      if (nextDate.isAfter(nextWeek)) continue;

      // فحص التكرار: هل يوجد بالفعل مهمة لهذه الدعوى من نوع court_session؟
      final existing = await db.customSelect(
        'SELECT id FROM daily_tasks WHERE source_type = ? AND source_id = ? AND task_type = ? AND status IN (0, 2)',
        variables: [
          const Variable.withString('cases'),
          Variable.withInt(caseId),
          const Variable.withString('court_session'),
        ],
      ).get();

      if (existing.isNotEmpty) continue;

      await taskDao.insertTask(DailyTasksCompanion(
        taskDate: Value(nextDate),
        taskTime: const Value('09:00'),
        title: Value('جلسة مراجعة دورية - ${data['subject'] ?? 'دعوى'}'),
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
    // العقود التي تنتهي خلال 30 يوم وليست منتهية/ملغاة
    final expiringContracts = await db.customSelect('''
      SELECT id, title, date_end
      FROM contracts
      WHERE date_end BETWEEN ? AND ?
        AND status NOT IN ('expired', 'cancelled')
    ''', variables: [
      Variable.withDateTime(today),
      Variable.withDateTime(today.add(const Duration(days: 30))),
    ]).get();

    int created = 0;

    for (final row in expiringContracts) {
      final data = row.data;
      final contractId = data['id'] as int;
      final expiryDate = _asDate(data['date_end']);
      if (expiryDate == null) continue;

      // فحص التكرار: تذكير نشط (غير مكتمل/ملغي) لنفس العقد
      final existing = await db.customSelect(
        'SELECT id FROM daily_tasks WHERE source_type = ? AND source_id = ? AND task_type = ? AND status IN (0, 2)',
        variables: [
          const Variable.withString('contracts'),
          Variable.withInt(contractId),
          const Variable.withString('contract_reminder'),
        ],
      ).get();

      if (existing.isNotEmpty) continue;

      // التذكير قبل 7 أيام من الانتهاء
      final reminderDate = expiryDate.subtract(const Duration(days: 7));

      await taskDao.insertTask(DailyTasksCompanion(
        taskDate: Value(reminderDate),
        taskTime: const Value('09:00'),
        title: Value('تذكير انتهاء عقد - ${data['title'] ?? 'عقد'}'),
        notes: Value('تاريخ الانتهاء: ${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}'),
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
    // الشركات النشطة بمراحل مستحقة خلال أسبوع
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

    int created = 0;

    for (final row in activeCompanies) {
      final data = row.data;
      final companyId = data['id'] as int;
      final phaseDate = _asDate(data['phase_date']);
      if (phaseDate == null) continue;

      // فحص التكرار: مهمة نشطة لنفس الشركة
      final existing = await db.customSelect(
        'SELECT id FROM daily_tasks WHERE source_type = ? AND source_id = ? AND task_type = ? AND status IN (0, 2)',
        variables: [
          const Variable.withString('companies'),
          Variable.withInt(companyId),
          const Variable.withString('company_phase'),
        ],
      ).get();

      if (existing.isNotEmpty) continue;

      await taskDao.insertTask(DailyTasksCompanion(
        taskDate: Value(phaseDate),
        taskTime: const Value('09:00'),
        title: Value('مراجعة مرحلة شركة - ${data['name'] ?? 'شركة'}'),
        notes: Value('المرحلة الحالية: ${data['current_phase'] ?? 'غير محدد'}'),
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

    // الأوقات المفضلة للجلسات (آخر 30 يوم)
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
  // ترحيل ذكي بناءً على قرار المحكمة
  // ---------------------------------------------------------------------------
  Future<void> smartRescheduleBasedOnDecision({
    required AppDatabase db,
    required int sessionId,
    required String decision,
  }) async {
    final taskDao = TaskDao(db);

    final sessionInfo = await db.customSelect('''
      SELECT cs.case_id, cs.session_date, c.subject
      FROM case_sessions cs
      LEFT JOIN cases c ON c.id = cs.case_id
      WHERE cs.id = ?
    ''', variables: [Variable.withInt(sessionId)]).getSingle();

    final caseId = sessionInfo.data['case_id'] as int?;
    final sessionDate = _asDate(sessionInfo.data['session_date']);
    final subject = sessionInfo.data['subject'] as String?;

    if (caseId == null || sessionDate == null) return;

    // تحديد الموعد التالي بناءً على نوع القرار
    int daysToAdd;
    String nextType;
    switch (decision) {
      case 'تأجيل لبيان':
        daysToAdd = 30;
        nextType = 'مرافعة';
        break;
      case 'تأجيل لقرار':
        daysToAdd = 60;
        nextType = 'تدقيق';
        break;
      case 'تأجيل لمرافعة':
        daysToAdd = 15;
        nextType = 'مرافعة';
        break;
      default:
        daysToAdd = 30;
        nextType = 'مرافعة';
    }

    final nextDate = sessionDate.add(Duration(days: daysToAdd));

    // إنشاء مهمة في الأجندة
    await taskDao.insertTask(DailyTasksCompanion(
      taskDate: Value(nextDate),
      taskTime: const Value('09:00'),
      title: Value('جلسة $nextType - ${subject ?? 'دعوى'}'),
      notes: Value('ترحيل تلقائي بناءً على القرار: $decision'),
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
