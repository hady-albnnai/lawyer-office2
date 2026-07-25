import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/presentation/screens/files/files_screen.dart';
import 'package:lawyer_office/presentation/screens/finance/finance_models.dart';
import 'package:lawyer_office/presentation/screens/search_reports/search_report_models.dart';

/// المرحلة الرابعة (الإغلاق الإداري) والمرحلة الرابعة عشرة (التقارير)
/// من خارطة التنفيذ النهائية.
void main() {
  SearchReportEngine engineWith(List<Map<String, String>> files) {
    return SearchReportEngine(
      index: const [],
      sessions: const [],
      overdue: const [],
      deficient: const [],
      workOrders: const [],
      memos: const [],
      officeFiles: files,
      financeState: const FinanceState(agreements: [], payments: [], expenses: []),
    );
  }

  final sample = [
    {
      'number': 'دعوى/2026/0001',
      'type': 'دعوى',
      'title': 'مطالبة مالية',
      'status': 'active',
      'statusLabel': 'جاري',
      'source': 'new_work',
      'closureReason': '—',
      'closedAt': '—',
      'nextDate': '2026-08-01',
      'quality': '',
    },
    {
      'number': 'عقد/2026/0001',
      'type': 'عقد',
      'title': 'عقد إيجار',
      'status': 'closed',
      'statusLabel': 'منتهي',
      'source': 'new_work',
      'closureReason': 'انتهى',
      'closedAt': '2026-07-01',
      'nextDate': '—',
      'quality': '',
    },
    {
      'number': 'دعوى/2025/0009',
      'type': 'دعوى',
      'title': 'ملف مستورد',
      'status': 'active',
      'statusLabel': 'جاري',
      'source': 'old_archive',
      'closureReason': '—',
      'closedAt': '—',
      'nextDate': '—',
      'quality': 'أصل ورقي ناقص',
    },
  ];

  test('Every file type has approved closure reasons', () {
    for (final type in FileType.values) {
      final reasons = kClosureReasonsByType[type];
      expect(reasons, isNotNull, reason: 'النوع ${type.displayName} بلا أسباب إغلاق');
      expect(reasons!, isNotEmpty);
    }
    // أمثلة صريحة من الخطة
    expect(kClosureReasonsByType[FileType.caseFile], contains('حكم قطعي'));
    expect(kClosureReasonsByType[FileType.agency], contains('عزل عنها'));
    expect(kClosureReasonsByType[FileType.company], contains('انحلت'));
  });

  test('Active files report lists only active files', () {
    final report = engineWith(sample).generate(ReportKind.activeFiles);
    expect(report.title, 'قائمة الملفات الجارية');
    expect(report.rowCount, 2);
    expect(report.summary['ملفات جارية'], '2');
  });

  test('Closed files report shows closure reason and date', () {
    final report = engineWith(sample).generate(ReportKind.closedFiles);
    expect(report.rowCount, 1);
    final row = report.rows.first.cells;
    expect(row, contains('انتهى'));
    expect(row, contains('2026-07-01'));
  });

  test('Old archive report isolates imported files and flags quality gaps', () {
    final report = engineWith(sample).generate(ReportKind.archiveQuality);
    expect(report.rowCount, 1);
    expect(report.rows.first.cells, contains('أصل ورقي ناقص'));
    expect(report.summary['تحتاج استكمال'], '1');
  });

  test('All roadmap report kinds produce a titled report', () {
    final engine = engineWith(sample);
    for (final kind in ReportKind.values) {
      final report = engine.generate(kind);
      expect(report.title, isNotEmpty, reason: 'التقرير $kind بلا عنوان');
      expect(report.headers, isNotEmpty);
    }
  });

  test('Empty database produces empty file reports, not invented rows', () {
    final engine = engineWith(const []);
    expect(engine.generate(ReportKind.activeFiles).rowCount, 0);
    expect(engine.generate(ReportKind.closedFiles).rowCount, 0);
    expect(engine.generate(ReportKind.archiveQuality).rowCount, 0);
  });
}
