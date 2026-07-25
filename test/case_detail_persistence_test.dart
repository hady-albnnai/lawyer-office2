import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/case_repository.dart';
import 'package:lawyer_office/data/repositories/document_repository.dart';
import 'package:lawyer_office/data/repositories/office_file_repository.dart';
import 'package:lawyer_office/data/repositories/task_repository.dart';
import 'package:lawyer_office/data/services/deficiency_service.dart';
import 'package:lawyer_office/data/services/file_storage_service.dart';
import 'package:lawyer_office/data/services/task_sync_service.dart';

/// أزرار ملف الدعوى (جلسة، نقص، ربط مستند، نقل مرحلة، إنهاء) كانت تعدّل
/// حالة الشاشة فقط فتضيع عند إعادة الفتح. هذه الاختبارات تتحقق من الحفظ الفعلي.
void main() {
  late AppDatabase db;
  late CaseRepository caseRepo;
  late TaskRepository taskRepo;
  late DocumentRepository docRepo;
  late OfficeFileRepository officeRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    officeRepo = OfficeFileRepository(db);
    caseRepo = CaseRepository(
      db.caseDao,
      TaskSyncService(db),
      DeficiencyService(db),
      FileStorageService(),
      officeRepo,
    );
    taskRepo = TaskRepository(db.taskDao, TaskSyncService(db), DeficiencyService(db));
    docRepo = DocumentRepository(db.documentDao, FileStorageService());
    await db.ensureOfficeFileTables();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> makeCase() async {
    final personId = await db.into(db.persons).insert(
          PersonsCompanion.insert(fullName: 'موكل تجريبي'),
        );
    return caseRepo.createCase(
      caseData: CasesCompanion.insert(
        internalNumber: '',
        year: 2026,
        caseType: 'مدني',
        subject: const Value('دعوى اختبار'),
      ),
      clientId: personId,
      userRef: 'هادي',
    );
  }

  test('Adding a session persists it to case_sessions', () async {
    final caseId = await makeCase();

    await caseRepo.addSession(
      session: CaseSessionsCompanion.insert(
        caseId: caseId,
        sessionDate: DateTime(2026, 8, 1, 9, 30),
        sessionTime: const Value('09:30'),
        sessionType: const Value('مرافعة'),
      ),
      caseTitle: 'دعوى اختبار',
      userRef: 'هادي',
    );

    final sessions = await caseRepo.getSessionsForCase(caseId);
    expect(sessions, hasLength(1));
    expect(sessions.first.sessionTime, '09:30');
  });

  test('Manual deficiency is stored and visible as open', () async {
    final caseId = await makeCase();

    await taskRepo.addManualDeficiency(
      entityType: EntityType.caseEntity,
      entityId: caseId,
      fieldName: 'سند توكيل',
      description: 'سند التوكيل غير مرفوع',
    );

    final open = await taskRepo
        .watchOpenDeficiencies(entityType: EntityType.caseEntity, entityId: caseId)
        .first;
    expect(open.any((d) => d.fieldName == 'سند توكيل'), isTrue);
  });

  test('Linking and unlinking an existing document persists', () async {
    final caseId = await makeCase();
    final docId = await db.into(db.documents).insert(
          DocumentsCompanion.insert(docName: 'حكم ابتدائي.pdf'),
        );

    await docRepo.linkExistingDocument(
      documentId: docId,
      entityType: EntityType.caseEntity.index,
      entityId: caseId,
    );

    var links = await docRepo.getAllLinks();
    expect(links.where((l) => l.documentId == docId && l.entityId == caseId), hasLength(1));

    await docRepo.unlinkDocument(
      documentId: docId,
      entityType: EntityType.caseEntity.index,
      entityId: caseId,
    );

    links = await docRepo.getAllLinks();
    expect(links.where((l) => l.documentId == docId && l.entityId == caseId), isEmpty);

    // المستند نفسه لا يُحذف من الأرشيف عند فك الربط
    final docs = await docRepo.getAllDocuments();
    expect(docs.any((d) => d.id == docId), isTrue);
  });

  test('Terminating a case closes the case, its deficiencies and its office file', () async {
    final caseId = await makeCase();

    await taskRepo.addManualDeficiency(
      entityType: EntityType.caseEntity,
      entityId: caseId,
      fieldName: 'رقم الأساس',
      description: 'بانتظار رقم الأساس',
    );

    final before = await officeRepo.getByLinkedEntity(
      entityType: EntityType.caseEntity.index,
      entityId: caseId,
    );
    expect(before, isNotNull);
    expect(before!.status, OfficeFileStatus.active);

    await caseRepo.terminateCase(
      caseId: caseId,
      terminationReason: 'صدور حكم مبرم',
      decisionNumber: '120/2026',
      summary: 'ربح الدعوى',
      userRef: 'هادي',
    );

    // 1) الدعوى مغلقة
    final updated = await caseRepo.getCaseById(caseId);
    expect(updated!.status, 'closed');

    // 2) النواقص المفتوحة أُغلقت
    final open = await taskRepo
        .watchOpenDeficiencies(entityType: EntityType.caseEntity, entityId: caseId)
        .first;
    expect(open, isEmpty);

    // 3) ملف المكتب أُغلق أيضاً حتى لا يبقى «جارياً» في شاشة الملفات
    final after = await officeRepo.getByLinkedEntity(
      entityType: EntityType.caseEntity.index,
      entityId: caseId,
    );
    expect(after!.status, OfficeFileStatus.closed);
    expect(after.closureReason, 'صدور حكم مبرم');
  });

  test('Transferring to the next phase persists the new phase', () async {
    final caseId = await makeCase();
    final courtId = await db.into(db.courts).insert(
          CourtsCompanion.insert(name: 'استئناف دمشق'),
        );

    await caseRepo.transferToNextPhase(
      caseId: caseId,
      newPhaseType: 'استئناف',
      newCourtId: courtId,
      newBaseNumber: '77',
      newYear: 2026,
      userRef: 'هادي',
    );

    final phases = await caseRepo.getPhasesForCase(caseId);
    expect(phases.any((p) => p.phaseType == 'استئناف' && p.baseNumber == '77'), isTrue);
  });
}
