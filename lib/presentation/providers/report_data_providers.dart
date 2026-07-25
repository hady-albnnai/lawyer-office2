import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/app_enums.dart';
import 'app_providers.dart';
import 'ui_data_providers.dart' show coreDataBootstrapProvider;

/// =============================================================================
/// مصادر بيانات التقارير الحقيقية (SQLite).
///
/// كانت التقارير سابقاً تُبنى من صفوف ثابتة مكتوبة داخل الكود، فتطبع أرقاماً
/// مخترعة لا علاقة لها بقاعدة البيانات. هذا الملف يستبدل ذلك بقراءة فعلية.
/// =============================================================================

String _fmtDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime _dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime? _parseDate(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _sessionStatusLabel(int? status) {
  final index = status ?? 0;
  if (index < 0 || index >= LifecycleStatus.values.length) return 'مجدولة';
  return LifecycleStatus.values[index].label;
}

/// صف واحد في كشف الجلسات.
class SessionReportRow {
  final String time;
  final String caseNumber;
  final String title;
  final String court;
  final String status;

  const SessionReportRow({
    required this.time,
    required this.caseNumber,
    required this.title,
    required this.court,
    required this.status,
  });
}

/// صف واحد في كشف المتأخرات.
class OverdueReportRow {
  final String type;
  final String reference;
  final String title;
  final String due;
  final String notes;

  const OverdueReportRow({
    required this.type,
    required this.reference,
    required this.title,
    required this.due,
    required this.notes,
  });
}

/// صف واحد في كشف الملفات الناقصة.
class DeficientReportRow {
  final String fileNumber;
  final String title;
  final String deficiencies;
  final String baseNumber;
  final String missingDocs;

  const DeficientReportRow({
    required this.fileNumber,
    required this.title,
    required this.deficiencies,
    required this.baseNumber,
    required this.missingDocs,
  });
}

/// حزمة بيانات التقارير المقروءة من قاعدة البيانات.
class ReportDataBundle {
  final List<SessionReportRow> sessions;
  final List<OverdueReportRow> overdue;
  final List<DeficientReportRow> deficient;

  const ReportDataBundle({
    this.sessions = const [],
    this.overdue = const [],
    this.deficient = const [],
  });
}

/// كشف جلسات يوم محدد (افتراضياً اليوم) من `case_sessions`.
final sessionsReportProvider =
    FutureProvider.family<List<SessionReportRow>, DateTime?>((ref, date) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final db = ref.watch(databaseProvider);
  final target = date ?? DateTime.now();
  // التواريخ مخزّنة كأعداد Unix epoch، لذا تُقارن بمجال [بداية اليوم، بداية الغد)
  // ولا تصلح معها دالة DATE() التي تُرجع NULL على الأعداد.
  final dayStart = _dayStart(target);
  final dayEnd = dayStart.add(const Duration(days: 1));

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
    Variable.withDateTime(dayStart),
    Variable.withDateTime(dayEnd),
  ]).get();

  return rows.map((row) {
    final data = row.data;
    final subject = (data['subject'] as String?) ?? '';
    final sessionType = (data['session_type'] as String?) ?? 'مرافعة';
    return SessionReportRow(
      time: (data['session_time'] as String?) ?? '—',
      caseNumber: (data['internal_number'] as String?) ?? '—',
      title: subject.isNotEmpty ? subject : sessionType,
      court: (data['court_name'] as String?) ?? 'غير محددة',
      status: _sessionStatusLabel(data['status'] as int?),
    );
  }).toList();
});

/// كشف المتأخرات: مهام يومية ومواعيد جلسات وأوامر عمل فات موعدها ولم تُنجز.
final overdueReportProvider = FutureProvider<List<OverdueReportRow>>((ref) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final db = ref.watch(databaseProvider);
  final todayStart = _dayStart(DateTime.now());
  final result = <OverdueReportRow>[];

  // 1) مهام يومية متأخرة (غير منجزة/ملغاة).
  final taskRows = await db.customSelect('''
    SELECT id, title, task_date, task_type, notes, status
    FROM daily_tasks
    WHERE task_date < ?
      AND status NOT IN (?, ?)
    ORDER BY task_date
  ''', variables: [
    Variable.withDateTime(todayStart),
    Variable.withInt(LifecycleStatus.completed.index),
    Variable.withInt(LifecycleStatus.cancelled.index),
  ]).get();

  for (final row in taskRows) {
    final data = row.data;
    final due = _parseDate(data['task_date']);
    result.add(OverdueReportRow(
      type: 'مهمة',
      reference: '#${data['id']}',
      title: (data['title'] as String?) ?? 'مهمة',
      due: due == null ? '—' : _fmtDate(due),
      notes: (data['notes'] as String?) ?? _sessionStatusLabel(data['status'] as int?),
    ));
  }

  // 2) جلسات فات موعدها ولم تُسجَّل نتيجتها.
  final sessionRows = await db.customSelect('''
    SELECT cs.id, cs.session_date, cs.session_type, cs.status,
           c.internal_number, c.subject
    FROM case_sessions cs
    LEFT JOIN cases c ON c.id = cs.case_id
    WHERE cs.session_date < ?
      AND cs.status NOT IN (?, ?)
    ORDER BY cs.session_date
  ''', variables: [
    Variable.withDateTime(todayStart),
    Variable.withInt(LifecycleStatus.completed.index),
    Variable.withInt(LifecycleStatus.cancelled.index),
  ]).get();

  for (final row in sessionRows) {
    final data = row.data;
    final due = _parseDate(data['session_date']);
    final subject = (data['subject'] as String?) ?? '';
    result.add(OverdueReportRow(
      type: 'جلسة',
      reference: (data['internal_number'] as String?) ?? '#${data['id']}',
      title: subject.isNotEmpty ? subject : ((data['session_type'] as String?) ?? 'جلسة'),
      due: due == null ? '—' : _fmtDate(due),
      notes: 'لم تُسجَّل نتيجة الجلسة',
    ));
  }

  // 3) أوامر عمل فات موعدها ولم تُعتمد.
  final workOrderRows = await db.customSelect('''
    SELECT id, internal_number, instructions, due_date, status, assigned_to_name
    FROM work_orders
    WHERE due_date < ?
      AND status NOT IN ('approved', 'cancelled', 'impossible')
    ORDER BY due_date
  ''', variables: [Variable.withDateTime(todayStart)]).get();

  for (final row in workOrderRows) {
    final data = row.data;
    final due = _parseDate(data['due_date']);
    final assignee = (data['assigned_to_name'] as String?) ?? '';
    result.add(OverdueReportRow(
      type: 'أمر عمل',
      reference: (data['internal_number'] as String?) ?? '#${data['id']}',
      title: (data['instructions'] as String?) ?? 'أمر عمل',
      due: due == null ? '—' : _fmtDate(due),
      notes: assignee.isEmpty ? 'بانتظار التنفيذ' : 'المكلف: $assignee',
    ));
  }

  result.sort((a, b) => a.due.compareTo(b.due));
  return result;
});

/// كشف الملفات الناقصة: دعاوى لها نواقص مفتوحة، مع بيان رقم الأساس والمستندات.
final deficientReportProvider = FutureProvider<List<DeficientReportRow>>((ref) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final db = ref.watch(databaseProvider);

  final rows = await db.customSelect('''
    SELECT c.id, c.internal_number, c.subject, c.base_number,
           COUNT(d.id) AS deficiency_count,
           SUM(CASE WHEN d.field_name LIKE '%doc%'
                      OR d.field_name LIKE '%attachment%'
                      OR d.field_name LIKE '%مستند%'
                    THEN 1 ELSE 0 END) AS missing_doc_count
    FROM deficiencies d
    INNER JOIN cases c ON c.id = d.entity_id
    WHERE d.status = 'open' AND d.entity_type = ?
    GROUP BY c.id, c.internal_number, c.subject, c.base_number
    ORDER BY deficiency_count DESC, c.internal_number
  ''', variables: [Variable.withInt(EntityType.caseEntity.index)]).get();

  return rows.map((row) {
    final data = row.data;
    final subject = (data['subject'] as String?) ?? '';
    final baseNumber = (data['base_number'] as String?) ?? '';
    final missingDocs = (data['missing_doc_count'] as int?) ?? 0;
    return DeficientReportRow(
      fileNumber: (data['internal_number'] as String?) ?? '#${data['id']}',
      title: subject.isNotEmpty ? subject : 'دعوى',
      deficiencies: '${(data['deficiency_count'] as int?) ?? 0}',
      baseNumber: baseNumber.isEmpty ? 'بانتظار' : baseNumber,
      missingDocs: missingDocs > 0 ? 'نعم' : 'لا',
    );
  }).toList();
});

/// صفوف ملفات المكتب لتقارير الجارية/المنتهية/الأرشيف القديم.
final officeFilesReportProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final files = await ref.watch(officeFileRepositoryProvider).getAll();

  return files.map((f) {
    final quality = <String>[];
    if (f.hasPendingFinance) quality.add('مالية معلقة');
    if (f.hasPendingPaperOriginal) quality.add('أصل ورقي ناقص');
    if (f.hasPostClosureActions) quality.add('إجراءات لاحقة');
    if ((f.title ?? '').trim().isEmpty) quality.add('بلا عنوان');

    return {
      'number': f.fileNumber,
      'type': f.fileType.label,
      'title': (f.title ?? '').trim().isEmpty ? '—' : f.title!.trim(),
      'status': f.status.dbValue,
      'statusLabel': f.status.label,
      'source': f.source.dbValue,
      'closureReason': f.closureReason ?? '—',
      'closedAt': f.closedAt == null ? '—' : _fmtDate(f.closedAt!),
      'nextDate': '—',
      'quality': quality.join('، '),
    };
  }).toList();
});

/// حزمة التقارير الكاملة، تُستهلك من محرك البحث والتقارير.
final reportDataBundleProvider = FutureProvider<ReportDataBundle>((ref) async {
  final sessions = await ref.watch(sessionsReportProvider(null).future);
  final overdue = await ref.watch(overdueReportProvider.future);
  final deficient = await ref.watch(deficientReportProvider.future);
  return ReportDataBundle(sessions: sessions, overdue: overdue, deficient: deficient);
});
