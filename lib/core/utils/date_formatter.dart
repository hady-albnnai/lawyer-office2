import 'package:intl/intl.dart';

/// أدوات مساعدة لتنسيق وعرض التواريخ والأوقات في واجهات ومطبوعات المكتب
class DateFormatter {
  /// تنسيق التاريخ بالصيغة السورية المعتمدة: 2026/07/07
  static String formatShortDate(DateTime? date, {String fallback = 'غير محدد'}) {
    if (date == null) return fallback;
    return DateFormat('yyyy/MM/dd', 'ar').format(date);
  }

  /// تنسيق التاريخ والوقت معاً (مثال: 2026/07/07 - 10:30 ص)
  static String formatDateTime(DateTime? dateTime, {String fallback = 'غير محدد'}) {
    if (dateTime == null) return fallback;
    return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(dateTime);
  }

  /// حساب عدد الأيام المتبقية حتى تاريخ معين (لمتابعة انتهاء العقود والمواعيد)
  static int getDaysUntil(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  /// نص وصفي للمدة المتبقية أو المنقضية
  static String getRelativeDateLabel(DateTime? date) {
    if (date == null) return 'بانتظار تحديد موعد';
    final days = getDaysUntil(date);
    if (days == 0) return 'اليوم';
    if (days == 1) return 'غداً';
    if (days == -1) return 'أمس';
    if (days > 1) return 'بعد $days أيام';
    return 'منذ ${days.abs()} أيام';
  }
}
