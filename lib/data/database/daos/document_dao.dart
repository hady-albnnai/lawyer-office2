import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'document_dao.g.dart';

@DriftAccessor(tables: [Documents, DocumentLinks])
class DocumentDao extends DatabaseAccessor<AppDatabase> with _$DocumentDaoMixin {
  DocumentDao(super.db);

  Stream<List<Document>> watchAllDocuments() {
    return (select(documents)
          ..orderBy([(t) => OrderingTerm(expression: t.dateAdded, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Document>> getAllDocuments() {
    return (select(documents)
          ..orderBy([(t) => OrderingTerm(expression: t.dateAdded, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<DocumentLink>> getAllLinks() => select(documentLinks).get();

  Stream<List<Document>> watchDocumentsByEntity(int entityType, int entityId) {
    final query = select(documents).join([
      innerJoin(
        documentLinks,
        documentLinks.documentId.equalsExp(documents.id) &
            documentLinks.entityType.equals(entityType) &
            documentLinks.entityId.equals(entityId),
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) => row.readTable(documents)).toList();
    });
  }

  Future<int> insertDocument(DocumentsCompanion companion) {
    return into(documents).insert(companion);
  }

  Future<int> linkDocument(int documentId, int entityType, int entityId, {String? linkType}) {
    return into(documentLinks).insert(
      DocumentLinksCompanion.insert(
        documentId: documentId,
        entityType: entityType,
        entityId: entityId,
        linkType: Value(linkType),
      ),
    );
  }

  Future<int> deleteDocument(int id) {
    return (delete(documents)..where((t) => t.id.equals(id))).go();
  }

  /// فك ربط مستند عن كيان محدد دون حذف المستند نفسه.
  Future<int> unlinkDocument(int documentId, int entityType, int entityId) {
    return (delete(documentLinks)
          ..where((t) =>
              t.documentId.equals(documentId) &
              t.entityType.equals(entityType) &
              t.entityId.equals(entityId)))
        .go();
  }
}
