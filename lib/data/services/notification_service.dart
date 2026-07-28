import 'package:flutter/material.dart';

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

  /// دالة مساعدة لإرسال الإشعار
  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    try {
      // تنفيذ بسيط للإشعارات - يمكن توسيعه لاحقاً
      print('إشعار: $title - $body');
    } catch (e) {
      print('خطأ في إرسال الإشعار: $e');
    }
  }

  /// إغلاق جميع الإشعارات
  Future<void> closeAllNotifications() async {
    // تنفيذ بسيط - يمكن توسيعه لاحقاً
  }
}

/// أنواع إشعارات الأجندة
enum AgendaNotificationType {
  courtSession,
  contractReminder,
  companyPhase,
  task,
}