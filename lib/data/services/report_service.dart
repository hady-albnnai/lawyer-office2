import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// خدمة التقارير وتصدير البيانات
class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  pw.ThemeData? _theme;

  /// تحميل خط عربي (Amiri) لضمان ظهور النصوص العربية بشكل صحيح في PDF
  Future<pw.ThemeData> _arabicTheme() async {
    if (_theme != null) return _theme!;
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    _theme = pw.ThemeData.withFont(base: regular, bold: bold);
    return _theme!;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _fmtDate(DateTime d) => '${d.year}/${_two(d.month)}/${_two(d.day)}';
  static String _fmtStamp(DateTime d) =>
      '${d.year}/${_two(d.month)}/${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
  static String _safeName(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');

  /// تصدير تقرير المواعيد اليومية إلى PDF
  Future<String> exportDailyAgendaToPDF({
    required List<Map<String, dynamic>> appointments,
    required DateTime date,
  }) async {
    final pdf = pw.Document(theme: await _arabicTheme());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'تقرير المواعيد اليومية',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'التاريخ: ${_fmtDate(date)}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: List<List<dynamic>>.generate(
                  appointments.length,
                  (index) => [
                    appointments[index]['time'] ?? '',
                    appointments[index]['title'] ?? '',
                    appointments[index]['type'] ?? '',
                    appointments[index]['status'] ?? '',
                  ],
                ),
                headers: ['الوقت', 'العنوان', 'النوع', 'الحالة'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.center,
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return _saveAndPrintPDF(pdf, _safeName('تقرير_المواعيد_${_fmtDate(date)}.pdf'));
  }

  /// تصدير تقرير المواعيد الأسبوعية إلى PDF
  Future<String> exportWeeklyAgendaToPDF({
    required Map<DateTime, List<Map<String, dynamic>>> weeklyAppointments,
    required DateTime weekStart,
  }) async {
    final pdf = pw.Document(theme: await _arabicTheme());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'تقرير المواعيد الأسبوعية',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'الأسبوع: ${_fmtDate(weekStart)} - ${_fmtDate(weekStart.add(const Duration(days: 6)))}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 20),
              ...weeklyAppointments.entries.map((entry) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _fmtDate(entry.key),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                    ),
                    pw.SizedBox(height: 10),
                    pw.TableHelper.fromTextArray(
                      context: context,
                      data: List<List<dynamic>>.generate(
                        entry.value.length,
                        (index) => [
                          entry.value[index]['time'] ?? '',
                          entry.value[index]['title'] ?? '',
                          entry.value[index]['type'] ?? '',
                        ],
                      ),
                      headers: ['الوقت', 'العنوان', 'النوع'],
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      cellAlignment: pw.Alignment.center,
                      cellStyle: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.SizedBox(height: 20),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );

    return _saveAndPrintPDF(pdf, _safeName('تقرير_المواعيد_الأسبوعي_${_fmtDate(weekStart)}.pdf'));
  }

  /// تصدير تقرير الإحصائيات إلى PDF
  Future<String> exportStatisticsToPDF({
    required Map<String, dynamic> statistics,
  }) async {
    final pdf = pw.Document(theme: await _arabicTheme());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'تقرير الإحصائيات',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'تاريخ التقرير: ${_fmtStamp(DateTime.now())}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'ملخص اليوم',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: [
                  ['إجمالي المواعيد', '${statistics['totalAppointments'] ?? 0}'],
                  ['منجز', '${statistics['completedAppointments'] ?? 0}'],
                  ['متبقي', '${statistics['pendingAppointments'] ?? 0}'],
                  ['متأخر', '${statistics['overdueAppointments'] ?? 0}'],
                ],
                headers: ['المؤشر', 'القيمة'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.center,
                cellStyle: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'إحصائيات الجلسات',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: [
                  ['جلسات اليوم', '${statistics['courtSessionsToday'] ?? 0}'],
                  ['جلسات الأسبوع', '${statistics['courtSessionsThisWeek'] ?? 0}'],
                  ['نسبة الإنجاز', '${statistics['sessionCompletionRate'] ?? 0}%'],
                ],
                headers: ['المؤشر', 'القيمة'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.center,
                cellStyle: const pw.TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );

    return _saveAndPrintPDF(pdf, _safeName('تقرير_الإحصائيات_${_fmtStamp(DateTime.now())}.pdf'));
  }

  /// دالة مساعدة لحفظ وطباعة PDF
  Future<String> _saveAndPrintPDF(pw.Document pdf, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final dir = Directory('${directory.path}/LawOffice/reports');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    debugPrint('تم حفظ التقرير في: ${file.path}');
    return file.path;
  }

  /// تصدير البيانات إلى Excel (تنسيق CSV بسيط)
  Future<String> exportToCSV({
    required List<Map<String, dynamic>> data,
    required String fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final dir = Directory('${directory.path}/LawOffice/reports');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/${_safeName(fileName)}.csv');

    final csvData = _convertToCSV(data);
    // BOM لضمان قراءة العربية بشكل صحيح في Excel
    await file.writeAsString('\uFEFF$csvData');
    debugPrint('تم تصدير البيانات إلى: ${file.path}');
    return file.path;
  }

  /// تحويل البيانات إلى CSV
  String _convertToCSV(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return '';
    
    final headers = data.first.keys.map((h) => '"$h"').join(',');
    final rows = data.map((row) {
      return row.values.map((value) {
        final stringValue = value?.toString() ?? '';
        final needsQuote = stringValue.contains(',') ||
            stringValue.contains('"') ||
            stringValue.contains('\n');
        final escaped = stringValue.replaceAll('"', '""');
        return needsQuote ? '"$escaped"' : escaped;
      }).join(',');
    }).join('\n');
    
    return '$headers\n$rows';
  }
}