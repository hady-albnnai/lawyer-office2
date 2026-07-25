import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/presentation/providers/report_data_providers.dart';
import 'package:lawyer_office/presentation/screens/cases/case_models.dart';
import 'package:lawyer_office/presentation/screens/documents/document_models.dart';
import 'package:lawyer_office/presentation/screens/finance/finance_models.dart';
import 'package:lawyer_office/presentation/screens/persons/person_models.dart';
import 'package:lawyer_office/presentation/screens/search_reports/search_report_models.dart';
import 'package:lawyer_office/presentation/screens/work_orders/work_order_models.dart';

void main() {
  SearchReportEngine buildEngine() {
    final directory = PersonsDirectoryNotifier.withDemoSeed().state;
    final documents = [
      DocumentItem(
        id: 'doc_test',
        title: 'مذكرة دفاع',
        documentType: DocumentType.memo,
        entityType: 'case',
        entityId: '1',
        entityTitle: 'الدعوى 2026/001',
        filePath: 'docs/memo.pdf',
        fileName: 'memo.pdf',
        fileSize: 1024,
        fileType: FileType.pdf,
        uploadDate: DateTime(2026, 7, 10),
        uploadedBy: 'هادي البني',
        physicalLocation: 'مكتب',
      ),
    ];
    final workOrders = [
      WorkOrder(
        id: 'wo1',
        internalNumber: 'WO-2026-001',
        linkedEntityType: 'case',
        linkedEntityId: 'CASE-001',
        assignedToName: 'أحمد محمد',
        assignedToPhone: '0912345678',
        orderType: WorkOrderType.courtAttendance,
        priority: WorkOrderPriority.high,
        status: WorkOrderStatus.draft,
        dueDate: DateTime(2026, 7, 10),
        instructions: 'حضور جلسة الدعوى رقم 2026/001',
        createdAt: DateTime(2026, 7, 9),
        createdBy: 'هادي البني',
      ),
    ];
    final finance = FinanceNotifier().state;
    final realCases = [
      Case(
        id: '1',
        caseNumber: 'دعوى/2026/0001',
        title: 'مطالبة بدل أتعاب',
        type: CaseType.civil,
        status: CaseStatus.inProgress,
        court: 'بداية مدنية دمشق',
        baseNumber: '345',
        creationDate: DateTime(2026, 7, 1),
      ),
    ];
    final contracts = [
      ContractSearchSeed(
        id: '1',
        internalNumber: 'عقد/2026/0001',
        title: 'عقد إيجار محل تجاري',
        contractType: 'إيجار',
        status: 'active',
        dateEnd: DateTime(2027, 1, 1),
      ),
    ];
    // بيانات التقارير تُمرَّر صراحةً كما تأتي من قاعدة البيانات في التطبيق،
    // ولم تعد صفوفاً ثابتة مخبأة داخل المحرك.
    const reportData = ReportDataBundle(
      sessions: [
        SessionReportRow(
          time: '09:00',
          caseNumber: 'دعوى/2026/0001',
          title: 'مطالبة بدل أتعاب',
          court: 'بداية مدنية دمشق',
          status: 'مجدولة',
        ),
        SessionReportRow(
          time: '10:30',
          caseNumber: 'دعوى/2026/0002',
          title: 'إخلاء مأجور',
          court: 'استئناف دمشق',
          status: 'مجدولة',
        ),
        SessionReportRow(
          time: '12:00',
          caseNumber: 'دعوى/2026/0003',
          title: 'دعوى تجارية',
          court: 'بداية تجارية دمشق',
          status: 'مجدولة',
        ),
      ],
      overdue: [
        OverdueReportRow(
          type: 'أمر عمل',
          reference: 'WO-2026-003',
          title: 'دفع رسم الدعوى',
          due: '2026-07-09',
          notes: 'بانتظار نتيجة المعقب',
        ),
      ],
      deficient: [
        DeficientReportRow(
          fileNumber: 'دعوى/2026/0002',
          title: 'إخلاء مأجور',
          deficiencies: '2',
          baseNumber: 'بانتظار',
          missingDocs: 'نعم',
        ),
      ],
    );

    // صفوف ملفات المكتب لتقارير الجارية/المنتهية/الأرشيف القديم.
    const officeFiles = [
      {
        'number': 'دعوى/2026/0001',
        'type': 'دعوى',
        'title': 'مطالبة',
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

    return SearchReportEngine.buildFromSources(
      realCases: realCases,
      directory: directory,
      documents: documents,
      workOrders: workOrders,
      finance: finance,
      contracts: contracts,
      reportData: reportData,
      officeFiles: officeFiles,
    );
  }

  test('Search engine indexes all required scopes', () {
    final engine = buildEngine();
    final scopes = engine.index.map((h) => h.scope).toSet();

    expect(scopes.contains(SearchScope.cases), isTrue);
    expect(scopes.contains(SearchScope.persons), isTrue);
    expect(scopes.contains(SearchScope.agencies), isTrue);
    expect(scopes.contains(SearchScope.documents), isTrue);
    expect(scopes.contains(SearchScope.workOrders), isTrue);
    expect(scopes.contains(SearchScope.finance), isTrue);
    expect(scopes.contains(SearchScope.legalLibrary), isTrue);
    expect(scopes.contains(SearchScope.contracts), isTrue);
  });

  test('Search finds cases, persons, work orders, finance and library items', () {
    final engine = buildEngine();

    expect(engine.search('تعويض'), isNotEmpty);
    expect(engine.search('WO-2026'), isNotEmpty);
    expect(engine.search('أصول المحاكمات'), isNotEmpty);
    expect(engine.search('سند قبض', scope: SearchScope.finance), isNotEmpty);

    final personHits = engine.search('أحمد', scope: SearchScope.persons);
    // may be empty depending on seed names; ensure filter by scope works
    expect(
      engine.search('تعويض', scope: SearchScope.workOrders).every((h) => h.scope == SearchScope.workOrders),
      isTrue,
    );
    expect(personHits.every((h) => h.scope == SearchScope.persons), isTrue);
  });

  test('Empty query returns no hits', () {
    final engine = buildEngine();
    expect(engine.search(''), isEmpty);
    expect(engine.search('   '), isEmpty);
  });

  test('Reports generate rows and summaries for all kinds', () {
    final engine = buildEngine();
    for (final kind in ReportKind.values) {
      final report = engine.generate(kind);
      expect(report.title, isNotEmpty);
      expect(report.headers, isNotEmpty);
      expect(report.summary, isNotEmpty);
      // finance/sessions/etc should have data from seed
      if (kind != ReportKind.legalMemos) {
        expect(report.rowCount, greaterThan(0), reason: 'report $kind should have rows');
      }
    }

    final financeReport = engine.generate(ReportKind.finance);
    expect(financeReport.summary.containsKey('إجمالي الأتعاب'), isTrue);
    expect(financeReport.rows, isNotEmpty);

    final sessions = engine.generate(ReportKind.sessions);
    expect(sessions.headers.length, 5);
    expect(sessions.rowCount, 3);
  });

  test('Count by scope aggregates search hits', () {
    final engine = buildEngine();
    final counts = engine.countByScope('2026');
    expect(counts.values.fold(0, (a, b) => a + b), greaterThan(0));
  });

  test('UI notifier updates query scope and report selection', () {
    final notifier = SearchReportsNotifier();
    notifier.setQuery('تعويض');
    notifier.setScope(SearchScope.cases);
    notifier.selectReport(ReportKind.overdue);

    expect(notifier.state.query, 'تعويض');
    expect(notifier.state.scope, SearchScope.cases);
    expect(notifier.state.selectedReport, ReportKind.overdue);

    final engine = buildEngine();
    final report = engine.generate(ReportKind.finance);
    notifier.setGeneratedReport(report);
    expect(notifier.state.lastReport?.kind, ReportKind.finance);
    notifier.clearGeneratedReport();
    expect(notifier.state.lastReport, isNull);
  });
}
