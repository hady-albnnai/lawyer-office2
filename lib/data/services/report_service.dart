import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:printing/printing.dart' as printing;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// خدمة التقارير وتصدير البيانات
class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  /// تصدير تقرير المواعيد اليومية إلى PDF
  Future<void> exportDailyAgendaToPDF({
    required List<Map<String, dynamic>> appointments,
    required DateTime date,
  }) async {
    final pdf = pw.Document();
    final arabicFormat = DateFormat('yyyy/MM/dd', 'ar');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
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
                'التاريخ: ${arabicFormat.format(date)}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
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

    await _saveAndPrintPDF(pdf, 'تقرير_المواعيد_${arabicFormat.format(date)}.pdf');
  }

  /// تصدير تقرير المواعيد الأسبوعية إلى PDF
  Future<void> exportWeeklyAgendaToPDF({
    required Map<DateTime, List<Map<String, dynamic>>> weeklyAppointments,
    required DateTime weekStart,
  }) async {
    final pdf = pw.Document();
    final arabicFormat = DateFormat('yyyy/MM/dd', 'ar');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
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
                'الأسبوع: ${arabicFormat.format(weekStart)} - ${arabicFormat.format(weekStart.add(const Duration(days: 6)))}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 20),
              ...weeklyAppointments.entries.map((entry) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      arabicFormat.format(entry.key),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Table.fromTextArray(
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
              }).toList(),
            ],
          );
        },
      ),
    );

    await _saveAndPrintPDF(pdf, 'تقرير_المواعيد_الأسبوعي_${arabicFormat.format(weekStart)}.pdf');
  }

  /// تصدير تقرير الإحصائيات إلى PDF
  Future<void> exportStatisticsToPDF({
    required Map<String, dynamic> statistics,
  }) async {
    final pdf = pw.Document();
    final arabicFormat = DateFormat('yyyy/MM/dd HH:mm', 'ar');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
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
                'تاريخ التقرير: ${arabicFormat.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'ملخص اليوم',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
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
              pw.Table.fromTextArray(
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

    await _saveAndPrintPDF(pdf, 'تقرير_الإحصائيات_${arabicFormat.format(DateTime.now())}.pdf');
  }

  /// دالة مساعدة لحفظ وطباعة PDF
  Future<void> _saveAndPrintPDF(pw.Document pdf, String fileName) async {
    try {
      // حفظ PDF محلياً
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      
      print('تم حفظ التقرير في: ${file.path}');
    } catch (e) {
      print('خطأ في تصدير PDF: $e');
    }
  }

  /// تصدير البيانات إلى Excel (تنسيق CSV بسيط)
  Future<void> exportToCSV({
    required List<Map<String, dynamic>> data,
    required String fileName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName.csv');
      
      final csvData = _convertToCSV(data);
      await file.writeAsString(csvData);
      
      print('تم تصدير البيانات إلى: ${file.path}');
    } catch (e) {
      print('خطأ في تصدير CSV: $e');
    }
  }

  /// تحويل البيانات إلى CSV
  String _convertToCSV(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return '';
    
    final headers = data.first.keys.join(',');
    final rows = data.map((row) {
      return row.values.map((value) {
        final stringValue = value?.toString() ?? '';
        return stringValue.contains(',') ? '"$stringValue"' : stringValue;
      }).join(',');
    }).join('\n');
    
    return '$headers\n$rows';
  }
}