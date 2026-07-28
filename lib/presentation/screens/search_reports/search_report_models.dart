/// نماذج ومحرك المرحلة 8: البحث الشامل والتقارير.
///
/// محرك بحث موحد قابل للاختبار يغطي الدعاوى والعقود والشركات والإجراءات
/// والأشخاص والوكالات والمستندات وأوامر العمل والمالية وبنود المكتبة.
/// التقارير تولَّد من نفس مصادر seed/providers الحالية offline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart' show allContractsProvider;
import '../../providers/report_data_providers.dart';
import '../../providers/ui_data_providers.dart' show uiCasesProvider;
import '../../theme/app_colors.dart';
import '../cases/case_models.dart' as ui_case;
import '../documents/document_models.dart';
import '../documents/document_models.dart' as ui_doc;
import '../finance/finance_models.dart';
import '../persons/person_models.dart';
import '../work_orders/work_order_models.dart';
import '../work_orders/work_orders_screen.dart' show woProvider;

/// نطاق البحث.
enum SearchScope {
  all,
  cases,
  contracts,
  companies,
  procedures,
  persons,
  agencies,
  documents,
  workOrders,
  finance,
  legalLibrary;

  String get displayName => const [
        'الكل',
        'دعاوى',
        'عقود',
        'شركات',
        'إجراءات',
        'أشخاص',
        'وكالات',
        'مستندات',
        'أوامر عمل',
        'مالية',
        'مكتبة قانونية',
      ][index];

  IconData get icon => const [
        Icons.manage_search,
        Icons.gavel,
        Icons.description,
        Icons.business,
        Icons.assignment,
        Icons.person,
        Icons.verified_user,
        Icons.folder_open,
        Icons.assignment_ind,
        Icons.account_balance_wallet,
        Icons.menu_book,
      ][index];
}

/// نوع التقرير.
enum ReportKind {
  sessions,
  overdue,
  deficient,
  finance,
  clientAccounts,
  workOrders,
  activeFiles,
  closedFiles,
  archiveQuality,
  legalMemos;

  String get displayName => const [
        'كشف الجلسات',
        'كشف المتأخرات',
        'كشف الملفات الناقصة',
        'كشف مالية',
        'كشف حسابات الموكلين',
        'كشف أوامر العمل',
        'قائمة الملفات الجارية',
        'قائمة الملفات المنتهية',
        'تقرير الأرشيف القديم',
        'مذكرات قانونية',
      ][index];

  String get description => const [
        'جلسات المحكمة القادمة واليوم مع الحالة والمحكمة.',
        'الملفات والمهام المتأخرة عن موعدها.',
        'الملفات ذات النواقص أو بانتظار رقم أساس أو مستند.',
        'ملخص الأتعاب والمقبوض والمتبقي والمصاريف وذمم الموكلين.',
        'حساب كل موكل: المستحق عليه، المقبوض منه، ورصيده أو أمانته.',
        'أوامر عمل المعقب حسب الحالة والأولوية.',
        'كل ملفات المكتب الجارية مع الموعد القادم والنواقص.',
        'الملفات المنتهية مع سبب الإغلاق وتاريخه.',
        'الملفات المستوردة من الأرشيف القديم وجودة بياناتها.',
        'المذكرات والمستندات القانونية المرتبطة بالملفات.',
      ][index];

  IconData get icon => const [
        Icons.event,
        Icons.schedule,
        Icons.warning_amber,
        Icons.payments,
        Icons.account_balance_wallet,
        Icons.assignment_turned_in,
        Icons.folder_open,
        Icons.folder_off,
        Icons.inventory_2,
        Icons.article,
      ][index];
}

/// نتيجة بحث واحدة.
class SearchHit {
  final String id;
  final SearchScope scope;
  final String title;
  final String subtitle;
  final String routeHint;
  final Map<String, String> meta;
  final List<String> keywords;

  const SearchHit({
    required this.id,
    required this.scope,
    required this.title,
    required this.subtitle,
    required this.routeHint,
    this.meta = const {},
    this.keywords = const [],
  });

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (title.toLowerCase().contains(q)) return true;
    if (subtitle.toLowerCase().contains(q)) return true;
    if (routeHint.toLowerCase().contains(q)) return true;
    for (final value in meta.values) {
      if (value.toLowerCase().contains(q)) return true;
    }
    for (final keyword in keywords) {
      if (keyword.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

/// صف تقرير جدولي.
class ReportRow {
  final List<String> cells;

  const ReportRow(this.cells);
}

/// تقرير جاهز للعرض/التصدير.
class GeneratedReport {
  final ReportKind kind;
  final String title;
  final DateTime generatedAt;
  final List<String> headers;
  final List<ReportRow> rows;
  final Map<String, String> summary;

  const GeneratedReport({
    required this.kind,
    required this.title,
    required this.generatedAt,
    required this.headers,
    required this.rows,
    this.summary = const {},
  });

  int get rowCount => rows.length;
}

/// عنصر مكتبة قانونية مصغّر للبحث (نواة المرحلة 8 قبل اكتمال المرحلة 9).
class LegalLibraryHitSeed {
  final String id;
  final String title;
  final String type;
  final String source;
  final int year;
  final String tags;

  const LegalLibraryHitSeed({
    required this.id,
    required this.title,
    required this.type,
    required this.source,
    required this.year,
    required this.tags,
  });
}

/// عقد مبسّط لفهرسة البحث، مبني من صفوف قاعدة البيانات الحقيقية.
class ContractSearchSeed {
  final String id;
  final String internalNumber;
  final String title;
  final String contractType;
  final String status;
  final DateTime? dateEnd;

  const ContractSearchSeed({
    required this.id,
    required this.internalNumber,
    required this.title,
    required this.contractType,
    required this.status,
    this.dateEnd,
  });

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'ساري';
      case 'expired':
        return 'منتهٍ';
      case 'cancelled':
        return 'ملغى';
      case 'disputed':
        return 'متنازع عليه';
      case 'suspended':
        return 'موقوف';
      default:
        return status;
    }
  }
}

/// محرك فهرسة وبحث وتوليد تقارير — قابل للاختبار بدون UI.
class SearchReportEngine {
  final List<SearchHit> index;
  final List<Map<String, String>> sessions;
  final List<Map<String, String>> overdue;
  final List<Map<String, String>> deficient;
  final List<Map<String, String>> workOrders;
  final List<Map<String, String>> memos;

  /// صفوف ملفات المكتب (جارية/منتهية/أرشيف قديم) من office_files.
  final List<Map<String, String>> officeFiles;

  final FinanceState financeState;

  const SearchReportEngine({
    required this.index,
    required this.sessions,
    required this.overdue,
    required this.deficient,
    required this.workOrders,
    required this.memos,
    this.officeFiles = const [],
    required this.financeState,
  });

  List<SearchHit> search(String query, {SearchScope scope = SearchScope.all}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    return index.where((hit) {
      final scopeOk = scope == SearchScope.all || hit.scope == scope;
      return scopeOk && hit.matches(q);
    }).toList();
  }

  Map<SearchScope, int> countByScope(String query) {
    final hits = search(query);
    final map = <SearchScope, int>{};
    for (final hit in hits) {
      map[hit.scope] = (map[hit.scope] ?? 0) + 1;
    }
    return map;
  }

  GeneratedReport generate(ReportKind kind) {
    final now = DateTime.now();
    switch (kind) {
      case ReportKind.sessions:
        return GeneratedReport(
          kind: kind,
          title: 'كشف الجلسات',
          generatedAt: now,
          headers: const ['الوقت', 'رقم الدعوى', 'الموضوع', 'المحكمة', 'الحالة'],
          rows: sessions
              .map(
                (s) => ReportRow([
                  s['time'] ?? '',
                  s['caseNumber'] ?? '',
                  s['title'] ?? '',
                  s['court'] ?? '',
                  s['status'] ?? '',
                ]),
              )
              .toList(),
          summary: {'عدد الجلسات': '${sessions.length}'},
        );
      case ReportKind.overdue:
        return GeneratedReport(
          kind: kind,
          title: 'كشف المتأخرات',
          generatedAt: now,
          headers: const ['النوع', 'المرجع', 'العنوان', 'الاستحقاق', 'الملاحظات'],
          rows: overdue
              .map(
                (s) => ReportRow([
                  s['type'] ?? '',
                  s['ref'] ?? '',
                  s['title'] ?? '',
                  s['due'] ?? '',
                  s['notes'] ?? '',
                ]),
              )
              .toList(),
          summary: {'عدد المتأخرات': '${overdue.length}'},
        );
      case ReportKind.deficient:
        return GeneratedReport(
          kind: kind,
          title: 'كشف الملفات الناقصة',
          generatedAt: now,
          headers: const ['الملف', 'العنوان', 'النواقص', 'رقم الأساس', 'مستندات ناقصة'],
          rows: deficient
              .map(
                (s) => ReportRow([
                  s['fileNumber'] ?? '',
                  s['title'] ?? '',
                  s['deficiencies'] ?? '',
                  s['baseNumber'] ?? '',
                  s['missingDocs'] ?? '',
                ]),
              )
              .toList(),
          summary: {'ملفات ناقصة': '${deficient.length}'},
        );
      case ReportKind.finance:
        final summary = financeState.summary;
        final clients = financeState.clientReceivables;
        return GeneratedReport(
          kind: kind,
          title: 'كشف مالية الموكلين',
          generatedAt: now,
          headers: const ['الموكل', 'اتفاقيات', 'المقبوض', 'المتبقي', 'الحالة'],
          rows: clients
              .map(
                (c) => ReportRow([
                  c.partyName,
                  _money(c.agreementsTotal),
                  _money(c.paymentsTotal),
                  _money(c.remaining),
                  c.isSettled ? 'مسدّد' : 'ذمة قائمة',
                ]),
              )
              .toList(),
          summary: {
            'إجمالي الأتعاب': _money(summary.agreementsTotal),
            'المقبوض': _money(summary.paymentsTotal),
            'المتبقي': _money(summary.remainingFees),
            'المصاريف': _money(summary.expensesTotal),
            'الصافي': _money(summary.netBalance),
          },
        );
      case ReportKind.clientAccounts:
        final statements = financeState.clientReceivables;
        final totalDue = statements.fold<double>(0, (sum, c) => sum + c.totalDue);
        final totalPaid = statements.fold<double>(0, (sum, c) => sum + c.paymentsTotal);
        final totalOwed = statements
            .where((c) => c.accountBalance > 0)
            .fold<double>(0, (sum, c) => sum + c.accountBalance);
        final totalCredit = statements.fold<double>(0, (sum, c) => sum + c.creditAmount);
        return GeneratedReport(
          kind: kind,
          title: 'كشف حسابات الموكلين',
          generatedAt: now,
          headers: const ['الموكل', 'أتعاب', 'مصاريف عنه', 'المقبوض', 'الرصيد', 'الحالة'],
          rows: statements
              .map(
                (c) => ReportRow([
                  c.partyName,
                  _money(c.agreementsTotal),
                  _money(c.expensesTotal),
                  _money(c.paymentsTotal),
                  _money(c.accountBalance.abs()),
                  c.accountStatusLabel,
                ]),
              )
              .toList(),
          summary: {
            'إجمالي المستحق': _money(totalDue),
            'إجمالي المقبوض': _money(totalPaid),
            'ذمم قائمة': _money(totalOwed),
            'أمانات الموكلين': _money(totalCredit),
          },
        );
      case ReportKind.workOrders:
        return GeneratedReport(
          kind: kind,
          title: 'كشف أوامر العمل',
          generatedAt: now,
          headers: const ['الرقم', 'المكلف', 'النوع', 'الحالة', 'الموعد'],
          rows: workOrders
              .map(
                (s) => ReportRow([
                  s['number'] ?? '',
                  s['assignee'] ?? '',
                  s['type'] ?? '',
                  s['status'] ?? '',
                  s['due'] ?? '',
                ]),
              )
              .toList(),
          summary: {'عدد الأوامر': '${workOrders.length}'},
        );
      case ReportKind.activeFiles:
      case ReportKind.closedFiles:
      case ReportKind.archiveQuality:
        final wantClosed = kind == ReportKind.closedFiles;
        final rows = officeFiles.where((f) {
          if (kind == ReportKind.archiveQuality) return f['source'] == 'old_archive';
          return wantClosed ? f['status'] == 'closed' : f['status'] == 'active';
        }).toList();

        if (kind == ReportKind.archiveQuality) {
          return GeneratedReport(
            kind: kind,
            title: 'تقرير الأرشيف القديم',
            generatedAt: now,
            headers: const ['رقم الملف', 'النوع', 'العنوان', 'الحالة', 'ملاحظات الجودة'],
            rows: rows
                .map((f) => ReportRow([
                      f['number'] ?? '',
                      f['type'] ?? '',
                      f['title'] ?? '',
                      f['statusLabel'] ?? '',
                      f['quality'] ?? '',
                    ]))
                .toList(),
            summary: {
              'ملفات مستوردة': '${rows.length}',
              'تحتاج استكمال': '${rows.where((f) => (f['quality'] ?? '').isNotEmpty).length}',
            },
          );
        }

        return GeneratedReport(
          kind: kind,
          title: wantClosed ? 'قائمة الملفات المنتهية' : 'قائمة الملفات الجارية',
          generatedAt: now,
          headers: wantClosed
              ? const ['رقم الملف', 'النوع', 'العنوان', 'سبب الإغلاق', 'تاريخ الإغلاق']
              : const ['رقم الملف', 'النوع', 'العنوان', 'الموعد القادم', 'ملاحظات'],
          rows: rows
              .map((f) => ReportRow(wantClosed
                  ? [
                      f['number'] ?? '',
                      f['type'] ?? '',
                      f['title'] ?? '',
                      f['closureReason'] ?? '—',
                      f['closedAt'] ?? '—',
                    ]
                  : [
                      f['number'] ?? '',
                      f['type'] ?? '',
                      f['title'] ?? '',
                      f['nextDate'] ?? '—',
                      f['quality'] ?? '',
                    ]))
              .toList(),
          summary: {
            wantClosed ? 'ملفات منتهية' : 'ملفات جارية': '${rows.length}',
          },
        );

      case ReportKind.legalMemos:
        return GeneratedReport(
          kind: kind,
          title: 'كشف المذكرات القانونية',
          generatedAt: now,
          headers: const ['العنوان', 'الملف', 'النوع', 'التاريخ', 'بواسطة'],
          rows: memos
              .map(
                (s) => ReportRow([
                  s['title'] ?? '',
                  s['entity'] ?? '',
                  s['type'] ?? '',
                  s['date'] ?? '',
                  s['by'] ?? '',
                ]),
              )
              .toList(),
          summary: {'عدد المذكرات': '${memos.length}'},
        );
    }
  }

  static String _money(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ل.س';
  }

  static String _date(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// بناء فهرس البحث من مصادر حقيقية (DB + Providers).
  static SearchReportEngine buildFromSources({
    required List<ui_case.Case> realCases,
    required List<ui_doc.DocumentItem> documents,
    required List<WorkOrder> workOrders,
    required FinanceState finance,
    required PersonsDirectoryState directory,
    List<ContractSearchSeed> contracts = const [],
    ReportDataBundle reportData = const ReportDataBundle(),
    List<Map<String, String>> officeFiles = const [],
  }) {
    final index = <SearchHit>[];

    // === الدعاوى الحقيقية ===
    for (final c in realCases) {
      index.add(
        SearchHit(
          id: 'case_${c.id}',
          scope: SearchScope.cases,
          title: 'دعوى ${c.caseNumber}: ${c.title}',
          subtitle: '${c.court} • ${c.status.displayName}',
          routeHint: '/cases/${c.id}',
          meta: {
            'رقم الأساس': c.baseNumber ?? 'بانتظار',
            'المحكمة': c.court,
          },
          keywords: [c.caseNumber, c.title, c.court],
        ),
      );
    }

    for (final person in directory.persons) {
      index.add(
        SearchHit(
          id: 'person_${person.id}',
          scope: SearchScope.persons,
          title: person.fullName,
          subtitle:
              'أدوار: ${person.roles.map((r) => r.displayName).join(', ')} • ${person.city}',
          routeHint: '/persons/${person.id}',
          meta: {
            'الهاتف': person.phone,
            'الهوية': person.nationalId,
            'واتساب': person.whatsapp,
          },
          keywords: [person.fullName, person.phone, person.nationalId, person.city],
        ),
      );
    }

    for (final agency in directory.agencies) {
      final principal = directory.personById(agency.principalPersonId);
      index.add(
        SearchHit(
          id: 'agency_${agency.id}',
          scope: SearchScope.agencies,
          title: 'وكالة ${agency.number}',
          subtitle: '${agency.type.displayName} • ${agency.agentName}',
          routeHint: '/poa/${agency.id}',
          meta: {
            'الموكل': principal?.fullName ?? '',
            'الفرع': agency.branch,
            'المصدر': agency.source.displayName,
          },
          keywords: [agency.number, agency.agentName, agency.branch, principal?.fullName ?? ''],
        ),
      );
    }

    for (final doc in documents) {
      index.add(
        SearchHit(
          id: 'doc_${doc.id}',
          scope: SearchScope.documents,
          title: doc.title,
          subtitle: '${doc.documentType.displayName} • ${doc.entityTitle}',
          routeHint: 'document:${doc.id}',
          meta: {
            'الملف': doc.fileName,
            'الموقع': doc.physicalLocation,
            'الرافع': doc.uploadedBy,
          },
          keywords: [doc.title, doc.fileName, doc.entityTitle, doc.documentType.displayName],
        ),
      );
    }

    for (final wo in workOrders) {
      index.add(
        SearchHit(
          id: 'wo_${wo.id}',
          scope: SearchScope.workOrders,
          title: '${wo.internalNumber} • ${wo.orderTypeText}',
          subtitle: '${wo.assignedToName} • ${wo.statusText}',
          routeHint: 'work-order:${wo.id}',
          meta: {
            'الهاتف': wo.assignedToPhone,
            'التعليمات': wo.instructions,
            'الملف': wo.linkedEntityId,
          },
          keywords: [wo.internalNumber, wo.assignedToName, wo.instructions, wo.orderTypeText],
        ),
      );
    }

    for (final agreement in finance.agreements) {
      index.add(
        SearchHit(
          id: 'fin_ag_${agreement.id}',
          scope: SearchScope.finance,
          title: 'اتفاق أتعاب: ${agreement.entityTitle}',
          subtitle: '${agreement.partyName} • ${_money(agreement.totalAmount)}',
          routeHint: '/finance',
          meta: {
            'النوع': agreement.agreementType.displayName,
            'الكيان': agreement.entityType.displayName,
          },
          keywords: [agreement.entityTitle, agreement.partyName, agreement.id],
        ),
      );
    }
    for (final payment in finance.payments) {
      final agreement = finance.agreementById(payment.agreementId);
      index.add(
        SearchHit(
          id: 'fin_pay_${payment.id}',
          scope: SearchScope.finance,
          title: 'سند قبض ${payment.displayReceiptNumber}',
          subtitle: '${agreement?.partyName ?? ''} • ${_money(payment.amount)}',
          routeHint: '/finance',
          meta: {'الطريقة': payment.method.displayName},
          keywords: [payment.displayReceiptNumber, agreement?.partyName ?? ''],
        ),
      );
    }

    // === العقود ===
    for (final contract in contracts) {
      index.add(
        SearchHit(
          id: 'contract_${contract.id}',
          scope: SearchScope.contracts,
          title: 'عقد ${contract.internalNumber}: ${contract.title}',
          subtitle: '${contract.contractType} • ${contract.statusLabel}',
          routeHint: '/contracts/${contract.id}',
          meta: {
            'نوع العقد': contract.contractType,
            'الحالة': contract.statusLabel,
            if (contract.dateEnd != null) 'تاريخ الانتهاء': _date(contract.dateEnd!),
          },
          keywords: [contract.internalNumber, contract.title, contract.contractType],
        ),
      );
    }

    const librarySeeds = [
      LegalLibraryHitSeed(
        id: 'lib_1',
        title: 'قانون أصول المحاكمات المدنية',
        type: 'قانون',
        source: 'الجريدة الرسمية',
        year: 2016,
        tags: 'أصول,محاكمات,مدني',
      ),
      LegalLibraryHitSeed(
        id: 'lib_2',
        title: 'اجتهاد نقض: عبء الإثبات في دعاوى التعويض',
        type: 'اجتهاد',
        source: 'محكمة النقض - الغرفة المدنية',
        year: 2022,
        tags: 'تعويض,إثبات,نقض',
      ),
      LegalLibraryHitSeed(
        id: 'lib_3',
        title: 'مجلة المحامون - العدد 3/2024',
        type: 'مجلة المحامون',
        source: 'نقابة المحامين',
        year: 2024,
        tags: 'مجلة,محامون',
      ),
    ];
    for (final item in librarySeeds) {
      index.add(
        SearchHit(
          id: item.id,
          scope: SearchScope.legalLibrary,
          title: item.title,
          subtitle: '${item.type} • ${item.source} • ${item.year}',
          routeHint: 'legal-library:${item.id}',
          meta: {'الوسوم': item.tags},
          keywords: [item.title, item.type, item.source, item.tags, '${item.year}'],
        ),
      );
    }

    // الجلسات والمتأخرات والملفات الناقصة تأتي من قاعدة البيانات الحقيقية
    // عبر reportDataBundleProvider، ولم تعد صفوفاً ثابتة داخل الكود.
    final sessions = reportData.sessions
        .map((s) => {
              'time': s.time,
              'caseNumber': s.caseNumber,
              'title': s.title,
              'court': s.court,
              'status': s.status,
            })
        .toList();

    final overdue = reportData.overdue
        .map((o) => {
              'type': o.type,
              'ref': o.reference,
              'title': o.title,
              'due': o.due,
              'notes': o.notes,
            })
        .toList();

    final deficient = reportData.deficient
        .map((d) => {
              'fileNumber': d.fileNumber,
              'title': d.title,
              'deficiencies': d.deficiencies,
              'baseNumber': d.baseNumber,
              'missingDocs': d.missingDocs,
            })
        .toList();

    final woRows = workOrders
        .map(
          (wo) => {
            'number': wo.internalNumber,
            'assignee': wo.assignedToName,
            'type': wo.orderTypeText,
            'status': wo.statusText,
            'due': _date(wo.dueDate),
          },
        )
        .toList();

    final memoRows = documents
        .where((d) => d.documentType == DocumentType.memo || d.documentType == DocumentType.decision)
        .map(
          (d) => {
            'title': d.title,
            'entity': d.entityTitle,
            'type': d.documentType.displayName,
            'date': _date(d.uploadDate),
            'by': d.uploadedBy,
          },
        )
        .toList();

    return SearchReportEngine(
      index: index,
      sessions: sessions,
      overdue: overdue,
      deficient: deficient,
      workOrders: woRows,
      memos: memoRows,
      officeFiles: officeFiles,
      financeState: finance,
    );
  }
}

/// مزود محرك البحث والتقارير المركّب من مصادر الواجهة الحالية.
final searchReportEngineProvider = Provider<SearchReportEngine>((ref) {
  final directory = ref.watch(personsDirectoryProvider);
  final documents = ref.watch(documentsProvider);
  final workOrders = ref.watch(woProvider);
  final finance = ref.watch(financeProvider);
  final realCases = ref.watch(uiCasesProvider).value ?? [];
  final reportData = ref.watch(reportDataBundleProvider).value ?? const ReportDataBundle();
  final officeFileRows = ref.watch(officeFilesReportProvider).value ?? const <Map<String, String>>[];
  final contracts = (ref.watch(allContractsProvider).value ?? [])
      .map((c) => ContractSearchSeed(
            id: '${c.id}',
            internalNumber: c.internalNumber,
            title: c.title,
            contractType: c.contractType,
            status: c.status,
            dateEnd: c.dateEnd,
          ))
      .toList();

  return SearchReportEngine.buildFromSources(
    realCases: realCases,
    documents: documents,
    workOrders: workOrders,
    finance: finance,
    directory: directory,
    contracts: contracts,
    reportData: reportData,
    officeFiles: officeFileRows,
  );
});

/// حالة واجهة البحث والتقارير.
class SearchReportsUiState {
  final String query;
  final SearchScope scope;
  final ReportKind? selectedReport;
  final GeneratedReport? lastReport;

  const SearchReportsUiState({
    this.query = '',
    this.scope = SearchScope.all,
    this.selectedReport,
    this.lastReport,
  });

  SearchReportsUiState copyWith({
    String? query,
    SearchScope? scope,
    ReportKind? selectedReport,
    GeneratedReport? lastReport,
    bool clearReport = false,
  }) {
    return SearchReportsUiState(
      query: query ?? this.query,
      scope: scope ?? this.scope,
      selectedReport: selectedReport ?? this.selectedReport,
      lastReport: clearReport ? null : lastReport ?? this.lastReport,
    );
  }
}

class SearchReportsNotifier extends StateNotifier<SearchReportsUiState> {
  SearchReportsNotifier() : super(const SearchReportsUiState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setScope(SearchScope scope) {
    state = state.copyWith(scope: scope);
  }

  void selectReport(ReportKind kind) {
    state = state.copyWith(selectedReport: kind);
  }

  void setGeneratedReport(GeneratedReport report) {
    state = state.copyWith(selectedReport: report.kind, lastReport: report);
  }

  void clearGeneratedReport() {
    state = state.copyWith(clearReport: true);
  }
}

final searchReportsUiProvider =
    StateNotifierProvider<SearchReportsNotifier, SearchReportsUiState>((ref) {
  return SearchReportsNotifier();
});

/// لون نطاق البحث.
Color scopeColor(SearchScope scope) {
  switch (scope) {
    case SearchScope.all:
      return AppColors.primaryNavy;
    case SearchScope.cases:
      return AppColors.primaryNavy;
    case SearchScope.contracts:
      return AppColors.info;
    case SearchScope.companies:
      return AppColors.secondaryGold;
    case SearchScope.procedures:
      return AppColors.warning;
    case SearchScope.persons:
      return AppColors.success;
    case SearchScope.agencies:
      return AppColors.info;
    case SearchScope.documents:
      return AppColors.primaryNavy;
    case SearchScope.workOrders:
      return AppColors.warning;
    case SearchScope.finance:
      return AppColors.success;
    case SearchScope.legalLibrary:
      return AppColors.secondaryGold;
  }
}
