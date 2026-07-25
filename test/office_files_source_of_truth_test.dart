import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/office_file_repository.dart';

/// اختبارات تثبت أن ملفات المكتب هي مصدر الحقيقة لشاشة الملفات:
/// كل كيان تشغيلي يجب أن يملك سجلاً في office_files، وبرقم واحد لا يتكرر.
void main() {
  late AppDatabase db;
  late OfficeFileRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = OfficeFileRepository(db);
    await db.ensureOfficeFileTables();
  });

  tearDown(() async {
    await db.close();
  });

  test('Backfill creates an office file for a legacy entity', () async {
    final caseId = await db.into(db.cases).insert(CasesCompanion.insert(
          internalNumber: '2026/001',
          year: 2026,
          caseType: 'مدني',
          subject: const Value('دعوى قديمة بلا ملف مكتب'),
        ));

    // لا يوجد ملف مكتب قبل الاستكمال
    expect(
      await repo.getByLinkedEntity(entityType: EntityType.caseEntity.index, entityId: caseId),
      isNull,
    );

    final created = await repo.ensureOfficeFileForEntity(
      fileType: OfficeFileType.caseFile,
      entityType: EntityType.caseEntity.index,
      entityId: caseId,
      title: 'دعوى قديمة بلا ملف مكتب',
      status: OfficeFileStatus.active,
      targetYear: 2026,
      fallbackNumber: '2026/001',
    );

    expect(created, isNotNull);
    expect(created!.fileNumber, 'دعوى/2026/0001');
    expect(created.source, OfficeFileSource.manualAdmin);
    expect(created.status, OfficeFileStatus.active);
    // الرقم القديم محفوظ للمرجعية
    expect(created.notes, contains('2026/001'));
  });

  test('Backfill is idempotent and never issues a second number', () async {
    final caseId = await db.into(db.cases).insert(CasesCompanion.insert(
          internalNumber: '2026/002',
          year: 2026,
          caseType: 'مدني',
        ));

    final first = await repo.ensureOfficeFileForEntity(
      fileType: OfficeFileType.caseFile,
      entityType: EntityType.caseEntity.index,
      entityId: caseId,
      title: 'دعوى',
      status: OfficeFileStatus.active,
    );
    final second = await repo.ensureOfficeFileForEntity(
      fileType: OfficeFileType.caseFile,
      entityType: EntityType.caseEntity.index,
      entityId: caseId,
      title: 'دعوى',
      status: OfficeFileStatus.active,
    );

    expect(first!.id, second!.id);
    expect(first.fileNumber, second.fileNumber);

    final all = await repo.getAll();
    expect(all.length, 1, reason: 'يجب ألا يتولد رقم ملف ثانٍ لنفس الكيان');
  });

  test('Closed entities are backfilled as closed office files', () async {
    final contractId = await db.into(db.contracts).insert(ContractsCompanion.insert(
          internalNumber: 'C-2025-9',
          title: 'عقد منتهٍ',
          contractType: 'إيجار',
          status: const Value('expired'),
        ));

    final created = await repo.ensureOfficeFileForEntity(
      fileType: OfficeFileType.contract,
      entityType: EntityType.contract.index,
      entityId: contractId,
      title: 'عقد منتهٍ',
      status: OfficeFileStatus.closed,
    );

    expect(created!.status, OfficeFileStatus.closed);

    final closed = await repo.getAll(status: OfficeFileStatus.closed);
    expect(closed.length, 1);
    final active = await repo.getAll(status: OfficeFileStatus.active);
    expect(active, isEmpty);
  });

  test('Numbering stays per type and per year', () async {
    Future<int> newCase(String number) => db.into(db.cases).insert(
          CasesCompanion.insert(internalNumber: number, year: 2026, caseType: 'مدني'),
        );

    final a = await newCase('a');
    final b = await newCase('b');
    final companyId = await db.into(db.companies).insert(CompaniesCompanion.insert(
          internalNumber: 'CO-1',
          companyType: 'محدودة',
          name: 'شركة',
        ));

    final f1 = await repo.ensureOfficeFileForEntity(
      fileType: OfficeFileType.caseFile,
      entityType: EntityType.caseEntity.index,
      entityId: a,
      title: 'أ',
      status: OfficeFileStatus.active,
      targetYear: 2026,
    );
    final f2 = await repo.ensureOfficeFileForEntity(
      fileType: OfficeFileType.caseFile,
      entityType: EntityType.caseEntity.index,
      entityId: b,
      title: 'ب',
      status: OfficeFileStatus.active,
      targetYear: 2026,
    );
    final f3 = await repo.ensureOfficeFileForEntity(
      fileType: OfficeFileType.company,
      entityType: EntityType.company.index,
      entityId: companyId,
      title: 'شركة',
      status: OfficeFileStatus.active,
      targetYear: 2026,
    );

    expect(f1!.fileNumber, 'دعوى/2026/0001');
    expect(f2!.fileNumber, 'دعوى/2026/0002');
    // تسلسل الشركات مستقل عن تسلسل الدعاوى
    expect(f3!.fileNumber, 'شركة/2026/0001');
  });

  test('Entity id zero is rejected instead of creating an orphan file', () async {
    final created = await repo.ensureOfficeFileForEntity(
      fileType: OfficeFileType.caseFile,
      entityType: EntityType.caseEntity.index,
      entityId: 0,
      title: 'كيان غير صالح',
      status: OfficeFileStatus.active,
    );
    expect(created, isNull);
    expect(await repo.getAll(), isEmpty);
  });
}
