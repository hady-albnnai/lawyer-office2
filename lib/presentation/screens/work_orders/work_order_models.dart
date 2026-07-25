/// Models لأوامر العمل
/// حسب مواصفات PRODUCT_REDESIGN_MASTER_PLAN.md - الأقسام 9.2، 9.4، 9.8

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// نوع أمر العمل المطلوب من المعقب أو فريق المكتب.
enum WorkOrderType {
  courtAttendance,
  documentPhotocopy,
  feePayment,
  extractCopy,
  organizeAgency,
  notaryReview,
  notificationFollowup,
  executionFollowup,
  commercialRegistry,
  financialReview,
  other;

  String get displayName => const [
        'حضور جلسة',
        'تصوير ضبط',
        'دفع رسم',
        'استخراج صورة',
        'تنظيم وكالة',
        'مراجعة كاتب عدل',
        'متابعة تبليغ',
        'متابعة تنفيذ',
        'مراجعة سجل تجاري',
        'مراجعة مالية',
        'أخرى',
      ][index];
}

/// أولوية أمر العمل.
enum WorkOrderPriority {
  high,
  medium,
  low;

  String get displayName => const ['عالية', 'متوسطة', 'منخفضة'][index];
}

/// حالة دورة حياة أمر العمل.
enum WorkOrderStatus {
  draft,
  printed,
  whatsappSent,
  waitingForResult,
  resultEntered,
  waitingForApproval,
  approved,
  returnedForCorrection,
  postponed,
  impossible,
  cancelled;

  String get displayName {
    switch (this) {
      case WorkOrderStatus.draft:
      case WorkOrderStatus.printed:
      case WorkOrderStatus.whatsappSent:
      case WorkOrderStatus.waitingForResult:
        return 'مفتوح';
      case WorkOrderStatus.resultEntered:
      case WorkOrderStatus.waitingForApproval:
        return 'نتيجة مدخلة';
      case WorkOrderStatus.approved:
        return 'معتمد';
      case WorkOrderStatus.returnedForCorrection:
        return 'يحتاج تصحيح';
      case WorkOrderStatus.postponed:
        return 'مؤجل';
      case WorkOrderStatus.impossible:
      case WorkOrderStatus.cancelled:
        return 'ملغى';
    }
  }

  Color get color {
    switch (this) {
      case WorkOrderStatus.draft:
      case WorkOrderStatus.printed:
      case WorkOrderStatus.whatsappSent:
      case WorkOrderStatus.waitingForResult:
        return AppColors.info;
      case WorkOrderStatus.resultEntered:
      case WorkOrderStatus.waitingForApproval:
        return AppColors.secondaryGold;
      case WorkOrderStatus.approved:
        return AppColors.success;
      case WorkOrderStatus.returnedForCorrection:
        return AppColors.error;
      case WorkOrderStatus.postponed:
        return AppColors.warning;
      case WorkOrderStatus.impossible:
      case WorkOrderStatus.cancelled:
        return AppColors.error;
    }
  }
}

/// نتيجة تنفيذ أمر العمل.
enum WorkOrderResultStatus {
  completed,
  partially,
  impossible,
  postponed,
  needsReview;

  String get displayName => const [
        'تم',
        'تم جزئياً',
        'تعذر',
        'مؤجل',
        'يحتاج مراجعة',
      ][index];
}

class WorkOrderChecklistItem {
  final String title;
  final bool isCompleted;

  const WorkOrderChecklistItem({
    required this.title,
    this.isCompleted = false,
  });
}

class WorkOrder {
  final String id;
  final String internalNumber;
  final String linkedEntityType;
  final String linkedEntityId;
  final String assignedToName;
  final String assignedToPhone;
  final String instructions;
  final String createdBy;
  final WorkOrderType orderType;
  final WorkOrderPriority priority;
  final WorkOrderStatus status;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime? printedAt;
  final DateTime? whatsappSentAt;
  final DateTime? resultDate;
  final DateTime? nextDate;
  final DateTime? approvedAt;
  final WorkOrderResultStatus? resultStatus;
  final String? resultText;
  final List<WorkOrderChecklistItem> checklist;
  final double? expenses;

  const WorkOrder({
    required this.id,
    required this.internalNumber,
    required this.linkedEntityType,
    required this.linkedEntityId,
    required this.assignedToName,
    required this.assignedToPhone,
    required this.orderType,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.instructions,
    required this.createdAt,
    required this.createdBy,
    this.printedAt,
    this.whatsappSentAt,
    this.resultStatus,
    this.resultText,
    this.resultDate,
    this.nextDate,
    this.approvedAt,
    this.checklist = const [],
    this.expenses,
  });

  Color get statusColor => status.color;
  String get statusText => status.displayName;
  String get orderTypeText => orderType.displayName;
  String get priorityText => priority.displayName;
}
