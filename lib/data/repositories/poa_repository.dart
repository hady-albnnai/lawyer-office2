import 'dart:io';
import 'package:drift/drift.dart';
import '../../core/enums/app_enums.dart';
import '../database/database.dart';
import '../database/daos/person_dao.dart';
import '../services/file_storage_service.dart';
import 'office_file_repository.dart';

/// مستودع إدارة الوكالات القضائية والقانونية (PoaRepository)
class PoaRepository {
  final PersonDao _personDao;
  final FileStorageService _storageService;
  final OfficeFileRepository _officeFileRepository;

  PoaRepository(this._personDao, this._storageService, this._officeFileRepository);

  Stream<List<PowersOfAttorneyData>> watchAllPoas() => _personDao.watchAllPoas();

  /// إصدار وحفظ سند توكيل جديد وربط الموكل والوكيل مع إرفاق صورة السند
  Future<int> createPoa({
    required PowersOfAttorneyCompanion poa,
    required int principalId,
    int? agentId,
    File? poaFile,
  }) async {
    return await _personDao.db.transaction(() async {
      final officeFile = await _officeFileRepository.createOfficeFile(
        fileType: OfficeFileType.agency,
        source: OfficeFileSource.newWork,
        status: OfficeFileStatus.active,
        title: poa.poaNumber.present ? 'وكالة ${poa.poaNumber.value ?? ''}'.trim() : 'وكالة',
      );
      final poaId = await _personDao.insertPoa(poa);
      await _officeFileRepository.linkOfficeFile(
        officeFileId: officeFile.id,
        entityType: EntityType.powerOfAttorney.index,
        entityId: poaId,
      );

      if (poaFile != null) {
        final filePath = await _storageService.saveAttachment(
          sourceFile: poaFile,
          folderType: 'powers_of_attorney',
          entityId: poaId,
        );
        await (_personDao.update(_personDao.db.powersOfAttorney)..where((t) => t.id.equals(poaId))).write(
          PowersOfAttorneyCompanion(filePath: Value(filePath)),
        );
      }

      // إضافة الموكل الأساسي
      await _personDao.insertPoaParty(
        PoaPartiesCompanion.insert(
          poaId: poaId,
          personId: principalId,
          partyRole: const Value('principal'),
          isPrimary: const Value(true),
        ),
      );

      // إضافة الوكيل إن وجد
      if (agentId != null) {
        await _personDao.insertPoaParty(
          PoaPartiesCompanion.insert(
            poaId: poaId,
            personId: agentId,
            partyRole: const Value('agent'),
            isPrimary: const Value(false),
          ),
        );
      }

      return poaId;
    });
  }

  Future<int> linkPoaToCase(int caseId, int poaId) {
    return _personDao.linkPoaToCase(caseId, poaId);
  }
  /// إنهاء الملف وإغلاق ملف المكتب المرتبط.
  ///
  /// المرحلة الرابعة من خارطة التنفيذ تشمل الأنواع الخمسة، وكان الإغلاق
  /// منفَّذاً للدعوى فقط، فتبقى بقية الملفات «جارية» بعد انتهائها فعلياً.
  Future<void> closeOfficeFileForEntity({
    required int entityId,
    required String reason,
    required String summary,
    String? userRef,
    bool hasPendingFinance = false,
    bool hasPendingPaperOriginal = false,
    bool hasPostClosureActions = false,
  }) async {
    final office = await _officeFileRepository.getByLinkedEntity(
      entityType: EntityType.powerOfAttorney.index,
      entityId: entityId,
    );
    if (office == null || office.status == OfficeFileStatus.closed) return;
    await _officeFileRepository.closeOfficeFile(
      officeFileId: office.id,
      reason: reason,
      summary: summary,
      closedByNameSnapshot: userRef,
      hasPendingFinance: hasPendingFinance,
      hasPendingPaperOriginal: hasPendingPaperOriginal,
      hasPostClosureActions: hasPostClosureActions,
    );
  }
}
