/// شاشة المكتبة القانونية السورية - المرحلة 9.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../documents/document_viewer.dart';
import 'legal_library_models.dart';

class LegalLibraryScreen extends ConsumerStatefulWidget {
  const LegalLibraryScreen({super.key});

  @override
  ConsumerState<LegalLibraryScreen> createState() => _LegalLibraryScreenState();
}

class _LegalLibraryScreenState extends ConsumerState<LegalLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  static const _sections = [
    LegalLibrarySection.all,
    LegalLibrarySection.laws,
    LegalLibrarySection.precedents,
    LegalLibrarySection.journals,
    LegalLibrarySection.principles,
    LegalLibrarySection.favorites,
    LegalLibrarySection.search,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _sections.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      ref.read(legalLibraryProvider.notifier).setSection(_sections[_tabController.index]);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(legalLibraryProvider);
    final items = state.filteredItems;
    final permissions = ref.watch(permissionServiceProvider);

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('المكتبة القانونية السورية'),
            actions: [
              if (permissions.can(PermissionKeys.libraryAdd))
                IconButton(
                  tooltip: 'تحميل الملفات القانونية السورية (من المحتوى)',
                  icon: const Icon(Icons.download),
                  onPressed: () async {
                    final count = await ref.read(legalLibraryProvider.notifier).loadRealLegalFiles();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(count > 0 
                              ? 'تم تحميل $count مادة قانونية سورية حقيقية من الملفات.' 
                              : 'الملفات القانونية محملة مسبقاً أو تم تجاوزها.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
              if (permissions.can(PermissionKeys.libraryAdd))
                IconButton(
                  tooltip: 'إضافة إلى المكتبة',
                  icon: const Icon(Icons.add_box),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AddLegalItemDialog(),
                  ),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.secondaryGold,
              labelColor: AppColors.secondaryGold,
              unselectedLabelColor: AppColors.textOnLight.withOpacity(0.75),
              labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
              tabs: _sections.map((s) => Tab(text: s.displayName)).toList(),
            ),
          ),
          body: Column(
            children: [
              _statsBar(state),
              _searchBar(state),
              Expanded(
                child: items.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _itemCard(state, items[index]),
                      ),
              ),
            ],
          ),
          floatingActionButton: permissions.can(PermissionKeys.libraryAdd)
              ? FloatingActionButton.extended(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AddLegalItemDialog(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة إلى المكتبة'),
                )
              : null,
        ),
      ),
    );
  }

  Widget _statsBar(LegalLibraryState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.cardBackground,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _statChip('المواد', '${state.items.length}', AppColors.primaryNavy),
          _statChip('قوانين', '${state.countByType(LegalItemType.law)}', AppColors.primaryNavy),
          _statChip(
            'اجتهادات',
            '${state.countByType(LegalItemType.precedent)}',
            AppColors.secondaryGold,
          ),
          _statChip(
            'مجلة المحامون',
            '${state.countByType(LegalItemType.barJournal)}',
            AppColors.info,
          ),
          _statChip('المفضلة', '${state.favoritesCount}', AppColors.success),
          _statChip('روابط ملفات', '${state.links.length}', AppColors.warning),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
      label: Text(label),
      backgroundColor: AppColors.cardBackground,
    );
  }

  Widget _searchBar(LegalLibraryState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث في العنوان، المبدأ، الكلمات المفتاحية، رقم القرار، رقم القانون...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(legalLibraryProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => ref.read(legalLibraryProvider.notifier).setSearchQuery(v),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<LegalItemType?>(
            value: state.typeFilter,
            items: [
              const DropdownMenuItem<LegalItemType?>(value: null, child: Text('كل الأنواع')),
              ...LegalItemType.values.map(
                (t) => DropdownMenuItem<LegalItemType?>(value: t, child: Text(t.displayName)),
              ),
            ],
            onChanged: (v) => ref.read(legalLibraryProvider.notifier).setTypeFilter(v),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(LegalLibraryState state, LegalLibraryItem item) {
    final links = state.linksForItem(item.id);
    final permissions = ref.watch(permissionServiceProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: item.type.color.withOpacity(0.12),
                  child: Icon(item.type.icon, color: item.type.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy),
                  ),
                ),
                if (permissions.can(PermissionKeys.libraryEdit))
                  IconButton(
                    tooltip: item.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                    icon: Icon(
                      item.isFavorite ? Icons.star : Icons.star_border,
                      color: AppColors.secondaryGold,
                    ),
                    onPressed: () async {
                      ref.read(legalLibraryProvider.notifier).toggleFavorite(item.id);
                      await ref.read(auditServiceProvider).log(action: 'update', category: 'library', entityType: 'library_item', entityId: item.id, entityTitle: item.title, description: 'تعديل حالة المفضلة', severity: 'info');
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(item.type.displayName, item.type.color),
                _badge('${item.year}', AppColors.textSecondary),
                if (item.isPrinciple) _badge('مبدأ مختار', AppColors.warning),
                if (item.isFavorite) _badge('مفضلة', AppColors.secondaryGold),
                if (item.hasFile) _badge('مرفق', AppColors.info),
                ...item.tags.take(4).map((t) => _badge(t, AppColors.primaryNavy)),
              ],
            ),
            const SizedBox(height: 8),
            if (item.source.isNotEmpty)
              _line(Icons.source, 'المصدر: ${item.source}'),
            if (item.type == LegalItemType.law) ...[
              if (item.lawNumber.isNotEmpty)
                _line(Icons.numbers, 'رقم القانون: ${item.lawNumber} • ${item.lawKind}'),
              if (item.lastAmendment.isNotEmpty)
                _line(Icons.update, 'آخر تعديل: ${item.lastAmendment}'),
            ],
            if (item.type == LegalItemType.precedent) ...[
              _line(Icons.account_balance, '${item.court} • ${item.chamber}'),
              _line(
                Icons.tag,
                'قرار ${item.decisionNumber} / أساس ${item.baseNumber}${item.decisionDate != null ? ' • ${_fmt(item.decisionDate!)}' : ''}',
              ),
              if (item.principle.isNotEmpty)
                _line(Icons.lightbulb_outline, 'المبدأ: ${item.principle}'),
              if (item.journalYear != null)
                _line(
                  Icons.menu_book,
                  'مجلة المحامون ${item.journalYear}/${item.journalIssue} ص ${item.page}',
                ),
            ],
            if (item.type == LegalItemType.barJournal)
              _line(
                Icons.library_books,
                'السنة ${item.journalYear ?? item.year} • العدد ${item.journalIssue} • الصفحات ${item.page}',
              ),
            if (item.extractedText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  item.extractedText,
                  style: AppTextStyles.bodySmallSecondary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (links.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('مرتبط بملفات:', style: AppTextStyles.labelMedium),
              ...links.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 16, color: AppColors.info),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${l.entityTitle}${l.note.isNotEmpty ? ' — ${l.note}' : ''}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                      if (permissions.can(PermissionKeys.libraryLink))
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'إزالة الربط',
                          onPressed: () async {
                            ref.read(legalLibraryProvider.notifier).removeLink(l.id);
                            await ref.read(auditServiceProvider).log(action: 'unlink', category: 'library', entityType: 'library_link', entityId: l.id, entityTitle: item.title, description: 'إزالة ربط مادة قانونية بملف', severity: 'info');
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.hasFile && ref.watch(permissionServiceProvider).can(PermissionKeys.documentsOpen))
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح المرفق'),
                    onPressed: () => openDocument(context, item.id),
                  ),
                if (permissions.can(PermissionKeys.libraryLink))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('ربط بملف'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => LinkLegalItemDialog(itemId: item.id),
                    ),
                  ),
                if (!item.isPrinciple && item.principle.isNotEmpty && permissions.can(PermissionKeys.libraryEdit))
                  TextButton.icon(
                    icon: const Icon(Icons.flag),
                    label: const Text('تعيين كمبدأ'),
                    onPressed: () async {
                      ref.read(legalLibraryProvider.notifier).markAsPrinciple(item.id, value: true);
                      await ref.read(auditServiceProvider).log(action: 'update', category: 'library', entityType: 'library_item', entityId: item.id, entityTitle: item.title, description: 'تعيين مادة كمبدأ مختار', severity: 'info');
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _line(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books, size: 72, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text('لا مواد في هذا القسم', style: AppTextStyles.headline5),
          const SizedBox(height: 8),
          Text(
            'أضف قانوناً أو اجتهاداً أو عدداً من مجلة المحامون.',
            style: AppTextStyles.bodySmallSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class AddLegalItemDialog extends ConsumerStatefulWidget {
  const AddLegalItemDialog({super.key});

  @override
  ConsumerState<AddLegalItemDialog> createState() => _AddLegalItemDialogState();
}

class _AddLegalItemDialogState extends ConsumerState<AddLegalItemDialog> {
  final _title = TextEditingController();
  final _source = TextEditingController();
  final _year = TextEditingController(text: '2026');
  final _tags = TextEditingController();
  final _lawNumber = TextEditingController();
  final _court = TextEditingController(text: 'محكمة النقض');
  final _chamber = TextEditingController();
  final _decisionNumber = TextEditingController();
  final _baseNumber = TextEditingController();
  final _principle = TextEditingController();
  final _journalIssue = TextEditingController();
  final _page = TextEditingController();
  final _fileName = TextEditingController();
  final _text = TextEditingController();
  LegalItemType _type = LegalItemType.law;
  bool _favorite = false;
  bool _principleFlag = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _source,
      _year,
      _tags,
      _lawNumber,
      _court,
      _chamber,
      _decisionNumber,
      _baseNumber,
      _principle,
      _journalIssue,
      _page,
      _fileName,
      _text,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة إلى المكتبة'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<LegalItemType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'نوع المادة'),
                items: LegalItemType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 10),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'العنوان *')),
              const SizedBox(height: 10),
              TextField(controller: _source, decoration: const InputDecoration(labelText: 'المصدر')),
              const SizedBox(height: 10),
              TextField(
                controller: _year,
                decoration: const InputDecoration(labelText: 'السنة'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(labelText: 'كلمات مفتاحية (مفصولة بفاصلة)'),
              ),
              if (_type == LegalItemType.law) ...[
                const SizedBox(height: 10),
                TextField(controller: _lawNumber, decoration: const InputDecoration(labelText: 'رقم القانون')),
              ],
              if (_type == LegalItemType.precedent) ...[
                const SizedBox(height: 10),
                TextField(controller: _court, decoration: const InputDecoration(labelText: 'المحكمة')),
                const SizedBox(height: 10),
                TextField(controller: _chamber, decoration: const InputDecoration(labelText: 'الغرفة')),
                const SizedBox(height: 10),
                TextField(controller: _decisionNumber, decoration: const InputDecoration(labelText: 'رقم القرار')),
                const SizedBox(height: 10),
                TextField(controller: _baseNumber, decoration: const InputDecoration(labelText: 'رقم الأساس')),
                const SizedBox(height: 10),
                TextField(
                  controller: _principle,
                  decoration: const InputDecoration(labelText: 'المبدأ القانوني'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(controller: _journalIssue, decoration: const InputDecoration(labelText: 'عدد مجلة المحامون')),
                const SizedBox(height: 10),
                TextField(controller: _page, decoration: const InputDecoration(labelText: 'الصفحة')),
              ],
              if (_type == LegalItemType.barJournal) ...[
                const SizedBox(height: 10),
                TextField(controller: _journalIssue, decoration: const InputDecoration(labelText: 'رقم العدد')),
                const SizedBox(height: 10),
                TextField(controller: _page, decoration: const InputDecoration(labelText: 'الصفحات')),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _fileName,
                decoration: const InputDecoration(labelText: 'اسم الملف (PDF/DOC/DOCX/TXT/RTF)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                decoration: const InputDecoration(labelText: 'نص/ملخص للفهرسة المحلية'),
                maxLines: 3,
              ),
              CheckboxListTile(
                value: _favorite,
                onChanged: (v) => setState(() => _favorite = v ?? false),
                title: const Text('إضافة للمفضلة'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_type == LegalItemType.precedent)
                CheckboxListTile(
                  value: _principleFlag,
                  onChanged: (v) => setState(() => _principleFlag = v ?? false),
                  title: const Text('مبدأ مختار'),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }

  Future<void> _save() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.libraryAdd)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'library', entityType: 'library_item', description: 'محاولة إضافة مادة قانونية دون صلاحية', severity: 'warning');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا تملك صلاحية إضافة مواد للمكتبة'), backgroundColor: AppColors.error));
      return;
    }
    final title = _title.text.trim();
    final year = int.tryParse(_year.text.trim()) ?? DateTime.now().year;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('العنوان إلزامي'), backgroundColor: AppColors.error),
      );
      return;
    }
    final tags = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final now = DateTime.now();
    final fileName = _fileName.text.trim();
    final itemId = 'lib_${now.microsecondsSinceEpoch}';
    ref.read(legalLibraryProvider.notifier).addItem(
          LegalLibraryItem(
            id: itemId,
            type: _type,
            title: title,
            source: _source.text.trim(),
            year: year,
            tags: tags,
            isFavorite: _favorite,
            isPrinciple: _principleFlag || _principle.text.trim().isNotEmpty,
            createdAt: now,
            lawNumber: _lawNumber.text.trim(),
            court: _court.text.trim(),
            chamber: _chamber.text.trim(),
            decisionNumber: _decisionNumber.text.trim(),
            baseNumber: _baseNumber.text.trim(),
            principle: _principle.text.trim(),
            journalYear: _type == LegalItemType.barJournal || _type == LegalItemType.precedent
                ? year
                : null,
            journalIssue: _journalIssue.text.trim(),
            page: _page.text.trim(),
            fileName: fileName,
            filePath: fileName.isEmpty ? '' : 'library/$fileName',
            extractedText: _text.text.trim(),
          ),
        );
    await ref.read(auditServiceProvider).log(action: 'create', category: 'library', entityType: 'library_item', entityId: itemId, entityTitle: title, description: 'إضافة مادة إلى المكتبة القانونية', after: {'title': title, 'type': _type.displayName, 'year': year}, severity: 'info');
    if (mounted) Navigator.pop(context);
  }
}

class LinkLegalItemDialog extends ConsumerStatefulWidget {
  final String itemId;

  const LinkLegalItemDialog({super.key, required this.itemId});

  @override
  ConsumerState<LinkLegalItemDialog> createState() => _LinkLegalItemDialogState();
}

class _LinkLegalItemDialogState extends ConsumerState<LinkLegalItemDialog> {
  String _entityType = 'case';
  final _entityId = TextEditingController(text: '1');
  final _entityTitle = TextEditingController(text: 'دعوى تعويض 2026/001');
  final _note = TextEditingController();

  @override
  void dispose() {
    _entityId.dispose();
    _entityTitle.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ربط المادة بملف'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _entityType,
              decoration: const InputDecoration(labelText: 'نوع الملف'),
              items: const [
                DropdownMenuItem(value: 'case', child: Text('دعوى')),
                DropdownMenuItem(value: 'contract', child: Text('عقد')),
                DropdownMenuItem(value: 'company', child: Text('شركة')),
                DropdownMenuItem(value: 'procedure', child: Text('إجراء إداري')),
                DropdownMenuItem(value: 'memo', child: Text('مذكرة')),
              ],
              onChanged: (v) => setState(() => _entityType = v ?? _entityType),
            ),
            const SizedBox(height: 10),
            TextField(controller: _entityId, decoration: const InputDecoration(labelText: 'معرف الملف')),
            const SizedBox(height: 10),
            TextField(controller: _entityTitle, decoration: const InputDecoration(labelText: 'عنوان الملف')),
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة الربط')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () async {
            if (!ref.read(permissionServiceProvider).can(PermissionKeys.libraryLink)) {
              await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'library', entityType: 'library_item', entityId: widget.itemId, description: 'محاولة ربط مادة قانونية دون صلاحية', severity: 'warning');
              return;
            }
            if (_entityTitle.text.trim().isEmpty) return;
            ref.read(legalLibraryProvider.notifier).linkToEntity(
                  libraryItemId: widget.itemId,
                  entityType: _entityType,
                  entityId: _entityId.text.trim(),
                  entityTitle: _entityTitle.text.trim(),
                  note: _note.text.trim(),
                );
            await ref.read(auditServiceProvider).log(action: 'link', category: 'library', entityType: 'library_item', entityId: widget.itemId, entityTitle: _entityTitle.text.trim(), description: 'ربط مادة قانونية بملف', after: {'entityType': _entityType, 'entityId': _entityId.text.trim(), 'note': _note.text.trim()}, severity: 'info');
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('ربط'),
        ),
      ],
    );
  }
}
