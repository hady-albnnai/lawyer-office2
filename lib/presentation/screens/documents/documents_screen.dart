import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
import '../../../core/auth/permission_catalog.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
/// شاشة المستندات (Smart File Explorer)
/// بناءً على الخطة الماسية لإعادة الهيكلة 2026 (المرحلة 4)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'document_models.dart' as doc_models;
import 'document_models.dart' show DocumentItem, DocumentType, documentsProvider, documentsFutureProvider, inferFileType;
import 'document_viewer.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.cardBackground,
        appBar: AppBar(
          title: const Text('مستعرض المستندات الذكي'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.go('/search-reports'),
              tooltip: 'بحث متقدم',
            ),
            if (permissions.can(PermissionKeys.documentsUpload))
              IconButton(
                icon: const Icon(Icons.upload_file),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => const UploadDocDialog(),
                ),
                tooltip: 'رفع مستند',
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: const _SmartExplorerView(),
      ),
    );
  }
}

class _SmartExplorerView extends ConsumerStatefulWidget {
  const _SmartExplorerView();

  @override
  ConsumerState<_SmartExplorerView> createState() => _SmartExplorerViewState();
}

class _SmartExplorerViewState extends ConsumerState<_SmartExplorerView> {
  // للتحكم في التنقل بين المجلدات (Navigation History)
  DocumentType? _currentFolder;
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // شريط المسار أدوات العرض (Breadcrumbs & View Controls)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
          ),
          child: Row(
            children: [
              // Breadcrumbs
              InkWell(
                onTap: () => setState(() => _currentFolder = null),
                child: Row(
                  children: [
                    const Icon(Icons.home, color: AppColors.primaryNavy, size: 20),
                    const SizedBox(width: 8),
                    Text('الرئيسية', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
                  ],
                ),
              ),
              if (_currentFolder != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(_currentFolder!.displayName, style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold)),
              ],
              
              const Spacer(),
              
              // View Toggles
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.grid_view, color: _isGridView ? AppColors.primaryNavy : AppColors.textSecondary),
                      onPressed: () => setState(() => _isGridView = true),
                      tooltip: 'عرض شبكي',
                    ),
                    IconButton(
                      icon: Icon(Icons.view_list, color: !_isGridView ? AppColors.primaryNavy : AppColors.textSecondary),
                      onPressed: () => setState(() => _isGridView = false),
                      tooltip: 'عرض القائمة',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // منطقة العرض الرئيسية (Main Content Area)
        Expanded(
          child: _currentFolder == null 
              ? _buildFoldersGrid(docs) // عرض المجلدات الرئيسية
              : _buildFilesView(docs.where((d) => d.documentType == _currentFolder).toList()), // عرض الملفات داخل المجلد
        ),
      ],
    );
  }

  // بناء شبكة المجلدات الذكية (Smart Folders)
  Widget _buildFoldersGrid(List<DocumentItem> allDocs) {
    // تجميع المستندات لمعرفة عددها داخل كل نوع
    final counts = <DocumentType, int>{};
    for (final doc in allDocs) {
      counts[doc.documentType] = (counts[doc.documentType] ?? 0) + 1;
    }

    // المجلدات الرئيسية المعتمدة في النظام
    final folders = [
      _FolderModel(type: DocumentType.caseDocument, icon: Icons.folder_shared, color: AppColors.primaryNavy),
      _FolderModel(type: DocumentType.powerOfAttorney, icon: Icons.verified_user, color: AppColors.info),
      _FolderModel(type: DocumentType.decision, icon: Icons.gavel, color: AppColors.error),
      _FolderModel(type: DocumentType.contract, icon: Icons.description, color: AppColors.secondaryGold),
      _FolderModel(type: DocumentType.receipt, icon: Icons.receipt_long, color: AppColors.success),
      _FolderModel(type: DocumentType.companyDocument, icon: Icons.business, color: Colors.blueGrey),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.1,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final count = counts[folder.type] ?? 0;
        
        return InkWell(
          onTap: () => setState(() => _currentFolder = folder.type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(folder.icon, size: 64, color: folder.color.withOpacity(0.8)),
                const SizedBox(height: 12),
                Text(folder.type.displayName, style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('$count ملف', style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  // بناء عرض الملفات (Grid أو List)
  Widget _buildFilesView(List<DocumentItem> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: AppColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('هذا المجلد فارغ', style: AppTextStyles.headline6.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final orderedDocs = [...docs]..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: orderedDocs.length,
        itemBuilder: (context, index) => _buildGridFileCard(orderedDocs[index]),
      );
    } else {
      return ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: orderedDocs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildListFileCard(orderedDocs[index]),
      );
    }
  }

  // بطاقة عرض شبكي للملف (تُشبه Windows Explorer Icon)
    Widget _buildGridFileCard(DocumentItem doc) {
    return InkWell(
      onDoubleTap: () => _openDocumentWithPermission(context, ref, doc),
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.transparent),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(doc.fileType.icon, size: 64, color: _getFileColor(doc.fileType)),
                if (doc.isMissingOriginal)
                  const Icon(Icons.warning, color: AppColors.warning, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              doc.title,
              style: AppTextStyles.labelMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            Text(doc.formattedSize, style: AppTextStyles.bodySmallSecondary.copyWith(fontSize: 10)),
            if (doc.notes.contains('الأصل الورقي')) ...[
              const SizedBox(height: 4),
              _tag(doc.physicalLocation, AppColors.info),
            ],
          ],
        ),
      ),
    );
  }

  // بطاقة عرض طولي للملف (List View Details)
    Widget _buildListFileCard(DocumentItem doc) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      leading: Icon(doc.fileType.icon, size: 36, color: _getFileColor(doc.fileType)),
      title: Text(doc.title, style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المرتبط بـ: ${doc.entityTitle} • الحجم: ${doc.formattedSize} • التاريخ: ${_formatDate(doc.uploadDate)}', style: AppTextStyles.bodySmallSecondary),
          if (doc.notes.contains('الأصل الورقي'))
            Text(_paperSummary(doc), style: AppTextStyles.bodySmallSecondary.copyWith(color: AppColors.info)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (doc.notes.contains('الأصل الورقي')) _tag('أصل ورقي', AppColors.info),
          if (doc.isMissingOriginal) _tag('بانتظار الأصل', AppColors.warning),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.visibility, color: AppColors.primaryNavy),
            onPressed: () => _openDocumentWithPermission(context, ref, doc),
            tooltip: 'عرض الملف',
          ),
        ],
      ),
      onTap: () => _openDocumentWithPermission(context, ref, doc),
    );
  }

  Future<void> _openDocumentWithPermission(BuildContext context, WidgetRef ref, DocumentItem doc) async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.documentsOpen)) {
      await ref.read(auditServiceProvider).log(
        action: 'access_denied',
        category: 'documents',
        entityType: 'document',
        entityId: doc.id,
        entityTitle: doc.title,
        description: 'محاولة فتح مستند دون صلاحية',
        severity: 'warning',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('لا تملك صلاحية فتح المستندات'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    await ref.read(auditServiceProvider).log(
      action: 'open',
      category: 'documents',
      entityType: 'document',
      entityId: doc.id,
      entityTitle: doc.title,
      description: 'فتح مستند',
      severity: 'info',
    );
    if (context.mounted) openDocument(context, doc.id);
  }

  Color _getFileColor(doc_models.FileType type) {
    switch (type) {
      case doc_models.FileType.pdf: return AppColors.error;
      case doc_models.FileType.docx:
      case doc_models.FileType.doc: return Colors.blue;
      case doc_models.FileType.jpg:
      case doc_models.FileType.png: return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  String _paperSummary(DocumentItem doc) {
    final lines = doc.notes.split('\n').where((line) => line.trim().isNotEmpty).toList();
    String pick(String prefix, [String fallback = '']) {
      final line = lines.firstWhere((item) => item.startsWith(prefix), orElse: () => '');
      final value = line.replaceFirst(prefix, '').trim();
      return value.isEmpty ? fallback : value;
    }

    final saved = lines.firstWhere((line) => line.startsWith('الأصل الورقي محفوظ'), orElse: () => 'الأصل الورقي محفوظ: غير محدد');
    final location = [
      pick('مكان الأصل:', doc.physicalLocation),
      if (pick('الصندوق:').isNotEmpty) 'صندوق ${pick('الصندوق:')}',
      if (pick('الرف:').isNotEmpty) 'رف ${pick('الرف:')}',
      if (pick('المجلد الورقي:').isNotEmpty) 'مجلد ${pick('المجلد الورقي:')}',
    ].where((v) => v.trim().isNotEmpty).join(' • ');
    return [saved, location].where((v) => v.trim().isNotEmpty).join(' • ');
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _FolderModel {
  final DocumentType type;
  final IconData icon;
  final Color color;
  const _FolderModel({required this.type, required this.icon, required this.color});
}

// نافذة الرفع بقيت كما هي لضمان عدم كسر أي دوال، سيتم تطويرها لاحقاً لربطها بـ FileStorageService




class UploadDocDialog extends ConsumerStatefulWidget {
  const UploadDocDialog({super.key});
  @override
  ConsumerState<UploadDocDialog> createState() => _UploadDocDialogState();
}

class _UploadDocDialogState extends ConsumerState<UploadDocDialog> {
  final _title = TextEditingController();
  DocumentType _type = DocumentType.caseDocument;
  final _customDocType = TextEditingController();
  fp.PlatformFile? _file;
  bool _saving = false;
  bool _paperOriginalSaved = false;
  bool _canDestroyOriginal = false;
  final _paperLocation = TextEditingController();
  final _box = TextEditingController();
  final _shelf = TextEditingController();
  final _paperFolder = TextEditingController();
  final _reviewedBy = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _customDocType.dispose();
    _paperLocation.dispose();
    _box.dispose();
    _shelf.dispose();
    _paperFolder.dispose();
    _reviewedBy.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await fp.FilePicker.platform.pickFiles();
    if (res != null && res.files.single.path != null) {
      setState(() {
        _file = res.files.single;
        if (_title.text.trim().isEmpty) _title.text = res.files.single.name;
      });
    }
  }

  Future<void> _save() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.documentsUpload)) {
      await ref.read(auditServiceProvider).log(
        action: 'access_denied',
        category: 'documents',
        entityType: 'document',
        description: 'محاولة رفع مستند دون صلاحية',
        severity: 'warning',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا تملك صلاحية رفع المستندات'), backgroundColor: AppColors.error));
      }
      return;
    }
    if (_file?.path == null || _title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('اختر ملفاً وأدخل عنوان المستند'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _saving = true);
    try {
      final effectiveDocType = _customDocType.text.trim().isNotEmpty ? _customDocType.text.trim() : _type.name;
      final paperNotes = [
        if (_customDocType.text.trim().isNotEmpty) 'نوع مستند مخصص: ${_customDocType.text.trim()}',
        'الأصل الورقي محفوظ: ${_paperOriginalSaved ? 'نعم' : 'لا'}',
        if (_paperLocation.text.trim().isNotEmpty) 'مكان الأصل: ${_paperLocation.text.trim()}',
        if (_box.text.trim().isNotEmpty) 'الصندوق: ${_box.text.trim()}',
        if (_shelf.text.trim().isNotEmpty) 'الرف: ${_shelf.text.trim()}',
        if (_paperFolder.text.trim().isNotEmpty) 'المجلد الورقي: ${_paperFolder.text.trim()}',
        'يجوز إتلاف الأصل: ${_canDestroyOriginal ? 'نعم' : 'لا'}',
        if (_reviewedBy.text.trim().isNotEmpty) 'راجع النسخة الرقمية: ${_reviewedBy.text.trim()}',
      ].join('\n');
      final docId = await ref.read(documentRepositoryProvider).addDocument(
            docName: _title.text.trim(),
            docType: effectiveDocType,
            fileType: _file!.extension,
            sourceFile: File(_file!.path!),
            physicalLocation: _paperOriginalSaved ? 0 : 1,
            notes: paperNotes,
            paperOriginalSaved: _paperOriginalSaved,
            paperLocation: _paperLocation.text.trim().isEmpty ? null : _paperLocation.text.trim(),
            paperBox: _box.text.trim().isEmpty ? null : _box.text.trim(),
            paperShelf: _shelf.text.trim().isEmpty ? null : _shelf.text.trim(),
            paperFolder: _paperFolder.text.trim().isEmpty ? null : _paperFolder.text.trim(),
            canDestroyOriginal: _canDestroyOriginal,
            reviewedBy: _reviewedBy.text.trim().isEmpty ? null : _reviewedBy.text.trim(),
            entityType: 99,
            entityId: 0,
            userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
          );
      await ref.read(auditServiceProvider).log(
        action: 'upload',
        category: 'documents',
        entityType: 'document',
        entityId: '$docId',
        entityTitle: _title.text.trim(),
        description: 'رفع مستند إلى الأرشيف العام',
        after: {'docType': effectiveDocType, 'paperOriginalSaved': _paperOriginalSaved, 'paperLocation': _paperLocation.text.trim(), 'box': _box.text.trim(), 'shelf': _shelf.text.trim(), 'paperFolder': _paperFolder.text.trim(), 'canDestroyOriginal': _canDestroyOriginal, 'reviewedBy': _reviewedBy.text.trim()},
        severity: 'info',
      );
      ref.invalidate(documentsFutureProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع المستند: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('رفع مستند'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'عنوان المستند *')),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'نوع المستند'),
              items: DocumentType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 8),
            TextField(controller: _customDocType, decoration: const InputDecoration(labelText: 'نوع مستند آخر / غير موجود بالقائمة')),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.attach_file), label: const Text('اختيار ملف')),
            if (_file != null) Text(_file!.name, style: AppTextStyles.bodySmallSecondary),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _paperOriginalSaved,
              title: const Text('هل الأصل الورقي محفوظ؟'),
              onChanged: (v) => setState(() => _paperOriginalSaved = v ?? false),
            ),
            if (_paperOriginalSaved) ...[
              TextField(controller: _paperLocation, decoration: const InputDecoration(labelText: 'مكان الأصل')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _box, decoration: const InputDecoration(labelText: 'الصندوق'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _shelf, decoration: const InputDecoration(labelText: 'الرف'))),
              ]),
              const SizedBox(height: 8),
              TextField(controller: _paperFolder, decoration: const InputDecoration(labelText: 'المجلد الورقي')),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _canDestroyOriginal,
                title: const Text('هل يجوز إتلاف الأصل لاحقاً؟'),
                onChanged: (v) => setState(() => _canDestroyOriginal = v ?? false),
              ),
            ],
            TextField(controller: _reviewedBy, decoration: const InputDecoration(labelText: 'من راجع النسخة الرقمية؟')),
          ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'جارٍ الرفع...' : 'حفظ')),
      ],
    );
  }
}
