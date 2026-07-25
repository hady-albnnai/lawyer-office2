import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/document_repository.dart';
import 'package:lawyer_office/data/services/file_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// يوجّه تخزين المرفقات إلى مجلد مؤقت أثناء الاختبار.
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

/// مرفقات إنشاء الدعوى كانت أسماء وهمية (مستند_1.pdf) لا تُحفظ إطلاقاً.
/// هذه الاختبارات تتحقق أن المرفق الحقيقي يُخزَّن ويُربط بالدعوى.
void main() {
  late AppDatabase db;
  late DocumentRepository repo;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lawyer_office_attachments');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DocumentRepository(db.documentDao, FileStorageService());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> makeFile(String name, [String content = 'محتوى تجريبي']) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(content);
    return file;
  }

  test('Attachment is persisted, stored on disk and linked to the case', () async {
    final file = await makeFile('لائحة_دعوى.pdf');

    final docId = await repo.addDocument(
      docName: 'لائحة_دعوى.pdf',
      docType: 'case_document',
      fileType: 'pdf',
      sourceFile: file,
      entityType: EntityType.caseEntity.index,
      entityId: 55,
      userRef: 'هادي',
    );

    final docs = await repo.getAllDocuments();
    expect(docs, hasLength(1));
    expect(docs.first.id, docId);
    expect(docs.first.docName, 'لائحة_دعوى.pdf');

    // نسخة الملف حُفظت فعلياً على القرص
    final storedPath = docs.first.filePath;
    expect(storedPath, isNotNull);
    final absolute = await FileStorageService().getAbsolutePath(storedPath!);
    expect(File(absolute).existsSync(), isTrue, reason: 'يجب حفظ نسخة المرفق فعلياً');

    // والربط بالدعوى تم
    final links = await repo.getAllLinks();
    expect(links, hasLength(1));
    expect(links.first.documentId, docId);
    expect(links.first.entityType, EntityType.caseEntity.index);
    expect(links.first.entityId, 55);
  });

  test('Multiple attachments are all linked to the same case', () async {
    for (var i = 1; i <= 3; i++) {
      await repo.addDocument(
        docName: 'مرفق_$i.pdf',
        sourceFile: await makeFile('مرفق_$i.pdf'),
        entityType: EntityType.caseEntity.index,
        entityId: 7,
        userRef: 'هادي',
      );
    }

    final links = await repo.getAllLinks();
    expect(links, hasLength(3));
    expect(links.every((l) => l.entityId == 7), isTrue);
  });

  test('Attachments of one case do not leak into another', () async {
    await repo.addDocument(
      docName: 'أ.pdf',
      sourceFile: await makeFile('أ.pdf'),
      entityType: EntityType.caseEntity.index,
      entityId: 1,
      userRef: 'هادي',
    );
    await repo.addDocument(
      docName: 'ب.pdf',
      sourceFile: await makeFile('ب.pdf'),
      entityType: EntityType.caseEntity.index,
      entityId: 2,
      userRef: 'هادي',
    );

    final links = await repo.getAllLinks();
    expect(links.where((l) => l.entityId == 1), hasLength(1));
    expect(links.where((l) => l.entityId == 2), hasLength(1));
  });
}
