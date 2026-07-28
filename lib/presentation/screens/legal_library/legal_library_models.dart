/// نماذج وحالة المرحلة 9: المكتبة القانونية السورية.
///
/// واجهة seed قابلة للاختبار مع أقسام القوانين، الاجتهادات، مجلة المحامون،
/// المبادئ، المفضلة، والبحث، مع ربط المواد بملفات المكتب.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drift/drift.dart' show Value;

import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart' show LegalLibraryItemsCompanion;
import '../../../data/repositories/legal_library_repository.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';

/// نوع مادة المكتبة.
enum LegalItemType {
  law,
  precedent,
  barJournal,
  memo,
  research,
  book,
  template,
  other;

  String get displayName => const [
        'قانون',
        'اجتهاد',
        'مجلة المحامون',
        'مذكرة',
        'بحث قانوني',
        'كتاب',
        'نموذج',
        'وثيقة أخرى',
      ][index];

  IconData get icon => const [
        Icons.balance,
        Icons.gavel,
        Icons.menu_book,
        Icons.article,
        Icons.science,
        Icons.auto_stories,
        Icons.description,
        Icons.insert_drive_file,
      ][index];

  Color get color => const [
        AppColors.primaryNavy,
        AppColors.secondaryGold,
        AppColors.info,
        AppColors.success,
        AppColors.warning,
        AppColors.primaryNavy,
        AppColors.info,
        AppColors.textSecondary,
      ][index];
}

/// قسم التبويب في شاشة المكتبة.
enum LegalLibrarySection {
  all,
  laws,
  precedents,
  journals,
  principles,
  favorites,
  search;

  String get displayName => const [
        'الكل',
        'القوانين',
        'اجتهادات النقض',
        'مجلة المحامون',
        'مبادئ مختارة',
        'المفضلة',
        'بحث قانوني',
      ][index];
}

/// ربط مادة مكتبية بملف في المكتب.
class LegalLibraryLink {
  final String id;
  final String libraryItemId;
  final String entityType;
  final String entityId;
  final String entityTitle;
  final String note;
  final DateTime linkedAt;

  const LegalLibraryLink({
    required this.id,
    required this.libraryItemId,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    this.note = '',
    required this.linkedAt,
  });
}

/// مادة في المكتبة القانونية.
class LegalLibraryItem {
  final String id;
  final LegalItemType type;
  final String title;
  final String category;
  final String source;
  final String sourceUrl;
  final String filePath;
  final String fileName;
  final String extractedText;
  final int year;
  final List<String> tags;
  final bool isFavorite;
  final bool isPrinciple;
  final DateTime createdAt;
  final String createdBy;

  // قانون
  final String lawNumber;
  final String lawKind;
  final String lastAmendment;

  // اجتهاد
  final String court;
  final String chamber;
  final String decisionNumber;
  final String baseNumber;
  final DateTime? decisionDate;
  final String principle;

  // مجلة المحامون
  final int? journalYear;
  final String journalIssue;
  final String page;

  final String notes;

  const LegalLibraryItem({
    required this.id,
    required this.type,
    required this.title,
    this.category = '',
    this.source = '',
    this.sourceUrl = '',
    this.filePath = '',
    this.fileName = '',
    this.extractedText = '',
    required this.year,
    this.tags = const [],
    this.isFavorite = false,
    this.isPrinciple = false,
    required this.createdAt,
    this.createdBy = 'هادي فيصل البني',
    this.lawNumber = '',
    this.lawKind = '',
    this.lastAmendment = '',
    this.court = '',
    this.chamber = '',
    this.decisionNumber = '',
    this.baseNumber = '',
    this.decisionDate,
    this.principle = '',
    this.journalYear,
    this.journalIssue = '',
    this.page = '',
    this.notes = '',
  });

  bool get hasFile => filePath.isNotEmpty || fileName.isNotEmpty;

  LegalLibraryItem copyWith({
    String? title,
    String? category,
    String? source,
    String? sourceUrl,
    String? filePath,
    String? fileName,
    String? extractedText,
    int? year,
    List<String>? tags,
    bool? isFavorite,
    bool? isPrinciple,
    String? lawNumber,
    String? lawKind,
    String? lastAmendment,
    String? court,
    String? chamber,
    String? decisionNumber,
    String? baseNumber,
    DateTime? decisionDate,
    String? principle,
    int? journalYear,
    String? journalIssue,
    String? page,
    String? notes,
  }) {
    return LegalLibraryItem(
      id: id,
      type: type,
      title: title ?? this.title,
      category: category ?? this.category,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      extractedText: extractedText ?? this.extractedText,
      year: year ?? this.year,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      isPrinciple: isPrinciple ?? this.isPrinciple,
      createdAt: createdAt,
      createdBy: createdBy,
      lawNumber: lawNumber ?? this.lawNumber,
      lawKind: lawKind ?? this.lawKind,
      lastAmendment: lastAmendment ?? this.lastAmendment,
      court: court ?? this.court,
      chamber: chamber ?? this.chamber,
      decisionNumber: decisionNumber ?? this.decisionNumber,
      baseNumber: baseNumber ?? this.baseNumber,
      decisionDate: decisionDate ?? this.decisionDate,
      principle: principle ?? this.principle,
      journalYear: journalYear ?? this.journalYear,
      journalIssue: journalIssue ?? this.journalIssue,
      page: page ?? this.page,
      notes: notes ?? this.notes,
    );
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = [
      title,
      category,
      source,
      extractedText,
      lawNumber,
      lawKind,
      court,
      chamber,
      decisionNumber,
      baseNumber,
      principle,
      journalIssue,
      page,
      notes,
      type.displayName,
      year.toString(),
      ...tags,
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }
}

/// حالة المكتبة.
class LegalLibraryState {
  final List<LegalLibraryItem> items;
  final List<LegalLibraryLink> links;
  final String searchQuery;
  final LegalLibrarySection section;
  final LegalItemType? typeFilter;

  const LegalLibraryState({
    required this.items,
    required this.links,
    this.searchQuery = '',
    this.section = LegalLibrarySection.all,
    this.typeFilter,
  });

  List<LegalLibraryItem> get filteredItems {
    Iterable<LegalLibraryItem> result = items;

    switch (section) {
      case LegalLibrarySection.all:
      case LegalLibrarySection.search:
        break;
      case LegalLibrarySection.laws:
        result = result.where((i) => i.type == LegalItemType.law);
        break;
      case LegalLibrarySection.precedents:
        result = result.where((i) => i.type == LegalItemType.precedent);
        break;
      case LegalLibrarySection.journals:
        result = result.where((i) => i.type == LegalItemType.barJournal);
        break;
      case LegalLibrarySection.principles:
        result = result.where((i) => i.isPrinciple || i.principle.isNotEmpty);
        break;
      case LegalLibrarySection.favorites:
        result = result.where((i) => i.isFavorite);
        break;
    }

    if (typeFilter != null) {
      result = result.where((i) => i.type == typeFilter);
    }

    if (searchQuery.trim().isNotEmpty) {
      result = result.where((i) => i.matches(searchQuery));
    }

    final list = result.toList()
      ..sort((a, b) {
        final byYear = b.year.compareTo(a.year);
        if (byYear != 0) return byYear;
        return a.title.compareTo(b.title);
      });
    return list;
  }

  LegalLibraryItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<LegalLibraryLink> linksForItem(String itemId) {
    return links.where((l) => l.libraryItemId == itemId).toList();
  }

  List<LegalLibraryLink> linksForEntity(String entityType, String entityId) {
    return links
        .where((l) => l.entityType == entityType && l.entityId == entityId)
        .toList();
  }

  int countByType(LegalItemType type) => items.where((i) => i.type == type).length;

  int get favoritesCount => items.where((i) => i.isFavorite).length;

  LegalLibraryState copyWith({
    List<LegalLibraryItem>? items,
    List<LegalLibraryLink>? links,
    String? searchQuery,
    LegalLibrarySection? section,
    LegalItemType? typeFilter,
    bool clearTypeFilter = false,
  }) {
    return LegalLibraryState(
      items: items ?? this.items,
      links: links ?? this.links,
      searchQuery: searchQuery ?? this.searchQuery,
      section: section ?? this.section,
      typeFilter: clearTypeFilter ? null : typeFilter ?? this.typeFilter,
    );
  }
}

final legalLibraryProvider =
    StateNotifierProvider<LegalLibraryNotifier, LegalLibraryState>((ref) {
  return LegalLibraryNotifier(repository: ref.watch(legalLibraryRepositoryProvider))..bootstrap();
});

class LegalLibraryNotifier extends StateNotifier<LegalLibraryState> {
  LegalLibraryNotifier({LegalLibraryRepository? repository})
      : _repository = repository,
        super(repository == null ? _seedState() : const LegalLibraryState(items: [], links: []));

  final LegalLibraryRepository? _repository;
  bool _ready = false;

  Future<void> bootstrap() async {
    final repo = _repository;
    if (repo == null || _ready) return;
    _ready = true;
    try {
      await reload();
      // آخر نقطة: تحميل الملفات القانونية الحقيقية من المحتوى إذا كانت المكتبة فارغة أو قليلة
      if (state.items.length < 8) {
        final imported = await repo.importLegalFilesFromContent();
        if (imported > 0) {
          await reload();
        }
      }
    } catch (_) {
      if (state.items.isEmpty) state = _seedState();
    }
  }

  /// استدعاء يدوي لتحميل الملفات القانونية السورية من مجلد content/
  Future<int> loadRealLegalFiles() async {
    final repo = _repository;
    if (repo == null) return 0;
    final count = await repo.importLegalFilesFromContent();
    if (count > 0) {
      await reload();
    }
    return count;
  }

  Future<void> reload() async {
    try {
    final repo = _repository;
    if (repo == null) return;
    final items = await repo.getAllItems();
    final links = await repo.getAllLinks();
    state = LegalLibraryState(
      items: items.map(_mapItem).toList(),
      links: links.map(_mapLink).toList(),
      searchQuery: state.searchQuery,
      section: state.section,
      typeFilter: state.typeFilter,
    );
    } catch (_) {
      if (state.items.isEmpty) state = _seedState();
    }
  }

  static LegalItemType _typeFromDb(String raw) {
    switch (raw) {
      case 'law': return LegalItemType.law;
      case 'precedent': return LegalItemType.precedent;
      case 'bar_journal': return LegalItemType.barJournal;
      case 'memo': return LegalItemType.memo;
      case 'research': return LegalItemType.research;
      case 'book': return LegalItemType.book;
      case 'template': return LegalItemType.template;
      default: return LegalItemType.other;
    }
  }

  static String _typeToDb(LegalItemType t) {
    switch (t) {
      case LegalItemType.law: return 'law';
      case LegalItemType.precedent: return 'precedent';
      case LegalItemType.barJournal: return 'bar_journal';
      case LegalItemType.memo: return 'memo';
      case LegalItemType.research: return 'research';
      case LegalItemType.book: return 'book';
      case LegalItemType.template: return 'template';
      case LegalItemType.other: return 'other';
    }
  }

  static LegalLibraryItem _mapItem(dynamic row) {
    return LegalLibraryItem(
      id: '${row.id}',
      type: _typeFromDb(row.itemType),
      title: row.title,
      category: row.category ?? '',
      source: row.source ?? '',
      sourceUrl: row.sourceUrl ?? '',
      filePath: row.filePath ?? '',
      fileName: row.fileName ?? '',
      extractedText: row.extractedText ?? '',
      year: row.year,
      tags: (row.tags ?? '').split(',').where((e) => e.trim().isNotEmpty).toList(),
      isFavorite: row.isFavorite,
      isPrinciple: row.isPrinciple,
      createdAt: row.createdAt,
      createdBy: row.createdBy ?? '',
      lawNumber: row.lawNumber ?? '',
      lawKind: row.lawKind ?? '',
      lastAmendment: row.lastAmendment ?? '',
      court: row.court ?? '',
      chamber: row.chamber ?? '',
      decisionNumber: row.decisionNumber ?? '',
      baseNumber: row.baseNumber ?? '',
      decisionDate: row.decisionDate,
      principle: row.principle ?? '',
      journalYear: row.journalYear,
      journalIssue: row.journalIssue ?? '',
      page: row.page ?? '',
      notes: row.notes ?? '',
    );
  }

  static LegalLibraryLink _mapLink(dynamic row) {
    return LegalLibraryLink(
      id: '${row.id}',
      libraryItemId: '${row.libraryItemId}',
      entityType: '${row.entityType}',
      entityId: '${row.entityId}',
      entityTitle: row.entityTitle ?? '',
      note: row.note ?? '',
      linkedAt: row.linkedAt,
    );
  }

  static LegalLibraryState _seedState() {
    final now = DateTime(2026, 7, 10);
    final items = [
      LegalLibraryItem(
        id: 'lib_law_1',
        type: LegalItemType.law,
        title: 'قانون أصول المحاكمات المدنية',
        category: 'قوانين إجرائية',
        source: 'الجريدة الرسمية',
        year: 2016,
        lawNumber: '1',
        lawKind: 'قانون',
        lastAmendment: 'تعديلات لاحقة معتمدة',
        tags: const ['أصول', 'محاكمات', 'مدني'],
        extractedText:
            'ينظم قانون أصول المحاكمات المدنية إجراءات التقاضي أمام المحاكم المدنية السورية.',
        fileName: 'civil_procedure_2016.pdf',
        filePath: 'library/laws/civil_procedure_2016.pdf',
        isFavorite: true,
        createdAt: now.subtract(const Duration(days: 40)),
      ),
      LegalLibraryItem(
        id: 'lib_law_2',
        type: LegalItemType.law,
        title: 'القانون المدني السوري',
        category: 'قوانين موضوعية',
        source: 'الجريدة الرسمية',
        year: 1949,
        lawNumber: '84',
        lawKind: 'قانون',
        tags: const ['مدني', 'التزامات', 'عقود'],
        extractedText: 'الأحكام العامة للالتزامات والعقود والملكية.',
        fileName: 'civil_code.pdf',
        filePath: 'library/laws/civil_code.pdf',
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      LegalLibraryItem(
        id: 'lib_prec_1',
        type: LegalItemType.precedent,
        title: 'عبء الإثبات في دعاوى التعويض',
        category: 'اجتهادات مدنية',
        source: 'محكمة النقض السورية',
        year: 2022,
        court: 'محكمة النقض',
        chamber: 'الغرفة المدنية',
        decisionNumber: '445',
        baseNumber: '1120/2021',
        decisionDate: DateTime(2022, 5, 18),
        principle:
            'يقع عبء إثبات الضرر والعلاقة السببية على المدعي في دعوى التعويض ما لم يقرر القانون خلاف ذلك.',
        isPrinciple: true,
        isFavorite: true,
        journalYear: 2023,
        journalIssue: '2',
        page: '145',
        tags: const ['تعويض', 'إثبات', 'نقض'],
        extractedText: 'مبدأ عبء الإثبات في التعويض عن الفعل الضار.',
        fileName: 'cassation_445_2022.pdf',
        filePath: 'library/precedents/cassation_445_2022.pdf',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      LegalLibraryItem(
        id: 'lib_prec_2',
        type: LegalItemType.precedent,
        title: 'شروط صحة التبليغ القضائي',
        category: 'اجتهادات إجرائية',
        source: 'محكمة النقض السورية',
        year: 2021,
        court: 'محكمة النقض',
        chamber: 'الغرفة المدنية',
        decisionNumber: '210',
        baseNumber: '88/2020',
        decisionDate: DateTime(2021, 11, 3),
        principle: 'التبليغ الباطل لا ينتج أثره ويمنح الخصم حق التمسك بالبطلان.',
        isPrinciple: true,
        tags: const ['تبليغ', 'بطلان', 'إجراءات'],
        fileName: 'cassation_210_2021.pdf',
        filePath: 'library/precedents/cassation_210_2021.pdf',
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      LegalLibraryItem(
        id: 'lib_journal_1',
        type: LegalItemType.barJournal,
        title: 'مجلة المحامون - العدد 3/2024',
        category: 'مجلة المحامون',
        source: 'نقابة المحامين في الجمهورية العربية السورية',
        year: 2024,
        journalYear: 2024,
        journalIssue: '3',
        page: '1-220',
        tags: const ['مجلة', 'محامون', 'نقابة'],
        extractedText: 'عدد يتضمن دراسات قانونية واجتهادات مختارة.',
        fileName: 'bar_journal_2024_3.pdf',
        filePath: 'library/journals/bar_journal_2024_3.pdf',
        isFavorite: true,
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      LegalLibraryItem(
        id: 'lib_memo_1',
        type: LegalItemType.memo,
        title: 'نموذج مذكرة دفاع في دعوى تعويض',
        category: 'مذكرات',
        source: 'مكتب المحامي',
        year: 2026,
        tags: const ['مذكرة', 'دفاع', 'تعويض'],
        extractedText: 'هيكل مذكرة دفاع مع دفوع شكلية وموضوعية.',
        fileName: 'memo_defense_template.docx',
        filePath: 'library/memos/memo_defense_template.docx',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      LegalLibraryItem(
        id: 'lib_research_1',
        type: LegalItemType.research,
        title: 'بحث: الطبيعة القانونية لعقد الوكالة',
        category: 'أبحاث',
        source: 'مكتبة المكتب',
        year: 2020,
        tags: const ['وكالة', 'عقد', 'بحث'],
        extractedText: 'دراسة في أركان الوكالة وآثارها في القانون السوري.',
        createdAt: now.subtract(const Duration(days: 90)),
      ),
    ];

    final links = [
      LegalLibraryLink(
        id: 'link_1',
        libraryItemId: 'lib_prec_1',
        entityType: 'case',
        entityId: '1',
        entityTitle: 'دعوى تعويض 2026/001',
        note: 'مرجع في عبء الإثبات',
        linkedAt: now.subtract(const Duration(days: 3)),
      ),
      LegalLibraryLink(
        id: 'link_2',
        libraryItemId: 'lib_law_1',
        entityType: 'case',
        entityId: '1',
        entityTitle: 'دعوى تعويض 2026/001',
        note: 'أصول التقاضي',
        linkedAt: now.subtract(const Duration(days: 2)),
      ),
      LegalLibraryLink(
        id: 'link_3',
        libraryItemId: 'lib_memo_1',
        entityType: 'case',
        entityId: '2',
        entityTitle: 'دعوى استئناف 2026/002',
        note: 'مسودة مذكرة',
        linkedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    return LegalLibraryState(items: items, links: links);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSection(LegalLibrarySection section) {
    state = state.copyWith(section: section);
  }

  void setTypeFilter(LegalItemType? type) {
    state = type == null
        ? state.copyWith(clearTypeFilter: true)
        : state.copyWith(typeFilter: type);
  }

  void addItem(LegalLibraryItem item) {
    state = state.copyWith(items: [item, ...state.items]);
    // الحفظ الفعلي في قاعدة البيانات، وإلا اختفى العنصر عند إعادة التحميل.
    final repo = _repository;
    if (repo == null) return;
    repo
        .addItem(
          LegalLibraryItemsCompanion.insert(
            itemType: _typeToDb(item.type),
            title: item.title,
            category: Value(item.category),
            source: Value(item.source),
            sourceUrl: Value(item.sourceUrl),
            filePath: Value(item.filePath),
            fileName: Value(item.fileName),
            extractedText: Value(item.extractedText),
            year: Value(item.year),
            tags: Value(item.tags.join(',')),
            isFavorite: Value(item.isFavorite),
            isPrinciple: Value(item.isPrinciple),
            lawNumber: Value(item.lawNumber),
            lawKind: Value(item.lawKind),
            lastAmendment: Value(item.lastAmendment),
            court: Value(item.court),
            chamber: Value(item.chamber),
            createdBy: Value(item.createdBy),
            createdAt: Value(item.createdAt),
          ),
        )
        .then((_) => reload())
        .catchError((_) => 0);
  }

  void toggleFavorite(String itemId) {
    final current = state.itemById(itemId);
    final updated = state.items.map((item) {
      if (item.id != itemId) return item;
      return item.copyWith(isFavorite: !item.isFavorite);
    }).toList();
    state = state.copyWith(items: updated);
    final repo = _repository;
    final id = int.tryParse(itemId);
    if (repo != null && id != null && current != null) {
      repo.toggleFavorite(id, !current.isFavorite).then((_) => reload()).catchError((_) {});
    }
  }

  void markAsPrinciple(String itemId, {required bool value}) {
    final updated = state.items.map((item) {
      if (item.id != itemId) return item;
      return item.copyWith(isPrinciple: value);
    }).toList();
    state = state.copyWith(items: updated);
    // الحفظ الفعلي حتى لا تعود العلامة عند إعادة التحميل.
    final repo = _repository;
    final id = int.tryParse(itemId);
    if (repo != null && id != null) {
      repo.setPrinciple(id, value).then((_) => reload()).catchError((_) {});
    }
  }

  void linkToEntity({
    required String libraryItemId,
    required String entityType,
    required String entityId,
    required String entityTitle,
    String note = '',
  }) {
    final link = LegalLibraryLink(
      id: 'link_${DateTime.now().microsecondsSinceEpoch}',
      libraryItemId: libraryItemId,
      entityType: entityType,
      entityId: entityId,
      entityTitle: entityTitle,
      note: note,
      linkedAt: DateTime.now(),
    );
    state = state.copyWith(links: [link, ...state.links]);
    final repo = _repository;
    final itemId = int.tryParse(libraryItemId);
    final targetId = int.tryParse(entityId);
    if (repo != null && itemId != null && targetId != null) {
      repo
          .linkToEntity(
            libraryItemId: itemId,
            entityType: _entityTypeIndex(entityType),
            entityId: targetId,
            entityTitle: entityTitle,
            note: note.isEmpty ? null : note,
          )
          .then((_) => reload())
          .catchError((_) => 0);
    }
  }

  /// تحويل مفتاح الكيان النصي إلى الفهرس المخزَّن في قاعدة البيانات.
  static int _entityTypeIndex(String key) {
    switch (key) {
      case 'case':
        return EntityType.caseEntity.index;
      case 'contract':
        return EntityType.contract.index;
      case 'company':
        return EntityType.company.index;
      case 'procedure':
      case 'admin_procedure':
        return EntityType.adminProcedure.index;
      case 'person':
        return EntityType.person.index;
      case 'poa':
      case 'agency':
        return EntityType.powerOfAttorney.index;
      default:
        return EntityType.caseEntity.index;
    }
  }

  void removeLink(String linkId) {
    state = state.copyWith(
      links: state.links.where((l) => l.id != linkId).toList(),
    );
    final repo = _repository;
    final id = int.tryParse(linkId);
    if (repo != null && id != null) {
      repo.removeLink(id).then((_) => reload()).catchError((_) {});
    }
  }
}
