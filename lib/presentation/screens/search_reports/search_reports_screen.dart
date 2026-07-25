/// شاشة البحث والتقارير - المرحلة 8.
///
/// تجمع البحث الشامل عبر كل كيانات المكتب مع توليد تقارير PDF offline
/// (جلسات، متأخرات، نواقص، مالية، أوامر عمل، مذكرات).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../providers/office_settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../documents/document_viewer.dart';
import '../persons/person_detail_screen.dart';
import '../poa/poa_detail_screen.dart';
import 'search_report_models.dart';

class SearchReportsScreen extends ConsumerStatefulWidget {
  const SearchReportsScreen({super.key});

  @override
  ConsumerState<SearchReportsScreen> createState() => _SearchReportsScreenState();
}

class _SearchReportsScreenState extends ConsumerState<SearchReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(searchReportEngineProvider);
    final ui = ref.watch(searchReportsUiProvider);

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('التقارير والكشوف'),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.secondaryGold,
              labelColor: AppColors.secondaryGold,
              unselectedLabelColor: AppColors.textOnLight.withOpacity(0.75),
              labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'البحث الشامل'),
                Tab(text: 'الكشوف والتقارير'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _searchTab(engine, ui),
              _reportsTab(engine, ui),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchTab(SearchReportEngine engine, SearchReportsUiState ui) {
    final hits = engine.search(ui.query, scope: ui.scope);
    final counts = engine.countByScope(ui.query);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'بحث برقم الملف، الأساس، الموكل، الوكالة، المستند، أمر العمل، المالية...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ui.query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchReportsUiProvider.notifier).setQuery('');
                          },
                        )
                      : null,
                ),
                onChanged: (value) =>
                    ref.read(searchReportsUiProvider.notifier).setQuery(value.trim()),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: SearchScope.values.map((scope) {
                    final selected = ui.scope == scope;
                    final count = scope == SearchScope.all
                        ? hits.length
                        : (counts[scope] ?? 0);
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        avatar: Icon(scope.icon, size: 16, color: selected ? AppColors.textOnLight : scopeColor(scope)),
                        label: Text(
                          ui.query.isEmpty ? scope.displayName : '${scope.displayName} ($count)',
                        ),
                        selected: selected,
                        onSelected: (_) =>
                            ref.read(searchReportsUiProvider.notifier).setScope(scope),
                        selectedColor: AppColors.primaryNavy,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.textOnLight : AppColors.primaryNavy,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        checkmarkColor: AppColors.textOnLight,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ui.query.isEmpty
              ? _emptySearchHint()
              : hits.isEmpty
                  ? _emptyState(Icons.search_off, 'لا نتائج', 'جرّب كلمة أخرى أو غيّر نطاق البحث.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: hits.length,
                      itemBuilder: (context, index) => _hitCard(hits[index]),
                    ),
        ),
      ],
    );
  }

  Widget _reportsTab(SearchReportEngine engine, SearchReportsUiState ui) {
    final selected = ui.selectedReport ?? ReportKind.sessions;
    final report = ui.lastReport ?? engine.generate(selected);

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(left: BorderSide(color: AppColors.cardBorder, width: 0.5)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('اختر الكشف أو التقرير', style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
                const SizedBox(height: 8),
                ...ReportKind.values.map((kind) {
                  final isSel = selected == kind;
                  return Card(
                    color: isSel ? AppColors.primaryNavy.withOpacity(0.06) : null,
                    child: ListTile(
                      leading: Icon(kind.icon, color: isSel ? AppColors.primaryNavy : AppColors.textSecondary),
                      title: Text(kind.displayName, style: AppTextStyles.labelLarge),
                      subtitle: Text(kind.description, style: AppTextStyles.bodySmallSecondary),
                      selected: isSel,
                      onTap: () {
                        final generated = engine.generate(kind);
                        ref.read(searchReportsUiProvider.notifier).setGeneratedReport(generated);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.title,
                        style: AppTextStyles.headline5.copyWith(color: AppColors.primaryNavy),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.preview),
                      label: const Text('معاينة PDF'),
                      onPressed: ref.watch(permissionServiceProvider).can(PermissionKeys.reportsView) ? () => _previewReportPdf(report) : null,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('تصدير PDF'),
                      onPressed: ref.watch(permissionServiceProvider).can(PermissionKeys.reportsExport) ? () => _exportReportPdf(report) : null,
                    ),
                  ],
                ),
              ),
              if (report.summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: report.summary.entries
                        .map(
                          (e) => Chip(
                            label: Text('${e.key}: ${e.value}'),
                            backgroundColor: AppColors.cardBackground,
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: report.rows.isEmpty
                    ? _emptyState(Icons.table_chart, 'لا صفوف', 'لا توجد بيانات لهذا التقرير حالياً.')
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              AppColors.primaryNavy.withOpacity(0.08),
                            ),
                            columns: report.headers
                                .map(
                                  (h) => DataColumn(
                                    label: Text(h, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                                  ),
                                )
                                .toList(),
                            rows: report.rows
                                .map(
                                  (row) => DataRow(
                                    cells: row.cells
                                        .map((cell) => DataCell(Text(cell, style: AppTextStyles.bodySmall)))
                                        .toList(),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hitCard(SearchHit hit) {
    final color = scopeColor(hit.scope);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(hit.scope.icon, color: color),
        ),
        title: Text(hit.title, style: AppTextStyles.labelLarge),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hit.subtitle, style: AppTextStyles.bodySmallSecondary),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                _miniBadge(hit.scope.displayName, color),
                ...hit.meta.entries.take(3).map((e) => _miniBadge('${e.key}: ${e.value}', AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openHit(hit),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 10)),
    );
  }

  void _openHit(SearchHit hit) {
    final hint = hit.routeHint;
    if (hint.startsWith('/cases/')) {
      final id = int.tryParse(hint.split('/').last) ?? 0;
      GoRouter.of(context).push('/cases/$id');
      return;
    }
    if (hint.startsWith('/persons/')) {
      final id = hint.split('/').last;
      GoRouter.of(context).push('/persons/$id');
      return;
    }
    if (hint.startsWith('/poa/')) {
      final id = hint.split('/').last;
      GoRouter.of(context).push('/poa/$id');
      return;
    }
    if (hint.startsWith('/finance')) {
      context.go('/finance');
      return;
    }
    if (hint.startsWith('document:')) {
      openDocument(context, hint.substring('document:'.length));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('نتيجة: ${hit.title} — ${hit.scope.displayName}'),
        backgroundColor: AppColors.primaryNavy,
      ),
    );
  }

  Widget _emptySearchHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search, size: 80, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text('البحث الشامل في أرشيف المكتب', style: AppTextStyles.headline5),
          const SizedBox(height: 8),
          Text(
            'يشمل: الدعاوى، العقود، الشركات، الإجراءات، الأشخاص، الوكالات،\nالمستندات، أوامر العمل، المالية، ونواة المكتبة القانونية.',
            style: AppTextStyles.bodySmallSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.headline5),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyles.bodySmallSecondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<OfficeSettingsModel> _settings() async {
    return ref.read(officeSettingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const OfficeSettingsModel(
            officeTitle: AppConstants.defaultOfficeTitle,
            lawyerName: AppConstants.defaultLawyerName,
            officeAddress: AppConstants.defaultAddress,
            officePhone: AppConstants.defaultPhone,
          ),
        );
  }

  Future<void> _exportReportPdf(GeneratedReport report) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.reportsExport)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'reports', entityType: 'report', entityTitle: report.title, description: 'محاولة تصدير تقرير دون صلاحية', severity: 'warning');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا تملك صلاحية تصدير التقارير'), backgroundColor: AppColors.error));
      return;
    }
    final settings = await _settings();
    final bytes = await SearchReportsPdfBuilder.build(settings: settings, report: report);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'report_${report.kind.toString().split('.').last}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await ref.read(auditServiceProvider).log(action: 'export', category: 'reports', entityType: 'report', entityTitle: report.title, description: 'تصدير تقرير PDF', severity: 'warning');
  }

  Future<void> _previewReportPdf(GeneratedReport report) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.reportsView)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'reports', entityType: 'report', entityTitle: report.title, description: 'محاولة معاينة تقرير دون صلاحية', severity: 'warning');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا تملك صلاحية عرض التقارير'), backgroundColor: AppColors.error));
      return;
    }
    final settings = await _settings();
    final bytes = await SearchReportsPdfBuilder.build(settings: settings, report: report);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: Text('معاينة: ${report.title}')),
            body: PdfPreview(
              build: (_) async => bytes,
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName: '${report.kind.toString().split('.').last}.pdf',
            ),
          ),
        ),
      ),
    );
  }
}

/// مولّد PDF للتقارير.
class SearchReportsPdfBuilder {
  static Future<Uint8List> build({
    required OfficeSettingsModel settings,
    required GeneratedReport report,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(settings.officeTitle,
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900)),
                  pw.Text('الأستاذ: ${settings.lawyerName}',
                      style: pw.TextStyle(font: fontBold, fontSize: 11)),
                ],
              ),
              pw.Text(AppConstants.defaultCountry, style: pw.TextStyle(font: fontBold, fontSize: 11)),
            ],
          ),
        ),
        footer: (context) => pw.Text(
          'صفحة ${context.pageNumber}/${context.pagesCount} — تقارير مكتب المحامي V6.2 Offline',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Text(report.title, style: pw.TextStyle(font: fontBold, fontSize: 16)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'تاريخ الإصدار: ${report.generatedAt.toString().substring(0, 10)} • صفوف: ${report.rowCount}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 10),
          if (report.summary.isNotEmpty) ...[
            pw.Wrap(
              spacing: 12,
              runSpacing: 6,
              children: report.summary.entries
                  .map(
                    (e) => pw.Text('${e.key}: ${e.value}',
                        style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 10),
          ],
          if (report.rows.isEmpty)
            pw.Center(child: pw.Text('لا توجد بيانات', style: pw.TextStyle(font: fontRegular)))
          else
            pw.Table.fromTextArray(
              headers: report.headers,
              data: report.rows.map((r) => r.cells).toList(),
              headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
              cellAlignment: pw.Alignment.centerRight,
            ),
        ],
      ),
    );

    return pdf.save();
  }
}
