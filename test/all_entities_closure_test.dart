import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/admin_procedure_repository.dart';
import 'package:lawyer_office/data/repositories/company_repository.dart';
import 'package:lawyer_office/data/repositories/contract_repository.dart';
import 'package:lawyer_office/data/repositories/office_file_repository.dart';
import 'package:lawyer_office/data/repositories/poa_repository.dart';
import 'package:lawyer_office/data/services/deficiency_service.dart';
import 'package:lawyer_office/data/services/file_storage_service.dart';
import 'package:lawyer_office/data/services/task_sync_service.dart';

/// المرحلة الرابعة تشمل الأنواع الخمسة، لا الدعوى وحدها.
/// كان الإغلاق ينفَّذ للدعوى فقط، فتبقى بقية الملفات «جارية» بعد انتهائها.
void main() {
  late AppDatabase db;
  late OfficeFileRepository officeRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    officeRepo = OfficeFileRepository(db);
    await db.ensureOfficeFileTables();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> makeOffice(OfficeFileType type, EntityType entity, int entityId) async {
    final f = await officeRepo.createOfficeFile(
      fileType: type,
      linkedEntityType: entity.index,
      linkedEntityId: entityId,
      title: 'ملف',
    );
    return f.id;
  }

  Future<OfficeFileRecord?> read(EntityType entity, int entityId) =>
      officeRepo.getByLinkedEntity(entityType: entity.index, entityId: entityId);

  test('Contract closure closes its office file', () async {
    await makeOffice(OfficeFileType.contract, EntityType.contract, 11);
    final repo = ContractRepository(
        db.contractDao, TaskSyncService(db), FileStorageService(), officeRepo);

    await repo.closeOfficeFileForEntity(
      entityId: 11,
      reason: 'انتهى',
      summary: 'انتهت مدة العقد',
      userRef: 'هادي',
    );

    final office = await read(EntityType.contract, 11);
    expect(office!.status, OfficeFileStatus.closed);
    expect(office.closureReason, 'انتهى');
  });

  test('Company closure closes its office file', () async {
    await makeOffice(OfficeFileType.company, EntityType.company, 12);
    final repo = CompanyRepository(
        db.companyDao, TaskSyncService(db), DeficiencyService(db), officeRepo);

    await repo.closeOfficeFileForEntity(
      entityId: 12,
      reason: 'اكتمل التأسيس',
      summary: 'تم الشهر في السجل التجاري',
    );

    final office = await read(EntityType.company, 12);
    expect(office!.status, OfficeFileStatus.closed);
  });

  test('Procedure closure closes its office file', () async {
    await makeOffice(OfficeFileType.procedure, EntityType.adminProcedure, 13);
    final repo = AdminProcedureRepository(db.adminProcedureDao, officeRepo);

    await repo.closeOfficeFileForEntity(
      entityId: 13,
      reason: 'تم إنجازه',
      summary: 'صدرت المعاملة',
    );

    final office = await read(EntityType.adminProcedure, 13);
    expect(office!.status, OfficeFileStatus.closed);
  });

  test('POA closure closes its office file', () async {
    await makeOffice(OfficeFileType.agency, EntityType.powerOfAttorney, 14);
    final repo = PoaRepository(db.personDao, FileStorageService(), officeRepo);

    await repo.closeOfficeFileForEntity(
      entityId: 14,
      reason: 'عزل عنها',
      summary: 'عزل الموكل الوكالة',
    );

    final office = await read(EntityType.powerOfAttorney, 14);
    expect(office!.status, OfficeFileStatus.closed);
  });

  test('Closing twice is safe and keeps the first reason', () async {
    await makeOffice(OfficeFileType.contract, EntityType.contract, 15);
    final repo = ContractRepository(
        db.contractDao, TaskSyncService(db), FileStorageService(), officeRepo);

    await repo.closeOfficeFileForEntity(
      entityId: 15, reason: 'انتهى', summary: 'أول إغلاق');
    await repo.closeOfficeFileForEntity(
      entityId: 15, reason: 'ألغي', summary: 'محاولة ثانية');

    final office = await read(EntityType.contract, 15);
    expect(office!.closureReason, 'انتهى',
        reason: 'الإغلاق المتكرر يجب ألا يعيد كتابة سبب الإغلاق الأصلي');
  });

  test('Closing an entity with no office file does not throw', () async {
    final repo = AdminProcedureRepository(db.adminProcedureDao, officeRepo);
    await repo.closeOfficeFileForEntity(
      entityId: 999, reason: 'تم إنجازه', summary: 'بلا ملف مكتب');
    expect(await read(EntityType.adminProcedure, 999), isNull);
  });

  test('Pending flags are preserved on closure', () async {
    await makeOffice(OfficeFileType.company, EntityType.company, 16);
    final repo = CompanyRepository(
        db.companyDao, TaskSyncService(db), DeficiencyService(db), officeRepo);

    await repo.closeOfficeFileForEntity(
      entityId: 16,
      reason: 'انحلت',
      summary: 'تصفية',
      hasPendingFinance: true,
      hasPendingPaperOriginal: true,
    );

    final office = await read(EntityType.company, 16);
    expect(office!.hasPendingFinance, isTrue);
    expect(office.hasPendingPaperOriginal, isTrue);
  });
}
