import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/app_enums.dart';
import '../../data/database/database.dart' as db;
import '../../data/repositories/office_file_repository.dart';
import '../screens/cases/case_models.dart' as ui_case;
import '../screens/documents/document_models.dart' as ui_doc;
import '../screens/files/files_screen.dart' as ui_files;
import '../screens/persons/person_models.dart' as ui_person;
import '../screens/work_orders/work_order_models.dart' as ui_wo;
import 'app_providers.dart';

// =============================================================================
// Bootstrap seeds for remaining modules
// =============================================================================

/// هل يُسمح ببذر بيانات تجريبية؟ (يُفعّل فقط من معالج أول تشغيل عند اختيار الزبون)
final allowDemoSeedProvider = StateProvider<bool>((ref) => false);

final coreDataBootstrapProvider = FutureProvider<void>((ref) async {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  await settingsRepo.ensureDefaults();

  // لا تُزرع بيانات تجريبية تلقائياً — فقط عند السماح الصريح.
  final allowDemo = ref.watch(allowDemoSeedProvider);
  if (!allowDemo) return;

  final personRepo = ref.watch(personRepositoryProvider);
  final caseRepo = ref.watch(caseRepositoryProvider);
  final docRepo = ref.watch(documentRepositoryProvider);
  final woRepo = ref.watch(workOrderRepositoryProvider);
  final financeRepo = ref.watch(financeRepositoryProvider);
  final legalRepo = ref.watch(legalLibraryRepositoryProvider);

  await personRepo.seedDemoIfEmpty();
  await caseRepo.seedDemoIfEmpty();
  await docRepo.seedDemoIfEmpty();
  await woRepo.seedDemoIfEmpty();
  await financeRepo.seedDemoIfEmpty();
  await legalRepo.seedDemoIfEmpty();
});

// =============================================================================
// Cases (UI model)
// =============================================================================

ui_case.CaseType _mapCaseType(String raw) {
  final v = raw.trim();
  if (v.contains('جزائ')) return ui_case.CaseType.criminal;
  if (v.contains('تجار')) return ui_case.CaseType.commercial;
  if (v.contains('شرع')) return ui_case.CaseType.personalStatus;
  if (v.contains('إدار')) return ui_case.CaseType.civil;
  return ui_case.CaseType.civil;
}

ui_case.CaseStatus _mapCaseStatus(String raw) {
  switch (raw) {
    case 'closed':
      return ui_case.CaseStatus.completed;
    case 'pending_registration':
      return ui_case.CaseStatus.postponed;
    case 'preparing':
      return ui_case.CaseStatus.scheduled;
    default:
      return ui_case.CaseStatus.inProgress;
  }
}

final uiCasesProvider = StreamProvider<List<ui_case.Case>>((ref) async* {
  await ref.watch(coreDataBootstrapProvider.future);
  final caseRepo = ref.watch(caseRepositoryProvider);
  
  await for (final cases in ref.watch(allCasesProvider.stream)) {
    final result = await Future.wait(cases.map((c) async {
      final sessions = await caseRepo.getSessionsForCase(c.id);
      final phases = await caseRepo.getPhasesForCase(c.id);
      final court = c.courtId != null ? await caseRepo.getCourtById(c.courtId!) : null;
      final courtName = court?.name ?? 'محكمة';

      final uiSessions = sessions.map((s) => ui_case.CaseSession(
        id: '${s.id}',
        sessionDate: s.sessionDate,
        sessionTime: _parseTime(s.sessionTime) ?? const TimeOfDay(hour: 9, minute: 0),
        type: ui_case.SessionType.ordinary,
        status: s.status == 2 ? ui_case.SessionStatus.held : ui_case.SessionStatus.scheduled,
        court: courtName,
      )).toList();

      final uiPhases = phases.map((p) => ui_case.CasePhase(
        id: '${p.id}',
        type: ui_case.CasePhaseType.initial,
        court: courtName,
        baseNumber: p.baseNumber ?? '',
        baseYear: p.year ?? c.year,
        startDate: p.startDate ?? c.createdAt,
      )).toList();

      return ui_case.Case(
        id: '${c.id}',
        caseNumber: c.internalNumber,
        title: c.subject ?? c.internalNumber,
        type: _mapCaseType(c.caseType),
        status: _mapCaseStatus(c.status),
        court: courtName,
        subject: c.subject ?? '',
        claim: c.subjectDetails ?? '',
        notes: c.notes ?? '',
        creationDate: c.createdAt,
        lastUpdated: c.updatedAt,
        baseNumber: c.baseNumber,
        baseYear: c.year,
        sessions: uiSessions,
        phases: uiPhases,
      );
    }));
    yield result;
  }
});

TimeOfDay? _parseTime(String? raw) {
  if (raw == null || !raw.contains(':')) return null;
  final parts = raw.split(':');
  return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
}

// =============================================================================
// Documents
// =============================================================================

ui_doc.DocumentType _mapDocType(String? raw) {
  final v = (raw ?? '').toLowerCase();
  if (v.contains('poa') || v.contains('وكال') || v.contains('power')) return ui_doc.DocumentType.powerOfAttorney;
  if (v.contains('contract') || v.contains('عقد')) return ui_doc.DocumentType.contract;
  if (v.contains('memo') || v.contains('مذكر')) return ui_doc.DocumentType.memo;
  if (v.contains('decision') || v.contains('قرار')) return ui_doc.DocumentType.decision;
  if (v.contains('receipt') || v.contains('إيص')) return ui_doc.DocumentType.receipt;
  return ui_doc.DocumentType.caseDocument;
}

ui_doc.FileType _mapFileType(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'pdf':
      return ui_doc.FileType.pdf;
    case 'docx':
      return ui_doc.FileType.docx;
    case 'doc':
      return ui_doc.FileType.doc;
    case 'jpg':
    case 'jpeg':
      return ui_doc.FileType.jpg;
    case 'png':
      return ui_doc.FileType.png;
    case 'txt':
      return ui_doc.FileType.txt;
    case 'rtf':
      return ui_doc.FileType.rtf;
    default:
      return ui_doc.FileType.other;
  }
}

String _paperArchiveLocationFromMetadata(Map<String, dynamic>? metadata, String? notes, int physicalLocation) {
  if (metadata != null) {
    final parts = <String>[
      (metadata['paper_location'] as String?)?.trim() ?? '',
      if (((metadata['box'] as String?)?.trim() ?? '').isNotEmpty) 'صندوق ${(metadata['box'] as String).trim()}',
      if (((metadata['shelf'] as String?)?.trim() ?? '').isNotEmpty) 'رف ${(metadata['shelf'] as String).trim()}',
      if (((metadata['paper_folder'] as String?)?.trim() ?? '').isNotEmpty) 'مجلد ${(metadata['paper_folder'] as String).trim()}',
    ].where((value) => value.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' • ');
  }
  return _paperArchiveLocation(notes, physicalLocation);
}

bool _isPaperOriginalMissingFromMetadata(Map<String, dynamic>? metadata, String? notes, int status) {
  if (metadata != null) {
    final saved = ((metadata['paper_original_saved'] as int?) ?? 0) == 1;
    return !saved || status != 0;
  }
  return _isPaperOriginalMissing(notes, status);
}

String? _mergePaperMetadataNotes(Map<String, dynamic>? metadata, String? existingNotes) {
  if (metadata == null) return existingNotes;
  final lines = <String>[
    if ((existingNotes ?? '').trim().isNotEmpty) existingNotes!.trim(),
    'الأصل الورقي محفوظ: ${((metadata['paper_original_saved'] as int?) ?? 0) == 1 ? 'نعم' : 'لا'}',
    if (((metadata['paper_location'] as String?) ?? '').trim().isNotEmpty) 'مكان الأصل: ${(metadata['paper_location'] as String).trim()}',
    if (((metadata['box'] as String?) ?? '').trim().isNotEmpty) 'الصندوق: ${(metadata['box'] as String).trim()}',
    if (((metadata['shelf'] as String?) ?? '').trim().isNotEmpty) 'الرف: ${(metadata['shelf'] as String).trim()}',
    if (((metadata['paper_folder'] as String?) ?? '').trim().isNotEmpty) 'المجلد الورقي: ${(metadata['paper_folder'] as String).trim()}',
    'يجوز إتلاف الأصل: ${((metadata['can_destroy_original'] as int?) ?? 0) == 1 ? 'نعم' : 'لا'}',
    if (((metadata['reviewed_by'] as String?) ?? '').trim().isNotEmpty) 'راجع النسخة الرقمية: ${(metadata['reviewed_by'] as String).trim()}',
  ];
  return lines.join('\n');
}

String _paperArchiveLocation(String? notes, int physicalLocation) {
  final raw = notes ?? '';
  String pick(String prefix) {
    final line = raw.split('\n').firstWhere(
          (item) => item.startsWith(prefix),
          orElse: () => '',
        );
    return line.replaceFirst(prefix, '').trim();
  }

  final parts = <String>[
    pick('مكان الأصل:'),
    if (pick('الصندوق:').isNotEmpty) 'صندوق ${pick('الصندوق:')}',
    if (pick('الرف:').isNotEmpty) 'رف ${pick('الرف:')}',
    if (pick('المجلد الورقي:').isNotEmpty) 'مجلد ${pick('المجلد الورقي:')}',
  ].where((value) => value.isNotEmpty).toList();
  if (parts.isNotEmpty) return parts.join(' • ');
  return physicalLocation == 0 ? 'مكتب المحامي' : 'خارج المكتب';
}

bool _isPaperOriginalMissing(String? notes, int status) {
  final raw = notes ?? '';
  return status != 0 || raw.contains('الأصل الورقي محفوظ: لا');
}

String _documentEntityKey(int entityType) {
  if (entityType == EntityType.contract.index) return 'contract';
  if (entityType == EntityType.company.index) return 'company';
  if (entityType == EntityType.adminProcedure.index) return 'adminProcedure';
  if (entityType == EntityType.person.index) return 'person';
  if (entityType == EntityType.powerOfAttorney.index) return 'poa';
  return 'case';
}

String _documentEntityTitle(int entityType, int entityId) {
  if (entityType == EntityType.contract.index) return 'عقد #$entityId';
  if (entityType == EntityType.company.index) return 'شركة #$entityId';
  if (entityType == EntityType.adminProcedure.index) return 'إجراء #$entityId';
  if (entityType == EntityType.person.index) return 'شخص / جهة #$entityId';
  if (entityType == EntityType.powerOfAttorney.index) return 'وكالة #$entityId';
  if (entityType == 99) return 'أرشيف غير مصنف';
  return 'دعوى #$entityId';
}

final uiDocumentsProvider = FutureProvider<List<ui_doc.DocumentItem>>((ref) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final repo = ref.watch(documentRepositoryProvider);
  final docs = await repo.getAllDocuments();
  final links = await repo.getAllLinks();
  final byDoc = <int, db.DocumentLink>{};
  for (final l in links) {
    byDoc.putIfAbsent(l.documentId, () => l);
  }
  final database = ref.watch(databaseProvider);
  await database.ensureArchiveTables();
  final paperRows = await database.customSelect('SELECT * FROM document_paper_metadata').get();
  final paperByDoc = <int, Map<String, dynamic>>{};
  for (final row in paperRows) {
    final docId = row.data['document_id'] as int?;
    if (docId != null) paperByDoc[docId] = row.data;
  }

  return docs.map((d) {
    final link = byDoc[d.id];
    final entityType = link?.entityType ?? 0;
    final entityId = link?.entityId ?? 0;
    final paper = paperByDoc[d.id];
    final notes = _mergePaperMetadataNotes(paper, d.notes);
    final originalMissing = _isPaperOriginalMissingFromMetadata(paper, d.notes, d.status);
    return ui_doc.DocumentItem(
      id: '${d.id}',
      title: d.docName,
      documentType: _mapDocType(d.docType),
      entityType: _documentEntityKey(entityType),
      entityId: '$entityId',
      entityTitle: _documentEntityTitle(entityType, entityId),
      filePath: d.filePath ?? '',
      fileName: d.filePath?.split('/').last ?? d.docName,
      fileSize: 0,
      fileType: _mapFileType(d.fileType),
      uploadDate: d.dateAdded,
      uploadedBy: 'المكتب',
      physicalLocation: _paperArchiveLocationFromMetadata(paper, d.notes, d.physicalLocation),
      hasOriginal: !originalMissing,
      isMissingOriginal: originalMissing,
      notes: notes ?? '',
    );
  }).toList();
});

// =============================================================================
// Files archive (unified)
// =============================================================================

final uiFilesProvider = FutureProvider<List<ui_files.FileItem>>((ref) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final docs = await ref.watch(uiDocumentsProvider.future);
  final officeRepo = ref.watch(officeFileRepositoryProvider);

  // 1) تجميع الكيانات التشغيلية الحالية (تفاصيل العرض تأتي منها).
  final cases = await ref.watch(uiCasesProvider.future);
  final contracts = await ref.watch(allContractsProvider.future);
  final companies = await ref.watch(allCompaniesProvider.future);
  final procedures = await ref.watch(allProceduresProvider.future);
  final directory = await ref.watch(uiPersonsDirectoryProvider.future);

  // 2) استكمال ملفات المكتب للكيانات القديمة التي أُنشئت قبل اعتماد OfficeFiles،
  //    حتى يصبح جدول office_files مصدر الحقيقة الفعلي لشاشة الملفات.
  Future<void> backfill({
    required OfficeFileType fileType,
    required int entityType,
    required int entityId,
    required String title,
    required bool isClosed,
    required DateTime createdAt,
    String? fallbackNumber,
  }) async {
    await officeRepo.ensureOfficeFileForEntity(
      fileType: fileType,
      entityType: entityType,
      entityId: entityId,
      title: title,
      status: isClosed ? OfficeFileStatus.closed : OfficeFileStatus.active,
      targetYear: createdAt.year,
      fallbackNumber: fallbackNumber,
    );
  }

  for (final c in cases) {
    await backfill(
      fileType: OfficeFileType.caseFile,
      entityType: EntityType.caseEntity.index,
      entityId: int.tryParse(c.id) ?? 0,
      title: c.title,
      isClosed: c.status == ui_case.CaseStatus.completed,
      createdAt: c.creationDate,
      fallbackNumber: c.caseNumber,
    );
  }
  for (final c in contracts) {
    final end = c.dateEnd;
    await backfill(
      fileType: OfficeFileType.contract,
      entityType: EntityType.contract.index,
      entityId: c.id,
      title: c.title,
      isClosed: c.status != 'active' || (end != null && end.isBefore(DateTime.now())),
      createdAt: c.createdAt,
      fallbackNumber: c.internalNumber,
    );
  }
  for (final c in companies) {
    await backfill(
      fileType: OfficeFileType.company,
      entityType: EntityType.company.index,
      entityId: c.id,
      title: c.name,
      isClosed: c.isArchived || c.legalStatus == 'dissolved' || c.legalStatus == 'archived',
      createdAt: c.createdAt,
      fallbackNumber: c.internalNumber,
    );
  }
  for (final p in procedures) {
    await backfill(
      fileType: OfficeFileType.procedure,
      entityType: EntityType.adminProcedure.index,
      entityId: p.id,
      title: p.title,
      isClosed: p.status == 2,
      createdAt: p.createdAt,
      fallbackNumber: p.internalNumber,
    );
  }
  for (final a in directory.agencies) {
    await backfill(
      fileType: OfficeFileType.agency,
      entityType: EntityType.powerOfAttorney.index,
      entityId: int.tryParse(a.id) ?? 0,
      title: 'وكالة ${a.type.displayName}',
      isClosed: a.isExpired,
      createdAt: a.issuedAt,
      fallbackNumber: a.number,
    );
  }

  // 3) office_files هو المصدر: نقرأ السجلات ثم نُلبسها تفاصيل الكيان المرتبط.
  final officeFiles = await officeRepo.getAll();

  final casesById = {for (final c in cases) c.id: c};
  final contractsById = {for (final c in contracts) c.id: c};
  final companiesById = {for (final c in companies) c.id: c};
  final proceduresById = {for (final p in procedures) p.id: p};
  final agenciesById = {for (final a in directory.agencies) a.id: a};

  ui_files.FileStatus mapStatus(OfficeFileRecord office) =>
      office.status == OfficeFileStatus.closed ? ui_files.FileStatus.completed : ui_files.FileStatus.active;

  // المؤشر المالي لكل ملف، محسوب من الاتفاقيات والدفعات والمصاريف الحقيقية.
  final financeRepo = ref.watch(financeRepositoryProvider);
  final allAgreements = await financeRepo.getAllAgreements();
  final allPayments = await financeRepo.getAllPayments();
  final allExpenses = await financeRepo.getAllExpenses();

  final paidByAgreement = <int, double>{};
  for (final p in allPayments) {
    paidByAgreement.update(p.agreementId, (v) => v + p.amount, ifAbsent: () => p.amount);
  }

  ui_files.FileFinanceStatus financeStatusFor(int entityType, int entityId) {
    final agreements =
        allAgreements.where((a) => a.entityType == entityType && a.entityId == entityId).toList();
    final expenses =
        allExpenses.where((e) => e.entityType == entityType && e.entityId == entityId).toList();

    if (agreements.isEmpty && expenses.isEmpty) return ui_files.FileFinanceStatus.none;

    final total = agreements.fold<double>(0, (sum, a) => sum + a.totalAmount);
    final paid = agreements.fold<double>(0, (sum, a) => sum + (paidByAgreement[a.id] ?? 0));
    final expensesTotal = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    // دفعات تتجاوز الاتفاق أو مبالغ سالبة تعني خللاً يحتاج مراجعة بشرية.
    if (paid > total || total < 0 || expensesTotal < 0) {
      return ui_files.FileFinanceStatus.needsReview;
    }
    if (agreements.isEmpty && expensesTotal > 0) {
      return ui_files.FileFinanceStatus.unpaidExpenses;
    }
    if (total > 0 && paid <= 0) return ui_files.FileFinanceStatus.openFees;
    if (paid > 0 && paid < total) return ui_files.FileFinanceStatus.partiallyPaid;
    if (total > 0 && paid >= total) return ui_files.FileFinanceStatus.fullyPaid;
    return ui_files.FileFinanceStatus.none;
  }

  final result = <ui_files.FileItem>[];

  for (final office in officeFiles) {
    final entityId = office.linkedEntityId;
    // ملف مكتب بلا كيان مرتبط لا يُعرض في شاشة الملفات التشغيلية.
    if (entityId == null || office.linkedEntityType == null) continue;
    final status = mapStatus(office);
    final entityKey = '$entityId';

    switch (office.fileType) {
      case OfficeFileType.caseFile:
        final c = casesById[entityKey];
        if (c == null) continue;
        final relatedDocs = docs.where((d) => d.entityType == 'case' && d.entityId == c.id).toList();
        final next = c.nextSession?.sessionDate ??
            c.sessions
                .where((s) => s.sessionDate.isAfter(DateTime.now()))
                .map((s) => s.sessionDate)
                .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
        final hasBase = (c.baseNumber ?? '').isNotEmpty;
        final deficient = c.openDeficienciesCount > 0 || !hasBase;
        result.add(ui_files.FileItem(
          id: c.id,
          fileNumber: office.fileNumber,
          title: c.title,
          type: ui_files.FileType.caseFile,
          court: c.court,
          subCategory: c.type.displayName,
          status: status,
          hasDeficiencies: deficient,
          deficiencyCount: c.openDeficienciesCount,
          nextSessionDate: next,
          baseNumber: c.baseNumber,
          hasBaseNumber: hasBase,
          isOverdue: next != null && next.isBefore(DateTime.now()),
          createdAt: c.creationDate,
          lastUpdated: c.lastUpdated ?? c.creationDate,
          documentCount: relatedDocs.length,
          documentIds: relatedDocs.map((d) => d.id).toList(),
          hasMissingDocuments: relatedDocs.any((d) => d.isMissingOriginal) || office.hasPendingPaperOriginal,
          financeStatus: financeStatusFor(office.linkedEntityType!, entityId),
        ));
        break;

      case OfficeFileType.contract:
        final c = contractsById[entityId];
        if (c == null) continue;
        final relatedDocs = docs.where((d) => d.entityType == 'contract' && d.entityId == entityKey).toList();
        final end = c.dateEnd;
        result.add(ui_files.FileItem(
          id: entityKey,
          fileNumber: office.fileNumber,
          title: c.title,
          type: ui_files.FileType.contract,
          court: c.contractType,
          subCategory: c.contractType,
          status: status,
          nextSessionDate: c.needsFollowup ? end : null,
          hasBaseNumber: true,
          isOverdue: end != null && end.isBefore(DateTime.now()) && status != ui_files.FileStatus.completed,
          createdAt: c.createdAt,
          lastUpdated: c.updatedAt,
          documentCount: relatedDocs.length,
          documentIds: relatedDocs.map((d) => d.id).toList(),
          hasMissingDocuments: relatedDocs.any((d) => d.isMissingOriginal) || office.hasPendingPaperOriginal,
          financeStatus: financeStatusFor(office.linkedEntityType!, entityId),
        ));
        break;

      case OfficeFileType.company:
        final c = companiesById[entityId];
        if (c == null) continue;
        final relatedDocs = docs.where((d) => d.entityType == 'company' && d.entityId == entityKey).toList();
        final deficient = (c.registrationNumber ?? '').isEmpty && status != ui_files.FileStatus.completed;
        result.add(ui_files.FileItem(
          id: entityKey,
          fileNumber: office.fileNumber,
          title: c.name,
          type: ui_files.FileType.company,
          court: c.companyType,
          subCategory: c.companyType,
          status: status,
          hasDeficiencies: deficient,
          deficiencyCount: deficient ? 1 : 0,
          hasBaseNumber: (c.registrationNumber ?? '').isNotEmpty,
          baseNumber: c.registrationNumber,
          createdAt: c.createdAt,
          lastUpdated: c.createdAt,
          documentCount: relatedDocs.length,
          documentIds: relatedDocs.map((d) => d.id).toList(),
          hasMissingDocuments: deficient || relatedDocs.any((d) => d.isMissingOriginal) || office.hasPendingPaperOriginal,
          financeStatus: financeStatusFor(office.linkedEntityType!, entityId),
        ));
        break;

      case OfficeFileType.procedure:
        final p = proceduresById[entityId];
        if (p == null) continue;
        final relatedDocs = docs.where((d) => d.entityType == 'adminProcedure' && d.entityId == entityKey).toList();
        final next = p.nextDate;
        result.add(ui_files.FileItem(
          id: entityKey,
          fileNumber: office.fileNumber,
          title: p.title,
          type: ui_files.FileType.adminProcedure,
          court: p.department ?? p.procedureType,
          subCategory: p.procedureType,
          status: status,
          nextSessionDate: next,
          hasBaseNumber: (p.transactionNumber ?? '').isNotEmpty,
          baseNumber: p.transactionNumber,
          isOverdue: next != null && next.isBefore(DateTime.now()) && status != ui_files.FileStatus.completed,
          createdAt: p.createdAt,
          lastUpdated: p.createdAt,
          documentCount: relatedDocs.length,
          documentIds: relatedDocs.map((d) => d.id).toList(),
          hasMissingDocuments: relatedDocs.any((d) => d.isMissingOriginal) || office.hasPendingPaperOriginal,
          financeStatus: financeStatusFor(office.linkedEntityType!, entityId),
        ));
        break;

      case OfficeFileType.agency:
        final a = agenciesById[entityKey];
        if (a == null) continue;
        final relatedDocs = docs.where((d) => d.entityType == 'poa' && d.entityId == a.id).toList();
        result.add(ui_files.FileItem(
          id: a.id,
          fileNumber: office.fileNumber,
          title: 'وكالة ${a.type.displayName} — ${directory.personById(a.principalPersonId)?.fullName ?? 'غير محدد'}',
          type: ui_files.FileType.agency,
          court: '${a.source.displayName} - ${a.branch}',
          subCategory: a.type.displayName,
          status: status,
          nextSessionDate: a.expiresAt,
          hasBaseNumber: a.number.isNotEmpty,
          baseNumber: a.number,
          hasMissingDocuments: !a.hasDocument || relatedDocs.any((d) => d.isMissingOriginal) || office.hasPendingPaperOriginal,
          financeStatus: financeStatusFor(office.linkedEntityType!, entityId),
          createdAt: a.issuedAt,
          lastUpdated: a.issuedAt,
          documentCount: relatedDocs.isNotEmpty ? relatedDocs.length : (a.hasDocument ? 1 : 0),
          documentIds: relatedDocs.isNotEmpty ? relatedDocs.map((d) => d.id).toList() : (a.hasDocument ? [a.documentId] : const []),
        ));
        break;
    }
  }

  result.sort((a, b) => (a.nextSessionDate ?? DateTime(9999)).compareTo(b.nextSessionDate ?? DateTime(9999)));
  return result;
});

// =============================================================================
// Office Files Live Counts (for Sidebar Badges)
// =============================================================================

final officeFileCountsProvider = FutureProvider<({int active, int closed, int needsCompletion})>((ref) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final officeRepo = ref.watch(officeFileRepositoryProvider);
  final allFiles = await officeRepo.getAll();

  final active = allFiles.where((f) => f.status == OfficeFileStatus.active).length;
  final closed = allFiles.where((f) => f.status == OfficeFileStatus.closed).length;

  // We approximate "needs completion" by files that have pending flags
  final needs = allFiles.where((f) =>
    f.status == OfficeFileStatus.active &&
    (f.hasPendingFinance || f.hasPendingPaperOriginal || f.hasPostClosureActions)
  ).length;

  return (active: active, closed: closed, needsCompletion: needs);
});

// =============================================================================
// Finance per entity (for case detail tab)
// =============================================================================

/// بيانات مالية مجمّعة لكيان واحد (دعوى/عقد/شركة/إجراء) مقروءة من قاعدة البيانات الحقيقية.
class EntityFinanceData {
  final double totalFees;
  final double totalExpenses;
  final double totalPaid;
  final List<ui_case.CaseFee> fees;
  final List<ui_case.CaseExpense> expenses;

  const EntityFinanceData({
    required this.totalFees,
    required this.totalExpenses,
    required this.totalPaid,
    required this.fees,
    required this.expenses,
  });

  double get remaining => totalFees - totalPaid;
}

/// تحويل مفتاح الكيان النصي المستخدم في الواجهة إلى EntityType الفعلي.
EntityType? _entityTypeFromKey(String key) {
  switch (key) {
    case 'case':
      return EntityType.caseEntity;
    case 'contract':
      return EntityType.contract;
    case 'company':
      return EntityType.company;
    case 'procedure':
    case 'admin_procedure':
      return EntityType.adminProcedure;
    case 'person':
      return EntityType.person;
    case 'poa':
    case 'agency':
      return EntityType.powerOfAttorney;
    default:
      return null;
  }
}

final financeByEntityProvider = FutureProvider.family<EntityFinanceData, (String, String)>((ref, params) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final entityType = _entityTypeFromKey(params.$1);
  final entityId = int.tryParse(params.$2);
  if (entityType == null || entityId == null || entityId <= 0) {
    return const EntityFinanceData(totalFees: 0, totalExpenses: 0, totalPaid: 0, fees: [], expenses: []);
  }

  final financeRepo = ref.watch(financeRepositoryProvider);
  final agreements = await financeRepo.getAgreementsByEntity(entityType.index, entityId);
  final payments = await financeRepo.getPaymentsByEntity(entityType.index, entityId);
  final dbExpenses = await financeRepo.getExpensesByEntity(entityType.index, entityId);

  final paidByAgreement = <int, double>{};
  for (final payment in payments) {
    paidByAgreement.update(payment.agreementId, (value) => value + payment.amount, ifAbsent: () => payment.amount);
  }

  final fees = agreements.map((a) {
    final paid = paidByAgreement[a.id] ?? 0;
    return ui_case.CaseFee(
      id: '${a.id}',
      clientId: '${a.partyId}',
      amount: a.totalAmount,
      currency: a.currency,
      agreementDate: a.createdAt,
      paymentDate: null,
      status: paid >= a.totalAmount && a.totalAmount > 0 ? 'paid' : 'unpaid',
      notes: a.notes ?? '',
    );
  }).toList();

  final expenses = dbExpenses
      .map((e) => ui_case.CaseExpense(
            id: '${e.id}',
            description: e.expenseType,
            amount: e.amount,
            expenseDate: e.expenseDate,
            category: e.expenseType,
            receipts: (e.receiptPath ?? '').isEmpty ? const <String>[] : [e.receiptPath!],
          ))
      .toList();

  final totalFees = fees.fold<double>(0, (sum, f) => sum + f.amount);
  final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);

  return EntityFinanceData(
    totalFees: totalFees,
    totalExpenses: totalExpenses,
    totalPaid: totalPaid,
    fees: fees,
    expenses: expenses,
  );
});

// =============================================================================
// Persons directory
// =============================================================================

final uiPersonsDirectoryProvider = FutureProvider<ui_person.PersonsDirectoryState>((ref) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final personRepo = ref.watch(personRepositoryProvider);
  final persons = await personRepo.getAllPersons();
  final poas = await personRepo.getAllPoas();

  final records = <ui_person.PersonDirectoryRecord>[];
  for (final p in persons) {
    final rolesDb = await personRepo.getPersonRoles(p.id);
    final roles = rolesDb.map((r) {
      if (r.roleType >= 0 && r.roleType < ui_person.PersonDirectoryRole.values.length) {
        // map subset
      }
      switch (r.roleType) {
        case 1:
          return ui_person.PersonDirectoryRole.opponent;
        case 4:
          return ui_person.PersonDirectoryRole.teamMember;
        case 5:
          return ui_person.PersonDirectoryRole.contractParty;
        default:
          return ui_person.PersonDirectoryRole.client;
      }
    }).toList();
    if (roles.isEmpty) {
      roles.add(p.type == 1 ? ui_person.PersonDirectoryRole.legalEntity : ui_person.PersonDirectoryRole.client);
    }

    records.add(
      ui_person.PersonDirectoryRecord(
        id: '${p.id}',
        kind: p.type == 1 ? ui_person.PersonDirectoryKind.legal : ui_person.PersonDirectoryKind.natural,
        fullName: p.fullName,
        fatherName: p.fatherName ?? '',
        motherName: p.motherName ?? '',
        nationalId: p.nationalId ?? '',
        registryInfo: '${p.registryPlace ?? ''} ${p.registryNumber ?? ''}'.trim(),
        phone: p.phone1 ?? '',
        whatsapp: p.whatsapp ?? p.phone1 ?? '',
        email: p.email ?? '',
        address: p.permanentAddress ?? '',
        city: p.city ?? '',
        profession: p.profession ?? '',
        notes: p.notes ?? '',
        roles: roles,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      ),
    );
  }

  final agencies = poas
      .map(
        (a) => ui_person.AgencyRecord(
          id: '${a.id}',
          number: a.poaNumber ?? 'POA-${a.id}',
          type: a.poaType == 1 ? ui_person.AgencyType.special : ui_person.AgencyType.general,
          source: a.sourceType == 'notary' ? ui_person.AgencySource.notary : ui_person.AgencySource.barDelegate,
          branch: a.delegateBranch ?? '',
          principalPersonId: records.isNotEmpty ? records.first.id : '0',
          agentName: 'وكيل المكتب',
          issuedAt: a.poaDate ?? a.createdAt,
          expiresAt: a.status == 'archived' ? DateTime(2000) : a.expiryDate,
          scope: a.scopeText ?? '',
          documentId: a.filePath ?? '',
          notes: a.status,
        ),
      )
      .toList();

  return ui_person.PersonsDirectoryState(persons: records, agencies: agencies);
});

// =============================================================================
// Work orders
// =============================================================================

ui_wo.WorkOrderType _mapWoType(String raw) {
  switch (raw) {
    case 'document_photocopy':
      return ui_wo.WorkOrderType.documentPhotocopy;
    case 'fee_payment':
      return ui_wo.WorkOrderType.feePayment;
    case 'notary_review':
      return ui_wo.WorkOrderType.notaryReview;
    case 'execution_followup':
      return ui_wo.WorkOrderType.executionFollowup;
    case 'court_attendance':
      return ui_wo.WorkOrderType.courtAttendance;
    default:
      return ui_wo.WorkOrderType.other;
  }
}

ui_wo.WorkOrderPriority _mapWoPriority(String raw) {
  switch (raw) {
    case 'high':
      return ui_wo.WorkOrderPriority.high;
    case 'low':
      return ui_wo.WorkOrderPriority.low;
    default:
      return ui_wo.WorkOrderPriority.medium;
  }
}

ui_wo.WorkOrderStatus _mapWoStatus(String raw) {
  switch (raw) {
    case 'printed':
      return ui_wo.WorkOrderStatus.printed;
    case 'whatsapp_sent':
      return ui_wo.WorkOrderStatus.whatsappSent;
    case 'waiting_for_result':
      return ui_wo.WorkOrderStatus.waitingForResult;
    case 'result_entered':
      return ui_wo.WorkOrderStatus.resultEntered;
    case 'waiting_for_approval':
      return ui_wo.WorkOrderStatus.waitingForApproval;
    case 'approved':
      return ui_wo.WorkOrderStatus.approved;
    case 'returned_for_correction':
      return ui_wo.WorkOrderStatus.returnedForCorrection;
    case 'postponed':
      return ui_wo.WorkOrderStatus.postponed;
    case 'impossible':
      return ui_wo.WorkOrderStatus.impossible;
    case 'cancelled':
      return ui_wo.WorkOrderStatus.cancelled;
    default:
      return ui_wo.WorkOrderStatus.draft;
  }
}


String _mapWorkOrderEntityType(int raw) {
  switch (raw) {
    case 0:
      return 'case';
    case 1:
      return 'procedure';
    case 2:
      return 'company';
    case 3:
      return 'contract';
    case 4:
      return 'person';
    case 99:
      return 'work_order';
    default:
      return 'general';
  }
}

final uiWorkOrdersProvider = StreamProvider<List<ui_wo.WorkOrder>>((ref) async* {
  await ref.watch(coreDataBootstrapProvider.future);
  final repo = ref.watch(workOrderRepositoryProvider);
  await for (final rows in repo.watchAll()) {
    yield rows
      .map(
        (w) => ui_wo.WorkOrder(
          id: '${w.id}',
          internalNumber: w.internalNumber,
          linkedEntityType: _mapWorkOrderEntityType(w.linkedEntityType),
          linkedEntityId: '${w.linkedEntityId}',
          assignedToName: w.assignedToName,
          assignedToPhone: w.assignedToPhone ?? '',
          orderType: _mapWoType(w.orderType),
          priority: _mapWoPriority(w.priority),
          status: _mapWoStatus(w.status),
          dueDate: w.dueDate,
          instructions: w.instructions ?? '',
          createdAt: w.createdAt,
          createdBy: w.createdBy ?? '',
          printedAt: w.printedAt,
          whatsappSentAt: w.whatsappSentAt,
          resultText: w.resultText,
          resultDate: w.resultDate,
          nextDate: w.nextDate,
          approvedAt: w.approvedAt,
        ),
      )
      .toList();
  }
});
