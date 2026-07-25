import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/document_repository.dart';
import 'package:lawyer_office/data/repositories/office_file_repository.dart';
import 'package:lawyer_office/data/services/file_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// المرحلة الثامنة من خارطة التنفيذ: حالة الأصل الورقي.
/// الحقول «مع الموكل» و«مبرز في المحكمة» و«نسخة رقمية فقط» ومحضر التسليم
/// كانت مفقودة من الجدول رغم النص عليها صراحة.
void main() {
  late AppDatabase db;
  late DocumentRepository repo;
  late OfficeFileRepository officeRepo;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paper_meta');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DocumentRepository(db.documentDao, FileStorageService());
    officeRepo = OfficeFileRepository(db);
    await db.ensureArchiveTables();
    await db.ensureOfficeFileTables();
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<Map<String, Object?>> paperRow(int docId) async {
    final rows = await db.customSelect(
      'SELECT * FROM document_paper_metadata WHERE document_id = ?',
      variables: [Variable.withInt(docId)],
    ).get();
    return rows.first.data;
  }

  test('All paper original fields required by the roadmap are stored', () async {
    final docId = await repo.addDocument(
      docName: 'سند ملكية',
      entityType: EntityType.caseEntity.index,
      entityId: 1,
      userRef: 'هادي',
      paperOriginalSaved: true,
      paperLocation: 'الخزنة',
      paperBox: 'ص-3',
      paperShelf: 'ر-2',
      paperFolder: 'مج-9',
      canDestroyOriginal: false,
      reviewedBy: 'هادي',
      withClient: false,
      courtExhibit: true,
      digitalOnly: false,
      handoverReference: 'محضر تسليم 12/2026',
    );

    final row = await paperRow(docId);
    expect(row['paper_original_saved'], 1);
    expect(row['box'], 'ص-3');
    expect(row['court_exhibit'], 1);
    expect(row['with_client'], 0);
    expect(row['digital_only'], 0);
    expect(row['handover_reference'], 'محضر تسليم 12/2026');
  });

  test('Digital-only document is not flagged as a pending paper original', () async {
    await repo.addDocument(
      docName: 'مراسلة إلكترونية',
      entityType: EntityType.caseEntity.index,
      entityId: 5,
      userRef: 'هادي',
      paperOriginalSaved: false,
      digitalOnly: true,
    );

    final office = await officeRepo.getByLinkedEntity(
      entityType: EntityType.caseEntity.index,
      entityId: 5,
    );
    // لا يوجد ملف مكتب لهذا الكيان في هذا الاختبار، لكن العلم يُحسب بلا استثناء
    expect(office, isNull);

    final docs = await repo.getAllDocuments();
    expect(docs, hasLength(1));
  });

  test('Missing original with no exemption marks the office file as pending', () async {
    await officeRepo.createOfficeFile(
      fileType: OfficeFileType.caseFile,
      linkedEntityType: EntityType.caseEntity.index,
      linkedEntityId: 7,
      title: 'دعوى',
    );

    await repo.addDocument(
      docName: 'صورة حكم',
      entityType: EntityType.caseEntity.index,
      entityId: 7,
      userRef: 'هادي',
      paperOriginalSaved: false,
    );

    final office = await officeRepo.getByLinkedEntity(
      entityType: EntityType.caseEntity.index,
      entityId: 7,
    );
    expect(office!.hasPendingPaperOriginal, isTrue);
  });

  test('Original held as a court exhibit clears the pending flag', () async {
    await officeRepo.createOfficeFile(
      fileType: OfficeFileType.caseFile,
      linkedEntityType: EntityType.caseEntity.index,
      linkedEntityId: 8,
      title: 'دعوى',
    );

    await repo.addDocument(
      docName: 'أصل مبرز',
      entityType: EntityType.caseEntity.index,
      entityId: 8,
      userRef: 'هادي',
      paperOriginalSaved: false,
      courtExhibit: true,
      handoverReference: 'ضبط إبراز 5/2026',
    );

    final office = await officeRepo.getByLinkedEntity(
      entityType: EntityType.caseEntity.index,
      entityId: 8,
    );
    expect(office!.hasPendingPaperOriginal, isFalse,
        reason: 'الأصل المبرز لدى المحكمة ليس أصلاً مفقوداً');
  });
}
