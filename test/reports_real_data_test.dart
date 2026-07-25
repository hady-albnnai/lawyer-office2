import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';

/// اختبارات تتحقق أن استعلامات التقارير تقرأ من قاعدة البيانات فعلياً،
/// وأنها لا تُرجع صفوفاً ثابتة مكتوبة داخل الكود كما كان سابقاً.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime dayEnd(DateTime d) => dayStart(d).add(const Duration(days: 1));

  Future<int> insertCase({
    required String internalNumber,
    String? subject,
    String? baseNumber,
    int? courtId,
  }) async {
    return db.into(db.cases).insert(
          CasesCompanion.insert(
            internalNumber: internalNumber,
            year: 2026,
            caseType: 'مدني',
            subject: Value(subject),
            baseNumber: Value(baseNumber),
            courtId: Value(courtId),
          ),
        );
  }

  test('Sessions report reads real rows for the target day only', () async {
    final courtId = await db.into(db.courts).insert(
          CourtsCompanion.insert(name: 'بداية مدنية دمشق', type: const Value('مدني')),
        );
    final caseId = await insertCase(
      internalNumber: 'دعوى/2026/0001',
      subject: 'مطالبة بتعويض',
      courtId: courtId,
    );

    final today = DateTime(2026, 7, 24);
    final other = DateTime(2026, 7, 25);

    await db.into(db.caseSessions).insert(CaseSessionsCompanion.insert(
          caseId: caseId,
          sessionDate: today,
          sessionTime: const Value('09:30'),
          sessionType: const Value('مرافعة'),
          status: Value(LifecycleStatus.scheduled.index),
        ));
    await db.into(db.caseSessions).insert(CaseSessionsCompanion.insert(
          caseId: caseId,
          sessionDate: other,
          sessionTime: const Value('11:00'),
          sessionType: const Value('تدقيق'),
        ));

    final rows = await db.customSelect('''
      SELECT cs.session_time, cs.session_type, cs.status,
             c.internal_number, c.subject,
             co.name AS court_name
      FROM case_sessions cs
      LEFT JOIN cases c ON c.id = cs.case_id
      LEFT JOIN courts co ON co.id = c.court_id
      WHERE cs.session_date >= ? AND cs.session_date < ?
      ORDER BY cs.session_time
    ''', variables: [
      Variable.withDateTime(dayStart(today)),
      Variable.withDateTime(dayEnd(today)),
    ]).get();

    expect(rows.length, 1);
    expect(rows.first.data['session_time'], '09:30');
    expect(rows.first.data['internal_number'], 'دعوى/2026/0001');
    expect(rows.first.data['subject'], 'مطالبة بتعويض');
    expect(rows.first.data['court_name'], 'بداية مدنية دمشق');
  });

  test('Overdue report finds late tasks and sessions but skips completed ones', () async {
    final caseId = await insertCase(internalNumber: 'دعوى/2026/0002', subject: 'إخلاء مأجور');
    final today = DateTime(2026, 7, 24);
    final past = DateTime(2026, 7, 20);

    // مهمة متأخرة غير منجزة => يجب أن تظهر
    await db.into(db.dailyTasks).insert(DailyTasksCompanion.insert(
          taskType: 'manual',
          title: 'تقديم لائحة جوابية',
          taskDate: past,
          status: Value(LifecycleStatus.scheduled.index),
        ));
    // مهمة متأخرة منجزة => يجب ألا تظهر
    await db.into(db.dailyTasks).insert(DailyTasksCompanion.insert(
          taskType: 'manual',
          title: 'مهمة منجزة',
          taskDate: past,
          status: Value(LifecycleStatus.completed.index),
        ));
    // جلسة فات موعدها بلا نتيجة => يجب أن تظهر
    await db.into(db.caseSessions).insert(CaseSessionsCompanion.insert(
          caseId: caseId,
          sessionDate: past,
          status: Value(LifecycleStatus.scheduled.index),
        ));

    final taskRows = await db.customSelect('''
      SELECT id, title, task_date, status
      FROM daily_tasks
      WHERE task_date < ? AND status NOT IN (?, ?)
    ''', variables: [
      Variable.withDateTime(dayStart(today)),
      Variable.withInt(LifecycleStatus.completed.index),
      Variable.withInt(LifecycleStatus.cancelled.index),
    ]).get();

    expect(taskRows.length, 1);
    expect(taskRows.first.data['title'], 'تقديم لائحة جوابية');

    final sessionRows = await db.customSelect('''
      SELECT cs.id FROM case_sessions cs
      WHERE cs.session_date < ? AND cs.status NOT IN (?, ?)
    ''', variables: [
      Variable.withDateTime(dayStart(today)),
      Variable.withInt(LifecycleStatus.completed.index),
      Variable.withInt(LifecycleStatus.cancelled.index),
    ]).get();

    expect(sessionRows.length, 1);
  });

  test('Overdue report skips approved and cancelled work orders', () async {
    final today = DateTime(2026, 7, 24);
    final past = DateTime(2026, 7, 18);

    await db.into(db.workOrders).insert(WorkOrdersCompanion.insert(
          internalNumber: 'WO-2026-001',
          assignedToName: 'المعقب سامر',
          orderType: 'court_attendance',
          dueDate: past,
          status: const Value('waiting_for_result'),
        ));
    await db.into(db.workOrders).insert(WorkOrdersCompanion.insert(
          internalNumber: 'WO-2026-002',
          assignedToName: 'المعقب سامر',
          orderType: 'court_attendance',
          dueDate: past,
          status: const Value('approved'),
        ));

    final rows = await db.customSelect('''
      SELECT internal_number FROM work_orders
      WHERE due_date < ?
        AND status NOT IN ('approved', 'cancelled', 'impossible')
    ''', variables: [Variable.withDateTime(dayStart(today))]).get();

    expect(rows.length, 1);
    expect(rows.first.data['internal_number'], 'WO-2026-001');
  });

  test('Deficient report groups open deficiencies per case and flags missing docs', () async {
    final caseId = await insertCase(
      internalNumber: 'دعوى/2026/0003',
      subject: 'دعوى تثبيت بيع',
      baseNumber: null,
    );

    Future<void> addDeficiency(String field, String status) async {
      await db.into(db.deficiencies).insert(DeficienciesCompanion.insert(
            entityType: EntityType.caseEntity.index,
            entityId: caseId,
            fieldName: field,
            description: 'نقص $field',
            status: Value(status),
          ));
    }

    await addDeficiency('base_number', 'open');
    await addDeficiency('poa_attachment', 'open');
    await addDeficiency('next_session_date', 'resolved');

    final rows = await db.customSelect('''
      SELECT c.internal_number, c.subject, c.base_number,
             COUNT(d.id) AS deficiency_count,
             SUM(CASE WHEN d.field_name LIKE '%doc%'
                        OR d.field_name LIKE '%attachment%'
                        OR d.field_name LIKE '%مستند%'
                      THEN 1 ELSE 0 END) AS missing_doc_count
      FROM deficiencies d
      INNER JOIN cases c ON c.id = d.entity_id
      WHERE d.status = 'open' AND d.entity_type = ?
      GROUP BY c.id, c.internal_number, c.subject, c.base_number
    ''', variables: [Variable.withInt(EntityType.caseEntity.index)]).get();

    expect(rows.length, 1);
    final data = rows.first.data;
    // النقص المحلول لا يُحتسب
    expect(data['deficiency_count'], 2);
    // poa_attachment يُحتسب كمستند ناقص
    expect(data['missing_doc_count'], 1);
    expect(data['base_number'], isNull);
  });

  test('Reports return empty on a clean database instead of invented rows', () async {
    final sessions = await db.customSelect(
      'SELECT * FROM case_sessions WHERE session_date >= ? AND session_date < ?',
      variables: [
        Variable.withDateTime(dayStart(DateTime(2026, 7, 24))),
        Variable.withDateTime(dayEnd(DateTime(2026, 7, 24))),
      ],
    ).get();
    final deficient = await db.customSelect(
      "SELECT * FROM deficiencies WHERE status = 'open'",
    ).get();

    expect(sessions, isEmpty);
    expect(deficient, isEmpty);
  });
}
