import 'dart:io';
import 'package:drift/drift.dart';
import '../../core/enums/app_enums.dart';
import '../database/database.dart';
import '../database/daos/contract_dao.dart';
import '../services/task_sync_service.dart';
import '../services/file_storage_service.dart';
import 'office_file_repository.dart';

/// مستودع إدارة العقود، التنبيهات الزمنية، ونماذج Word (ContractRepository)
class ContractRepository {
  final ContractDao _contractDao;
  final TaskSyncService _taskSyncService;
  final FileStorageService _storageService;
  final OfficeFileRepository _officeFileRepository;

  ContractRepository(
    this._contractDao,
    this._taskSyncService,
    this._storageService,
    this._officeFileRepository,
  );

  Stream<List<Contract>> watchAllContracts() => _contractDao.watchAllContracts();
  Future<Contract?> getContractById(int id) => _contractDao.getContractById(id);
  Stream<List<ContractParty>> watchContractParties(int contractId) => _contractDao.watchContractParties(contractId);
  Stream<List<ContractReminder>> watchContractReminders(int contractId) => _contractDao.watchContractReminders(contractId);
  Stream<List<ContractTemplate>> watchContractTemplates({String? type}) => _contractDao.watchContractTemplates(contractType: type);
  Stream<List<ContractVersion>> watchContractVersions(int contractId) => _contractDao.watchContractVersions(contractId);
  Stream<List<ContractInstallment>> watchContractInstallments(int contractId) => _contractDao.watchContractInstallments(contractId);
  Future<List<ContractInstallment>> getContractInstallments(int contractId) => _contractDao.getContractInstallments(contractId);

  /// تنظيم عقد جديد وربط التنبيهات بجدول الأعمال اليومية مع رفع ملف Word
  /// 
  /// يدعم حفظ: الأطراف، التذكيرات، الأقساط، المستندات، واتفاقيات الأتعاب
  Future<int> createContract({
    required ContractsCompanion contract,
    required List<ContractPartiesCompanion> parties,
    List<ContractRemindersCompanion>? reminders,
    List<ContractInstallmentsCompanion>? installments,
    List<int>? documentIds,
    FeeAgreementsCompanion? feeAgreement,
    File? wordFile,
    required String userRef,
  }) async {
    return await _contractDao.db.transaction(() async {
      final officeFile = await _officeFileRepository.createOfficeFile(
        fileType: OfficeFileType.contract,
        source: OfficeFileSource.newWork,
        status: OfficeFileStatus.active,
        title: contract.title.value,
        openedByNameSnapshot: userRef,
      );
      final String internalNum = officeFile.fileNumber;
      
      final contractId = await _contractDao.insertContract(
        contract.copyWith(
          internalNumber: Value(internalNum),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _officeFileRepository.linkOfficeFile(
        officeFileId: officeFile.id,
        entityType: EntityType.contract.index,
        entityId: contractId,
      );

      for (final party in parties) {
        await _contractDao.insertContractParty(party.copyWith(contractId: Value(contractId)));
      }

      if (wordFile != null) {
        final filePath = await _storageService.saveAttachment(
          sourceFile: wordFile,
          folderType: 'contracts',
          entityId: contractId,
        );

        await _contractDao.insertContractVersion(
          ContractVersionsCompanion.insert(
            contractId: contractId,
            versionNumber: 1,
            filePath: Value(filePath),
            editedBy: Value(userRef),
            notes: const Value('النسخة الأولى عند إبرام العقد'),
          ),
        );
      }

      // حفظ التذكيرات الزمنية
      if (reminders != null) {
        for (final r in reminders) {
          final companion = r.copyWith(contractId: Value(contractId));
          await _taskSyncService.syncContractReminder(
            reminder: companion,
            contractTitle: contract.title.value,
            contractId: contractId,
          );
        }
      }

      // حفظ الأقساط (إذا كانت طريقة الدفع بالتقسيط)
      if (installments != null && installments.isNotEmpty) {
        for (final installment in installments) {
          await _contractDao.insertContractInstallment(
            installment.copyWith(contractId: Value(contractId)),
          );
        }
      }

      // ربط المستندات المرفقة بالعقد
      if (documentIds != null && documentIds.isNotEmpty) {
        for (final docId in documentIds) {
          await _contractDao.into(_contractDao.db.documentLinks).insert(
            DocumentLinksCompanion.insert(
              documentId: docId,
              entityType: EntityType.contract.index,
              entityId: contractId,
              linkType: const Value('general'),
            ),
          );
        }
      }

      // حفظ اتفاقية الأتعاب
      if (feeAgreement != null) {
        await _contractDao.into(_contractDao.db.feeAgreements).insert(
          feeAgreement.copyWith(
            entityType: Value(EntityType.contract.index),
            entityId: Value(contractId),
          ),
        );
      }

      await _contractDao.into(_contractDao.db.timelineEvents).insert(
        TimelineEventsCompanion.insert(
          entityType: EntityType.contract.index,
          entityId: contractId,
          eventType: 'contract_created',
          eventDate: Value(DateTime.now()),
          description: 'تم تنظيم عقد جديد [${contract.title.value}] برقم ملف: $internalNum',
          userRef: Value(userRef),
        ),
      );

      return contractId;
    });
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
      entityType: EntityType.contract.index,
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

  /// رفع ملف Word كنسخة جديدة من العقد.
  ///
  /// يُخزَّن الملف مشفّراً مثل بقية المرفقات، ويأخذ رقم النسخة التالي
  /// تلقائياً حتى لا تتضارب النسخ.
  Future<int> addContractVersion({
    required int contractId,
    required File wordFile,
    String? userRef,
    String? notes,
  }) async {
    final filePath = await _storageService.saveAttachment(
      sourceFile: wordFile,
      folderType: 'contracts',
      entityId: contractId,
    );

    final existing =
        await _contractDao.watchContractVersions(contractId).first;
    final nextVersion = existing.isEmpty
        ? 1
        : (existing
                .map((v) => v.versionNumber)
                .reduce((a, b) => a > b ? a : b) +
            1);

    return _contractDao.insertContractVersion(
      ContractVersionsCompanion.insert(
        contractId: contractId,
        versionNumber: nextVersion,
        filePath: Value(filePath),
        editedBy: Value(userRef),
        notes: Value(notes ?? 'نسخة مرفوعة يدوياً'),
      ),
    );
  }

}
