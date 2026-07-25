import 'dart:io';
import 'package:drift/drift.dart';
import '../../core/enums/app_enums.dart';
import '../database/database.dart';
import '../database/daos/document_dao.dart';
import '../services/file_storage_service.dart';
import 'office_file_repository.dart';

class DocumentRepository {
  final DocumentDao _documentDao;
  final FileStorageService _storageService;

  DocumentRepository(this._documentDao, this._storageService);

  Stream<List<Document>> watchAllDocuments() => _documentDao.watchAllDocuments();
  Future<List<Document>> getAllDocuments() => _documentDao.getAllDocuments();
  Future<List<DocumentLink>> getAllLinks() => _documentDao.getAllLinks();

  Stream<List<Document>> watchDocumentsByEntity(EntityType entityType, int entityId) {
    return _documentDao.watchDocumentsByEntity(entityType.index, entityId);
  }

  /// ربط مستند موجود بكيان (ربط عالمي) دون تكرار نسخة الملف.
  Future<void> linkExistingDocument({
    required int documentId,
    required int entityType,
    required int entityId,
    String linkType = 'manual_link',
  }) async {
    await _documentDao.linkDocument(documentId, entityType, entityId, linkType: linkType);
  }

  /// فك ربط مستند عن كيان. المستند يبقى محفوظاً في الأرشيف العام.
  Future<void> unlinkDocument({
    required int documentId,
    required int entityType,
    required int entityId,
  }) async {
    await _documentDao.unlinkDocument(documentId, entityType, entityId);
  }

  Future<int> addDocument({
    required String docName,
    String? docType,
    String? fileType,
    String? summary,
    String? notes,
    int? physicalLocation,
    bool? paperOriginalSaved,
    String? paperLocation,
    String? paperBox,
    String? paperShelf,
    String? paperFolder,
    bool? canDestroyOriginal,
    String? reviewedBy,
    /// الأصل بيد الموكل.
    bool? withClient,
    /// الأصل مبرز لدى المحكمة.
    bool? courtExhibit,
    /// لا يوجد أصل ورقي، نسخة رقمية فقط.
    bool? digitalOnly,
    /// مرجع محضر التسليم/الاستلام.
    String? handoverReference,
    File? sourceFile,
    required int entityType,
    required int entityId,
    required String userRef,
  }) async {
    return await _documentDao.db.transaction(() async {
      String? filePath;
      if (sourceFile != null) {
        filePath = await _storageService.saveAttachment(
          sourceFile: sourceFile,
          folderType: 'documents',
          entityId: entityId,
        );
      }

      final docId = await _documentDao.insertDocument(
        DocumentsCompanion.insert(
          docName: docName,
          docType: Value(docType),
          filePath: Value(filePath),
          fileType: Value(fileType),
          summary: Value(summary),
          notes: Value(notes),
          physicalLocation: Value(physicalLocation ?? 0),
        ),
      );

      await _documentDao.linkDocument(docId, entityType, entityId);

      final hasPaperMetadata = paperOriginalSaved != null ||
          (paperLocation ?? '').trim().isNotEmpty ||
          (paperBox ?? '').trim().isNotEmpty ||
          (paperShelf ?? '').trim().isNotEmpty ||
          (paperFolder ?? '').trim().isNotEmpty ||
          canDestroyOriginal != null ||
          withClient != null ||
          courtExhibit != null ||
          digitalOnly != null ||
          (handoverReference ?? '').trim().isNotEmpty ||
          (reviewedBy ?? '').trim().isNotEmpty;
      if (hasPaperMetadata) {
        await _documentDao.db.customStatement('''
          INSERT OR REPLACE INTO document_paper_metadata(
            document_id, paper_original_saved, paper_location, box, shelf, paper_folder,
            can_destroy_original, reviewed_by, reviewed_at, notes,
            with_client, court_exhibit, digital_only, handover_reference, updated_at
          ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ''', [
          docId,
          (paperOriginalSaved ?? false) ? 1 : 0,
          paperLocation,
          paperBox,
          paperShelf,
          paperFolder,
          (canDestroyOriginal ?? false) ? 1 : 0,
          reviewedBy,
          notes,
          (withClient ?? false) ? 1 : 0,
          (courtExhibit ?? false) ? 1 : 0,
          (digitalOnly ?? false) ? 1 : 0,
          handoverReference,
        ]);
      }

      await OfficeFileRepository(_documentDao.db).updatePendingFlagsByLinkedEntity(
        entityType: entityType,
        entityId: entityId,
        // الأصل يُعد معلقاً فقط إذا لم يُحفظ ولم يكن رقمياً بحتاً ولا مبرزاً
        // لدى المحكمة ولا بيد الموكل بمحضر.
        hasPendingPaperOriginal: paperOriginalSaved == null
            ? null
            : !(paperOriginalSaved ||
                (digitalOnly ?? false) ||
                (courtExhibit ?? false) ||
                (withClient ?? false)),
      );

      await _documentDao.into(_documentDao.db.timelineEvents).insert(
            TimelineEventsCompanion.insert(
              entityType: entityType,
              entityId: entityId,
              eventType: 'document_added',
              eventDate: Value(DateTime.now()),
              description: 'إضافة مستند: $docName',
              userRef: Value(userRef),
            ),
          );

      return docId;
    });
  }

  Future<bool> deleteDocument(int id, String? relativePath) async {
    await _documentDao.deleteDocument(id);
    return true;
  }

  Future<void> seedDemoIfEmpty() async {
    final docs = await _documentDao.getAllDocuments();
    if (docs.isNotEmpty) return;

    Future<void> add(String name, String type, String fileType, int entityType, int entityId, {bool missing = false}) async {
      final id = await _documentDao.insertDocument(
        DocumentsCompanion.insert(
          docName: name,
          docType: Value(type),
          fileType: Value(fileType),
          filePath: Value('docs/$name'),
          summary: Value(name),
          physicalLocation: Value(missing ? 1 : 0),
          status: Value(missing ? 1 : 0),
        ),
      );
      await _documentDao.linkDocument(id, entityType, entityId);
    }

    await add('وكالة عامة لعام 2026', 'power_of_attorney', 'pdf', 0, 1);
    await add('قرار المحكمة', 'decision', 'pdf', 0, 1);
    await add('مذكرة قانونية', 'memo', 'docx', 0, 1);
    await add('سند التوكيل', 'power_of_attorney', 'pdf', 0, 2, missing: true);
    await add('عقد بيع', 'contract', 'docx', 1, 1);
  }
}
