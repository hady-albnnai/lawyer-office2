/// Models لنظام الدعاوى القضائية.
///
/// هذه النماذج مستقلة عن طبقة قاعدة البيانات الحالية وتستخدمها شاشات المرحلة 5
/// لعرض وإدارة الدعوى بواجهة عربية RTL مع ثيم موحد.

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// حالة الدعوى في دورة العمل.
enum CaseStatus {
  scheduled,
  inProgress,
  completed,
  postponed,
  cancelled,
  pendingBaseNumber,
  pendingDocuments,
  pendingPayment;

  String get displayName => const [
        'مجدولة',
        'قيد التنفيذ',
        'منجزة',
        'مؤجلة',
        'ملغاة',
        'بانتظار رقم أساس',
        'بانتظار مستندات',
        'بانتظار دفع',
      ][index];

  Color get color => const [
        AppColors.info,
        AppColors.primaryNavy,
        AppColors.success,
        AppColors.warning,
        AppColors.error,
        AppColors.warning,
        AppColors.warning,
        AppColors.warning,
      ][index];
}

/// نوع الدعوى القانوني.
enum CaseType {
  civil,
  commercial,
  criminal,
  administrative,
  personalStatus,
  realEstate,
  labor,
  constitutional,
  other;

  String get displayName => const [
        'مدنية',
        'تجارية',
        'جزائية',
        'إدارية',
        'أحوال شخصية',
        'عقارية',
        'عمالية',
        'دستورية',
        'أخرى',
      ][index];
}

/// نوع المرحلة القضائية.
enum CasePhaseType {
  initial,
  hearing,
  evidence,
  judgment,
  appeal,
  cassation,
  execution,
  settlement;

  String get displayName => const [
        'بداية',
        'جلسات',
        'إثبات',
        'حكم',
        'استئناف',
        'نقض',
        'تنفيذ',
        'صلح',
      ][index];
}

/// نوع الجلسة.
enum SessionType {
  ordinary,
  urgent,
  evidence,
  judgment,
  review,
  other;

  String get displayName => const [
        'عادية',
        'مستعجلة',
        'إثبات',
        'حكم',
        'مراجعة',
        'أخرى',
      ][index];
}

/// حالة الجلسة.
enum SessionStatus {
  scheduled,
  held,
  postponed,
  cancelled;

  String get displayName => const [
        'مجدولة',
        'عقدت',
        'مؤجلة',
        'ملغاة',
      ][index];

  Color get color => const [
        AppColors.info,
        AppColors.success,
        AppColors.warning,
        AppColors.error,
      ][index];
}

/// نتيجة جلسة قضائية.
class SessionResult {
  final String decision;
  final String nextRequired;
  final String notes;
  final bool clientAttended;
  final bool opponentAttended;
  final bool opponentLawyerAttended;
  final DateTime? nextSessionDate;
  final double expenses;
  final List<String> attachments;

  const SessionResult({
    this.decision = '',
    this.clientAttended = true,
    this.opponentAttended = true,
    this.opponentLawyerAttended = true,
    this.nextSessionDate,
    this.nextRequired = '',
    this.expenses = 0,
    this.attachments = const [],
    this.notes = '',
  });
}

/// مرحلة قضائية ضمن ملف الدعوى.
class CasePhase {
  final String id;
  final String court;
  final String description;
  final CasePhaseType type;
  final String? baseNumber;
  final int? baseYear;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> documents;

  const CasePhase({
    required this.id,
    required this.type,
    required this.court,
    this.baseNumber,
    this.baseYear,
    required this.startDate,
    this.endDate,
    this.description = '',
    this.documents = const [],
  });
}

/// جلسة قضائية مرتبطة بالدعوى.
class CaseSession {
  final String id;
  final String court;
  final String decision;
  final DateTime sessionDate;
  final TimeOfDay sessionTime;
  final SessionType type;
  final SessionStatus status;
  final SessionResult? result;
  final List<String> attendees;
  final List<String> documents;

  const CaseSession({
    required this.id,
    required this.sessionDate,
    required this.sessionTime,
    required this.type,
    this.status = SessionStatus.scheduled,
    required this.court,
    this.decision = '',
    this.result,
    this.attendees = const [],
    this.documents = const [],
  });
}

/// إجراء إداري أو قضائي خارج الجلسات.
class CaseAction {
  final String id;
  final String title;
  final String description;
  final String assignedTo;
  final String status;
  final DateTime actionDate;
  final DateTime? dueDate;
  final List<String> documents;

  const CaseAction({
    required this.id,
    required this.title,
    this.description = '',
    required this.actionDate,
    this.dueDate,
    this.assignedTo = '',
    this.status = 'pending',
    this.documents = const [],
  });
}

/// نقص في ملف الدعوى.
class CaseDeficiency {
  final String id;
  final String field;
  final String description;
  final String severity;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final bool isResolved;

  const CaseDeficiency({
    required this.id,
    required this.field,
    required this.description,
    required this.createdAt,
    this.resolvedAt,
    this.isResolved = false,
    this.severity = 'medium',
  });
}

/// حدث في الخط الزمني للدعوى.
class CaseTimelineEvent {
  final String id;
  final String eventType;
  final String description;
  final DateTime eventDate;
  final String? createdBy;
  final List<String>? documents;

  const CaseTimelineEvent({
    required this.id,
    required this.eventDate,
    required this.eventType,
    required this.description,
    this.createdBy,
    this.documents,
  });
}

/// اتفاق أتعاب مرتبط بالدعوى.
class CaseFee {
  final String id;
  final String clientId;
  final String currency;
  final String status;
  final String paymentMethod;
  final String notes;
  final double amount;
  final DateTime agreementDate;
  final DateTime? paymentDate;

  const CaseFee({
    required this.id,
    required this.clientId,
    required this.amount,
    this.currency = 'ل.س',
    required this.agreementDate,
    this.paymentDate,
    this.status = 'unpaid',
    this.paymentMethod = 'cash',
    this.notes = '',
  });
}

/// مصروف قضائي أو مكتبي متعلق بالدعوى.
class CaseExpense {
  final String id;
  final String description;
  final String paidBy;
  final String category;
  final double amount;
  final String currency;
  final DateTime expenseDate;
  final List<String> receipts;

  const CaseExpense({
    required this.id,
    required this.description,
    required this.amount,
    this.currency = 'ل.س',
    required this.expenseDate,
    this.paidBy = '',
    this.category = 'other',
    this.receipts = const [],
  });
}

/// النموذج الرئيسي للدعوى.
class Case {
  final String id;
  final String caseNumber;
  final String title;
  final String court;
  final String subject;
  final String claim;
  final String notes;
  final CaseType type;
  final CaseStatus status;
  final String? baseNumber;
  final int? baseYear;
  final DateTime creationDate;
  final DateTime? lastUpdated;
  final List<String> clientIds;
  final List<String> opponentIds;
  final List<String> lawyerIds;
  final List<String> poaIds;
  final List<String> documentIds;
  final List<CasePhase> phases;
  final List<CaseSession> sessions;
  final List<CaseAction> actions;
  final List<CaseDeficiency> deficiencies;
  final List<CaseTimelineEvent> timeline;
  final List<CaseFee> fees;
  final List<CaseExpense> expenses;

  const Case({
    required this.id,
    required this.caseNumber,
    required this.title,
    required this.type,
    this.status = CaseStatus.scheduled,
    required this.court,
    this.baseNumber,
    this.baseYear,
    this.subject = '',
    this.claim = '',
    required this.creationDate,
    this.lastUpdated,
    this.clientIds = const [],
    this.opponentIds = const [],
    this.lawyerIds = const [],
    this.poaIds = const [],
    this.phases = const [],
    this.sessions = const [],
    this.actions = const [],
    this.deficiencies = const [],
    this.timeline = const [],
    this.fees = const [],
    this.expenses = const [],
    this.documentIds = const [],
    this.notes = '',
  });

  CaseSession? get nextSession {
    final upcoming = sessions
        .where((session) => session.sessionDate.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return upcoming.firstOrNull;
  }

  int get openDeficienciesCount =>
      deficiencies.where((deficiency) => !deficiency.isResolved).length;

  double get totalFees => fees.fold(0, (sum, fee) => sum + fee.amount);

  double get totalExpenses =>
      expenses.fold(0, (sum, expense) => sum + expense.amount);

  double get balance => totalFees - totalExpenses;
}

extension NullableListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
