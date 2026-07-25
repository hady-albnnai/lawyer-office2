import 'package:drift/drift.dart';
import '../../core/enums/app_enums.dart';
import '../database/database.dart';
import '../database/daos/company_dao.dart';
import '../services/task_sync_service.dart';
import '../services/deficiency_service.dart';
import 'office_file_repository.dart';

/// مستودع إدارة الشركات التجارية والمدنية ومراحل التأسيس (CompanyRepository)
class CompanyRepository {
  final CompanyDao _companyDao;
  final TaskSyncService _taskSyncService;
  final DeficiencyService _deficiencyService;
  final OfficeFileRepository _officeFileRepository;

  CompanyRepository(
    this._companyDao,
    this._taskSyncService,
    this._deficiencyService,
    this._officeFileRepository,
  );

  Stream<List<Company>> watchAllCompanies() => _companyDao.watchAllCompanies();
  Future<Company?> getCompanyById(int id) => _companyDao.getCompanyById(id);
  Stream<List<CompanyPhase>> watchCompanyPhases(int companyId) => _companyDao.watchCompanyPhases(companyId);
  Stream<List<CompanyManagementData>> watchCompanyManagement(int companyId) => _companyDao.watchCompanyManagement(companyId);
  Stream<List<CompanyPartner>> watchCompanyPartners(int companyId) => _companyDao.watchCompanyPartners(companyId);
  Stream<List<CompanyDirector>> watchCompanyDirectors(int companyId) => _companyDao.watchCompanyDirectors(companyId);

  /// تأسيس شركة جديدة وتوليد المراحل الابتدائية وأتمتة المهام وتدقيق النواقص
  Future<int> createCompany({
    required CompaniesCompanion company,
    required List<CompanyPartnersCompanion> partners,
    required List<CompanyDirectorsCompanion> directors,
    required String userRef,
  }) async {
    return await _companyDao.db.transaction(() async {
      final officeFile = await _officeFileRepository.createOfficeFile(
        fileType: OfficeFileType.company,
        source: OfficeFileSource.newWork,
        status: OfficeFileStatus.active,
        title: company.name.value,
        openedByNameSnapshot: userRef,
      );
      final String internalNum = officeFile.fileNumber;
      
      final companyId = await _companyDao.insertCompany(
        company.copyWith(
          internalNumber: Value(internalNum),
          createdAt: Value(DateTime.now()),
        ),
      );
      await _officeFileRepository.linkOfficeFile(
        officeFileId: officeFile.id,
        entityType: EntityType.company.index,
        entityId: companyId,
      );

      for (final p in partners) {
        await _companyDao.insertCompanyPartner(p.copyWith(companyId: Value(companyId)));
      }

      for (final d in directors) {
        await _companyDao.insertCompanyDirector(d.copyWith(companyId: Value(companyId)));
      }

      final archived = (company.isArchived.present && company.isArchived.value) ||
          (company.legalStatus.present && company.legalStatus.value == 'archived');

      if (!archived) {
        // إضافة مرحلة التأسيس الأولى تلقائياً للملفات الجارية فقط.
        await _taskSyncService.syncCompanyPhase(
          phase: CompanyPhasesCompanion.insert(
            companyId: companyId,
            phaseName: 'صياغة عقد التأسيس وتصديق النقابة',
            phaseOrder: 1,
            status: const Value(0),
            scheduledDate: Value(DateTime.now().add(const Duration(days: 2))),
          ),
          companyName: company.name.value,
          companyId: companyId,
          userRef: userRef,
        );

        // تدقيق النواقص للملفات الجارية فقط حتى لا يظهر الأرشيف المنتهي كعمل مطلوب.
        await _deficiencyService.auditCompanyDeficiencies(
          companyId: companyId,
          companyData: company,
          hasPartners: partners.isNotEmpty,
          hasDirectors: directors.isNotEmpty,
        );
      }

      await _companyDao.into(_companyDao.db.timelineEvents).insert(
        TimelineEventsCompanion.insert(
          entityType: EntityType.company.index,
          entityId: companyId,
          eventType: 'company_created',
          eventDate: Value(DateTime.now()),
          description: 'تم البدء بتأسيس شركة جديدة [${company.name.value}] برقم ملف: $internalNum',
          userRef: Value(userRef),
        ),
      );

      return companyId;
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
      entityType: EntityType.company.index,
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
