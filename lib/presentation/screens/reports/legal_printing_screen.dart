import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/office_settings_provider.dart';

/// شاشة الطباعة القانونية الرسمية وتصدير تقارير PDF بالترويسة السورية (LegalPrintingScreen V6.2)
class LegalPrintingScreen extends ConsumerStatefulWidget {
  const LegalPrintingScreen({super.key});

  @override
  ConsumerState<LegalPrintingScreen> createState() => _LegalPrintingScreenState();
}

class _LegalPrintingScreenState extends ConsumerState<LegalPrintingScreen> {
  String _selectedReportType = 'summary_report'; // summary_report, agenda_report, financial_report

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(officeSettingsProvider);
    final canPrint = ref.watch(permissionServiceProvider).can(PermissionKeys.reportsExport);

    return Scaffold(
      appBar: AppBar(title: const Text('الطباعة والتصدير')),
      body: Row(
        children: [
          // شريط اختيار نوع التقرير
          Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            color: AppConstants.surfaceWhite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختيار الكشف أو التقرير للطباعة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const Divider(height: 24),
                _reportOption('summary_report', 'تقرير كشف الدعاوى القضائية', Icons.gavel, 'قائمة بالملفات، أرقام الأساس، والمحاكم المختصة.'),
                _reportOption('agenda_report', 'تقرير أجندة وجلسات المكتب', Icons.calendar_month, 'جدول مواعيد الجلسات والمراجعات القادمة.'),
                _reportOption('financial_report', 'التقرير المالي لأتعاب الموكلين', Icons.account_balance_wallet, 'كشف بالاتفاقيات المالية والدفعات والمتبقي.'),
                const Spacer(),
                const Text('ملاحظة: المطبوعات تصدر مزودة بالترويسة السورية الرسمية للمكتب وبخط Cairo المعتمد.', style: TextStyle(fontSize: 12, color: AppConstants.textMuted)),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // معاينة التقرير والطباعة
          Expanded(
            child: settingsAsync.when(
              data: (settings) => PdfPreview(
                build: (format) => _generatePdfReport(format, settings),
                allowPrinting: canPrint,
                allowSharing: canPrint,
                canChangeOrientation: false,
                canChangePageFormat: false,
                pdfFileName: 'SyrLawOffice_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('خطأ في تحميل إعدادات الترويسة: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportOption(String key, String title, IconData icon, String subtitle) {
    final isSel = _selectedReportType == key;
    return Card(
      color: isSel ? AppConstants.primaryNavy.withOpacity(0.08) : Colors.transparent,
      elevation: isSel ? 2 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSel ? AppConstants.primaryNavy : Colors.transparent, width: 1.5)),
      child: ListTile(
        leading: Icon(icon, color: isSel ? AppConstants.primaryNavy : AppConstants.textMuted),
        title: Text(title, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? AppConstants.primaryNavy : AppConstants.textDark)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        onTap: () => setState(() => _selectedReportType = key),
      ),
    );
  }

  /// توليد مستند الـ PDF القانوني السوري الرسمي
  Future<Uint8List> _generatePdfReport(PdfPageFormat format, OfficeSettingsModel settings) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.reportsView)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'reports', entityType: 'legal_printing', description: 'محاولة توليد تقرير طباعة دون صلاحية', severity: 'warning');
      final denied = pw.Document();
      denied.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('لا تملك صلاحية عرض التقارير'))));
      return denied.save();
    }
    await ref.read(auditServiceProvider).log(action: 'preview', category: 'reports', entityType: 'legal_printing', entityTitle: _getReportTitle(), description: 'معاينة تقرير الطباعة القانونية', severity: 'info');
    final pdf = pw.Document();

    // جلب الخطوط العربية الرسمية المعتمدة
    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    // جلب البيانات من المزودات حسب نوع التقرير
    List<dynamic> items = [];
    if (_selectedReportType == 'summary_report') {
      items = await ref.read(caseRepositoryProvider).watchAllCases().first;
    } else if (_selectedReportType == 'agenda_report') {
      items = await ref.read(taskRepositoryProvider).watchTasksByDate(DateTime.now()).first;
    } else if (_selectedReportType == 'financial_report') {
      items = await ref.read(companyRepositoryProvider).watchAllCompanies().first; // نموذج مالي
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        header: (context) => _buildPdfHeader(settings, fontBold),
        footer: (context) => _buildPdfFooter(context, settings, fontRegular),
        build: (context) => [
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              _getReportTitle(),
              style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.black),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              'تاريخ الإصدار: ${DateTime.now().toString().substring(0, 10)} - عدد السجلات: ${items.length}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          ),
          pw.Divider(thickness: 1.5, color: PdfColors.grey400),
          pw.SizedBox(height: 12),
          _buildTableContent(items, fontRegular, fontBold),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfHeader(OfficeSettingsModel settings, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(settings.officeTitle, style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900)),
              pw.SizedBox(height: 2),
              pw.Text('الأستاذ: ${settings.lawyerName}', style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.amber800)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(AppConstants.defaultCountry, style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black)),
              pw.SizedBox(height: 2),
              pw.Text(settings.officeAddress, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context, OfficeSettingsModel settings, pw.Font fontRegular) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.8))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('صدر عن نظام إدارة وأرشفة مكتب المحاماة (V6.2 Offline-First)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
        ],
      ),
    );
  }

  String _getReportTitle() {
    switch (_selectedReportType) {
      case 'summary_report': return 'جدول كشف أرشيف الدعاوى القضائية';
      case 'agenda_report': return 'جدول أعمال وجلسات المكتب اليومية';
      default: return 'الكشف المالي لأتعاب المكتب والشركات';
    }
  }

  pw.Widget _buildTableContent(List<dynamic> items, pw.Font fontRegular, pw.Font fontBold) {
    if (items.isEmpty) {
      return pw.Center(child: pw.Text('لا توجد سجلات لعرضها في هذا التقرير', style: pw.TextStyle(font: fontRegular)));
    }

    if (_selectedReportType == 'summary_report') {
      return pw.Table.fromTextArray(
        headers: ['رقم الملف', 'النوع والتصنيف', 'رقم الأساس', 'تاريخ الجلسة القادمة', 'الحالة'],
        data: items.map((c) => [
          c.internalNumber,
          '${c.caseType} (${c.subType ?? ""})',
          c.baseNumber ?? 'بانتظار التسجيل',
          c.nextSessionDate?.toString().substring(0, 10) ?? 'غير محددة',
          c.status == 'closed' ? 'منتهية ✖' : 'عاملة ✓',
        ]).toList(),
        headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 11),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
        cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
        cellAlignment: pw.Alignment.centerRight,
      );
    } else if (_selectedReportType == 'agenda_report') {
      return pw.Table.fromTextArray(
        headers: ['العنوان والإجراء', 'النوع', 'الوقت', 'الأولوية', 'الحالة'],
        data: items.map((t) => [
          t.title,
          t.taskType,
          t.taskTime ?? 'طوال اليوم',
          t.priority == 3 ? 'عاجلة جداً' : 'عادية',
          t.status == 2 ? 'منجزة ✓' : 'مجدولة ⏳',
        ]).toList(),
        headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 11),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
        cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
        cellAlignment: pw.Alignment.centerRight,
      );
    }

    return pw.Center(child: pw.Text('جدول التقرير المالي', style: pw.TextStyle(font: fontRegular)));
  }
}
