import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/case_repository.dart';
import 'package:lawyer_office/data/repositories/document_repository.dart';
import 'package:lawyer_office/data/repositories/office_file_repository.dart';
import 'package:lawyer_office/data/repositories/person_repository.dart';
import 'package:lawyer_office/data/repositories/work_order_repository.dart';
import 'package:lawyer_office/data/services/deficiency_service.dart';
import 'package:lawyer_office/data/services/file_storage_service.dart';
import 'package:lawyer_office/data/services/task_sync_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  CaseRepository caseRepo() => CaseRepository(
        db.caseDao,
        TaskSyncService(db),
        DeficiencyService(db),
        FileStorageService(),
        OfficeFileRepository(db),
      );

  test('Person/case/document/workorder seed and persist in SQLite', () async {
    final persons = PersonRepository(db.personDao, FileStorageService());
    final cases = caseRepo();
    final docs = DocumentRepository(db.documentDao, FileStorageService());
    final wo = WorkOrderRepository(db.workOrderDao);

    await persons.seedDemoIfEmpty();
    await cases.seedDemoIfEmpty();
    await docs.seedDemoIfEmpty();
    await wo.seedDemoIfEmpty();

    expect(await persons.getAllPersons(), isNotEmpty);
    expect(await cases.getAllCases(), isNotEmpty);
    expect(await docs.getAllDocuments(), isNotEmpty);
    expect(await wo.getAll(), isNotEmpty);

    // idempotent seed
    final pCount = (await persons.getAllPersons()).length;
    await persons.seedDemoIfEmpty();
    expect((await persons.getAllPersons()).length, pCount);

    final cCount = (await cases.getAllCases()).length;
    await cases.seedDemoIfEmpty();
    expect((await cases.getAllCases()).length, cCount);
  });

  test('Work order create adds row', () async {
    final wo = WorkOrderRepository(db.workOrderDao);
    await wo.seedDemoIfEmpty();
    final before = (await wo.getAll()).length;
    await wo.create(
      internalNumber: 'WO-TEST-999',
      assignedToName: 'معقب',
      orderType: 'other',
      priority: 'low',
      status: 'draft',
      dueDate: DateTime.now(),
      instructions: 'اختبار',
    );
    expect((await wo.getAll()).length, before + 1);
  });
}
