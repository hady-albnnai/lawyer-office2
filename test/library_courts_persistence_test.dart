import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/legal_library_repository.dart';
import 'package:lawyer_office/data/repositories/settings_repository.dart';
import 'package:lawyer_office/data/services/backup_service.dart';

/// روابط المكتبة القانونية وقائمة المحاكم كانت تُعدَّل في الذاكرة فقط.
/// هذه اختبارات ربط تقني بحت، ولا تضيف أي محتوى قانوني.
void main() {
  late AppDatabase db;
  late LegalLibraryRepository libraryRepo;
  late SettingsRepository settingsRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    libraryRepo = LegalLibraryRepository(db.legalLibraryDao);
    settingsRepo = SettingsRepository(db.settingsDao, BackupService());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addItem(String title) => libraryRepo.addItem(
        LegalLibraryItemsCompanion.insert(itemType: 'law', title: title),
      );

  test('Library item is persisted and readable', () async {
    final id = await addItem('قانون أصول المحاكمات');

    final items = await libraryRepo.getAllItems();
    expect(items.any((i) => i.id == id && i.title == 'قانون أصول المحاكمات'), isTrue);
  });

  test('Marking an item as principle survives a reload', () async {
    final id = await addItem('اجتهاد نقض');

    await libraryRepo.setPrinciple(id, true);

    final items = await libraryRepo.getAllItems();
    expect(items.firstWhere((i) => i.id == id).isPrinciple, isTrue);
  });

  test('Linking a library item to a case is persisted, and unlinking removes it', () async {
    final itemId = await addItem('مرجع قانوني');
    final caseId = await db.into(db.cases).insert(
          CasesCompanion.insert(internalNumber: 'د/1', year: 2026, caseType: 'مدني'),
        );

    final linkId = await libraryRepo.linkToEntity(
      libraryItemId: itemId,
      entityType: EntityType.caseEntity.index,
      entityId: caseId,
      entityTitle: 'دعوى تجريبية',
    );

    var links = await libraryRepo.getAllLinks();
    expect(links.any((l) => l.id == linkId && l.entityId == caseId), isTrue);

    await libraryRepo.removeLink(linkId);

    links = await libraryRepo.getAllLinks();
    expect(links.any((l) => l.id == linkId), isFalse);

    // العنصر نفسه يبقى في المكتبة بعد فك الربط
    final items = await libraryRepo.getAllItems();
    expect(items.any((i) => i.id == itemId), isTrue);
  });

  test('Court added from settings is stored and available to cases', () async {
    await settingsRepo.addCourt(name: 'بداية مدنية حمص', type: 'مدني', city: 'حمص');

    final courts = await settingsRepo.getCourts();
    final added = courts.where((c) => c.name == 'بداية مدنية حمص');
    expect(added, hasLength(1));
    expect(added.first.city, 'حمص');

    // المحكمة قابلة للاستخدام فعلياً كمرجع في الدعاوى
    final caseId = await db.into(db.cases).insert(
          CasesCompanion.insert(
            internalNumber: 'د/2',
            year: 2026,
            caseType: 'مدني',
            courtId: Value(added.first.id),
          ),
        );
    final saved = await (db.select(db.cases)..where((t) => t.id.equals(caseId))).getSingle();
    expect(saved.courtId, added.first.id);
  });
}
