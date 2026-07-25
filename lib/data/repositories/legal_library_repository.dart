import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/daos/legal_library_dao.dart';

/// مستودع المكتبة القانونية — SQLite عبر Drift.
class LegalLibraryRepository {
  final LegalLibraryDao _dao;

  LegalLibraryRepository(this._dao);

  Stream<List<LegalLibraryItem>> watchAllItems() => _dao.watchAllItems();
  Future<List<LegalLibraryItem>> getAllItems() => _dao.getAllItems();
  Stream<List<LegalLibraryLink>> watchAllLinks() => _dao.watchAllLinks();
  Future<List<LegalLibraryLink>> getAllLinks() => _dao.getAllLinks();

  Future<int> addItem(LegalLibraryItemsCompanion companion) => _dao.insertItem(companion);

  Future<void> toggleFavorite(int id, bool value) => _dao.setFavorite(id, value);

  Future<void> setPrinciple(int id, bool value) => _dao.setPrinciple(id, value);

  Future<int> linkToEntity({
    required int libraryItemId,
    required int entityType,
    required int entityId,
    String? entityTitle,
    String? note,
  }) {
    return _dao.insertLink(
      LegalLibraryLinksCompanion.insert(
        libraryItemId: libraryItemId,
        entityType: entityType,
        entityId: entityId,
        entityTitle: Value(entityTitle),
        note: Value(note),
      ),
    );
  }

  Future<void> removeLink(int id) => _dao.deleteLink(id);

  Future<void> seedDemoIfEmpty() async {
    final items = await _dao.getAllItems();
    if (items.isNotEmpty) return;
    await importLegalFilesFromContent();
  }

  /// تحميل الملفات القانونية السورية الحقيقية من مجلد content/legal_library
  /// يستخدم البيانات من فهرس laws_decrees_index.csv + الملفات الموجودة فعلياً.
  /// يُستدعى مرة واحدة أو عند طلب المستخدم "تحميل الملفات القانونية للمكتبة".
  Future<int> importLegalFilesFromContent() async {
    final existing = await _dao.getAllItems();
    if (existing.length > 5) {
      // إذا كان هناك أكثر من 5 مواد، نفترض أن الاستيراد تم مسبقاً
      return 0;
    }

    final now = DateTime.now();
    int imported = 0;

    // قائمة الملفات القانونية الرئيسية من الفهرس (PDF + Markdown)
    final legalFiles = [
      // قوانين PDF رئيسية
      {
        'itemType': 'law',
        'title': 'القانون المدني السوري',
        'lawNumber': '84',
        'year': 1949,
        'category': 'قوانين موضوعية',
        'source': 'الجريدة الرسمية',
        'fileName': '1949_القانون_المدني_السوري_84.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/1949_القانون_المدني_السوري_84.pdf',
        'tags': 'مدني,التزامات,عقود',
        'extractedText': 'الأحكام العامة للالتزامات والعقود والملكية في القانون المدني السوري.',
      },
      {
        'itemType': 'law',
        'title': 'قانون أصول المحاكمات المدنية',
        'lawNumber': '1',
        'year': 2016,
        'category': 'قوانين إجرائية',
        'source': 'الجريدة الرسمية',
        'fileName': '2016_قانون_أصول_المحاكمات_المدنية_1.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/2016_قانون_أصول_المحاكمات_المدنية_1.pdf',
        'tags': 'أصول,محاكمات,مدني',
        'extractedText': 'ينظم قانون أصول المحاكمات المدنية إجراءات التقاضي أمام المحاكم المدنية السورية.',
        'isFavorite': true,
      },
      {
        'itemType': 'law',
        'title': 'قانون العقوبات العام',
        'lawNumber': '148',
        'year': 1949,
        'category': 'قوانين جزائية',
        'source': 'الجريدة الرسمية',
        'fileName': '1949_قانون_العقوبات_العام_148.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/1949_قانون_العقوبات_العام_148.pdf',
        'tags': 'عقوبات,جزائي',
        'extractedText': 'القانون الجنائي العام السوري.',
      },
      {
        'itemType': 'law',
        'title': 'قانون أصول المحاكمات الجزائية',
        'lawNumber': '112',
        'year': 1950,
        'category': 'أصول محاكمات جزائية',
        'source': 'مرسوم تشريعي',
        'fileName': '1950_قانون_أصول_المحاكمات_الجزائية_112.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/1950_قانون_أصول_المحاكمات_الجزائية_112.pdf',
        'tags': 'أصول,جزائي,إجراءات',
        'extractedText': 'إجراءات المحاكمات الجزائية في سوريا.',
      },
      {
        'itemType': 'law',
        'title': 'قانون الشركات',
        'lawNumber': '29',
        'year': 2011,
        'category': 'قوانين تجارية',
        'source': 'مرسوم تشريعي',
        'fileName': '2011_قانون_الشركات_29.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/2011_قانون_الشركات_29.pdf',
        'tags': 'شركات,تجاري',
      },
      {
        'itemType': 'law',
        'title': 'قانون العمل',
        'lawNumber': '17',
        'year': 2010,
        'category': 'قوانين العمل',
        'source': 'الجريدة الرسمية',
        'fileName': '2010_قانون_العمل_17.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/2010_قانون_العمل_17.pdf',
        'tags': 'عمل,تأمينات',
      },
      {
        'itemType': 'law',
        'title': 'دستور الجمهورية العربية السورية',
        'year': 2012,
        'category': 'الدستور',
        'source': 'الجريدة الرسمية',
        'fileName': '2012_دستور_الجمهورية_العربية_السورية_.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/2012_دستور_الجمهورية_العربية_السورية_.pdf',
        'tags': 'دستور,أساسي',
      },
      {
        'itemType': 'law',
        'title': 'قانون الأحوال المدنية',
        'lawNumber': '13',
        'year': 2021,
        'category': 'أحوال مدنية',
        'source': 'الجريدة الرسمية',
        'fileName': '2021_قانون_الأحوال_المدنية_13.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/2021_قانون_الأحوال_المدنية_13.pdf',
        'tags': 'أحوال,مدنية',
      },
      {
        'itemType': 'law',
        'title': 'قانون حماية المستهلك',
        'lawNumber': '8',
        'year': 2021,
        'category': 'قوانين المستهلك',
        'source': 'الجريدة الرسمية',
        'fileName': '2021_قانون_حماية_المستهلك_8.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/2021_قانون_حماية_المستهلك_8.pdf',
        'tags': 'مستهلك,حماية',
      },
      // Markdowns (HTML converted) - قوانين مهمة
      {
        'itemType': 'law',
        'title': 'قانون البينات السوري',
        'year': 2014,
        'category': 'قوانين الإثبات',
        'source': 'الجريدة الرسمية',
        'fileName': '2014_قانون_البينات_السوري_.md',
        'filePath': 'content/legal_library/laws_decrees/markdown/2014_قانون_البينات_السوري_.md',
        'tags': 'بينات,إثبات',
      },
      {
        'itemType': 'law',
        'title': 'قانون الأحوال الشخصية السوري',
        'lawNumber': '59',
        'year': 1953,
        'category': 'أحوال شخصية',
        'source': 'الجريدة الرسمية',
        'fileName': '1953_قانون_الأحوال_الشخصية_السوري_59.md',
        'filePath': 'content/legal_library/laws_decrees/markdown/1953_قانون_الأحوال_الشخصية_السوري_59.md',
        'tags': 'أحوال,شخصية,شرعي',
        'isFavorite': true,
      },
      {
        'itemType': 'law',
        'title': 'قانون تنظيم مهنة المحاماة',
        'lawNumber': '30',
        'year': 2010,
        'category': 'مهنة المحاماة',
        'source': 'نقابة المحامين',
        'fileName': '2010_قانون_تنظيم_مهنة_المحاماة_30.md',
        'filePath': 'content/legal_library/laws_decrees/markdown/2010_قانون_تنظيم_مهنة_المحاماة_30.md',
        'tags': 'محاماة,نقابة',
      },
      {
        'itemType': 'law',
        'title': 'قانون التحكيم',
        'lawNumber': '4',
        'year': 2008,
        'category': 'تحكيم',
        'source': 'الجريدة الرسمية',
        'fileName': '2008_قانون_التحكيم_4.md',
        'filePath': 'content/legal_library/laws_decrees/markdown/2008_قانون_التحكيم_4.md',
        'tags': 'تحكيم',
      },
      // اجتهادات ومجلة (من seed السابق + حقيقي)
      {
        'itemType': 'precedent',
        'title': 'عبء الإثبات في دعاوى التعويض',
        'year': 2022,
        'category': 'اجتهادات مدنية',
        'source': 'محكمة النقض السورية',
        'court': 'محكمة النقض',
        'chamber': 'الغرفة المدنية',
        'decisionNumber': '445',
        'baseNumber': '1120/2021',
        'principle': 'يقع عبء إثبات الضرر والعلاقة السببية على المدعي في دعوى التعويض ما لم يقرر القانون خلاف ذلك.',
        'isPrinciple': true,
        'isFavorite': true,
        'fileName': 'cassation_445_2022.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/cassation_445_2022.pdf',
        'tags': 'تعويض,إثبات,نقض',
        'extractedText': 'مبدأ عبء الإثبات في التعويض عن الفعل الضار.',
      },
      {
        'itemType': 'bar_journal',
        'title': 'مجلة المحامون - العدد 3/2024',
        'year': 2024,
        'category': 'مجلة المحامون',
        'source': 'نقابة المحامين في الجمهورية العربية السورية',
        'fileName': 'bar_journal_2024_3.pdf',
        'filePath': 'content/legal_library/laws_decrees/pdf/bar_journal_2024_3.pdf',
        'tags': 'مجلة,محامون,نقابة',
        'isFavorite': true,
      },
      {
        'itemType': 'memo',
        'title': 'نموذج مذكرة دفاع في دعوى تعويض',
        'year': 2026,
        'category': 'مذكرات',
        'source': 'مكتب المحامي',
        'fileName': 'memo_defense_template.docx',
        'filePath': 'content/legal_library/laws_decrees/markdown/memo_defense_template.docx',
        'tags': 'مذكرة,دفاع,تعويض',
      },
    ];

    for (final f in legalFiles) {
      // تجنب التكرار إذا كان العنوان موجوداً
      final exists = existing.any((e) => e.title == f['title']);
      if (exists) continue;

      await _dao.insertItem(
        LegalLibraryItemsCompanion.insert(
          itemType: f['itemType'] as String,
          title: f['title'] as String,
          category: Value(f['category'] as String? ?? ''),
          source: Value(f['source'] as String? ?? ''),
          year: Value(f['year'] as int? ?? 2026),
          lawNumber: Value(f['lawNumber'] as String? ?? ''),
          court: Value(f['court'] as String? ?? ''),
          chamber: Value(f['chamber'] as String? ?? ''),
          decisionNumber: Value(f['decisionNumber'] as String? ?? ''),
          baseNumber: Value(f['baseNumber'] as String? ?? ''),
          principle: Value(f['principle'] as String? ?? ''),
          isPrinciple: Value(f['isPrinciple'] as bool? ?? false),
          isFavorite: Value(f['isFavorite'] as bool? ?? false),
          fileName: Value(f['fileName'] as String? ?? ''),
          filePath: Value(f['filePath'] as String? ?? ''),
          tags: Value(f['tags'] as String? ?? ''),
          extractedText: Value(f['extractedText'] as String? ?? ''),
          createdBy: const Value('استيراد من المحتوى'),
          createdAt: Value(now),
        ),
      );
      imported++;
    }

    return imported;
  }
}
