import 'dart:io';
import 'package:drift/drift.dart';
import '../../core/constants/court_catalog.dart';
import '../../core/enums/app_enums.dart';
import '../database/database.dart';
import '../database/daos/case_dao.dart';
import '../services/task_sync_service.dart';
import '../services/deficiency_service.dart';
import '../services/file_storage_service.dart';
import 'office_file_repository.dart';

/// مستودع إدارة الدعاوى القضائية، الجلسات، المراحل، ونقل القرارات (CaseRepository)
class CaseRepository {
  final CaseDao _caseDao;
  final TaskSyncService _taskSyncService;
  final DeficiencyService _deficiencyService;
  final FileStorageService _storageService;
  final OfficeFileRepository _officeFileRepository;

  CaseRepository(
    this._caseDao,
    this._taskSyncService,
    this._deficiencyService,
    this._storageService,
    this._officeFileRepository,
  );

  Stream<List<Case>> watchAllCases() => _caseDao.watchAllCases();
  Future<List<Case>> getAllCases() => _caseDao.getAllCases();
  Future<List<CaseSession>> getSessionsForCase(int caseId) => _caseDao.getSessionsForCase(caseId);
  Future<List<CaseParty>> getPartiesForCase(int caseId) => _caseDao.getPartiesForCase(caseId);
  Future<List<CasePhase>> getPhasesForCase(int caseId) => _caseDao.getPhasesForCase(caseId);
  Future<Court?> getCourtById(int id) => _caseDao.getCourtById(id);

  Future<Case?> getCaseById(int id) => _caseDao.getCaseById(id);
  Stream<List<CaseParty>> watchCaseParties(int caseId) => _caseDao.watchCaseParties(caseId);
  Stream<List<CasePhase>> watchCasePhases(int caseId) => _caseDao.watchCasePhases(caseId);
  Stream<List<CaseSession>> watchCaseSessions(int caseId) => _caseDao.watchCaseSessions(caseId);
  Stream<List<CaseAction>> watchCaseActions(int caseId) => _caseDao.watchCaseActions(caseId);

  /// إنشاء دعوى جديدة مع رقم ملف مكتب موحد وإضافة الأطراف والمرحلة الابتدائية وتدقيق النواقص
  Future<int> createCase({
    required CasesCompanion caseData,
    required int clientId,
    int? opponentId,
    int? poaId,
    required String userRef,
  }) async {
    return await _caseDao.db.transaction(() async {
      // 1. توليد رقم ملف مكتب موحد غير قابل للتعديل (دعوى/2026/0001)
      final officeFile = await _officeFileRepository.createOfficeFile(
        fileType: OfficeFileType.caseFile,
        source: OfficeFileSource.newWork,
        status: OfficeFileStatus.active,
        title: caseData.subject.present ? caseData.subject.value : null,
        openedByNameSnapshot: userRef,
        targetYear: caseData.year.present ? caseData.year.value : DateTime.now().year,
      );
      final String internalNum = officeFile.fileNumber;

      final finalCompanion = caseData.copyWith(
        internalNumber: Value(internalNum),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );

      // 2. إدخال الدعوى وربط ملف المكتب بها
      final caseId = await _caseDao.insertCase(finalCompanion);
      await _officeFileRepository.linkOfficeFile(
        officeFileId: officeFile.id,
        entityType: EntityType.caseEntity.index,
        entityId: caseId,
      );

      // 3. إضافة الموكل الرئيسي
      await _caseDao.insertCaseParty(
        CasePartiesCompanion.insert(
          caseId: caseId,
          personId: clientId,
          partyRole: 'مدعي',
          isPrimary: const Value(true),
          isClient: const Value(true),
        ),
      );

      // 4. إضافة الخصم إن وجد
      if (opponentId != null) {
        await _caseDao.insertCaseParty(
          CasePartiesCompanion.insert(
            caseId: caseId,
            personId: opponentId,
            partyRole: 'مدعى عليه',
            isPrimary: const Value(true),
            isClient: const Value(false),
          ),
        );
      }

      // 5. ربط الوكالة بالدعوى إن وجدت
      if (poaId != null) {
        await _caseDao.into(_caseDao.db.casePoaLinks).insert(
          CasePoaLinksCompanion.insert(caseId: caseId, poaId: poaId),
        );
      }

      // 6. إنشاء المرحلة الابتدائية الأولى للدعوى
      final phaseId = await _caseDao.insertCasePhase(
        CasePhasesCompanion.insert(
          caseId: caseId,
          phaseOrder: const Value(1),
          phaseType: caseData.subType.present ? caseData.subType.value! : 'بداية / صلح',
          courtId: caseData.courtId,
          // نوع المحكمة والغرفة ينتقلان إلى المرحلة الأولى، وإلا بدأ
          // سجل المراحل بلا درجة فتعذّر حساب مسار الطعن منه.
          courtKind: caseData.courtKind,
          chamberNumber: caseData.chamberNumber,
          baseNumber: caseData.baseNumber,
          year: caseData.year,
          startDate: Value(DateTime.now()),
        ),
      );

      await _caseDao.updateCase(
        CasesCompanion(
          id: Value(caseId),
          internalNumber: Value(internalNum),
          year: finalCompanion.year,
          caseType: finalCompanion.caseType,
          currentPhaseId: Value(phaseId),
        ),
      );

      // 7. إذا تم تحديد موعد القادم أثناء الإنشاء، يتم توليد مهمة مجدولة
      if (finalCompanion.nextSessionDate.present && finalCompanion.nextSessionDate.value != null) {
        await _taskSyncService.syncSessionToDailyTask(
          session: CaseSessionsCompanion.insert(
            caseId: caseId,
            phaseId: Value(phaseId),
            sessionDate: finalCompanion.nextSessionDate.value!,
            sessionType: const Value('مرافعة أولى'),
            status: const Value(0),
            nextSessionDate: Value(finalCompanion.nextSessionDate.value!),
            nextAction: const Value('مرافعة أولى / متابعة ملف جارٍ'),
          ),
          caseTitle: '$internalNum - ${finalCompanion.subject.value ?? ""}',
          userRef: userRef,
        );
      }

      // 8. فحص النواقص التلقائي وتدقيق الملف
      // لا يتم توليد نواقص للأرشيف المنتهي/الدعاوى المغلقة لأنها للحفظ والبحث فقط.
      final isClosedArchive = finalCompanion.status.present && finalCompanion.status.value == 'closed';
      if (!isClosedArchive) {
        await _deficiencyService.auditCaseDeficiencies(
          caseId: caseId,
          caseData: finalCompanion,
          hasPoa: poaId != null,
          hasRepresentativeDoc: false,
        );
      }

      // 9. تسجيل الحدث في الخط الزمني
      await _caseDao.into(_caseDao.db.timelineEvents).insert(
        TimelineEventsCompanion.insert(
          entityType: EntityType.caseEntity.index,
          entityId: caseId,
          eventType: 'case_created',
          eventDate: Value(DateTime.now()),
          description: 'تم فتح ملف دعوى جديد برقم داخلي: $internalNum',
          userRef: Value(userRef),
        ),
      );

      return caseId;
    });
  }

  /// إضافة جلسة قضائية وتوليد المهمة اليومية اللاحقة أوتوماتيكياً
  Future<int> addSession({
    required CaseSessionsCompanion session,
    required String caseTitle,
    required String userRef,
  }) async {
    final sessionId = await _taskSyncService.syncSessionToDailyTask(
      session: session,
      caseTitle: caseTitle,
      userRef: userRef,
    );

    // إذا تم تحديد جلسة قادمة يتم إغلاق نقص "next_session_date" إن وجد
    if (session.nextSessionDate.present && session.nextSessionDate.value != null) {
      await _deficiencyService.resolveDeficiency(
        EntityType.caseEntity,
        session.caseId.value,
        'next_session_date',
      );
    }

    return sessionId;
  }

  /// تحديث بيانات الدعوى (رقم الأساس، المحكمة، إلخ)
  Future<void> updateCase({
    required int caseId,
    String? baseNumber,
    int? courtId,
    String? courtKind,
    int? chamberNumber,
    String? status,
  }) async {
    await _caseDao.db.transaction(() async {
      await (_caseDao.update(_caseDao.db.cases)..where((t) => t.id.equals(caseId))).write(
        CasesCompanion(
          baseNumber: baseNumber != null ? Value(baseNumber) : const Value.absent(),
          courtId: courtId != null ? Value(courtId) : const Value.absent(),
          courtKind: courtKind != null ? Value(courtKind) : const Value.absent(),
          chamberNumber: chamberNumber != null ? Value(chamberNumber) : const Value.absent(),
          status: status != null ? Value(status) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // إغلاق النقص المتعلق برقم الأساس إذا تم إدخاله
      if (baseNumber != null && baseNumber.isNotEmpty) {
        await _deficiencyService.resolveDeficiency(
          EntityType.caseEntity,
          caseId,
          'base_number',
        );
      }

      // تسجيل الحدث في الخط الزمني
      final updates = <String>[];
      if (baseNumber != null) updates.add('رقم الأساس: $baseNumber');
      if (courtId != null) updates.add('المحكمة');
      if (status != null) updates.add('الحالة: $status');
      
      if (updates.isNotEmpty) {
        await _caseDao.into(_caseDao.db.timelineEvents).insert(
          TimelineEventsCompanion.insert(
            entityType: EntityType.caseEntity.index,
            entityId: caseId,
            eventType: 'case_updated',
            eventDate: Value(DateTime.now()),
            description: 'تم تحديث بيانات الدعوى: ${updates.join('، ')}',
            userRef: const Value('النظام'),
          ),
        );
      }
    });
  }

  /// نقل الدعوى للمرحلة القضائية الأعلى (مثال: بداية ← استئناف ← نقض)
  /// القاعدة الذهبية V6.2: ينتقل القرار القضائي السابق وكل الثبوتيات المبرزة تلقائياً للمرحلة الجديدة
  Future<int> transferToNextPhase({
    required int caseId,
    required String newPhaseType,
    required int newCourtId,
    String? newCourtKind,
    int? newChamberNumber,
    String? newBaseNumber,
    int? newYear,
    required String userRef,
  }) async {
    return await _caseDao.db.transaction(() async {
      final currentCase = await _caseDao.getCaseById(caseId);
      if (currentCase == null) throw Exception('الدعوى غير موجودة');

      // حارس مسار الطعن: لا يُقبل الانتقال إلى محكمة لا يبلغها
      // الطعن من المحكمة الحالية. بدونه كان يمكن نقل دعوى من
      // الاستئناف إلى الصلح، وهو انحدار لا وجود له في التقاضي.
      final currentKind = currentCase.courtKind;
      if (currentKind != null && newCourtKind != null) {
        final allowed = CourtCatalog.nextStagesFrom(currentKind)
            .map((k) => k.id)
            .toSet();
        if (allowed.isNotEmpty && !allowed.contains(newCourtKind)) {
          final from = CourtCatalog.byId(currentKind)?.label ?? currentKind;
          final to = CourtCatalog.byId(newCourtKind)?.label ?? newCourtKind;
          throw Exception('لا يجوز الانتقال من «$from» إلى «$to».');
        }
      }

      // 1. جلب المرحلة الحالية لإغلاقها ونقل قرارها
      final phases = await (_caseDao.select(_caseDao.db.casePhases)
            ..where((t) => t.caseId.equals(caseId))
            ..orderBy([(t) => OrderingTerm(expression: t.phaseOrder, mode: OrderingMode.desc)]))
          .get();

      final currentPhase = phases.isNotEmpty ? phases.first : null;
      final int nextOrder = (currentPhase?.phaseOrder ?? 0) + 1;

      // 2. تحديث المرحلة السابقة كـ "منتقلة"
      if (currentPhase != null) {
        await (_caseDao.update(_caseDao.db.casePhases)..where((t) => t.id.equals(currentPhase.id))).write(
          CasePhasesCompanion(
            isTransferred: const Value(true),
            endDate: Value(DateTime.now()),
          ),
        );
      }

      // 3. إنشاء المرحلة الجديدة مع نقل نص القرار السابق إليها
      final newPhaseId = await _caseDao.insertCasePhase(
        CasePhasesCompanion.insert(
          caseId: caseId,
          phaseOrder: Value(nextOrder),
          phaseType: newPhaseType,
          courtId: Value(newCourtId),
          courtKind: Value(newCourtKind),
          chamberNumber: Value(newChamberNumber),
          baseNumber: Value(newBaseNumber),
          year: Value(newYear ?? DateTime.now().year),
          startDate: Value(DateTime.now()),
          decisionText: Value('منتقلة بموجب قرار المرحلة السابقة: ${currentPhase?.decisionText ?? "غير مدخل"}'),
          decisionDocPath: Value(currentPhase?.decisionDocPath),
        ),
      );

      // 4. ربط المرحلة السابقة بالجديلة عبر nextPhaseId
      if (currentPhase != null) {
        await (_caseDao.update(_caseDao.db.casePhases)..where((t) => t.id.equals(currentPhase.id))).write(
          CasePhasesCompanion(nextPhaseId: Value(newPhaseId)),
        );
      }

      // 5. تحديث الدعوى بالمرحلة والمحكمة الجديدة
      await (_caseDao.update(_caseDao.db.cases)..where((t) => t.id.equals(caseId))).write(
        CasesCompanion(
          currentPhaseId: Value(newPhaseId),
          courtId: Value(newCourtId),
          courtKind: Value(newCourtKind),
          chamberNumber: Value(newChamberNumber),
          subType: Value(
              CourtCatalog.byId(newCourtKind)?.label ?? newPhaseType),
          baseNumber: Value(newBaseNumber),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // 6. تسجيل الحدث في الخط الزمني
      await _caseDao.into(_caseDao.db.timelineEvents).insert(
        TimelineEventsCompanion.insert(
          entityType: EntityType.caseEntity.index,
          entityId: caseId,
          eventType: 'phase_transferred',
          eventDate: Value(DateTime.now()),
          description: 'تم نقل القضية إلى ${CourtCatalog.describeStored(kindId: newCourtKind, chamberNumber: newChamberNumber)} برقم أساس: ${newBaseNumber ?? "بانتظار التسجيل"}',
          userRef: Value(userRef),
        ),
      );

      return newPhaseId;
    });
  }

  /// إنهاء الدعوى بحكم قضائي قطعي أو اعتزال توكيل مع فرض إرفاق صورة القرار
  Future<void> terminateCase({
    required int caseId,
    required String terminationReason,
    String? decisionNumber,
    DateTime? decisionDate,
    required String summary,
    File? decisionFile,
    required String userRef,
  }) async {
    await _caseDao.db.transaction(() async {
      String? docPath; // may be unused if no file
      if (decisionFile != null) {
        docPath = await _storageService.saveAttachment(
          sourceFile: decisionFile,
          folderType: 'cases_decisions',
          entityId: caseId,
        );
      }

      await (_caseDao.update(_caseDao.db.cases)..where((t) => t.id.equals(caseId))).write(
        CasesCompanion(
          status: const Value('closed'),
          notes: Value('تم إنهاء الدعوى ($terminationReason). ملخص الحكم/القرار: $summary'
              '${docPath != null ? ' | مرفق: $docPath' : ''}'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await _caseDao.into(_caseDao.db.timelineEvents).insert(
        TimelineEventsCompanion.insert(
          entityType: EntityType.caseEntity.index,
          entityId: caseId,
          eventType: 'case_terminated',
          eventDate: Value(DateTime.now()),
          description: 'تم إغلاق القضية والسبب: $terminationReason - قرار رقم ${decisionNumber ?? "بدون"}',
          userRef: Value(userRef),
        ),
      );

      // إغلاق أي نواقص معلقة في الملف لأن الدعوى انتهت
      await (_caseDao.update(_caseDao.db.deficiencies)
            ..where((t) => t.entityType.equals(0) & t.entityId.equals(caseId) & t.status.equals('open')))
          .write(
        DeficienciesCompanion(
          status: const Value('resolved'),
          resolvedAt: Value(DateTime.now()),
        ),
      );

      // إغلاق ملف المكتب المرتبط حتى لا تبقى الدعوى «جارية» في شاشة الملفات.
      final officeFile = await _officeFileRepository.getByLinkedEntity(
        entityType: EntityType.caseEntity.index,
        entityId: caseId,
      );
      if (officeFile != null && officeFile.status != OfficeFileStatus.closed) {
        await _officeFileRepository.closeOfficeFile(
          officeFileId: officeFile.id,
          reason: terminationReason,
          summary: summary,
          closedByNameSnapshot: userRef,
        );
      }
    });
  }

  /// بذر دعاوى تجريبية داخل SQLite عند كون الجدول فارغاً.
  Future<void> seedDemoIfEmpty() async {
    final existing = await _caseDao.getAllCases();
    if (existing.isNotEmpty) return;

    final courts = await (_caseDao.select(_caseDao.courts)..limit(1)).get();
    final courtId = courts.isNotEmpty ? courts.first.id : null;

    final persons = await (_caseDao.select(_caseDao.persons)).get();
    late int clientId;
    late int opponentId;
    if (persons.isEmpty) {
      clientId = await _caseDao.into(_caseDao.persons).insert(
            PersonsCompanion.insert(fullName: 'أحمد محمد الخطيب', phone1: const Value('0933000001')),
          );
      opponentId = await _caseDao.into(_caseDao.persons).insert(
            PersonsCompanion.insert(fullName: 'محمد أحمد السالم', phone1: const Value('0944000002')),
          );
    } else {
      clientId = persons.first.id;
      opponentId = persons.length > 1 ? persons[1].id : persons.first.id;
    }

    Future<int> addCase({
      required String caseType,
      required String subject,
      String? baseNumber,
      String status = 'registered',
      DateTime? nextSession,
    }) {
      return createCase(
        caseData: CasesCompanion.insert(
          internalNumber: 'TMP',
          year: DateTime.now().year,
          caseType: caseType,
          status: Value(status),
          courtId: Value(courtId),
          baseNumber: Value(baseNumber),
          subject: Value(subject),
          subjectDetails: Value(subject),
          nextSessionDate: Value(nextSession),
        ),
        clientId: clientId,
        opponentId: opponentId,
        userRef: 'النظام',
      );
    }

    final c1 = await addCase(
      caseType: 'مدني',
      subject: 'تعويض عن ضرر',
      baseNumber: '12345',
      nextSession: DateTime.now().add(const Duration(days: 5)),
    );
    await addCase(
      caseType: 'تجاري',
      subject: 'استئناف حكم',
      status: 'pending_registration',
      nextSession: DateTime.now().add(const Duration(days: 2)),
    );
    await addCase(
      caseType: 'تجاري',
      subject: 'منازعة تجارية',
      baseNumber: '67890',
      status: 'closed',
    );

    await _caseDao.insertCaseSession(
      CaseSessionsCompanion.insert(
        caseId: c1,
        sessionDate: DateTime.now().add(const Duration(days: 5)),
        sessionTime: const Value('09:00'),
        sessionType: const Value('مرافعة'),
        status: const Value(0),
      ),
    );
  }
}
