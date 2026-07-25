import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/presentation/screens/legal_library/legal_library_models.dart';

void main() {
  test('Seed library contains laws, precedents, journals and favorites', () {
    final state = LegalLibraryNotifier().state;

    expect(state.items, isNotEmpty);
    expect(state.countByType(LegalItemType.law), greaterThan(0));
    expect(state.countByType(LegalItemType.precedent), greaterThan(0));
    expect(state.countByType(LegalItemType.barJournal), greaterThan(0));
    expect(state.favoritesCount, greaterThan(0));
    expect(state.links, isNotEmpty);
  });

  test('Section filters work for laws precedents principles and favorites', () {
    final notifier = LegalLibraryNotifier();

    notifier.setSection(LegalLibrarySection.laws);
    expect(
      notifier.state.filteredItems.every((i) => i.type == LegalItemType.law),
      isTrue,
    );

    notifier.setSection(LegalLibrarySection.precedents);
    expect(
      notifier.state.filteredItems.every((i) => i.type == LegalItemType.precedent),
      isTrue,
    );

    notifier.setSection(LegalLibrarySection.principles);
    expect(
      notifier.state.filteredItems.every((i) => i.isPrinciple || i.principle.isNotEmpty),
      isTrue,
    );

    notifier.setSection(LegalLibrarySection.favorites);
    expect(notifier.state.filteredItems.every((i) => i.isFavorite), isTrue);
  });

  test('Search matches title principle tags and decision numbers', () {
    final notifier = LegalLibraryNotifier();
    notifier.setSection(LegalLibrarySection.search);

    notifier.setSearchQuery('أصول المحاكمات');
    expect(notifier.state.filteredItems, isNotEmpty);

    notifier.setSearchQuery('عبء الإثبات');
    expect(notifier.state.filteredItems, isNotEmpty);

    notifier.setSearchQuery('445');
    expect(notifier.state.filteredItems.any((i) => i.decisionNumber == '445'), isTrue);

    notifier.setSearchQuery('تعويض');
    expect(notifier.state.filteredItems, isNotEmpty);
  });

  test('Add item toggle favorite and link to entity', () {
    final notifier = LegalLibraryNotifier();
    final before = notifier.state.items.length;

    final item = LegalLibraryItem(
      id: 'lib_test_new',
      type: LegalItemType.book,
      title: 'كتاب اختبار قانوني',
      year: 2025,
      createdAt: DateTime(2026, 7, 10),
      tags: const ['اختبار'],
    );
    notifier.addItem(item);
    expect(notifier.state.items.length, before + 1);
    expect(notifier.state.itemById('lib_test_new')?.title, contains('اختبار'));

    final favBefore = notifier.state.favoritesCount;
    notifier.toggleFavorite('lib_test_new');
    expect(notifier.state.itemById('lib_test_new')?.isFavorite, isTrue);
    expect(notifier.state.favoritesCount, favBefore + 1);

    notifier.linkToEntity(
      libraryItemId: 'lib_test_new',
      entityType: 'case',
      entityId: '9',
      entityTitle: 'دعوى اختبار',
      note: 'مرجع اختبار',
    );
    expect(notifier.state.linksForItem('lib_test_new'), isNotEmpty);
    expect(
      notifier.state.linksForEntity('case', '9').first.libraryItemId,
      'lib_test_new',
    );

    final linkId = notifier.state.linksForItem('lib_test_new').first.id;
    notifier.removeLink(linkId);
    expect(notifier.state.linksForItem('lib_test_new'), isEmpty);
  });

  test('Type filter narrows results', () {
    final notifier = LegalLibraryNotifier();
    notifier.setTypeFilter(LegalItemType.memo);
    expect(
      notifier.state.filteredItems.every((i) => i.type == LegalItemType.memo),
      isTrue,
    );
    notifier.setTypeFilter(null);
    expect(notifier.state.typeFilter, isNull);
  });
}
