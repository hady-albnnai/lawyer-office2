import 'dart:io';
import 'package:drift/drift.dart';
import '../../core/enums/app_enums.dart';
import '../database/database.dart';
import '../database/daos/person_dao.dart';
import '../services/file_storage_service.dart';

/// مستودع إدارة الأشخاص، الكيانات الاعتبارية، ودليل المحامين وكتاب العدل (PersonRepository)
class PersonRepository {
  final PersonDao _personDao;
  final FileStorageService _storageService;

  PersonRepository(this._personDao, this._storageService);

  Stream<List<PersonEntity>> watchAllPersons({PersonType? type}) {
    return _personDao.watchAllPersons(type: type?.index);
  }

  Future<List<PersonEntity>> getAllPersons({PersonType? type}) {
    return _personDao.getAllPersons(type: type?.index);
  }

  Stream<List<PowersOfAttorneyData>> watchAllPoas() => _personDao.watchAllPoas();
  Future<List<PowersOfAttorneyData>> getAllPoas() => _personDao.getAllPoas();
  Future<List<PersonRole>> getPersonRoles(int personId) => _personDao.getPersonRoles(personId);



  Future<PersonEntity?> getPersonById(int id) {
    return _personDao.getPersonById(id);
  }

  /// حفظ شخص جديد مع إمكانية حفظ سند تمثيل إذا كان كياناً اعتبارياً
  Future<int> createPerson({
    required PersonsCompanion person,
    LegalEntitiesCompanion? legalEntity,
    File? representationDocFile,
    List<PersonRoleType>? initialRoles,
  }) async {
    return await _personDao.db.transaction(() async {
      final personId = await _personDao.insertPerson(person);

      final personType = person.type.present ? person.type.value : 0;
      if (personType == PersonType.legal.index && legalEntity != null) {
        String? docPath;
        if (representationDocFile != null) {
          docPath = await _storageService.saveAttachment(
            sourceFile: representationDocFile,
            folderType: 'legal_entities',
            entityId: personId,
          );
        }

        await _personDao.insertLegalEntity(
          legalEntity.copyWith(
            personId: Value(personId),
            representationDocPath: Value(docPath),
          ),
        );
      }

      if (initialRoles != null) {
        for (final role in initialRoles) {
          await _personDao.insertPersonRole(
            PersonRolesCompanion.insert(
              personId: personId,
              roleType: role.index,
            ),
          );
        }
      }
      return personId;
    });
  }

  Stream<List<PersonRole>> watchPersonRoles(int personId) => _personDao.watchPersonRoles(personId);
  Stream<List<TeamMember>> watchTeamMembers() => _personDao.watchTeamMembers();
  Stream<List<OpponentLawyer>> watchOpponentLawyers() => _personDao.watchOpponentLawyers();
  Stream<List<Notary>> watchNotaries() => _personDao.watchNotaries();

  /// إضافة ملاحظة متابعة على الخط الزمني للشخص (تُحفظ في timeline_events).
  Future<int> addTimelineNote({
    required int personId,
    required String note,
    required String userRef,
  }) {
    return _personDao.db.into(_personDao.db.timelineEvents).insert(
          TimelineEventsCompanion.insert(
            entityType: EntityType.person.index,
            entityId: personId,
            eventType: 'note',
            eventDate: Value(DateTime.now()),
            description: note,
            userRef: Value(userRef),
          ),
        );
  }

  Future<void> seedDemoIfEmpty() async {
    final existing = await _personDao.getAllPersons();
    if (existing.isNotEmpty) return;

    await createPerson(
      person: PersonsCompanion.insert(
        fullName: 'أحمد محمد الخطيب',
        fatherName: const Value('محمد'),
        nationalId: const Value('01010010001'),
        phone1: const Value('0933000001'),
        whatsapp: const Value('0933000001'),
        city: const Value('دمشق'),
        profession: const Value('تاجر'),
        notes: const Value('موكل رئيسي'),
      ),
      initialRoles: [PersonRoleType.client],
    );
    await createPerson(
      person: PersonsCompanion.insert(
        fullName: 'محمد أحمد السالم',
        phone1: const Value('0944000002'),
        city: const Value('السويداء'),
      ),
      initialRoles: [PersonRoleType.opponent],
    );
    await createPerson(
      person: PersonsCompanion.insert(
        fullName: 'شركة التطوير الحديث المحدودة المسؤولية',
        type: const Value(1),
        phone1: const Value('0111234567'),
        city: const Value('دمشق'),
      ),
      initialRoles: [PersonRoleType.client],
    );

    // وكالة
    await _personDao.insertPoa(
      PowersOfAttorneyCompanion.insert(
        sourceType: 'delegate',
        poaType: 0,
        poaNumber: const Value('POA-2026-001'),
        poaDate: Value(DateTime.now().subtract(const Duration(days: 20))),
        delegateBranch: const Value('دمشق'),
        scopeText: const Value('وكالة عامة'),
        status: const Value('active'),
      ),
    );
  }
}
