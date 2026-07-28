/// شاشة تفاصيل الدعوى - المرحلة 5.
///
/// تنفذ ملف الدعوى الكامل بتسعة تبويبات: الملخص، الأطراف، المراحل، الجلسات،
/// المستندات، المالية، النواقص، الخط الزمني، والإنهاء. تعتمد الشاشة على
/// Riverpod لإدارة حالة الدعوى وتستخدم AppTheme/AppColors/AppTextStyles فقط.
library;

import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart' as db;
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/ui_data_providers.dart' show uiDocumentsProvider, financeByEntityProvider, uiCasesProvider, uiFilesProvider;
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../documents/document_models.dart';
import '../documents/document_viewer.dart';
import 'case_models.dart';
import 'cases_screen.dart' show casesProvider;

/// نتيجة إغلاق الدعوى.
enum CaseClosureResult {
  win,
  loss,
  settlement,
  cancellation;

  String get displayName => const [
        'فوز لصالح الموكل',
        'خسارة الدعوى',
        'تصالح / تسوية',
        'إلغاء / شطب',
      ][index];

  String get timelineCode => const [
        'termination_win',
        'termination_loss',
        'termination_settlement',
        'termination_cancellation',
      ][index];

  Color get color => const [
        AppColors.success,
        AppColors.error,
        AppColors.info,
        AppColors.warning,
      ][index];
}

/// فلتر الخط الزمني.
enum TimelineFilter {
  all,
  phases,
  sessions,
  documents,
  finance,
  deficiencies,
  termination;

  String get displayName => const [
        'جميع الأحداث',
        'المراحل القضائية',
        'الجلسات والإجراءات',
        'المستندات',
        'المالية',
        'النواقص',
        'الإنهاء',
      ][index];

  bool accepts(String eventType) {
    switch (this) {
      case TimelineFilter.all:
        return true;
      case TimelineFilter.phases:
        return eventType.contains('phase');
      case TimelineFilter.sessions:
        return eventType.contains('session') || eventType.contains('action');
      case TimelineFilter.documents:
        return eventType.contains('document');
      case TimelineFilter.finance:
        return eventType.contains('fee') || eventType.contains('expense') || eventType.contains('finance');
      case TimelineFilter.deficiencies:
        return eventType.contains('deficiency');
      case TimelineFilter.termination:
        return eventType.contains('termination');
    }
  }
}

/// طرف في الدعوى لعرض الموكلين والخصوم.
class CasePartyView {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String address;
  final bool isPrimary;

  const CasePartyView({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.address,
    this.isPrimary = false,
  });
}

/// وكالة مرتبطة بالدعوى.
class CaseAgencyView {
  final String id;
  final String number;
  final String type;
  final String principal;
  final String agent;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final bool isActive;

  const CaseAgencyView({
    required this.id,
    required this.number,
    required this.type,
    required this.principal,
    required this.agent,
    required this.issuedAt,
    this.expiresAt,
    this.isActive = true,
  });
}

/// حالة شاشة تفاصيل الدعوى.
class CaseDetailState {
  final Case? caseItem;
  final List<CasePartyView> clients;
  final List<CasePartyView> opponents;
  final List<CaseAgencyView> agencies;
  final List<CasePhase> phases;
  final List<CaseSession> sessions;
  final List<CaseAction> actions;
  final List<DocumentItem> documents;
  final List<CaseDeficiency> deficiencies;
  final List<CaseTimelineEvent> timeline;
  final TimelineFilter timelineFilter;
  final bool isTerminated;
  final CaseClosureResult? closureResult;
  final String closureSummary;
  final DateTime? closedAt;

  const CaseDetailState({
    required this.caseItem,
    this.clients = const [],
    this.opponents = const [],
    this.agencies = const [],
    this.phases = const [],
    this.sessions = const [],
    this.actions = const [],
    this.documents = const [],
    this.deficiencies = const [],
    this.timeline = const [],
    this.timelineFilter = TimelineFilter.all,
    this.isTerminated = false,
    this.closureResult,
    this.closureSummary = '',
    this.closedAt,
  });

  int get openDeficienciesCount =>
      deficiencies.where((item) => !item.isResolved).length;

  double get totalFees => caseItem?.totalFees ?? 0;

  double get totalExpenses => caseItem?.totalExpenses ?? 0;

  double get balance => totalFees - totalExpenses;

  List<CaseTimelineEvent> get filteredTimeline {
    final filtered = timeline
        .where((event) => timelineFilter.accepts(event.eventType))
        .toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return filtered;
  }

  CaseSession? get nextSession {
    final upcoming = sessions
        .where((session) => session.sessionDate.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return upcoming.firstOrNull;
  }

  CaseDetailState copyWith({
    Case? caseItem,
    List<CasePartyView>? clients,
    List<CasePartyView>? opponents,
    List<CaseAgencyView>? agencies,
    List<CasePhase>? phases,
    List<CaseSession>? sessions,
    List<CaseAction>? actions,
    List<DocumentItem>? documents,
    List<CaseDeficiency>? deficiencies,
    List<CaseTimelineEvent>? timeline,
    TimelineFilter? timelineFilter,
    bool? isTerminated,
    CaseClosureResult? closureResult,
    String? closureSummary,
    DateTime? closedAt,
  }) {
    return CaseDetailState(
      caseItem: caseItem ?? this.caseItem,
      clients: clients ?? this.clients,
      opponents: opponents ?? this.opponents,
      agencies: agencies ?? this.agencies,
      phases: phases ?? this.phases,
      sessions: sessions ?? this.sessions,
      actions: actions ?? this.actions,
      documents: documents ?? this.documents,
      deficiencies: deficiencies ?? this.deficiencies,
      timeline: timeline ?? this.timeline,
      timelineFilter: timelineFilter ?? this.timelineFilter,
      isTerminated: isTerminated ?? this.isTerminated,
      closureResult: closureResult ?? this.closureResult,
      closureSummary: closureSummary ?? this.closureSummary,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}

/// مزود تفاصيل الدعوى بحسب رقم المسار /cases/:caseId (من المستودع الحقيقي - 100%).
final caseDetailProvider =
    StateNotifierProvider.autoDispose.family<CaseDetailNotifier, CaseDetailState, int>(
  (ref, caseId) {
    final caseFuture = ref.watch(caseDetailFromRepoProvider(caseId));
    final partiesAsync = ref.watch(casePartiesProvider(caseId));
    final sessionsAsync = ref.watch(caseSessionsProvider(caseId));
    final phasesAsync = ref.watch(casePhasesProvider(caseId));
    final deficienciesAsync = ref.watch(caseOpenDeficienciesProvider(caseId));

    // أسماء الأطراف تُقرأ من دليل الأشخاص، وإلا ظهر معرّف الشخص رقماً مكانه.
    final personsAsync = ref.watch(allPersonsProvider(null));

    final dynamic caseItem = caseFuture.value;
    final dynamic parties = partiesAsync.value ?? [];
    final dynamic sessions = sessionsAsync.value ?? [];
    final dynamic phases = phasesAsync.value ?? [];
    final dynamic deficiencies = deficienciesAsync.value ?? [];
    final persons = personsAsync.value ?? const <db.PersonEntity>[];

    return CaseDetailNotifier.fromRepository(
      caseItem,
      parties: parties,
      sessions: sessions,
      phases: phases,
      deficiencies: deficiencies,
      persons: persons,
    );
  },
);

/// Notifier لإدارة كل عمليات الشاشة محلياً لحين الربط النهائي بمستودع Drift.
class CaseDetailNotifier extends StateNotifier<CaseDetailState> {
  CaseDetailNotifier(Case? caseItem, List<DocumentItem> allDocuments)
      : super(_initialState(caseItem, allDocuments));

  CaseDetailNotifier._(super.state);

  /// إنشاء الحالة من بيانات المستودع الحقيقي (Drift)
  factory CaseDetailNotifier.fromRepository(
    dynamic caseItemDynamic, {
    List<dynamic> parties = const [],
    List<dynamic> sessions = const [],
    List<dynamic> phases = const [],
    List<dynamic> deficiencies = const [],
    List<dynamic> persons = const [],
  }) {
    final db.Case? caseItem = caseItemDynamic as db.Case?;
    if (caseItem == null) {
      return CaseDetailNotifier(null, []);
    }

    final dbParties = parties.cast<db.CaseParty>();
    final dbSessions = sessions.cast<db.CaseSession>();
    final dbPhases = phases.cast<db.CasePhase>();
    final dbDeficiencies = deficiencies.cast<db.Deficiency>();
    final personById = {for (final p in persons.cast<db.PersonEntity>()) p.id: p};

    final uiCase = _convertDbCase(caseItem, dbPhases, dbSessions, dbDeficiencies);

    final clients = dbParties
        .where((p) => p.isClient)
        .map((p) => CasePartyView(
              id: p.id.toString(),
              name: personById[p.personId]?.fullName ?? 'شخص #${p.personId}',
              role: p.partyRole,
              phone: personById[p.personId]?.phone1 ?? '',
              address: personById[p.personId]?.permanentAddress ?? '',
              isPrimary: p.isPrimary,
            ))
        .toList();

    final opponents = dbParties
        .where((p) => !p.isClient)
        .map((p) => CasePartyView(
              id: p.id.toString(),
              name: personById[p.personId]?.fullName ?? 'شخص #${p.personId}',
              role: p.partyRole,
              phone: personById[p.personId]?.phone1 ?? '',
              address: personById[p.personId]?.permanentAddress ?? '',
              isPrimary: p.isPrimary,
            ))
        .toList();

    return CaseDetailNotifier._(
      CaseDetailState(
        caseItem: uiCase,
        clients: clients,
        opponents: opponents,
        phases: uiCase.phases,
        sessions: uiCase.sessions,
        deficiencies: uiCase.deficiencies,
      ),
    );
  }

  static Case _convertDbCase(db.Case dbCase, List<db.CasePhase> phases, List<db.CaseSession> sessions, List<db.Deficiency> deficiencies) {
    return Case(
      id: dbCase.id.toString(),
      caseNumber: dbCase.internalNumber,
      title: dbCase.subject ?? dbCase.internalNumber,
      type: _parseCaseType(dbCase.caseType),
      status: _parseCaseStatus(dbCase.status),
      court: dbCase.courtId?.toString() ?? '',
      subject: dbCase.subject ?? '',
      claim: dbCase.subjectDetails ?? '',
      notes: dbCase.notes ?? '',
      creationDate: dbCase.createdAt,
      lastUpdated: dbCase.updatedAt,
      baseNumber: dbCase.baseNumber,
      baseYear: dbCase.year,
      phases: phases.map(_convertPhase).toList(),
      sessions: sessions.map((s) => _convertSession(s, dbCase.courtId?.toString() ?? '')).toList(),
      deficiencies: deficiencies.map(_convertDeficiency).toList(),
    );
  }

  static CaseType _parseCaseType(String type) {
    switch (type) {
      case 'مدني': return CaseType.civil;
      case 'تجاري': return CaseType.commercial;
      case 'جزائي': return CaseType.criminal;
      case 'إداري': return CaseType.administrative;
      case 'شرعي': return CaseType.personalStatus;
      case 'عقاري': return CaseType.realEstate;
      case 'عمالي': return CaseType.labor;
      case 'دستوري': return CaseType.constitutional;
      default: return CaseType.other;
    }
  }

  static CaseStatus _parseCaseStatus(String status) {
    switch (status) {
      case 'registered': return CaseStatus.inProgress;
      case 'closed': return CaseStatus.completed;
      case 'preparing': return CaseStatus.pendingDocuments;
      case 'pending_registration': return CaseStatus.pendingBaseNumber;
      default: return CaseStatus.scheduled;
    }
  }

  static CasePhase _convertPhase(db.CasePhase p) {
    return CasePhase(
      id: p.id.toString(),
      type: _parsePhaseType(p.phaseType),
      court: p.courtId?.toString() ?? '',
      baseNumber: p.baseNumber,
      baseYear: p.year,
      startDate: p.startDate ?? DateTime.now(),
      endDate: p.endDate,
      description: p.decisionText ?? '',
      documents: p.decisionDocPath != null ? [p.decisionDocPath!] : const [],
    );
  }

  static CasePhaseType _parsePhaseType(String type) {
    switch (type) {
      case 'بداية': return CasePhaseType.initial;
      case 'استئناف': return CasePhaseType.appeal;
      case 'نقض': return CasePhaseType.cassation;
      case 'إعادة محاكمة': return CasePhaseType.initial;
      case 'صلح': return CasePhaseType.settlement;
      case 'جلسات': return CasePhaseType.hearing;
      case 'إثبات': return CasePhaseType.evidence;
      case 'حكم': return CasePhaseType.judgment;
      case 'تنفيذ': return CasePhaseType.execution;
      default: return CasePhaseType.initial;
    }
  }

  static CaseSession _convertSession(db.CaseSession s, String court) {
    return CaseSession(
      id: s.id.toString(),
      sessionDate: s.sessionDate,
      sessionTime: _parseTime(s.sessionTime),
      type: _parseSessionType(s.sessionType),
      status: _parseSessionStatus(s.status),
      court: court,
      decision: s.decision ?? '',
      result: SessionResult(
        notes: s.notes ?? '',
        decision: s.decision ?? '',
        nextRequired: s.nextAction ?? '',
      ),
      attendees: const [],
      documents: const [],
    );
  }

  static TimeOfDay _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts.last) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static SessionType _parseSessionType(String? type) {
    switch (type) {
      case 'مرافعة': return SessionType.ordinary;
      case 'تدقيق': return SessionType.review;
      case 'سماع شهود': return SessionType.evidence;
      case 'خبرة': return SessionType.other;
      case 'تفهيم حكم': return SessionType.judgment;
      default: return SessionType.ordinary;
    }
  }

  static SessionStatus _parseSessionStatus(int status) {
    switch (status) {
      case 0: return SessionStatus.scheduled;
      case 1: return SessionStatus.held;
      case 2: return SessionStatus.postponed;
      case 3: return SessionStatus.cancelled;
      default: return SessionStatus.scheduled;
    }
  }

  static CaseDeficiency _convertDeficiency(db.Deficiency d) {
    return CaseDeficiency(
      id: d.id.toString(),
      field: d.fieldName,
      description: d.description,
      severity: d.severity == 0 ? 'low' : (d.severity == 2 ? 'high' : 'medium'),
      createdAt: d.createdAt,
      resolvedAt: d.resolvedAt,
      isResolved: d.status == 'resolved',
    );
  }

  static CaseDetailState _initialState(
    Case? caseItem,
    List<DocumentItem> allDocuments,
  ) {
    if (caseItem == null) {
      return const CaseDetailState(caseItem: null);
    }

    final relatedDocuments = allDocuments
        .where((document) =>
            document.entityType == 'case' && document.entityId == caseItem.id)
        .toList();

    // لا تُصطنع مستندات لمعرّفات غير موجودة في الأرشيف؛ تُعرض الحقيقية فقط.
    final documents = relatedDocuments;

    final clients = _buildParties(
      ids: caseItem.clientIds,
      names: const ['أحمد محمد', 'شركة الأمانة للتجارة', 'هادي فيصل البني'],
      rolePrefix: 'موكل',
      primaryRole: 'مدعي أصلي',
    );
    final opponents = _buildParties(
      ids: caseItem.opponentIds,
      names: const ['محمد أحمد', 'شركة التطوير الحديث', 'سامي عبد الله'],
      rolePrefix: 'خصم',
      primaryRole: 'مدعى عليه',
    );
    final agencies = _buildAgencies(caseItem, clients);
    final phases = caseItem.phases.isNotEmpty
        ? caseItem.phases
        : [
            CasePhase(
              id: 'phase_${caseItem.id}_1',
              type: CasePhaseType.initial,
              court: caseItem.court,
              baseNumber: caseItem.baseNumber,
              baseYear: caseItem.baseYear,
              startDate: caseItem.creationDate,
              description: 'افتتاح الدعوى وتسجيلها أمام ${caseItem.court}',
            ),
          ];
    final actions = caseItem.actions.isNotEmpty
        ? caseItem.actions
        : [
            CaseAction(
              id: 'action_${caseItem.id}_1',
              title: 'مراجعة ديوان المحكمة',
              description: 'متابعة قيد الملف وتأكيد المرفقات الأساسية.',
              actionDate: caseItem.creationDate.add(const Duration(days: 1)),
              dueDate: caseItem.nextSession?.sessionDate,
              assignedTo: 'المعقب',
              status: 'pending',
            ),
          ];

    return CaseDetailState(
      caseItem: caseItem,
      clients: clients,
      opponents: opponents,
      agencies: agencies,
      phases: phases,
      sessions: caseItem.sessions,
      actions: actions,
      documents: documents,
      deficiencies: caseItem.deficiencies,
      timeline: _buildTimeline(
        caseItem: caseItem,
        phases: phases,
        sessions: caseItem.sessions,
        actions: actions,
        documents: documents,
        deficiencies: caseItem.deficiencies,
      ),
    );
  }

  static List<CasePartyView> _buildParties({
    required List<String> ids,
    required List<String> names,
    required String rolePrefix,
    required String primaryRole,
  }) {
    if (ids.isEmpty) {
      return [
        CasePartyView(
          id: '${rolePrefix}_1',
          name: '$rolePrefix افتراضي',
          role: primaryRole,
          phone: 'غير محدد',
          address: 'غير محدد',
          isPrimary: true,
        ),
      ];
    }

    return ids.asMap().entries.map((entry) {
      final index = entry.key;
      return CasePartyView(
        id: entry.value,
        name: names[index % names.length],
        role: index == 0 ? primaryRole : '$rolePrefix إضافي',
        phone: '09${(90000000 + index * 224411).toString().padLeft(8, '0')}',
        address: index.isEven ? 'دمشق - المزة' : 'السويداء - المركز',
        isPrimary: index == 0,
      );
    }).toList();
  }

  static List<CaseAgencyView> _buildAgencies(
    Case caseItem,
    List<CasePartyView> clients,
  ) {
    final ids = caseItem.poaIds.isNotEmpty ? caseItem.poaIds : ['poa_${caseItem.id}'];
    return ids.asMap().entries.map((entry) {
      return CaseAgencyView(
        id: entry.value,
        number: 'وكالة-${caseItem.baseYear ?? caseItem.creationDate.year}-${(entry.key + 1).toString().padLeft(3, '0')}',
        type: entry.key.isEven ? 'وكالة قضائية عامة' : 'وكالة خاصة بالدعوى',
        principal: clients.isEmpty ? 'الموكل' : clients.first.name,
        agent: 'الأستاذ هادي فيصل البني',
        issuedAt: caseItem.creationDate.subtract(Duration(days: 7 + entry.key)),
        expiresAt: caseItem.creationDate.add(Duration(days: 365 + entry.key * 30)),
        isActive: true,
      );
    }).toList();
  }

  static List<CaseTimelineEvent> _buildTimeline({
    required Case caseItem,
    required List<CasePhase> phases,
    required List<CaseSession> sessions,
    required List<CaseAction> actions,
    required List<DocumentItem> documents,
    required List<CaseDeficiency> deficiencies,
  }) {
    final events = <CaseTimelineEvent>[
      ...caseItem.timeline,
      CaseTimelineEvent(
        id: 'timeline_created_${caseItem.id}',
        eventDate: caseItem.creationDate,
        eventType: 'case_created',
        description: 'تم فتح ملف الدعوى رقم ${caseItem.caseNumber}.',
        createdBy: 'مكتب المحامي',
      ),
      ...phases.map(
        (phase) => CaseTimelineEvent(
          id: 'timeline_phase_${phase.id}',
          eventDate: phase.startDate,
          eventType: 'phase_started',
          description: 'بدء مرحلة ${phase.type.displayName} أمام ${phase.court}.',
          createdBy: 'النظام',
          documents: phase.documents,
        ),
      ),
      ...sessions.map(
        (session) => CaseTimelineEvent(
          id: 'timeline_session_${session.id}',
          eventDate: session.sessionDate,
          eventType: 'session_${session.status.toString().split('.').last}',
          description: 'جلسة ${session.type.displayName} في ${session.court} - ${session.decision.isEmpty ? 'بانتظار النتيجة' : session.decision}.',
          createdBy: 'جدول الجلسات',
          documents: session.documents,
        ),
      ),
      ...actions.map(
        (action) => CaseTimelineEvent(
          id: 'timeline_action_${action.id}',
          eventDate: action.actionDate,
          eventType: 'action_${action.status}',
          description: '${action.title}: ${action.description}',
          createdBy: action.assignedTo.isEmpty ? 'المكتب' : action.assignedTo,
          documents: action.documents,
        ),
      ),
      ...documents.map(
        (document) => CaseTimelineEvent(
          id: 'timeline_document_${document.id}',
          eventDate: document.uploadDate,
          eventType: 'document_added',
          description: 'تم ربط المستند: ${document.title}.',
          createdBy: document.uploadedBy,
          documents: [document.id],
        ),
      ),
      ...deficiencies.map(
        (deficiency) => CaseTimelineEvent(
          id: 'timeline_deficiency_${deficiency.id}',
          eventDate: deficiency.createdAt,
          eventType: deficiency.isResolved
              ? 'deficiency_resolved'
              : 'deficiency_opened',
          description: deficiency.description,
          createdBy: 'نظام النواقص',
        ),
      ),
      ...caseItem.fees.map(
        (fee) => CaseTimelineEvent(
          id: 'timeline_fee_${fee.id}',
          eventDate: fee.paymentDate ?? fee.agreementDate,
          eventType: fee.status == 'paid' ? 'fee_paid' : 'fee_agreed',
          description: 'اتفاق أتعاب بقيمة ${fee.amount.toStringAsFixed(0)} ${fee.currency}.',
          createdBy: 'الإدارة المالية',
        ),
      ),
      ...caseItem.expenses.map(
        (expense) => CaseTimelineEvent(
          id: 'timeline_expense_${expense.id}',
          eventDate: expense.expenseDate,
          eventType: 'expense_added',
          description: 'مصروف: ${expense.description} بقيمة ${expense.amount.toStringAsFixed(0)} ${expense.currency}.',
          createdBy: expense.paidBy.isEmpty ? 'الإدارة المالية' : expense.paidBy,
          documents: expense.receipts,
        ),
      ),
    ];

    events.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return events;
  }

  void addSession({
    required DateTime sessionDate,
    required TimeOfDay sessionTime,
    required SessionType type,
    required String decision,
    required String notes,
  }) {
    final caseItem = state.caseItem;
    if (caseItem == null) {
      return;
    }

    final session = CaseSession(
      id: 'session_${DateTime.now().microsecondsSinceEpoch}',
      sessionDate: sessionDate,
      sessionTime: sessionTime,
      type: type,
      status: SessionStatus.scheduled,
      court: caseItem.court,
      decision: decision,
      result: SessionResult(notes: notes, decision: decision),
      attendees: const ['المحامي الوكيل'],
    );

    _appendTimeline(
      CaseTimelineEvent(
        id: 'timeline_${session.id}',
        eventDate: sessionDate,
        eventType: 'session_added',
        description: 'تمت إضافة جلسة ${type.displayName} بتاريخ ${_formatDateValue(sessionDate)}.',
        createdBy: 'مكتب المحامي',
      ),
      sessions: [...state.sessions, session],
    );
  }

  void addDocument(DocumentItem document) {
    _appendTimeline(
      CaseTimelineEvent(
        id: 'timeline_document_${document.id}',
        eventDate: document.uploadDate,
        eventType: 'document_added',
        description: 'تم رفع / ربط المستند: ${document.title}.',
        createdBy: document.uploadedBy,
        documents: [document.id],
      ),
      documents: [...state.documents, document],
    );
  }

  void deleteDocument(String documentId) {
    final document = state.documents.firstWhereOrNull((item) => item.id == documentId);
    final updatedDocuments = state.documents
        .where((item) => item.id != documentId)
        .toList(growable: false);

    _appendTimeline(
      CaseTimelineEvent(
        id: 'timeline_document_deleted_$documentId',
        eventDate: DateTime.now(),
        eventType: 'document_deleted',
        description: 'تم حذف ربط المستند: ${document?.title ?? documentId}.',
        createdBy: 'مكتب المحامي',
      ),
      documents: updatedDocuments,
    );
  }

  void addDeficiency({
    required String field,
    required String description,
    required String severity,
  }) {
    final deficiency = CaseDeficiency(
      id: 'def_${DateTime.now().microsecondsSinceEpoch}',
      field: field,
      description: description,
      severity: severity,
      createdAt: DateTime.now(),
    );

    _appendTimeline(
      CaseTimelineEvent(
        id: 'timeline_${deficiency.id}',
        eventDate: deficiency.createdAt,
        eventType: 'deficiency_opened',
        description: description,
        createdBy: 'نظام النواقص',
      ),
      deficiencies: [...state.deficiencies, deficiency],
    );
  }

  void resolveDeficiency(String deficiencyId) {
    final updated = state.deficiencies.map((item) {
      if (item.id != deficiencyId) {
        return item;
      }
      return CaseDeficiency(
        id: item.id,
        field: item.field,
        description: item.description,
        severity: item.severity,
        createdAt: item.createdAt,
        resolvedAt: DateTime.now(),
        isResolved: true,
      );
    }).toList();

    _appendTimeline(
      CaseTimelineEvent(
        id: 'timeline_resolved_$deficiencyId',
        eventDate: DateTime.now(),
        eventType: 'deficiency_resolved',
        description: 'تم استكمال النقص رقم $deficiencyId وإغلاقه.',
        createdBy: 'مكتب المحامي',
      ),
      deficiencies: updated,
    );
  }

  void addPhase(CasePhase phase) {
    _appendTimeline(
      CaseTimelineEvent(
        id: 'timeline_phase_${phase.id}',
        eventDate: phase.startDate,
        eventType: 'phase_added',
        description: 'تم نقل الدعوى إلى مرحلة ${phase.type.displayName}.',
        createdBy: 'مكتب المحامي',
      ),
      phases: [...state.phases, phase],
    );
  }

  void setTimelineFilter(TimelineFilter filter) {
    state = state.copyWith(timelineFilter: filter);
  }

  void terminateCase({
    required CaseClosureResult result,
    required String decisionNumber,
    required String summary,
    required DateTime closedAt,
  }) {
    _appendTimeline(
      CaseTimelineEvent(
        id: 'timeline_termination_${DateTime.now().microsecondsSinceEpoch}',
        eventDate: closedAt,
        eventType: result.timelineCode,
        description: 'تم إنهاء الدعوى: ${result.displayName}. رقم القرار: ${decisionNumber.isEmpty ? 'غير مدخل' : decisionNumber}. $summary',
        createdBy: 'مكتب المحامي',
      ),
      isTerminated: true,
      closureResult: result,
      closureSummary: summary,
      closedAt: closedAt,
    );
  }

  void _appendTimeline(
    CaseTimelineEvent event, {
    List<CasePhase>? phases,
    List<CaseSession>? sessions,
    List<CaseAction>? actions,
    List<DocumentItem>? documents,
    List<CaseDeficiency>? deficiencies,
    bool? isTerminated,
    CaseClosureResult? closureResult,
    String? closureSummary,
    DateTime? closedAt,
  }) {
    final updatedTimeline = [event, ...state.timeline]
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    state = state.copyWith(
      phases: phases,
      sessions: sessions,
      actions: actions,
      documents: documents,
      deficiencies: deficiencies,
      timeline: updatedTimeline,
      isTerminated: isTerminated,
      closureResult: closureResult,
      closureSummary: closureSummary,
      closedAt: closedAt,
    );
  }

  static String _formatDateValue(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// شاشة تفاصيل الدعوى مع 9 تبويبات.
class CaseDetailScreen extends ConsumerStatefulWidget {
  final int caseId;

  const CaseDetailScreen({
    super.key,
    required this.caseId,
  });

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _terminationNumberController = TextEditingController();
  final TextEditingController _terminationSummaryController = TextEditingController();
  CaseClosureResult _selectedClosureResult = CaseClosureResult.win;
  bool _terminationConfirmed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _terminationNumberController.dispose();
    _terminationSummaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(caseDetailProvider(widget.caseId));
    final caseItem = detailState.caseItem;

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: caseItem == null
            ? _buildNotFoundScaffold()
            : Scaffold(
                appBar: AppBar(
                  title: Text(
                    'ملف الدعوى ${caseItem.caseNumber}',
                    style: AppTextStyles.headline5.copyWith(
                      color: AppColors.textOnLight,
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'تحديث البيانات',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.invalidate(caseDetailProvider(widget.caseId)),
                    ),
                    IconButton(
                      tooltip: 'العودة',
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(56),
                    child: Container(
                      color: AppColors.cardBackground,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: AppTextStyles.labelMedium,
                        labelColor: AppColors.primaryNavy,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.secondaryGold,
                        tabs: const [
                          Tab(text: '1 الملخص'),
                          Tab(text: '2 الأطراف والوكالات'),
                          Tab(text: '3 المراحل القضائية'),
                          Tab(text: '4 الجلسات والإجراءات'),
                          Tab(text: '5 المستندات'),
                          Tab(text: '6 المالية'),
                          Tab(text: '7 النواقص'),
                          Tab(text: '8 الخط الزمني'),
                          Tab(text: '9 الإنهاء'),
                        ],
                      ),
                    ),
                  ),
                ),
                body: Column(
                  children: [
                    _buildStatusBar(detailState),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSummaryTab(detailState),
                          _buildPartiesTab(detailState),
                          _buildPhasesTab(detailState),
                          _buildSessionsTab(detailState),
                          _buildDocumentsTab(detailState),
                          _buildFinanceTab(detailState),
                          _buildDeficienciesTab(detailState),
                          _buildTimelineTab(detailState),
                          _buildTerminationTab(detailState),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Scaffold _buildNotFoundScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('الدعوى غير موجودة')),
      body: _emptyState(
        icon: Icons.search_off,
        title: 'لم يتم العثور على الدعوى',
        subtitle: 'رقم الدعوى المطلوب غير موجود ضمن بيانات المرحلة الحالية.',
      ),
    );
  }

  Widget _buildStatusBar(CaseDetailState state) {
    final statusColor = state.isTerminated
        ? AppColors.error
        : state.openDeficienciesCount > 0
            ? AppColors.warning
            : caseItem.status.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _statusChip(Icons.gavel, 'النوع', caseItem.type.displayName, AppColors.primaryNavy),
          _statusChip(Icons.balance, 'المحكمة', caseItem.court, AppColors.primaryNavy),
          _statusChip(
            Icons.confirmation_number,
            'رقم الأساس',
            caseItem.baseNumber ?? 'بانتظار التسجيل',
            caseItem.baseNumber == null ? AppColors.warning : AppColors.success,
          ),
          _statusChip(
            Icons.event,
            'الجلسة القادمة',
            nextSession == null ? 'غير محددة' : _formatDate(nextSession.sessionDate),
            nextSession == null ? AppColors.warning : AppColors.info,
          ),
          _statusChip(
            Icons.rule_folder,
            'النواقص',
            '${state.openDeficienciesCount}',
            state.openDeficienciesCount > 0 ? AppColors.error : AppColors.success,
          ),
          _badge(
            state.isTerminated ? 'منتهية' : caseItem.status.displayName,
            statusColor,
            icon: state.isTerminated ? Icons.lock : Icons.verified,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(CaseDetailState state) {
    final progress = state.isTerminated ? 1.0 : (state.sessions.length > 5 ? 0.8 : (state.sessions.length / 10).clamp(0.1, 0.9));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("التقدم المالي (Micro-Dashboard)", style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
                      const SizedBox(height: 16),
                      _progressBar("مؤشر إنجاز الدعوى القضائية", progress, AppColors.success),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _financeSummaryBox("الأتعاب المتفق عليها", state.totalFees, AppColors.primaryNavy),
                          _financeSummaryBox("إجمالي المصاريف", state.totalExpenses, AppColors.error),
                          _financeSummaryBox("الرصيد الصافي", state.balance, AppColors.success),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("النواقص العاجلة للحل", style: AppTextStyles.headline6.copyWith(color: AppColors.warning)),
                      const SizedBox(height: 16),
                      if (state.openDeficienciesCount == 0)
                        Text("الملف مكتمل ولا يوجد نواقص.", style: AppTextStyles.bodyMediumSecondary)
                      else
                        ...state.deficiencies.where((d) => !d.isResolved).take(3).map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(d.description, style: AppTextStyles.bodyMedium)),
                              TextButton(
                                onPressed: () => _tabController.animateTo(6),
                                style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                child: const Text("حل الآن"),
                              ),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text("الخط الزمني المصغر", style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 16),
          _buildMiniTimeline(state),
        ],
      ),
    );
  }

  Widget _progressBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.labelMedium),
            Text("${(value * 100).toInt()}%", style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value,
          backgroundColor: AppColors.cardBorder,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _financeSummaryBox(String title, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.bodySmallSecondary),
        const SizedBox(height: 4),
        Text("${amount.toStringAsFixed(0)} ل.س", style: AppTextStyles.headline6.copyWith(color: color)),
      ],
    );
  }

  Widget _buildMiniTimeline(CaseDetailState state) {
    final events = state.filteredTimeline.take(3).toList();
    if (events.isEmpty) return Text("لا يوجد أحداث بعد.", style: AppTextStyles.bodyMediumSecondary);
    return Column(
      children: events.map((e) => ListTile(
        leading: Icon(Icons.history, color: AppColors.primaryNavy),
        title: Text(e.description),
        subtitle: Text("${e.eventDate.year}-${e.eventDate.month}-${e.eventDate.day} • بواسطة: ${e.createdBy}"),
        dense: true,
      )).toList(),
    );
  }


  Widget _buildPartiesTab(CaseDetailState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            title: 'الأطراف والوكالات',
            subtitle: 'قائمة الموكلين والخصوم وسندات الوكالة المرتبطة بالدعوى.',
            icon: Icons.groups,
          ),
          _twoColumnLayout(
            first: _partySection(
              title: 'الموكلون',
              parties: state.clients,
              icon: Icons.person,
              color: AppColors.success,
            ),
            second: _partySection(
              title: 'الخصوم',
              parties: state.opponents,
              icon: Icons.person_off,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 16),
          _infoCard(
            title: 'الوكالات القضائية',
            icon: Icons.verified_user,
            trailing: TextButton.icon(
              onPressed: () => _showSnack('سيتم ربط الوكالات من شاشة المستندات العالمية.'),
              icon: const Icon(Icons.link),
              label: const Text('ربط وكالة'),
            ),
            children: [
              if (state.agencies.isEmpty)
                _emptyState(
                  icon: Icons.assignment_late,
                  title: 'لا توجد وكالة مرتبطة',
                  subtitle: 'يمكن ربط وكالة من المستندات العالمية أو رفع وكالة جديدة.',
                  compact: true,
                )
              else
                ...state.agencies.map(_agencyTile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhasesTab(CaseDetailState state) {
    return Column(
      children: [
        _tabHeader(
          title: 'المراحل القضائية',
          subtitle: 'تتبع تسلسل الدعوى من البداية حتى مراحل الطعن والتنفيذ.',
          icon: Icons.account_tree,
          action: ref.watch(permissionServiceProvider).can(PermissionKeys.casesEdit)
              ? ElevatedButton.icon(
                  onPressed: () => _showAddPhaseDialog(context, state),
                  icon: const Icon(Icons.add),
                  label: const Text('نقل للمرحلة التالية'),
                )
              : null,
        ),
        Expanded(
          child: state.phases.isEmpty
              ? _emptyState(
                  icon: Icons.account_tree_outlined,
                  title: 'لا توجد مراحل قضائية',
                  subtitle: 'أضف المرحلة الأولى لتبدأ متابعة الدعوى.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.phases.length,
                  itemBuilder: (context, index) {
                    final phase = state.phases[index];
                    final isActive = phase.endDate == null && index == state.phases.length - 1;
                    return _phaseTile(phase, index, isActive);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSessionsTab(CaseDetailState state) {
    final orderedSessions = [...state.sessions]
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    final orderedActions = [...state.actions]
      ..sort((a, b) => b.actionDate.compareTo(a.actionDate));

    return Column(
      children: [
        _tabHeader(
          title: 'الجلسات والإجراءات',
          subtitle: 'سجل جلسات المحكمة والإجراءات الخارجية مع النتائج والملاحظات.',
          icon: Icons.event_note,
          action: ref.watch(permissionServiceProvider).can(PermissionKeys.casesSessionsManage)
              ? ElevatedButton.icon(
                  onPressed: () => _showAddSessionDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة جلسة جديدة'),
                )
              : null,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _infoCard(
                  title: 'سجل الجلسات',
                  icon: Icons.gavel,
                  children: [
                    if (orderedSessions.isEmpty)
                      _emptyState(
                        icon: Icons.event_busy,
                        title: 'لا توجد جلسات مسجلة',
                        subtitle: 'اضغط إضافة جلسة جديدة لتسجيل أول موعد.',
                        compact: true,
                      )
                    else
                      ...orderedSessions.map(_sessionTile),
                  ],
                ),
                const SizedBox(height: 16),
                _infoCard(
                  title: 'الإجراءات الخارجية',
                  icon: Icons.checklist,
                  children: [
                    if (orderedActions.isEmpty)
                      _emptyState(
                        icon: Icons.playlist_add_check,
                        title: 'لا توجد إجراءات خارجية',
                        subtitle: 'الإجراءات ستظهر هنا عند تسجيلها.',
                        compact: true,
                      )
                    else
                      ...orderedActions.map(_actionTile),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab(CaseDetailState state) {
    final caseId = state.caseItem?.id;
    final allDocsAsync = ref.watch(uiDocumentsProvider);

    return Column(
      children: [
        _tabHeader(
          title: 'مستندات الدعوى',
          subtitle: 'رفع، حذف، فتح، وربط مستندات الدعوى بالمستندات العالمية.',
          icon: Icons.folder_copy,
          action: Wrap(
            spacing: 8,
            children: [
              if (ref.watch(permissionServiceProvider).can(PermissionKeys.documentsEdit))
                OutlinedButton.icon(
                  onPressed: () => _linkGlobalDocument(state),
                  icon: const Icon(Icons.link),
                  label: const Text('ربط عالمي'),
                ),
              if (ref.watch(permissionServiceProvider).can(PermissionKeys.documentsUpload))
                ElevatedButton.icon(
                  onPressed: () => _pickAndAddDocument(state),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('رفع مستند'),
                ),
            ],
          ),
        ),
        Expanded(
          child: allDocsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
            data: (allDocs) {
              final documents = allDocs
                  .where((d) => d.entityType == 'case' && d.entityId == caseId)
                  .toList()
                ..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));

              if (documents.isEmpty) {
                return _emptyState(
                  icon: Icons.folder_off,
                  title: 'لا توجد مستندات مرتبطة',
                  subtitle: 'ارفع مستنداً أو اربط مستنداً من الأرشيف العالمي.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: documents.length,
                itemBuilder: (context, index) => _documentTile(documents[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceTab(CaseDetailState state) {
    final caseId = state.caseItem?.id;
    final financeAsync = ref.watch(financeByEntityProvider(('case', caseId ?? '')));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            title: 'المالية',
            subtitle: 'الأتعاب، المصروفات القضائية، الدفعات، الرصيد، والتقرير المالي.',
            icon: Icons.account_balance_wallet,
          ),
          financeAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('خطأ في تحميل المالية: $e'),
            data: (financeData) {
              final totalFees = financeData.totalFees;
              final totalExpenses = financeData.totalExpenses;
              final balance = totalFees - totalExpenses;

              return Column(
                children: [
                  _responsiveCards([
                    _metricCard('إجمالي الأتعاب', _formatCurrency(totalFees), Icons.payments, AppColors.primaryNavy),
                    _metricCard('المصروفات', _formatCurrency(totalExpenses), Icons.money_off, AppColors.error),
                    _metricCard('الرصيد', _formatCurrency(balance), Icons.trending_up, balance >= 0 ? AppColors.success : AppColors.error),
                  ]),
                  const SizedBox(height: 16),
                  _twoColumnLayout(
                    first: _financeList(
                      title: 'اتفاقيات الأتعاب والدفعات',
                      icon: Icons.receipt_long,
                      emptyTitle: 'لا توجد أتعاب مسجلة',
                      children: financeData.fees.map(_feeTile).toList(),
                    ),
                    second: _financeList(
                      title: 'المصروفات القضائية',
                      icon: Icons.request_quote,
                      emptyTitle: 'لا توجد مصروفات مسجلة',
                      children: financeData.expenses.map(_expenseTile).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _showFinancialReport(state),
              icon: const Icon(Icons.summarize),
              label: const Text('إصدار تقرير مالي مختصر'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeficienciesTab(CaseDetailState state) {
    final deficiencies = [...state.deficiencies]
      ..sort((a, b) {
        if (a.isResolved != b.isResolved) {
          return a.isResolved ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    return Column(
      children: [
        _tabHeader(
          title: 'النواقص',
          subtitle: 'متابعة النواقص حسب النوع، الأولوية، تاريخ الاستحقاق، والحالة.',
          icon: Icons.rule,
          action: ElevatedButton.icon(
            onPressed: () => _showAddDeficiencyDialog(context),
            icon: const Icon(Icons.add_alert),
            label: const Text('إضافة نقص'),
          ),
        ),
        Expanded(
          child: deficiencies.isEmpty
              ? _emptyState(
                  icon: Icons.verified,
                  title: 'ملف مكتمل',
                  subtitle: 'لا توجد نواقص مفتوحة أو مغلقة لهذه الدعوى.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: deficiencies.length,
                  itemBuilder: (context, index) => _deficiencyTile(deficiencies[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab(CaseDetailState state) {
    final events = state.filteredTimeline;

    return Column(
      children: [
        _tabHeader(
          title: 'الخط الزمني',
          subtitle: 'كل أحداث الدعوى بترتيب زمني مع فلترة حسب النوع.',
          icon: Icons.timeline,
          action: DropdownButton<TimelineFilter>(
            value: state.timelineFilter,
            items: TimelineFilter.values
                .map(
                  (filter) => DropdownMenuItem(
                    value: filter,
                    child: Text(filter.displayName),
                  ),
                )
                .toList(),
            onChanged: (filter) {
              if (filter != null) {
                ref.read(caseDetailProvider(widget.caseId).notifier).setTimelineFilter(filter);
              }
            },
          ),
        ),
        Expanded(
          child: events.isEmpty
              ? _emptyState(
                  icon: Icons.history_toggle_off,
                  title: 'لا توجد أحداث مطابقة',
                  subtitle: 'غيّر الفلتر أو أضف أحداثاً من تبويبات الدعوى.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) => _timelineTile(events[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildTerminationTab(CaseDetailState state) {
    if (state.isTerminated) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _infoCard(
            title: 'الدعوى منتهية',
            icon: Icons.lock,
            children: [
              _alertBox(
                icon: Icons.archive,
                title: state.closureResult?.displayName ?? 'تم الإغلاق',
                message: 'تاريخ الإنهاء: ${state.closedAt == null ? 'غير محدد' : _formatDate(state.closedAt!)}\n${state.closureSummary}',
                color: state.closureResult?.color ?? AppColors.primaryNavy,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: _infoCard(
            title: 'إنهاء الدعوى',
            icon: Icons.gavel,
            children: [
              _alertBox(
                icon: Icons.warning_amber,
                title: 'إجراء حساس',
                message: 'سيتم اعتبار الدعوى منتهية بعد التأكيد. يجب تحديد نتيجة الإنهاء وملخص القرار النهائي.',
                color: AppColors.warning,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CaseClosureResult>(
                value: _selectedClosureResult,
                decoration: const InputDecoration(
                  labelText: 'نتيجة الإنهاء',
                  prefixIcon: Icon(Icons.flag),
                ),
                items: CaseClosureResult.values
                    .map(
                      (result) => DropdownMenuItem(
                        value: result,
                        child: Text(result.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (result) {
                  if (result != null) {
                    setState(() => _selectedClosureResult = result);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _terminationNumberController,
                decoration: const InputDecoration(
                  labelText: 'رقم قرار الحكم / محضر الصلح',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _terminationSummaryController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'ملخص ومنطوق القرار النهائي',
                  prefixIcon: Icon(Icons.subject),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _terminationConfirmed,
                onChanged: (value) => setState(() => _terminationConfirmed = value ?? false),
                title: Text(
                  'أؤكد مراجعة الملف والمستندات المالية قبل إنهاء الدعوى.',
                  style: AppTextStyles.bodyMedium,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: ref.watch(permissionServiceProvider).can(PermissionKeys.casesClose) ? () => _terminateCase(state) : null,
                  icon: const Icon(Icons.lock),
                  label: const Text('اعتماد الإنهاء وإغلاق الدعوى'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.textOnLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text('$label: ', style: AppTextStyles.labelSmall),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.textOnLight, size: 16),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.badgeText,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryNavy.withOpacity(0.1),
            child: Icon(icon, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headline4),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryNavy.withOpacity(0.1),
            child: Icon(icon, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headline5),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _responsiveCards(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: isWide ? (constraints.maxWidth - 48) / 5 : 260,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.bodySmallSecondary),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.headline5.copyWith(color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.headline5.copyWith(color: AppColors.primaryNavy),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: AppTextStyles.labelMedium),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _alertBox({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.45), width: 0.7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(message, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _twoColumnLayout({required Widget first, required Widget second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 16), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _partySection({
    required String title,
    required List<CasePartyView> parties,
    required IconData icon,
    required Color color,
  }) {
    return _infoCard(
      title: title,
      icon: icon,
      children: parties.map((party) => _partyTile(party, color)).toList(),
    );
  }

  Widget _partyTile(CasePartyView party, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(Icons.person, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(party.name, style: AppTextStyles.labelLarge),
                Text('${party.role} • ${party.phone}', style: AppTextStyles.bodySmallSecondary),
                Text(party.address, style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
          if (party.isPrimary) _badge('رئيسي', color),
        ],
      ),
    );
  }

  Widget _agencyTile(CaseAgencyView agency) {
    final color = agency.isActive ? AppColors.success : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_ind, color: AppColors.primaryNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(agency.number, style: AppTextStyles.labelLarge),
              ),
              _badge(agency.isActive ? 'سارية' : 'منتهية', color),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow('النوع', agency.type),
          _infoRow('الموكل', agency.principal),
          _infoRow('الوكيل', agency.agent),
          _infoRow('تاريخ الإصدار', _formatDate(agency.issuedAt)),
          _infoRow('انتهاء الصلاحية', agency.expiresAt == null ? 'غير محدد' : _formatDate(agency.expiresAt!)),
        ],
      ),
    );
  }

  Widget _phaseTile(CasePhase phase, int index, bool isActive) {
    final color = isActive ? AppColors.success : AppColors.primaryNavy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Text(
                '${index + 1}',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnLight),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          phase.type.displayName,
                          style: AppTextStyles.headline5.copyWith(color: color),
                        ),
                      ),
                      _badge(isActive ? 'نشطة' : 'سابقة', color),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow('المحكمة', phase.court),
                  _infoRow('رقم الأساس', phase.baseNumber ?? 'غير مدخل'),
                  _infoRow('سنة الأساس', phase.baseYear?.toString() ?? 'غير محددة'),
                  _infoRow('تاريخ البداية', _formatDate(phase.startDate)),
                  _infoRow('تاريخ النهاية', phase.endDate == null ? 'مستمرة' : _formatDate(phase.endDate!)),
                  if (phase.description.isNotEmpty) _infoRow('الوصف', phase.description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionTile(CaseSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: session.status.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: session.status.color.withOpacity(0.35), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.event, color: session.status.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${session.type.displayName} • ${_formatDate(session.sessionDate)} • ${_formatTime(session.sessionTime)}',
                  style: AppTextStyles.labelLarge,
                ),
              ),
              _badge(session.status.displayName, session.status.color),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow('المحكمة', session.court),
          _infoRow('النتيجة', session.decision.isEmpty ? 'بانتظار النتيجة' : session.decision),
          if (session.result?.nextRequired.isNotEmpty ?? false)
            _infoRow('المطلوب القادم', session.result!.nextRequired),
          if (session.result?.notes.isNotEmpty ?? false)
            _infoRow('ملاحظات', session.result!.notes),
        ],
      ),
    );
  }

  Widget _actionTile(CaseAction action) {
    final color = action.status == 'completed' ? AppColors.success : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(action.title, style: AppTextStyles.labelLarge)),
              _badge(_statusArabic(action.status), color),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow('التاريخ', _formatDate(action.actionDate)),
          _infoRow('المكلف', action.assignedTo.isEmpty ? 'غير محدد' : action.assignedTo),
          _infoRow('الوصف', action.description.isEmpty ? 'لا يوجد وصف' : action.description),
          _infoRow('الاستحقاق', action.dueDate == null ? 'غير محدد' : _formatDate(action.dueDate!)),
        ],
      ),
    );
  }

  Widget _documentTile(DocumentItem document) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryNavy.withOpacity(0.1),
              child: Icon(document.fileType.icon, color: AppColors.primaryNavy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(document.title, style: AppTextStyles.labelLarge),
                  Text(
                    '${document.documentType.displayName} • ${document.fileType.displayName} • ${document.formattedSize}',
                    style: AppTextStyles.bodySmallSecondary,
                  ),
                  Text(
                    'أضيف بتاريخ ${_formatDate(document.uploadDate)} • ${document.physicalLocation}',
                    style: AppTextStyles.bodySmallSecondary,
                  ),
                ],
              ),
            ),
            if (document.isMissingOriginal)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _badge('بانتظار الأصل', AppColors.warning),
              ),
            IconButton(
              tooltip: 'فتح',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openDocument(context, document.id),
            ),
            IconButton(
              tooltip: 'حذف الربط',
              icon: Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _confirmDeleteDocument(document),
            ),
          ],
        ),
      ),
    );
  }

  Widget _financeList({
    required String title,
    required IconData icon,
    required String emptyTitle,
    required List<Widget> children,
  }) {
    return _infoCard(
      title: title,
      icon: icon,
      children: children.isEmpty
          ? [
              _emptyState(
                icon: icon,
                title: emptyTitle,
                subtitle: 'يمكن إضافة البيانات المالية لاحقاً من شاشة المالية الموحدة.',
                compact: true,
              ),
            ]
          : children,
    );
  }

  Widget _feeTile(CaseFee fee) {
    final isPaid = fee.status == 'paid';
    final color = isPaid ? AppColors.success : AppColors.warning;
    return ListTile(
      leading: Icon(Icons.payments, color: color),
      title: Text(_formatCurrency(fee.amount), style: AppTextStyles.labelLarge),
      subtitle: Text('الموكل: ${fee.clientId} • الاتفاق: ${_formatDate(fee.agreementDate)}', style: AppTextStyles.bodySmallSecondary),
      trailing: _badge(isPaid ? 'مدفوع' : 'غير مدفوع', color),
    );
  }

  Widget _expenseTile(CaseExpense expense) {
    return ListTile(
      leading: Icon(Icons.receipt, color: AppColors.error),
      title: Text(expense.description, style: AppTextStyles.labelLarge),
      subtitle: Text(_formatDate(expense.expenseDate), style: AppTextStyles.bodySmallSecondary),
      trailing: Text(_formatCurrency(expense.amount), style: AppTextStyles.numberText.copyWith(color: AppColors.error)),
    );
  }

  Widget _deficiencyTile(CaseDeficiency deficiency) {
    final color = deficiency.isResolved ? AppColors.success : _severityColor(deficiency.severity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(deficiency.isResolved ? Icons.verified : Icons.error_outline, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(deficiency.field, style: AppTextStyles.labelLarge)),
                      _badge(deficiency.isResolved ? 'مكتمل' : _severityLabel(deficiency.severity), color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(deficiency.description, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'تاريخ الرصد: ${_formatDate(deficiency.createdAt)}${deficiency.resolvedAt == null ? '' : ' • الإغلاق: ${_formatDate(deficiency.resolvedAt!)}'}',
                    style: AppTextStyles.bodySmallSecondary,
                  ),
                ],
              ),
            ),
            if (!deficiency.isResolved)
              TextButton.icon(
                onPressed: () => ref
                    .read(caseDetailProvider(widget.caseId).notifier)
                    .resolveDeficiency(deficiency.id),
                icon: const Icon(Icons.done),
                label: const Text('إغلاق'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _timelineTile(CaseTimelineEvent event) {
    final color = _timelineColor(event.eventType);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(_timelineIcon(event.eventType), color: AppColors.textOnLight, size: 20),
            ),
            Container(width: 2, height: 58, color: AppColors.cardBorder),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(event.description, style: AppTextStyles.bodyMedium)),
                      _badge(_eventArabic(event.eventType), color),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatDate(event.eventDate)} • ${event.createdBy ?? 'النظام'}',
                    style: AppTextStyles.bodySmallSecondary,
                  ),
                  if (event.documents?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: event.documents!
                          .map((documentId) => ActionChip(
                                avatar: const Icon(Icons.description, size: 16),
                                label: Text(documentId),
                                onPressed: () => openDocument(context, documentId),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool compact = false,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, size: compact ? 42 : 72, color: AppColors.textSecondary),
            SizedBox(height: compact ? 8 : 16),
            Text(title, style: compact ? AppTextStyles.headline6 : AppTextStyles.headline4),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTextStyles.bodySmallSecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSessionDialog(BuildContext context) async {
    final decisionController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    SessionType selectedType = SessionType.ordinary;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('إضافة جلسة جديدة'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<SessionType>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'نوع الجلسة'),
                      items: SessionType.values
                          .map((type) => DropdownMenuItem(value: type, child: Text(type.displayName)))
                          .toList(),
                      onChanged: (type) {
                        if (type != null) {
                          setLocalState(() => selectedType = type);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Text('التاريخ: ${_formatDate(selectedDate)}', style: AppTextStyles.bodyMedium)),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setLocalState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('اختيار'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: Text('الوقت: ${_formatTime(selectedTime)}', style: AppTextStyles.bodyMedium)),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setLocalState(() => selectedTime = picked);
                            }
                          },
                          icon: const Icon(Icons.access_time),
                          label: const Text('اختيار'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: decisionController,
                      decoration: const InputDecoration(labelText: 'النتيجة / القرار المتوقع'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    final permissions = ref.read(permissionServiceProvider);
                    if (!permissions.can(PermissionKeys.casesSessionsManage)) {
                      await ref.read(auditServiceProvider).log(
                        action: 'access_denied',
                        category: 'cases',
                        entityType: 'case_session',
                        entityId: '${widget.caseId}',
                        description: 'محاولة إضافة جلسة دون صلاحية',
                        severity: 'warning',
                      );
                      return;
                    }
                    // الحفظ الفعلي في قاعدة البيانات (يولّد أيضاً مهمة يومية
                    // للموعد القادم ويغلق نقص next_session_date).
                    final caseDbId = widget.caseId;
                    try {
                      await ref.read(caseRepositoryProvider).addSession(
                            session: db.CaseSessionsCompanion.insert(
                              caseId: caseDbId,
                              sessionDate: DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              ),
                              sessionTime: drift.Value(
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                              ),
                              sessionType: drift.Value(selectedType.displayName),
                              decision: drift.Value(decisionController.text.trim()),
                              notes: drift.Value(notesController.text.trim()),
                            ),
                            caseTitle: 'دعوى ${widget.caseId}',
                            userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
                          );
                    } catch (e) {
                      _showSnack('تعذر حفظ الجلسة: $e', isError: true);
                      return;
                    }
                    ref.invalidate(allCasesProvider);
                    ref.invalidate(uiCasesProvider);
                    await ref.read(auditServiceProvider).log(
                      action: 'create',
                      category: 'cases',
                      entityType: 'case_session',
                      entityId: '${widget.caseId}',
                      entityTitle: 'جلسة دعوى ${widget.caseId}',
                      description: 'إضافة جلسة جديدة',
                      after: {
                        'date': selectedDate.toIso8601String(),
                        'type': selectedType.displayName,
                        'decision': decisionController.text.trim(),
                      },
                      severity: 'info',
                    );
                    Navigator.of(dialogContext).pop();
                    _showSnack('تمت إضافة الجلسة بنجاح.');
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    decisionController.dispose();
    notesController.dispose();
  }

  Future<void> _showAddPhaseDialog(BuildContext context, CaseDetailState state) async {
    CasePhaseType selectedType = CasePhaseType.appeal;
    int? selectedCourtId;
    final baseController = TextEditingController();
    final yearController = TextEditingController(text: DateTime.now().year.toString());
    final descriptionController = TextEditingController(text: 'نقل للمرحلة القضائية التالية مع المبرزات السابقة.');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('نقل الدعوى إلى مرحلة قضائية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CasePhaseType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'المرحلة الجديدة'),
                  items: CasePhaseType.values
                      .map((type) => DropdownMenuItem(value: type, child: Text(type.displayName)))
                      .toList(),
                  onChanged: (type) {
                    if (type != null) {
                      setLocalState(() => selectedType = type);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // اختيار محكمة حقيقية لأن النقل يتطلب معرّف محكمة في قاعدة البيانات.
                ref.watch(activeCourtsProvider(null)).maybeWhen(
                      data: (courts) => DropdownButtonFormField<int>(
                        value: selectedCourtId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'المحكمة الجديدة *'),
                        items: courts
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setLocalState(() => selectedCourtId = v),
                      ),
                      orElse: () => const LinearProgressIndicator(),
                    ),
                const SizedBox(height: 12),
                TextField(controller: baseController, decoration: const InputDecoration(labelText: 'رقم الأساس الجديد')),
                const SizedBox(height: 12),
                TextField(controller: yearController, decoration: const InputDecoration(labelText: 'سنة الأساس')),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (selectedCourtId == null) {
                  _showSnack('اختر المحكمة الجديدة أولاً.', isError: true);
                  return;
                }
                // النقل الفعلي: يغلق المرحلة الحالية وينشئ المرحلة الأعلى
                // وينقل القرار والثبوتيات حسب القاعدة الذهبية.
                try {
                  await ref.read(caseRepositoryProvider).transferToNextPhase(
                        caseId: widget.caseId,
                        newPhaseType: selectedType.displayName,
                        newCourtId: selectedCourtId!,
                        newBaseNumber: baseController.text.trim().isEmpty ? null : baseController.text.trim(),
                        newYear: int.tryParse(yearController.text.trim()),
                        userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
                      );
                } catch (e) {
                  _showSnack('تعذر نقل المرحلة: $e', isError: true);
                  return;
                }
                ref.invalidate(allCasesProvider);
                ref.invalidate(uiCasesProvider);
                ref.invalidate(caseDetailProvider(widget.caseId));
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                _showSnack('تم نقل الدعوى إلى المرحلة الجديدة.');
              },
              child: const Text('حفظ المرحلة'),
            ),
          ],
        ),
      ),
    );

  }

  Future<void> _pickAndAddDocument(CaseDetailState state) async {
    final caseItem = state.caseItem!;
    final caseId = int.tryParse(caseItem.id);
    if (caseId == null) {
      _showSnack('تعذر تحديد رقم الدعوى لحفظ المستند.', isError: true);
      return;
    }
    final result = await file_picker.FilePicker.platform.pickFiles(allowMultiple: false);
    final picked = result?.files.firstOrNull;
    final path = picked?.path;
    if (picked == null || path == null || path.isEmpty) return;

    // الحفظ الفعلي في قاعدة البيانات وتخزين نسخة الملف، بدل إضافته
    // إلى حالة الشاشة فقط حيث كان يضيع عند إعادة فتح الدعوى.
    try {
      await ref.read(documentRepositoryProvider).addDocument(
            docName: picked.name,
            docType: 'case_document',
            fileType: picked.extension?.toLowerCase(),
            summary: 'مستند مرفوع من ملف الدعوى',
            sourceFile: File(path),
            entityType: EntityType.caseEntity.index,
            entityId: caseId,
            userRef: ref.read(authControllerProvider).user?.fullName ?? 'مكتب المحامي',
          );
    } catch (e) {
      _showSnack('تعذر حفظ المستند: $e', isError: true);
      return;
    }

    ref.invalidate(uiDocumentsProvider);
    _showSnack('تم رفع وربط المستند بالدعوى.');
  }

  /// ربط مستند موجود فعلاً في الأرشيف العام بهذه الدعوى.
  ///
  /// سابقاً كان هذا الزر يخترع مستنداً وهمياً (linked_document.pdf) ويضيفه
  /// إلى حالة الشاشة فقط، فيختفي عند إعادة فتح الدعوى.
  Future<void> _linkGlobalDocument(CaseDetailState state) async {
    final allDocs = await ref.read(uiDocumentsProvider.future);
    final linkedIds = allDocs
        .where((d) => d.entityType == 'case' && d.entityId == '${widget.caseId}')
        .map((d) => d.id)
        .toSet();
    final candidates = allDocs.where((d) => !linkedIds.contains(d.id)).toList();

    if (!mounted) return;
    if (candidates.isEmpty) {
      _showSnack('لا توجد مستندات غير مرتبطة بهذه الدعوى.', isError: true);
      return;
    }

    final search = TextEditingController();
    final selected = await showDialog<DocumentItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final query = search.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? candidates
              : candidates.where((d) => d.title.toLowerCase().contains(query)).toList();
          return AlertDialog(
            title: const Text('ربط مستند من الأرشيف'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(labelText: 'بحث', prefixIcon: Icon(Icons.search)),
                    onChanged: (_) => setDialog(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('لا توجد نتائج مطابقة'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => ListTile(
                              leading: const Icon(Icons.description),
                              title: Text(filtered[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(filtered[i].entityTitle),
                              onTap: () => Navigator.pop(ctx, filtered[i]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء'))],
          );
        },
      ),
    );

    if (selected == null) return;
    final documentId = int.tryParse(selected.id);
    if (documentId == null) {
      _showSnack('معرّف المستند غير صالح.', isError: true);
      return;
    }

    try {
      await ref.read(documentRepositoryProvider).linkExistingDocument(
            documentId: documentId,
            entityType: EntityType.caseEntity.index,
            entityId: widget.caseId,
          );
    } catch (e) {
      _showSnack('تعذر ربط المستند: $e', isError: true);
      return;
    }
    ref.invalidate(uiDocumentsProvider);
    _showSnack('تم ربط المستند بالدعوى.');
  }

  Future<void> _confirmDeleteDocument(DocumentItem document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف ربط المستند'),
        content: Text('هل تريد حذف ربط المستند "${document.title}" من الدعوى؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final documentId = int.tryParse(document.id);
    if (documentId == null) {
      _showSnack('معرّف المستند غير صالح.', isError: true);
      return;
    }
    try {
      // يُفَك الربط فقط؛ المستند يبقى محفوظاً في الأرشيف العام.
      await ref.read(documentRepositoryProvider).unlinkDocument(
            documentId: documentId,
            entityType: EntityType.caseEntity.index,
            entityId: widget.caseId,
          );
    } catch (e) {
      _showSnack('تعذر حذف الربط: $e', isError: true);
      return;
    }
    ref.invalidate(uiDocumentsProvider);
    _showSnack('تم حذف ربط المستند.');
  }

  Future<void> _showAddDeficiencyDialog(BuildContext context) async {
    final fieldController = TextEditingController();
    final descriptionController = TextEditingController();
    String severity = 'medium';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('إضافة نقص جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: fieldController, decoration: const InputDecoration(labelText: 'نوع النقص')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(labelText: 'الأولوية'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('منخفضة')),
                    DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
                    DropdownMenuItem(value: 'high', child: Text('عالية')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setLocalState(() => severity = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final field = fieldController.text.trim();
                final description = descriptionController.text.trim();
                if (field.isEmpty || description.isEmpty) {
                  _showSnack('يرجى إدخال نوع النقص والوصف.', isError: true);
                  return;
                }
                // الحفظ في جدول deficiencies حتى يظهر النقص في مكتب العمل
                // وكشف الملفات الناقصة، لا في حالة الشاشة فقط.
                try {
                  await ref.read(taskRepositoryProvider).addManualDeficiency(
                        entityType: EntityType.caseEntity,
                        entityId: widget.caseId,
                        fieldName: field,
                        description: description,
                        severity: severity == 'high' ? 0 : 1,
                      );
                } catch (e) {
                  _showSnack('تعذر حفظ النقص: $e', isError: true);
                  return;
                }
                ref.invalidate(openDeficienciesProvider(null));
                ref.invalidate(caseDetailProvider(widget.caseId));
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                _showSnack('تمت إضافة النقص.');
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    fieldController.dispose();
    descriptionController.dispose();
  }

  void _showFinancialReport(CaseDetailState state) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تقرير مالي مختصر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('إجمالي الأتعاب', _formatCurrency(state.totalFees)),
            _infoRow('إجمالي المصروفات', _formatCurrency(state.totalExpenses)),
            _infoRow('الرصيد الحالي', _formatCurrency(state.balance)),
            const SizedBox(height: 8),
            Text('التقرير جاهز للطباعة أو التصدير من شاشة المالية الموحدة.', style: AppTextStyles.bodySmallSecondary),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _terminateCase(CaseDetailState state) async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.casesClose)) {
      await ref.read(auditServiceProvider).log(
        action: 'access_denied',
        category: 'cases',
        entityType: 'case',
        entityId: '${widget.caseId}',
        entityTitle: state.caseItem?.title ?? 'دعوى #${widget.caseId}',
        description: 'محاولة إنهاء دعوى دون صلاحية',
        severity: 'warning',
      );
      _showSnack('لا تملك صلاحية إنهاء الدعوى.', isError: true);
      return;
    }
    if (!_terminationConfirmed) {
      _showSnack('يجب تأكيد مراجعة الملف قبل الإنهاء.', isError: true);
      return;
    }
    final summary = _terminationSummaryController.text.trim();
    if (summary.isEmpty) {
      _showSnack('ملخص القرار النهائي إلزامي.', isError: true);
      return;
    }

    // الإغلاق الفعلي في قاعدة البيانات: يحدّث حالة الدعوى إلى closed
    // ويغلق ملف المكتب المرتبط. سابقاً كان يعدّل حالة الشاشة فقط،
    // فتعود الدعوى مفتوحة عند إعادة فتحها.
    try {
      await ref.read(caseRepositoryProvider).terminateCase(
            caseId: widget.caseId,
            terminationReason: _selectedClosureResult.displayName,
            decisionNumber: _terminationNumberController.text.trim(),
            decisionDate: DateTime.now(),
            summary: summary,
            userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
          );
    } catch (e) {
      _showSnack('تعذر إنهاء الدعوى: $e', isError: true);
      return;
    }
    ref.invalidate(allCasesProvider);
    ref.invalidate(uiCasesProvider);
    ref.invalidate(uiFilesProvider);
    ref.invalidate(caseDetailProvider(widget.caseId));
    await ref.read(auditServiceProvider).log(
      action: 'close',
      category: 'cases',
      entityType: 'case',
      entityId: '${widget.caseId}',
      entityTitle: state.caseItem?.title ?? 'دعوى #${widget.caseId}',
      description: 'إنهاء الدعوى',
      after: {
        'result': _selectedClosureResult.displayName,
        'decisionNumber': _terminationNumberController.text.trim(),
        'summary': summary,
      },
      severity: 'critical',
    );
    setState(() => _terminationConfirmed = false);
    _showSnack('تم إنهاء الدعوى وإضافة الحدث إلى الخط الزمني.');
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')} ل.س';
  }

  String _statusArabic(String status) {
    switch (status) {
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغى';
      case 'pending':
      default:
        return 'قيد المتابعة';
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
        return AppColors.error;
      case 'low':
        return AppColors.info;
      case 'medium':
      default:
        return AppColors.warning;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'high':
        return 'عالية';
      case 'low':
        return 'منخفضة';
      case 'medium':
      default:
        return 'متوسطة';
    }
  }

  IconData _timelineIcon(String eventType) {
    if (eventType.contains('session')) {
      return Icons.event;
    }
    if (eventType.contains('document')) {
      return Icons.description;
    }
    if (eventType.contains('fee') || eventType.contains('expense')) {
      return Icons.payments;
    }
    if (eventType.contains('deficiency')) {
      return Icons.rule;
    }
    if (eventType.contains('termination')) {
      return Icons.lock;
    }
    if (eventType.contains('phase')) {
      return Icons.account_tree;
    }
    return Icons.history;
  }

  Color _timelineColor(String eventType) {
    if (eventType.contains('session')) {
      return AppColors.info;
    }
    if (eventType.contains('document')) {
      return AppColors.primaryNavy;
    }
    if (eventType.contains('fee')) {
      return AppColors.success;
    }
    if (eventType.contains('expense')) {
      return AppColors.error;
    }
    if (eventType.contains('deficiency')) {
      return eventType.contains('resolved') ? AppColors.success : AppColors.warning;
    }
    if (eventType.contains('termination')) {
      return AppColors.error;
    }
    if (eventType.contains('phase')) {
      return AppColors.secondaryGold;
    }
    return AppColors.textSecondary;
  }

  String _eventArabic(String eventType) {
    if (eventType.contains('created')) {
      return 'إنشاء';
    }
    if (eventType.contains('session')) {
      return 'جلسة';
    }
    if (eventType.contains('document')) {
      return 'مستند';
    }
    if (eventType.contains('fee') || eventType.contains('expense')) {
      return 'مالية';
    }
    if (eventType.contains('deficiency')) {
      return 'نقص';
    }
    if (eventType.contains('termination')) {
      return 'إنهاء';
    }
    if (eventType.contains('phase')) {
      return 'مرحلة';
    }
    return 'حدث';
  }
}

extension _FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}
