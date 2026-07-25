import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/office_file_repository.dart';
import 'package:lawyer_office/data/repositories/work_order_repository.dart';
import 'package:lawyer_office/data/services/conflict_of_interest_service.dart';

/// المراحل 6 و10 و13 و17 من خارطة التنفيذ النهائية.
void main() {
  late AppDatabase db;
  late OfficeFileRepository officeRepo;
  late ConflictOfInterestService conflicts;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    officeRepo = OfficeFileRepository(db);
    conflicts = ConflictOfInterestService(db);
    await db.ensureOfficeFileTables();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> newPerson(String name) =>
      db.into(db.persons).insert(PersonsCompanion.insert(fullName: name));

  Future<int> newCase(String number, {String status = 'registered'}) =>
      db.into(db.cases).insert(CasesCompanion.insert(
            internalNumber: number,
            year: 2026,
            caseType: 'مدني',
            status: Value(status),
          ));

  Future<void> addParty(int caseId, int personId, {required bool isClient}) =>
      db.into(db.caseParties).insert(CasePartiesCompanion.insert(
            caseId: caseId,
            personId: personId,
            partyRole: isClient ? 'مدعي' : 'مدعى عليه',
            isClient: Value(isClient),
          ));

  // ---------------- المرحلة السادسة ----------------

  test('Stage 6: work order is linked directly to the office file', () async {
    final office = await officeRepo.createOfficeFile(
      fileType: OfficeFileType.caseFile,
      linkedEntityType: EntityType.caseEntity.index,
      linkedEntityId: 30,
      title: 'دعوى',
    );

    final repo = WorkOrderRepository(db.workOrderDao);
    final id = await repo.create(
      assignedToName: 'المعقب سامر',
      orderType: 'court_attendance',
      priority: 'high',
      dueDate: DateTime(2026, 9, 1),
      linkedEntityType: EntityType.caseEntity.index,
      linkedEntityId: 30,
    );

    final saved = await (db.select(db.workOrders)..where((t) => t.id.equals(id))).getSingle();
    expect(saved.officeFileId, office.id,
        reason: 'أمر العمل يجب أن يرتبط بملف المكتب مباشرة');
  });

  test('Stage 6: work order without an office file still saves', () async {
    final repo = WorkOrderRepository(db.workOrderDao);
    final id = await repo.create(
      assignedToName: 'سامر',
      orderType: 'other',
      priority: 'low',
      dueDate: DateTime(2026, 9, 1),
    );
    final saved = await (db.select(db.workOrders)..where((t) => t.id.equals(id))).getSingle();
    expect(saved.officeFileId, isNull);
  });

  // ---------------- المرحلة العاشرة ----------------

  test('Stage 10: former opponent becoming a client raises a high warning', () async {
    final person = await newPerson('سامي');
    final oldCase = await newCase('دعوى/2025/0001');
    await addParty(oldCase, person, isClient: false);

    final warnings = await conflicts.checkPerson(personId: person, asClient: true);

    expect(warnings, isNotEmpty);
    expect(warnings.first.severity, ConflictSeverity.high);
    expect(warnings.first.relatedFiles, contains('دعوى/2025/0001'));
  });

  test('Stage 10: existing client set as opponent raises a warning', () async {
    final person = await newPerson('أحمد');
    final c = await newCase('دعوى/2026/0002');
    await addParty(c, person, isClient: true);

    final warnings = await conflicts.checkPerson(personId: person, asClient: false);
    expect(warnings.any((w) => w.severity == ConflictSeverity.high), isTrue);
  });

  test('Stage 10: a clean person produces no warnings', () async {
    final person = await newPerson('شخص جديد');
    final warnings = await conflicts.checkPerson(personId: person, asClient: true);
    expect(warnings, isEmpty);
  });

  test('Stage 10: contradictory roles across files are flagged', () async {
    final person = await newPerson('جهة');
    final a = await newCase('د/1');
    final b = await newCase('د/2');
    await addParty(a, person, isClient: true);
    await addParty(b, person, isClient: false);

    final warnings = await conflicts.checkPerson(personId: person, asClient: true);
    expect(warnings.any((w) => w.title.contains('صفة متضاربة')), isTrue);
  });

  test('Stage 10: revoked POA on an active case is detected', () async {
    final person = await newPerson('موكل');
    final poaId = await db.into(db.powersOfAttorney).insert(
          PowersOfAttorneyCompanion.insert(
            sourceType: 'notary',
            poaType: PoaType.general.index,
            status: Value(PoaStatus.revoked.dbValue),
          ),
        );
    await db.into(db.poaParties).insert(
          PoaPartiesCompanion.insert(poaId: poaId, personId: person),
        );
    final caseId = await newCase('دعوى/2026/0009');
    await db.into(db.casePoaLinks).insert(
          CasePoaLinksCompanion.insert(caseId: caseId, poaId: poaId),
        );

    final warnings = await conflicts.checkPerson(personId: person, asClient: true);
    expect(warnings.any((w) => w.title.contains('وكالة غير صالحة')), isTrue);
  });

  // ---------------- المرحلة الثالثة عشرة ----------------

  test('Stage 13: template source defaults to ready and accepts imported', () async {
    final readyId = await db.into(db.contractTemplates).insert(
          ContractTemplatesCompanion.insert(
            contractType: 'إيجار',
            templateName: 'نموذج جاهز',
            filePath: 'templates/a.docx',
          ),
        );
    final importedId = await db.into(db.contractTemplates).insert(
          ContractTemplatesCompanion.insert(
            contractType: 'بيع',
            templateName: 'نموذج مستورد',
            filePath: 'templates/b.docx',
            templateSource: const Value('imported'),
          ),
        );

    final all = await db.select(db.contractTemplates).get();
    expect(all.firstWhere((t) => t.id == readyId).templateSource, 'ready');
    expect(all.firstWhere((t) => t.id == importedId).templateSource, 'imported');
  });

  test('Stage 13: a generated template can reference its source office file', () async {
    final office = await officeRepo.createOfficeFile(
      fileType: OfficeFileType.contract,
      linkedEntityType: EntityType.contract.index,
      linkedEntityId: 3,
      title: 'عقد',
    );
    final id = await db.into(db.contractTemplates).insert(
          ContractTemplatesCompanion.insert(
            contractType: 'إيجار',
            templateName: 'مولّد من ملف',
            filePath: 'templates/gen.docx',
            templateSource: const Value('generated'),
            sourceOfficeFileId: Value(office.id),
          ),
        );
    final saved = await (db.select(db.contractTemplates)..where((t) => t.id.equals(id))).getSingle();
    expect(saved.templateSource, 'generated');
    expect(saved.sourceOfficeFileId, office.id);
  });
}
