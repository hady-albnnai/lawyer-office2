import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../database/daos/task_dao.dart';

/// خدمة الأتمتة الذكية للمواعيد المتكررة
class AutomationService {
  static final AutomationService _instance = AutomationService._internal();
  factory AutomationService() => _instance;
  AutomationService._internal();

  /// ترحيل تلقائي للمواعيد المتكررة
  Future<void> autoRecurringAppointments({
    required Ref ref,
    required DateTime currentDate,
  }) async {
    final db = ref.read(databaseProvider);
    final taskDao = TaskDao(db);

    // 1. ترحيل الجلسات الدورية (مراجعة دورية كل 3 أشهر)
    await _autoRecurringCourtSessions(db, taskDao, currentDate);

    // 2. ترحيل تذكيرات العقود (قبل شهر من الانتهاء)
    await _autoContractReminders(db, taskDao, currentDate);

    // 3. ترحيل مراحل الشركات (المراحل الدورية)
    await _autoCompanyPhases(db, taskDao, currentDate);
  }

  /// ترحيل الجلسات الدورية
  Future<void> _autoRecurringCourtSessions(
    AppDatabase db,
    TaskDao taskDao,
    DateTime currentDate,
  ) async {
    // البحث عن الجلسات المنجزة من نوع "مراجعة دورية"
    final recurringSessions = await db.customSelect('''
      SELECT cs.id, cs.case_id, cs.session_date, cs.session_type, c.subject
      FROM case_sessions cs
      LEFT JOIN cases c ON c.id = cs.case_id
      WHERE cs.session_type LIKE '%مراجعة دورية%'
      AND cs.status = 1
      AND cs.session_date >= ?
      ORDER BY cs.session_date DESC
      LIMIT 10
    ''', variables: [
      currentDate.subtract(const Duration(days: 90)),
    ]).get();

    for (final row in recurringSessions) {
      final data = row.data;
      final lastSessionDate = data['session_date'] as DateTime?;
      
      if (lastSessionDate != null) {
        final nextSessionDate = lastSessionDate.add(const Duration(days: 90));
        
        // إذا حان موعد الجلسة التالية، أنشئ مهمة جديدة
        if (nextSessionDate.isBefore(currentDate.add(const Duration(days: 7)))) {
          await taskDao.insertTask(DailyTasksCompanion(
            taskDate: Value(nextSessionDate),
            taskTime: Value('09:00'),
            title: Value('جلسة مراجعة دورية - ${data['subject'] ?? 'دعوى'}'),
            notes: Value('ترحيل تلقائي من جلسة سابقة'),
            status: const Value(0),
            taskType: Value('court_session'),
            sourceType: const Value('cases'),
            sourceId: Value(data['case_id'] as int?),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ));
        }
      }
    }
  }

  /// ترحيل تذكيرات العقود
  Future<void> _autoContractReminders(
    AppDatabase db,
    TaskDao taskDao,
    DateTime currentDate,
  ) async {
    // البحث عن العقود التي تنتهي خلال شهر
    final expiringContracts = await db.customSelect('''
      SELECT id, title, expiry_date
      FROM contracts
      WHERE expiry_date BETWEEN ? AND ?
      AND status != 'completed'
    ''', variables: [
      currentDate,
      currentDate.add(const Duration(days: 30)),
    ]).get();

    for (final row in expiringContracts) {
      final data = row.data;
      final expiryDate = data['expiry_date'] as DateTime?;
      
      if (expiryDate != null) {
        // إنشاء تذكير قبل أسبوع من الانتهاء
        final reminderDate = expiryDate.subtract(const Duration(days: 7));
        
        if (reminderDate.isAfter(currentDate.subtract(const Duration(days: 1))) &&
            reminderDate.isBefore(currentDate.add(const Duration(days: 1)))) {
          await taskDao.insertTask(DailyTasksCompanion(
            taskDate: Value(reminderDate),
            taskTime: Value('09:00'),
            title: Value('تذكير انتهاء عقد - ${data['title'] ?? 'عقد'}'),
            notes: Value('تاريخ الانتهاء: ${expiryDate.toString().split(' ')[0]}'),
            status: const Value(0),
            taskType: Value('contract_reminder'),
            sourceType: const Value('contracts'),
            sourceId: Value(data['id'] as int?),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ));
        }
      }
    }
  }

  /// ترحيل مراحل الشركات
  Future<void> _autoCompanyPhases(
    AppDatabase db,
    TaskDao taskDao,
    DateTime currentDate,
  ) async {
    // البحث عن الشركات النشطة
    final activeCompanies = await db.customSelect('''
      SELECT id, company_name, current_phase, phase_completion_date
      FROM companies
      WHERE status = 'active'
      AND phase_completion_date <= ?
    ''', variables: [
      currentDate.add(const Duration(days: 7)),
    ]).get();

    for (final row in activeCompanies) {
      final data = row.data;
      final phaseCompletionDate = data['phase_completion_date'] as DateTime?;
      
      if (phaseCompletionDate != null) {
        // إنشاء مهمة لمراجعة المرحلة
        await taskDao.insertTask(DailyTasksCompanion(
          taskDate: Value(phaseCompletionDate),
          taskTime: Value('09:00'),
          title: Value('مراجعة مرحلة شركة - ${data['company_name'] ?? 'شركة'}'),
          notes: Value('المرحلة الحالية: ${data['current_phase'] ?? 'غير محدد'}'),
          status: const Value(0),
          taskType: Value('company_phase'),
          sourceType: const Value('companies'),
          sourceId: Value(data['id'] as int?),
          createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ));
      }
    }
  }

  /// اقتراح مواعيد محتملة بناءً على الأنماط
  Future<List<Map<String, dynamic>>> suggestAppointments({
    required Ref ref,
    required DateTime targetDate,
  }) async {
    final db = ref.read(databaseProvider);
    final suggestions = <Map<String, dynamic>>[];

    // 1. اقتراح أوقات الجلسات بناءً على الأوقات المفضلة
    final preferredTimes = await db.customSelect('''
      SELECT session_time, COUNT(*) as count
      FROM case_sessions
      WHERE session_date >= ?
      GROUP BY session_time
      ORDER BY count DESC
      LIMIT 3
    ''', variables: [
      targetDate.subtract(const Duration(days: 30)),
    ]).get();

    for (final row in preferredTimes) {
      final data = row.data;
      suggestions.add({
        'type': 'preferred_time',
        'value': data['session_time'],
        'reason': 'وقت مفضل بناءً على الجلسات السابقة',
      });
    }

    // 2. اقتراح الأيام الأقل ازدحاماً
    final busyDays = await db.customSelect('''
      SELECT DATE(session_date) as day, COUNT(*) as count
      FROM case_sessions
      WHERE session_date >= ? AND session_date <= ?
      GROUP BY day
      ORDER BY count ASC
      LIMIT 5
    ''', variables: [
      targetDate,
      targetDate.add(const Duration(days: 30)),
    ]).get();

    for (final row in busyDays) {
      final data = row.data;
      suggestions.add({
        'type': 'less_busy_day',
        'value': data['day'],
        'reason': 'يوم أقل ازدحاماً للجلسات',
      });
    }

    return suggestions;
  }

  /// ترحيل مشروط (إذا أنجزت المهمة الحالية، يرحل الموعد التالي)
  Future<void> conditionalReschedule({
    required Ref ref,
    required int currentTaskId,
    required int nextTaskId,
  }) async {
    final db = ref.read(databaseProvider);
    final taskDao = TaskDao(db);

    // التحقق من إتمام المهمة الحالية
    final currentTask = await db.customSelect('''
      SELECT status FROM daily_tasks WHERE id = ?
    ''', variables: [
      currentTaskId,
    ]).getSingle();

    final currentStatus = currentTask.data['status'] as int?;

    if (currentStatus == 1) { // completed
      // ترحيل الموعد التالي
      await taskDao.updateTaskStatus(nextTaskId, 0); // تعيين إلى scheduled
    }
  }

  /// ترحيل ذكي بناءً على القرارات
  Future<void> smartRescheduleBasedOnDecision({
    required Ref ref,
    required int sessionId,
    required String decision,
  }) async {
    final db = ref.read(databaseProvider);
    final taskDao = TaskDao(db);

    // استخراج معلومات الجلسة
    final sessionInfo = await db.customSelect('''
      SELECT cs.case_id, cs.session_date, c.subject
      FROM case_sessions cs
      LEFT JOIN cases c ON c.id = cs.case_id
      WHERE cs.id = ?
    ''', variables: [
      sessionId,
    ]).getSingle();

    final caseId = sessionInfo.data['case_id'] as int?;
    final sessionDate = sessionInfo.data['session_date'] as DateTime?;
    final subject = sessionInfo.data['subject'] as String?;

    if (caseId != null && sessionDate != null) {
      DateTime nextSessionDate;

      // تحديد الموعد التالي بناءً على القرار
      switch (decision.toLowerCase()) {
        case 'تأجيل لبيان':
          nextSessionDate = sessionDate.add(const Duration(days: 30));
          break;
        case 'تأجيل لقرار':
          nextSessionDate = sessionDate.add(const Duration(days: 60));
          break;
        case 'تأجيل لمرافعة':
          nextSessionDate = sessionDate.add(const Duration(days: 15));
          break;
        default:
          nextSessionDate = sessionDate.add(const Duration(days: 30));
      }

      // إنشاء جلسة جديدة
      await db.customInsert('''
        INSERT INTO case_sessions (case_id, session_date, session_time, session_type, status, created_at, updated_at)
        VALUES (?, ?, '09:00', 'مرافعة', 0, datetime('now'), datetime('now'))
      ''', variables: [
        caseId,
        nextSessionDate,
      ]);

      // إنشاء مهمة في الأجندة
      await taskDao.insertTask(DailyTasksCompanion(
        taskDate: Value(nextSessionDate),
        taskTime: Value('09:00'),
        title: Value('جلسة مرافعة - ${subject ?? 'دعوى'}'),
        notes: Value('ترحيل تلقائي بناءً على القرار: $decision'),
        status: const Value(0),
        taskType: Value('court_session'),
        sourceType: const Value('cases'),
        sourceId: Value(caseId),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }
}