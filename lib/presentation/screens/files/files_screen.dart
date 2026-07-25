/// شاشة الملفات الموحدة.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../../core/enums/app_enums.dart';
import '../../providers/auth_providers.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../documents/document_models.dart' as doc_models;
import '../work_orders/work_order_models.dart' as wo_models;
import '../documents/document_viewer.dart';
import '../../providers/ui_data_providers.dart';

enum FileType {
  caseFile,
  contract,
  company,
  adminProcedure,
  agency;

  String get displayName => const ['دعوى', 'عقد', 'شركة', 'إجراء إداري', 'وكالة'][index];
}

enum FileStatus {
  active,
  completed,
  archived;

  String get displayName => const ['جارية', 'منتهية', 'مؤرشفة'][index];

  Color get color => const [AppColors.info, AppColors.success, AppColors.textSecondary][index];
}

/// المؤشر المالي للملف (المرحلة التاسعة من خارطة التنفيذ).
enum FileFinanceStatus {
  none,
  openFees,
  partiallyPaid,
  fullyPaid,
  unpaidExpenses,
  needsReview;

  String get displayName => const [
        'لا مالية',
        'أتعاب مفتوحة',
        'مدفوع جزئياً',
        'مدفوع بالكامل',
        'مصاريف غير مسددة',
        'مالية تحتاج مراجعة',
      ][index];

  Color get color => const [
        AppColors.textSecondary,
        AppColors.warning,
        AppColors.info,
        AppColors.success,
        AppColors.error,
        AppColors.error,
      ][index];

  /// هل يمنع هذا المؤشر الإغلاق دون تأكيد صريح؟
  bool get blocksClosure =>
      this == FileFinanceStatus.openFees ||
      this == FileFinanceStatus.partiallyPaid ||
      this == FileFinanceStatus.unpaidExpenses ||
      this == FileFinanceStatus.needsReview;
}

class FileItem {
  final String id;
  final String fileNumber;
  final String title;
  final String court;
  final String subCategory;
  final FileType type;
  final FileStatus status;
  final bool hasDeficiencies;
  final bool hasBaseNumber;
  final bool hasMissingDocuments;
  final bool isOverdue;
  final int deficiencyCount;
  final DateTime? nextSessionDate;
  final String? baseNumber;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final int documentCount;
  final List<String>? documentIds;
  final FileFinanceStatus financeStatus;

  const FileItem({
    required this.id,
    required this.fileNumber,
    required this.title,
    required this.type,
    required this.court,
    this.subCategory = '',
    required this.status,
    this.hasDeficiencies = false,
    this.deficiencyCount = 0,
    this.nextSessionDate,
    this.hasBaseNumber = true,
    this.baseNumber,
    this.hasMissingDocuments = false,
    this.isOverdue = false,
    required this.createdAt,
    required this.lastUpdated,
    this.documentCount = 0,
    this.documentIds,
    this.financeStatus = FileFinanceStatus.none,
  });

  Color get statusColor => status.color;
}

final filesProvider = Provider<List<FileItem>>((ref) {
  final asyncFiles = ref.watch(uiFilesProvider);
  return asyncFiles.maybeWhen(data: (items) => items, orElse: () => const <FileItem>[]);
});


class FilesScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const FilesScreen({super.key, this.initialStatus});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  late String _statusFilter;
  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus == 'completed' ? 'completed' : 'active';
  }

  @override
  void didUpdateWidget(covariant FilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialStatus == 'completed' ? 'completed' : 'active';
    if (oldWidget.initialStatus != widget.initialStatus && _statusFilter != next) {
      _statusFilter = next;
    }
  }
  FileType? _typeFilter;
  String? _subCategoryFilter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allFiles = ref.watch(filesProvider);
    final files = _filteredFiles(allFiles);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ملفات المكتب'),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () => context.go('/search-reports'), tooltip: 'بحث'),

          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilters(allFiles),
            _buildSummary(allFiles, files),
            Expanded(child: _buildOfficeFilesList(files)),
          ],
        ),
      ),
    );
  }

  List<FileItem> _filteredFiles(List<FileItem> all) {
    final q = _query.trim().toLowerCase();
    return all.where((file) {
      final statusOk = switch (_statusFilter) {
        'all' => true,
        'active' => file.status == FileStatus.active,
        'completed' => file.status == FileStatus.completed || file.status == FileStatus.archived,
        'needs_completion' => file.hasDeficiencies || file.hasMissingDocuments || !file.hasBaseNumber,
        _ => true,
      };
      final typeOk = _typeFilter == null || file.type == _typeFilter;
      final subCategoryOk = _subCategoryFilter == null || file.subCategory == _subCategoryFilter;
      final queryOk = q.isEmpty ||
          file.fileNumber.toLowerCase().contains(q) ||
          file.title.toLowerCase().contains(q) ||
          file.court.toLowerCase().contains(q) ||
          (file.baseNumber ?? '').toLowerCase().contains(q);
      return statusOk && typeOk && subCategoryOk && queryOk;
    }).toList()
      ..sort((a, b) => (a.nextSessionDate ?? DateTime(9999)).compareTo(b.nextSessionDate ?? DateTime(9999)));
  }

  Widget _buildFilters(List<FileItem> allFiles) {
    final subCategories = allFiles
        .where((f) => _typeFilter == null || f.type == _typeFilter)
        .map((f) => f.subCategory)
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (_subCategoryFilter != null && !subCategories.contains(_subCategoryFilter)) {
      _subCategoryFilter = null;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'بحث برقم الملف، الاسم، المحكمة/الجهة، رقم الأساس أو القيد...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<FileType?>(
                value: _typeFilter,
                items: [
                  const DropdownMenuItem<FileType?>(value: null, child: Text('كل الأنواع')),
                  ...FileType.values.map((type) => DropdownMenuItem<FileType?>(value: type, child: Text(type.displayName))),
                ],
                onChanged: (value) => setState(() {
                  _typeFilter = value;
                  _subCategoryFilter = null;
                }),
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                value: _subCategoryFilter,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('كل التصنيفات')),
                  ...subCategories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
                ],
                onChanged: (value) => setState(() => _subCategoryFilter = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statusTab('active', 'الملفات الجارية', 'تؤثر على مكتب العمل والمواعيد القادمة')),
              const SizedBox(width: 10),
              Expanded(child: _statusTab('completed', 'الملفات المنتهية', 'للحفظ والبحث فقط دون أثر على المواعيد')),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _typeChip(null, 'كل الأنواع', Icons.folder_copy),
                ...FileType.values.map((type) => _typeChip(type, type.displayName, _fileTypeIcon(type))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(FileType? value, String label, IconData icon) {
    final selected = _typeFilter == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: selected ? AppColors.primaryNavy : AppColors.textSecondary),
        selected: selected,
        label: Text(label),
        selectedColor: AppColors.primaryNavy.withOpacity(0.10),
        labelStyle: TextStyle(color: selected ? AppColors.primaryNavy : AppColors.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        onSelected: (_) => setState(() {
          _typeFilter = value;
          _subCategoryFilter = null;
        }),
      ),
    );
  }

  IconData _fileTypeIcon(FileType type) {
    switch (type) {
      case FileType.caseFile:
        return Icons.gavel;
      case FileType.contract:
        return Icons.description;
      case FileType.company:
        return Icons.business;
      case FileType.adminProcedure:
        return Icons.assignment;
      case FileType.agency:
        return Icons.verified_user_outlined;
    }
  }

  Widget _statusTab(String value, String label, String subtitle) {
    final selected = _statusFilter == value;
    return InkWell(
      onTap: () {
        setState(() => _statusFilter = value);
        context.go('/files?status=$value');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryNavy.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primaryNavy : AppColors.cardBorder, width: selected ? 1.5 : 0.7),
        ),
        child: Row(
          children: [
            Icon(value == 'active' ? Icons.pending_actions : Icons.inventory_2, color: selected ? AppColors.primaryNavy : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.labelLarge.copyWith(color: selected ? AppColors.primaryNavy : AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTextStyles.bodySmallSecondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<FileItem> all, List<FileItem> filtered) {
    final active = all.where((f) => f.status == FileStatus.active).length;
    final completed = all.where((f) => f.status == FileStatus.completed || f.status == FileStatus.archived).length;
    final needs = all.where((f) => f.status == FileStatus.active && (f.hasDeficiencies || f.hasMissingDocuments || !f.hasBaseNumber)).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _metric('المعروض', filtered.length, Icons.folder_open, AppColors.primaryNavy),
          _metric('جارية', active, Icons.play_circle_outline, AppColors.info),
          _metric('منتهية', completed, Icons.check_circle_outline, AppColors.success),
          _metric('تحتاج استكمال', needs, Icons.warning_amber, AppColors.warning),
        ],
      ),
    );
  }

  Widget _metric(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.22))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: AppTextStyles.labelSmall),
          Text('$count', style: AppTextStyles.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildOfficeFilesList(List<FileItem> files) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 72, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('لا توجد ملفات ضمن هذا التبويب', style: AppTextStyles.headline6),
            const SizedBox(height: 8),
            Text(_statusFilter == 'active' ? 'لا توجد ملفات جارية حالياً. يمكن إنشاء ملف جديد من مكتب العمل.' : 'لا توجد ملفات منتهية ضمن الفلتر الحالي.', style: AppTextStyles.bodySmallSecondary),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                if (_statusFilter == 'active')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('إنشاء جديد'),
                    onPressed: () => context.go('/today'),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) => FileCard(file: files[index]),
    );
  }
}

class AllFilesTab extends ConsumerWidget {
  const AllFilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _buildList(ref.watch(filesProvider), context);
}

class ActiveFilesTab extends ConsumerWidget {
  const ActiveFilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _buildList(
        ref.watch(filesProvider).where((file) => file.status == FileStatus.active).toList(),
        context,
        'لا يوجد ملفات جارية',
      );
}

class DeficientFilesTab extends ConsumerWidget {
  const DeficientFilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _buildList(
        ref.watch(filesProvider).where((file) => file.hasDeficiencies).toList(),
        context,
        'لا يوجد ملفات ناقصة',
      );
}

class OverdueFilesTab extends ConsumerWidget {
  const OverdueFilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _buildList(
        ref.watch(filesProvider).where((file) => file.isOverdue).toList(),
        context,
        'لا يوجد ملفات متأخرة',
      );
}

class CompletedFilesTab extends ConsumerWidget {
  const CompletedFilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _buildList(
        ref.watch(filesProvider).where((file) => file.status == FileStatus.completed).toList(),
        context,
        'لا يوجد ملفات منتهية',
      );
}

class NearSessionFilesTab extends ConsumerWidget {
  const NearSessionFilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _buildList(
        ref.watch(filesProvider).where((file) => file.nextSessionDate != null).toList(),
        context,
        'لا يوجد ملفات بجلسة قريب',
      );
}

class WaitingBaseFilesTab extends ConsumerWidget {
  const WaitingBaseFilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _buildList(
        ref.watch(filesProvider).where((file) => !file.hasBaseNumber).toList(),
        context,
        'لا يوجد ملفات بانتظار رقم أساس',
      );
}

class WaitingDocFilesTab extends ConsumerWidget {
  const WaitingDocFilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _buildList(
        ref.watch(filesProvider).where((file) => file.hasMissingDocuments).toList(),
        context,
        'لا يوجد ملفات بانتظار مستند',
      );
}

Widget _buildList(List<FileItem> files, BuildContext context, [String empty = 'لا يوجد ملفات']) {
  if (files.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(empty, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  final ordered = [...files]
    ..sort((a, b) => (a.nextSessionDate ?? DateTime(9999)).compareTo(b.nextSessionDate ?? DateTime(9999)));
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: ordered.length,
    itemBuilder: (context, index) => FileCard(file: ordered[index]),
  );
}

class FileCard extends StatelessWidget {
  final FileItem file;

  const FileCard({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openFile(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      file.fileNumber,
                      style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy),
                    ),
                  ),
                  _tag(file.type.displayName, AppColors.primaryNavy),
                  if (file.subCategory.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _tag(file.subCategory, AppColors.info),
                  ],
                  const SizedBox(width: 8),
                  _tag(file.status.displayName, file.statusColor),
                  const SizedBox(width: 8),
                  if (file.status == FileStatus.active)
                    IconButton(
                      icon: const Icon(Icons.lock_outline, color: AppColors.warning, size: 20),
                      tooltip: 'إغلاق إداري',
                      onPressed: () => _showCloseDialog(context),
                    )
                  else if (file.status == FileStatus.completed)
                    IconButton(
                      icon: const Icon(Icons.lock_open, color: AppColors.info, size: 20),
                      tooltip: 'إعادة فتح الملف',
                      onPressed: () => _showReopenDialog(context),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(file.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              if (file.type == FileType.caseFile && file.court.isNotEmpty) _line(Icons.balance, file.court),
              if (file.hasBaseNumber && file.baseNumber != null)
                _line(Icons.confirmation_number, 'رقم الأساس: ${file.baseNumber}')
              else if (file.status == FileStatus.active)
                _tagLine('بانتظار رقم أساس', AppColors.warning),
              if (file.nextSessionDate != null) _line(Icons.calendar_today, 'الموعد القادم: ${_formatDate(file.nextSessionDate!)}'),
              if (file.status == FileStatus.active && file.hasDeficiencies) _tagLine('نواقص: ${file.deficiencyCount}', AppColors.error),
              if (file.status == FileStatus.active && file.hasMissingDocuments) _tagLine('مستندات ناقصة', AppColors.warning),
              if (file.financeStatus != FileFinanceStatus.none)
                _tagLine(file.financeStatus.displayName, file.financeStatus.color),
              if (file.status != FileStatus.active) _tagLine('ملف محفوظ للأرشيف والبحث فقط', AppColors.textSecondary),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_file, color: AppColors.textSecondary, size: 16),
                  const SizedBox(width: 4),
                  Text('المستندات: ${file.documentCount}', style: AppTextStyles.bodySmallSecondary),
                  const SizedBox(width: 8),
                  if (file.documentCount > 0 && (file.documentIds?.isNotEmpty ?? false))
                    TextButton(onPressed: () => _showDocsDialog(context, file), child: const Text('عرض المستندات')),
                ],
              ),
              Text('آخر تحديث: ${_formatDate(file.lastUpdated)}', style: AppTextStyles.bodySmallSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _openFile(BuildContext context) {
    switch (file.type) {
      case FileType.caseFile:
        context.go('/cases/${file.id}');
        return;
      case FileType.contract:
        context.go('/contracts/${file.id}');
        return;
      case FileType.company:
        context.go('/companies/${file.id}');
        return;
      case FileType.adminProcedure:
        context.go('/procedures/${file.id}');
        return;
      case FileType.agency:
        context.go('/poa/${file.id}');
        return;
    }
  }

  Widget _line(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: AppTextStyles.bodySmallSecondary)),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _tagLine(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(alignment: Alignment.centerRight, child: _tag(text, color)),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showMsg(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.info));
  }

  void _showDocsDialog(BuildContext context, FileItem file) {
    showDialog<void>(context: context, builder: (context) => FileDocsDialog(file: file));
  }

  void _showCloseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => CloseOfficeFileDialog(
        file: file,
        onClosed: () {
          // Refresh the files list after closing
          // The provider will automatically refresh on next watch
        },
      ),
    );
  }

  void _showReopenDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ReopenOfficeFileDialog(
        file: file,
        onReopened: () {
          // Refresh the files list
        },
      ),
    );
  }
}

class FileDocsDialog extends ConsumerWidget {
  final FileItem file;

  const FileDocsDialog({super.key, required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = _getDocs(file, ref);
    final canOpenDocs = ref.watch(permissionServiceProvider).can(PermissionKeys.documentsOpen);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: AppColors.textOnLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مستندات الملف: ${file.fileNumber}',
                      style: AppTextStyles.headline6.copyWith(color: AppColors.textOnLight),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) => ListTile(
                  leading: Icon(docs[index].fileType.icon, color: AppColors.primaryNavy),
                  title: Text(docs[index].title, style: AppTextStyles.bodyMedium),
                  subtitle: Text('${docs[index].fileType.displayName} - ${docs[index].formattedSize}', style: AppTextStyles.bodySmallSecondary),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: canOpenDocs ? () => openDocument(context, docs[index].id) : null,
                    tooltip: 'فتح',
                  ),
                  onTap: canOpenDocs ? () => openDocument(context, docs[index].id) : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// مستندات الملف الحقيقية من الأرشيف؛ يُلجأ للعرض المبسّط فقط إن تعذّر
  /// العثور على المستند (سجل قديم أو رابط مكسور).
  List<doc_models.DocumentItem> _getDocs(FileItem file, WidgetRef ref) {
    final ids = file.documentIds ?? const <String>[];
    if (ids.isEmpty) return const [];
    final all = ref.watch(uiDocumentsProvider).maybeWhen(
          data: (items) => items,
          orElse: () => const <doc_models.DocumentItem>[],
        );
    final byId = {for (final d in all) d.id: d};
    final resolved = ids.where(byId.containsKey).map((id) => byId[id]!).toList();
    if (resolved.length == ids.length) return resolved;

    final missing = ids.where((id) => !byId.containsKey(id)).toList();
    return [
      ...resolved,
      ...missing
        .asMap()
        .entries
        .map(
          (entry) => doc_models.DocumentItem(
            id: entry.value,
            title: 'مستند غير موجود (${entry.value})',
            documentType: doc_models.DocumentType.other,
            entityType: file.type.toString().split('.').last,
            entityId: file.id,
            entityTitle: file.title,
            filePath: '',
            fileName: '',
            fileSize: 0,
            fileType: doc_models.FileType.other,
            uploadDate: file.lastUpdated,
            uploadedBy: 'غير معروف',
            physicalLocation: 'غير محدد',
            notes: 'تعذر العثور على هذا المستند في الأرشيف.',
          ),
        ),
    ];
  }
}

class FilesFilterDialog extends StatefulWidget {
  const FilesFilterDialog({super.key});

  @override
  State<FilesFilterDialog> createState() => _FilesFilterDialogState();
}

class _FilesFilterDialogState extends State<FilesFilterDialog> {
  FileType? _type;
  FileStatus? _status;
  bool _deficient = false;
  bool _missingDocuments = false;
  bool _overdue = false;
  bool _pendingBase = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('فلترة الملفات', style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy)),
            const SizedBox(height: 24),
            DropdownButtonFormField<FileType?>(
              value: _type,
              items: [
                const DropdownMenuItem<FileType?>(value: null, child: Text('جميع الأنواع')),
                ...FileType.values.map((type) => DropdownMenuItem<FileType?>(value: type, child: Text(type.displayName))),
              ],
              onChanged: (value) => setState(() => _type = value),
              decoration: const InputDecoration(labelText: 'نوع الملف'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FileStatus?>(
              value: _status,
              items: [
                const DropdownMenuItem<FileStatus?>(value: null, child: Text('جميع الحالات')),
                ...FileStatus.values.map((status) => DropdownMenuItem<FileStatus?>(value: status, child: Text(status.displayName))),
              ],
              onChanged: (value) => setState(() => _status = value),
              decoration: const InputDecoration(labelText: 'حالة الملف'),
            ),
            CheckboxListTile(title: const Text('الملفات الناقصة'), value: _deficient, onChanged: (value) => setState(() => _deficient = value ?? false)),
            CheckboxListTile(title: const Text('المستندات الناقصة'), value: _missingDocuments, onChanged: (value) => setState(() => _missingDocuments = value ?? false)),
            CheckboxListTile(title: const Text('الملفات المتأخرة'), value: _overdue, onChanged: (value) => setState(() => _overdue = value ?? false)),
            CheckboxListTile(title: const Text('بانتظار رقم أساس'), value: _pendingBase, onChanged: (value) => setState(() => _pendingBase = value ?? false)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تم تطبيق الفلاتر'), backgroundColor: AppColors.success));
                  },
                  child: const Text('تطبيق'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== حوار الإغلاق الإداري ====================
class CloseOfficeFileDialog extends ConsumerStatefulWidget {
  final FileItem file;
  final VoidCallback? onClosed;

  const CloseOfficeFileDialog({
    super.key,
    required this.file,
    this.onClosed,
  });

  @override
  ConsumerState<CloseOfficeFileDialog> createState() => _CloseOfficeFileDialogState();
}

/// أسباب الإغلاق المعتمدة لكل نوع ملف (المرحلة الرابعة من خارطة التنفيذ).
const Map<FileType, List<String>> kClosureReasonsByType = {
  FileType.caseFile: [
    'حكم قطعي',
    'صلح',
    'إسقاط / ترك / شطب',
    'اعتزال وكالة',
    'عزل وكالة',
    'عدم متابعة بطلب الموكل',
  ],
  FileType.adminProcedure: [
    'تم إنجازه',
    'تعذر تنفيذه',
    'تحول إلى دعوى',
    'أوقفه الموكل',
  ],
  FileType.contract: [
    'انتهى',
    'ألغي',
    'استبدل',
    'نفذ بالكامل',
  ],
  FileType.company: [
    'اكتمل التأسيس',
    'انحلت',
    'توقف الإجراء',
    'انتقلت لإدارة لاحقة',
  ],
  FileType.agency: [
    'انتهت',
    'عزل عنها',
    'ألغيت',
    'لم تعد مستخدمة',
  ],
};

class _CloseOfficeFileDialogState extends ConsumerState<CloseOfficeFileDialog> {
  String? _selectedReason;
  /// تأكيد صريح مطلوب عند الإغلاق مع مالية مفتوحة.
  bool _financeOverrideConfirmed = false;
  final _reasonController = TextEditingController();
  final _summaryController = TextEditingController();
  bool _hasPendingFinance = false;
  bool _hasPendingPaperOriginal = false;
  bool _hasPostClosureActions = false;
  bool _isClosing = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إغلاق إداري للملف'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الملف: ${widget.file.fileNumber}', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            // سبب الإغلاق يُختار من قائمة معتمدة حسب نوع الملف، مع خيار
            // «سبب آخر» للحالات الاستثنائية.
            DropdownButtonFormField<String>(
              value: _selectedReason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'سبب الإغلاق *'),
              items: [
                ...(kClosureReasonsByType[widget.file.type] ?? const <String>[])
                    .map((r) => DropdownMenuItem(value: r, child: Text(r))),
                const DropdownMenuItem(value: '__other__', child: Text('سبب آخر')),
              ],
              onChanged: (v) => setState(() => _selectedReason = v),
            ),
            if (_selectedReason == '__other__') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'اكتب سبب الإغلاق *'),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _summaryController,
              decoration: const InputDecoration(
                labelText: 'ملخص الإغلاق *',
                hintText: 'ملخص مختصر للقرار أو الإجراء النهائي',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // فحص تلقائي للأعمال المفتوحة والمالية قبل الإغلاق (خطوات 3-6).
            _buildPreCloseChecks(),
            if (widget.file.financeStatus.blocksClosure) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.file.financeStatus.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.file.financeStatus.color.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.account_balance_wallet, color: widget.file.financeStatus.color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الحالة المالية: ${widget.file.financeStatus.displayName}',
                          style: AppTextStyles.labelLarge.copyWith(color: widget.file.financeStatus.color),
                        ),
                      ),
                    ]),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _financeOverrideConfirmed,
                      title: const Text('أؤكد الإغلاق رغم وجود مالية مفتوحة'),
                      onChanged: _canOverrideFinance
                          ? (v) => setState(() => _financeOverrideConfirmed = v ?? false)
                          : null,
                    ),
                    if (!_canOverrideFinance)
                      Text(
                        'لا تملك صلاحية الإغلاق مع مالية مفتوحة. راجع مالك المكتب.',
                        style: AppTextStyles.bodySmallSecondary.copyWith(color: AppColors.error),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('يوجد ذمم مالية معلقة'),
              value: _hasPendingFinance,
              onChanged: (v) => setState(() => _hasPendingFinance = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('يوجد أصل ورقي معلق'),
              value: _hasPendingPaperOriginal,
              onChanged: (v) => setState(() => _hasPendingPaperOriginal = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('يوجد إجراءات لاحقة مطلوبة'),
              value: _hasPostClosureActions,
              onChanged: (v) => setState(() => _hasPostClosureActions = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isClosing ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isClosing ? null : _performClose,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: _isClosing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('إغلاق الملف'),
        ),
      ],
    );
  }

  /// صلاحية تجاوز المالية المفتوحة عند الإغلاق.
  bool get _canOverrideFinance {
    final user = ref.read(authControllerProvider).user;
    if (user?.isOwner ?? false) return true;
    // التجاوز يتطلب صلاحية الإغلاق ورؤية المالية معاً.
    final perms = ref.read(permissionServiceProvider);
    return perms.can(PermissionKeys.casesClose) && perms.can(PermissionKeys.financeView);
  }

  /// فحص ما قبل الإغلاق: أعمال مفتوحة ومالية غير مسددة ومستندات ناقصة.
  Widget _buildPreCloseChecks() {
    final entityId = int.tryParse(widget.file.id) ?? 0;
    final entityKey = switch (widget.file.type) {
      FileType.caseFile => 'case',
      FileType.contract => 'contract',
      FileType.company => 'company',
      FileType.adminProcedure => 'procedure',
      FileType.agency => 'poa',
    };

    final finance = ref.watch(financeByEntityProvider((entityKey, '$entityId')));
    final openWorkOrders = ref.watch(uiWorkOrdersProvider).maybeWhen(
          data: (orders) => orders
              .where((w) =>
                  w.linkedEntityId == widget.file.id &&
                  w.status != wo_models.WorkOrderStatus.approved &&
                  w.status != wo_models.WorkOrderStatus.cancelled)
              .length,
          orElse: () => 0,
        );

    final warnings = <String>[];
    finance.whenData((data) {
      if (data.remaining > 0) {
        warnings.add('أتعاب غير مقبوضة: ${data.remaining.toStringAsFixed(0)}');
      }
    });
    if (openWorkOrders > 0) {
      warnings.add('أوامر عمل مفتوحة: $openWorkOrders');
    }
    if (widget.file.hasMissingDocuments) {
      warnings.add('مستندات أو أصول ورقية ناقصة');
    }
    if (widget.file.hasDeficiencies) {
      warnings.add('نواقص مفتوحة: ${widget.file.deficiencyCount}');
    }

    if (warnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.verified, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('لا توجد أعمال أو مالية معلقة على هذا الملف.', style: AppTextStyles.bodySmallSecondary)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
            const SizedBox(width: 8),
            Text('تنبيهات قبل الإغلاق', style: AppTextStyles.labelLarge.copyWith(color: AppColors.warning)),
          ]),
          const SizedBox(height: 6),
          ...warnings.map((w) => Text('• $w', style: AppTextStyles.bodySmallSecondary)),
        ],
      ),
    );
  }

  Future<void> _performClose() async {
    final reason = _selectedReason == '__other__'
        ? _reasonController.text.trim()
        : (_selectedReason ?? '');
    if (reason.isEmpty || _summaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب اختيار سبب الإغلاق وإدخال الملخص'), backgroundColor: AppColors.error),
      );
      return;
    }

    // منع الإغلاق مع مالية مفتوحة إلا بتأكيد صريح وصلاحية كافية.
    if (widget.file.financeStatus.blocksClosure) {
      if (!_canOverrideFinance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن إغلاق ملف بحالة «${widget.file.financeStatus.displayName}» دون صلاحية.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (!_financeOverrideConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أكّد الإغلاق رغم المالية المفتوحة أولاً'), backgroundColor: AppColors.error),
        );
        return;
      }
    }

    setState(() => _isClosing = true);

    try {
      final entityType = _getEntityTypeFromFile(widget.file);
      final entityId = int.tryParse(widget.file.id) ?? 0;

      final officeRepo = ref.read(officeFileRepositoryProvider);
      final officeFile = await officeRepo.getByLinkedEntity(entityType: entityType, entityId: entityId);

      if (officeFile == null) {
        throw Exception('لم يتم العثور على ملف المكتب المرتبط');
      }

      await officeRepo.closeOfficeFile(
        officeFileId: officeFile.id,
        reason: reason,
        summary: _summaryController.text.trim(),
        closedByNameSnapshot: ref.read(authControllerProvider).user?.fullName,
        hasPendingFinance: _hasPendingFinance,
        hasPendingPaperOriginal: _hasPendingPaperOriginal,
        hasPostClosureActions: _hasPostClosureActions,
      );

      await ref.read(auditServiceProvider).log(
            action: 'close',
            category: 'office_files',
            entityType: 'office_file',
            entityId: '${officeFile.id}',
            entityTitle: widget.file.fileNumber,
            description: 'إغلاق إداري للملف: $reason',
            after: {
              'reason': reason,
              'summary': _summaryController.text.trim(),
              'hasPendingFinance': _hasPendingFinance,
              'hasPendingPaperOriginal': _hasPendingPaperOriginal,
              'hasPostClosureActions': _hasPostClosureActions,
              'financeStatus': widget.file.financeStatus.displayName,
              'financeOverride': _financeOverrideConfirmed,
            },
            severity: 'critical',
          );
      ref.invalidate(uiFilesProvider);

      if (mounted) {
        Navigator.pop(context);
        widget.onClosed?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إغلاق الملف ${widget.file.fileNumber}'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الإغلاق: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  int _getEntityTypeFromFile(FileItem file) {
    switch (file.type) {
      case FileType.caseFile:
        return EntityType.caseEntity.index;
      case FileType.contract:
        return EntityType.contract.index;
      case FileType.company:
        return EntityType.company.index;
      case FileType.adminProcedure:
        return EntityType.adminProcedure.index;
      case FileType.agency:
        return EntityType.powerOfAttorney.index;
    }
  }
}

// ==================== حوار إعادة الفتح ====================
class ReopenOfficeFileDialog extends ConsumerStatefulWidget {
  final FileItem file;
  final VoidCallback? onReopened;

  const ReopenOfficeFileDialog({
    super.key,
    required this.file,
    this.onReopened,
  });

  @override
  ConsumerState<ReopenOfficeFileDialog> createState() => _ReopenOfficeFileDialogState();
}

class _ReopenOfficeFileDialogState extends ConsumerState<ReopenOfficeFileDialog> {
  final _reasonController = TextEditingController();
  bool _isReopening = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعادة فتح الملف'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('الملف: ${widget.file.fileNumber}', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'سبب إعادة الفتح *',
              hintText: 'مثال: استئناف / تصحيح خطأ / طلب جديد',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isReopening ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isReopening ? null : _performReopen,
          child: _isReopening
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('إعادة فتح'),
        ),
      ],
    );
  }

  Future<void> _performReopen() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إدخال سبب إعادة الفتح'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isReopening = true);

    try {
      final entityType = _getEntityTypeFromFile(widget.file);
      final entityId = int.tryParse(widget.file.id) ?? 0;

      final officeRepo = ref.read(officeFileRepositoryProvider);
      final officeFile = await officeRepo.getByLinkedEntity(entityType: entityType, entityId: entityId);

      if (officeFile == null) {
        throw Exception('لم يتم العثور على ملف المكتب المرتبط');
      }

      await officeRepo.reopenOfficeFile(
        officeFileId: officeFile.id,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onReopened?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إعادة فتح الملف ${widget.file.fileNumber}'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء إعادة الفتح: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isReopening = false);
    }
  }

  int _getEntityTypeFromFile(FileItem file) {
    switch (file.type) {
      case FileType.caseFile:
        return EntityType.caseEntity.index;
      case FileType.contract:
        return EntityType.contract.index;
      case FileType.company:
        return EntityType.company.index;
      case FileType.adminProcedure:
        return EntityType.adminProcedure.index;
      case FileType.agency:
        return EntityType.powerOfAttorney.index;
    }
  }
}
