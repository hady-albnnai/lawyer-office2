import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

/// خدمة الإشعارات الذكية للأجندة
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    // التهيئة البسيطة - يمكن توسيعها لاحقاً
  }

  /// إرسال إشعار للموعد القادم
  Future<void> sendUpcomingAppointmentNotification({
    required String title,
    required String body,
    required DateTime appointmentTime,
  }) async {
    final timeUntilAppointment = appointmentTime.difference(DateTime.now());
    
    if (timeUntilAppointment.inHours > 24) {
      // إشعار قبل يوم واحد
      await _showNotification(
        title: 'موعد غداً: $title',
        body: body,
      );
    } else if (timeUntilAppointment.inHours > 1) {
      // إشعار قبل ساعة واحدة
      await _showNotification(
        title: 'موعد قريباً: $title',
        body: 'باقي ${timeUntilAppointment.inHours} ساعة',
      );
    } else if (timeUntilAppointment.inMinutes > 0) {
      // إشعار فوري
      await _showNotification(
        title: 'موعد الآن: $title',
        body: body,
      );
    }
  }

  /// إرسال إشعار مخصص حسب نوع الموعد
  Future<void> sendCustomNotification({
    required AgendaNotificationType type,
    required Map<String, dynamic> details,
  }) async {
    String title;
    String body;

    switch (type) {
      case AgendaNotificationType.courtSession:
        title = 'جلسة محكمة: ${details['courtName'] ?? 'غير محدد'}';
        body = 'الدعوى رقم: ${details['caseNumber'] ?? 'غير محدد'}';
        break;
      case AgendaNotificationType.contractReminder:
        title = 'تذكير عقد: ${details['contractTitle'] ?? 'غير محدد'}';
        body = 'تاريخ الانتهاء: ${details['expiryDate'] ?? 'غير محدد'}';
        break;
      case AgendaNotificationType.companyPhase:
        title = 'مرحلة شركة: ${details['companyName'] ?? 'غير محدد'}';
        body = 'المرحلة الحالية: ${details['currentPhase'] ?? 'غير محدد'}';
        break;
      case AgendaNotificationType.task:
        title = 'مهمة: ${details['taskTitle'] ?? 'غير محدد'}';
        body = details['taskNotes'] ?? 'مهمة يومية';
        break;
    }

    await _showNotification(
      title: title,
      body: body,
    );
  }

  /// إرسال إشعار تغيير حالة الموعد
  Future<void> sendStatusChangeNotification({
    required String appointmentTitle,
    required String newStatus,
  }) async {
    await _showNotification(
      title: 'تغيير حالة الموعد',
      body: '$appointmentTitle: $newStatus',
    );
  }

  /// تجميع الإشعارات لنفس اليوم
  Future<void> sendDailySummaryNotification({
    required int totalAppointments,
    required int completedCount,
    required int pendingCount,
  }) async {
    await _showNotification(
      title: 'ملخص اليوم',
      body: 'مواعيد اليوم: $totalAppointments (منجز: $completedCount، متبقي: $pendingCount)',
    );
  }

  /// إرسال إشعار للملفات المرتبطة بنفس اليوم
  Future<void> sendRelatedFilesNotification({
    required String fileName,
    required int appointmentCount,
  }) async {
    await _showNotification(
      title: 'ملف: $fileName',
      body: 'يوجد $appointmentCount موعد مرتبط بهذا الملف اليوم',
    );
  }

  /// الإشعارات المعروضة حالياً (لإغلاقها لاحقاً)
  final List<LocalNotification> _active = [];

  bool get _desktopSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// دالة مساعدة لإرسال الإشعار عبر نظام التشغيل
  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    if (!_desktopSupported) {
      debugPrint('إشعار (منصة غير مدعومة): $title - $body');
      return;
    }
    try {
      final notification = LocalNotification(title: title, body: body);
      notification.onClose = (reason) => _active.remove(notification);
      _active.add(notification);
      await notification.show();
    } catch (e) {
      // لا نُسقط العملية الأساسية بسبب فشل الإشعار
      debugPrint('خطأ في إرسال الإشعار: $e');
    }
  }

  /// إغلاق جميع الإشعارات المعروضة
  Future<void> closeAllNotifications() async {
    for (final n in List<LocalNotification>.from(_active)) {
      try {
        await n.close();
      } catch (_) {
        // تجاهل: الإشعار قد يكون أُغلق من المستخدم
      }
    }
    _active.clear();
  }
}

/// أنواع إشعارات الأجندة
enum AgendaNotificationType {
  courtSession,
  contractReminder,
  companyPhase,
  task,
}