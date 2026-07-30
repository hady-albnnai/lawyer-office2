import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/app_enums.dart';
import '../../data/database/database.dart';
import '../../data/services/conflict_of_interest_service.dart';
import '../../data/services/sequence_service.dart';
import '../../data/services/task_sync_service.dart';
import '../../data/services/deficiency_service.dart';
import '../../data/services/attachment_service.dart';
import '../../data/services/file_storage_service.dart';
import '../../data/services/backup_service.dart';
import '../../data/repositories/person_repository.dart';
import '../../data/repositories/poa_repository.dart';
import '../../data/repositories/case_repository.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/contract_repository.dart';
import '../../data/repositories/admin_procedure_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/lookup_repository.dart';
import '../../data/repositories/legal_library_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/work_order_repository.dart';
import '../../data/repositories/archive_intake_repository.dart';
import '../../data/repositories/office_file_repository.dart';

// =============================================================================
// 1. مزود قاعدة البيانات الموحدة (Database Provider)
// =============================================================================
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// =============================================================================
// 2. مزودات المحركات والخدمات الخلفية (Services & Engines Providers)
// =============================================================================
final sequenceServiceProvider = Provider<SequenceService>((ref) {
  return SequenceService(ref.watch(databaseProvider));
});

final taskSyncServiceProvider = Provider<TaskSyncService>((ref) {
  return TaskSyncService(ref.watch(databaseProvider));
});

final deficiencyServiceProvider = Provider<DeficiencyService>((ref) {
  return DeficiencyService(ref.watch(databaseProvider));
});

final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});

/// إدارة اختيار المرفقات وفتحها (المرفقات مخزَّنة مشفّرة).
final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref.watch(fileStorageServiceProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

// =============================================================================
// 3. مزودات المستودعات (Repositories Providers)
// =============================================================================
final personRepositoryProvider = Provider<PersonRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PersonRepository(db.personDao, ref.watch(fileStorageServiceProvider));
});

final poaRepositoryProvider = Provider<PoaRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PoaRepository(db.personDao, ref.watch(fileStorageServiceProvider), ref.watch(officeFileRepositoryProvider));
});

final caseRepositoryProvider = Provider<CaseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CaseRepository(
    db.caseDao,
    ref.watch(taskSyncServiceProvider),
    ref.watch(deficiencyServiceProvider),
    ref.watch(fileStorageServiceProvider),
    ref.watch(officeFileRepositoryProvider),
  );
});

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CompanyRepository(
    db.companyDao,
    ref.watch(taskSyncServiceProvider),
    ref.watch(deficiencyServiceProvider),
    ref.watch(officeFileRepositoryProvider),
  );
});

final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ContractRepository(
    db.contractDao,
    ref.watch(taskSyncServiceProvider),
    ref.watch(fileStorageServiceProvider),
    ref.watch(officeFileRepositoryProvider),
  );
});

final adminProcedureRepositoryProvider = Provider<AdminProcedureRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AdminProcedureRepository(
    db.adminProcedureDao,
    ref.watch(officeFileRepositoryProvider),
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TaskRepository(
    db.taskDao,
    ref.watch(taskSyncServiceProvider),
    ref.watch(deficiencyServiceProvider),
  );
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FinanceRepository(db.financeDao, ref.watch(fileStorageServiceProvider));
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DocumentRepository(db.documentDao, ref.watch(fileStorageServiceProvider));
});

final lookupRepositoryProvider = Provider<LookupRepository>((ref) {
  return LookupRepository(ref.watch(databaseProvider).lookupDao);
});


final archiveIntakeRepositoryProvider = Provider<ArchiveIntakeRepository>((ref) {
  return ArchiveIntakeRepository(ref.watch(databaseProvider), ref.watch(fileStorageServiceProvider));
});


final officeFileRepositoryProvider = Provider<OfficeFileRepository>((ref) {
  return OfficeFileRepository(ref.watch(databaseProvider));
});


// =============================================================================
// 4. مزودات التدفق المباشر للبيانات للواجهات (Stream & UI Providers)
// =============================================================================

/// قائمة الدعاوى القضائية
final allCasesProvider = StreamProvider<List<Case>>((ref) {
  return ref.watch(caseRepositoryProvider).watchAllCases();
});

/// عدد الدعاوى الجارية في المكتب.
///
/// يشمل ما أُدخل من أرشيف الدعاوى الجارية وكل ما يُضاف بعد تشغيل
/// التطبيق. الدعوى المنتهية (status = 'closed') تخرج من هذا العد
/// تلقائياً لأن المزوّد مشتق من تدفق الدعاوى نفسه.
final activeCasesCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(allCasesProvider).whenData(
        (cases) => cases.where((c) => c.status != 'closed').length,
      );
});

/// عدد الدعاوى المنتهية في المكتب.
final closedCasesCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(allCasesProvider).whenData(
        (cases) => cases.where((c) => c.status == 'closed').length,
      );
});

/// تفاصيل دعوى واحدة من المستودع الحقيقي (Drift)
final caseDetailFromRepoProvider = FutureProvider.family<Case?, int>((ref, caseId) {
  return ref.watch(caseRepositoryProvider).getCaseById(caseId);
});

final casePartiesProvider = StreamProvider.family<List<CaseParty>, int>((ref, caseId) {
  return ref.watch(caseRepositoryProvider).watchCaseParties(caseId);
});

final caseSessionsProvider = StreamProvider.family<List<CaseSession>, int>((ref, caseId) {
  return ref.watch(caseRepositoryProvider).watchCaseSessions(caseId);
});

final casePhasesProvider = StreamProvider.family<List<CasePhase>, int>((ref, caseId) {
  return ref.watch(caseRepositoryProvider).watchCasePhases(caseId);
});

final caseOpenDeficienciesProvider = StreamProvider.family<List<Deficiency>, int>((ref, caseId) {
  return ref.watch(taskRepositoryProvider).watchOpenDeficiencies(
    entityType: EntityType.caseEntity,
    entityId: caseId,
  );
});

final allPersonsProvider = StreamProvider.family<List<PersonEntity>, PersonType?>((ref, type) {
  return ref.watch(personRepositoryProvider).watchAllPersons(type: type);
});

/// كل الوكالات المسجلة (تُستخدم في ربط الدعوى بسند التوكيل).
/// خدمة فحص تعارض المصالح (المرحلة العاشرة من خارطة التنفيذ).
final conflictOfInterestServiceProvider = Provider<ConflictOfInterestService>((ref) {
  return ConflictOfInterestService(ref.watch(databaseProvider));
});

/// تنبيهات تعارض المصالح لشخص بصفة محددة.
final conflictWarningsProvider =
    FutureProvider.family<List<ConflictWarning>, ({int personId, bool asClient})>((ref, q) {
  return ref.watch(conflictOfInterestServiceProvider).checkPerson(
        personId: q.personId,
        asClient: q.asClient,
      );
});

final allPoasProvider = FutureProvider<List<PowersOfAttorneyData>>((ref) {
  return ref.watch(personRepositoryProvider).getAllPoas();
});

final allCompaniesProvider = StreamProvider<List<Company>>((ref) {
  return ref.watch(companyRepositoryProvider).watchAllCompanies();
});

final allContractsProvider = StreamProvider<List<Contract>>((ref) {
  return ref.watch(contractRepositoryProvider).watchAllContracts();
});

final allProceduresProvider = StreamProvider<List<AdminProcedure>>((ref) {
  return ref.watch(adminProcedureRepositoryProvider).watchAllProcedures();
});

final tasksByDateProvider = StreamProvider.family<List<DailyTask>, DateTime?>((ref, date) {
  final target = date ?? DateTime.now();
  return ref.watch(taskRepositoryProvider).watchTasksByDate(target);
});

final openDeficienciesProvider = StreamProvider.family<List<Deficiency>, ({EntityType? type, int? id})?>((ref, filter) {
  return ref.watch(taskRepositoryProvider).watchOpenDeficiencies(
    entityType: filter?.type,
    entityId: filter?.id,
  );
});

final activeCourtsProvider = StreamProvider.family<List<Court>, String?>((ref, type) {
  return ref.watch(lookupRepositoryProvider).watchActiveCourts(type: type);
});


final legalLibraryRepositoryProvider = Provider<LegalLibraryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LegalLibraryRepository(db.legalLibraryDao);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsRepository(db.settingsDao, ref.watch(backupServiceProvider));
});


final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return WorkOrderRepository(db.workOrderDao);
});

/// المحاكم النشطة من قاعدة البيانات.
///
/// ضروري لربط الدعوى بمحكمة حقيقية: تمرير فهرس قائمة معروضة بدل
/// المعرّف الفعلي يكسر قيد المفتاح الأجنبي عند الحفظ.
final activeCourtsProvider = StreamProvider<List<Court>>((ref) {
  return ref.watch(settingsRepositoryProvider).watchCourts();
});
