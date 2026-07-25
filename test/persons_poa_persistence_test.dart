import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/person_repository.dart';
import 'package:lawyer_office/data/repositories/office_file_repository.dart';
import 'package:lawyer_office/data/repositories/poa_repository.dart';
import 'package:lawyer_office/data/services/file_storage_service.dart';

/// ربط الوكالة بدعوى وإضافة ملاحظة على الخط الزمني كانا يعدّلان حالة الشاشة
/// فقط عبر PersonsDirectoryNotifier، فتضيع النتيجة عند إعادة الفتح.
void main() {
  late AppDatabase db;
  late PersonRepository personRepo;
  late PoaRepository poaRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    personRepo = PersonRepository(db.personDao, FileStorageService());
    poaRepo = PoaRepository(db.personDao, FileStorageService(), OfficeFileRepository(db));
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> makePerson([String name = 'موكل']) =>
      db.into(db.persons).insert(PersonsCompanion.insert(fullName: name));

  Future<int> makeCase(String number) => db.into(db.cases).insert(
        CasesCompanion.insert(internalNumber: number, year: 2026, caseType: 'مدني'),
      );

  Future<int> makePoa() => db.into(db.powersOfAttorney).insert(
        PowersOfAttorneyCompanion.insert(
          sourceType: 'notary',
          poaType: PoaType.general.index,
          poaNumber: const Value('POA-1'),
        ),
      );

  test('Linking a POA to a case persists in case_poa_links', () async {
    final caseId = await makeCase('دعوى/2026/0001');
    final poaId = await makePoa();

    await poaRepo.linkPoaToCase(caseId, poaId);

    final links = await db.select(db.casePoaLinks).get();
    expect(links, hasLength(1));
    expect(links.first.caseId, caseId);
    expect(links.first.poaId, poaId);
  });

  test('A POA can be linked to several distinct cases', () async {
    final poaId = await makePoa();
    final first = await makeCase('دعوى/2026/0001');
    final second = await makeCase('دعوى/2026/0002');

    await poaRepo.linkPoaToCase(first, poaId);
    await poaRepo.linkPoaToCase(second, poaId);

    final links = await db.select(db.casePoaLinks).get();
    expect(links, hasLength(2));
  });

  test('Timeline note is stored against the person', () async {
    final personId = await makePerson('أحمد الخطيب');

    await personRepo.addTimelineNote(
      personId: personId,
      note: 'اتصل الموكل لتأكيد موعد الجلسة',
      userRef: 'هادي',
    );

    final events = await (db.select(db.timelineEvents)
          ..where((t) =>
              t.entityType.equals(EntityType.person.index) & t.entityId.equals(personId)))
        .get();

    expect(events, hasLength(1));
    expect(events.first.eventType, 'note');
    expect(events.first.description, 'اتصل الموكل لتأكيد موعد الجلسة');
    expect(events.first.userRef, 'هادي');
  });

  test('Notes of one person do not leak into another', () async {
    final first = await makePerson('أ');
    final second = await makePerson('ب');

    await personRepo.addTimelineNote(personId: first, note: 'ملاحظة أ', userRef: 'هادي');

    final events = await (db.select(db.timelineEvents)
          ..where((t) =>
              t.entityType.equals(EntityType.person.index) & t.entityId.equals(second)))
        .get();
    expect(events, isEmpty);
  });
}
