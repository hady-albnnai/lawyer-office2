import 'package:drift/drift.dart';
import '../database.dart';
import '../schema.dart';

part 'legal_library_dao.g.dart';

@DriftAccessor(tables: [LegalLibraryItems, LegalLibraryLinks])
class LegalLibraryDao extends DatabaseAccessor<AppDatabase> with _$LegalLibraryDaoMixin {
  LegalLibraryDao(super.db);

  Stream<List<LegalLibraryItem>> watchAllItems() {
    return (select(legalLibraryItems)
          ..orderBy([(t) => OrderingTerm(expression: t.year, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<LegalLibraryItem>> getAllItems() {
    return (select(legalLibraryItems)
          ..orderBy([(t) => OrderingTerm(expression: t.year, mode: OrderingMode.desc)]))
        .get();
  }

  Future<LegalLibraryItem?> getItemById(int id) {
    return (select(legalLibraryItems)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertItem(LegalLibraryItemsCompanion companion) {
    return into(legalLibraryItems).insert(companion);
  }

  Future<bool> updateItem(LegalLibraryItemsCompanion companion) {
    return update(legalLibraryItems).replace(companion);
  }

  Future<int> setFavorite(int id, bool value) {
    return (update(legalLibraryItems)..where((t) => t.id.equals(id)))
        .write(LegalLibraryItemsCompanion(isFavorite: Value(value)));
  }

  Future<int> setPrinciple(int id, bool value) {
    return (update(legalLibraryItems)..where((t) => t.id.equals(id)))
        .write(LegalLibraryItemsCompanion(isPrinciple: Value(value)));
  }

  Stream<List<LegalLibraryLink>> watchAllLinks() {
    return select(legalLibraryLinks).watch();
  }

  Future<List<LegalLibraryLink>> getAllLinks() {
    return select(legalLibraryLinks).get();
  }

  Future<List<LegalLibraryLink>> getLinksForItem(int itemId) {
    return (select(legalLibraryLinks)..where((t) => t.libraryItemId.equals(itemId))).get();
  }

  Future<int> insertLink(LegalLibraryLinksCompanion companion) {
    return into(legalLibraryLinks).insert(companion);
  }

  Future<int> deleteLink(int id) {
    return (delete(legalLibraryLinks)..where((t) => t.id.equals(id))).go();
  }
}
