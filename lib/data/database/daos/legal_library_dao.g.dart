// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'legal_library_dao.dart';

// ignore_for_file: type=lint
mixin _$LegalLibraryDaoMixin on DatabaseAccessor<AppDatabase> {
  $LegalLibraryItemsTable get legalLibraryItems =>
      attachedDatabase.legalLibraryItems;
  $LegalLibraryLinksTable get legalLibraryLinks =>
      attachedDatabase.legalLibraryLinks;
  LegalLibraryDaoManager get managers => LegalLibraryDaoManager(this);
}

class LegalLibraryDaoManager {
  final _$LegalLibraryDaoMixin _db;
  LegalLibraryDaoManager(this._db);
  $$LegalLibraryItemsTableTableManager get legalLibraryItems =>
      $$LegalLibraryItemsTableTableManager(
          _db.attachedDatabase, _db.legalLibraryItems);
  $$LegalLibraryLinksTableTableManager get legalLibraryLinks =>
      $$LegalLibraryLinksTableTableManager(
          _db.attachedDatabase, _db.legalLibraryLinks);
}
