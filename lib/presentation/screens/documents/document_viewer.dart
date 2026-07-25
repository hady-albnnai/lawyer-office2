/// نظام فتح وعرض المرفقات
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'document_models.dart';

class DocumentViewerScreen extends ConsumerWidget {
  final String documentId;
  const DocumentViewerScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsFutureProvider);
    return docsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('تحميل المستند')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('تعذر تحميل المستند')),
        body: Center(child: Text('تعذر تحميل بيانات المستند: $error')),
      ),
      data: (docs) {
        final doc = _getDoc(docs, documentId);
        if (doc == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('غير موجود')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('المستند غير موجود', style: AppTextStyles.headline4),
                  const SizedBox(height: 8),
                  Text('الرقم: $documentId', style: AppTextStyles.bodyMediumSecondary),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => context.pop(), child: const Text('العودة')),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(doc.title),
        actions: [
          if (doc.filePath.isNotEmpty)
            IconButton(icon: const Icon(Icons.download), onPressed: () => _showMsg(context, 'تم تنزيل ${doc.fileName}'), tooltip: 'تنزيل'),
          if (doc.filePath.isNotEmpty)
            IconButton(icon: const Icon(Icons.share), onPressed: () => _showMsg(context, 'تم مشاركة ${doc.fileName}'), tooltip: 'مشاركة'),
        ],
          ),
          body: Column(
            children: [
              _buildInfo(context, ref, doc),
              Expanded(child: _buildViewer(doc, context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfo(BuildContext context, WidgetRef ref, DocumentItem d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, border: Border.all(color: AppColors.cardBorder, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(d.fileType.icon, color: AppColors.primaryNavy, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(d.fileName, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold))),
              Text(d.formattedSize, style: AppTextStyles.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _info(Icons.folder, 'النوع: ${d.documentType.displayName}'),
              _info(Icons.link, 'مرتبط: ${d.entityTitle}'),
              _info(Icons.calendar_today, 'تاريخ: ${_formatDate(d.uploadDate)}'),
              _info(Icons.person, 'مرفوع: ${d.uploadedBy}'),
              _info(Icons.location_on, 'الموقع: ${d.physicalLocation}'),
              if (_linkedEntityRoute(d) != null)
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('فتح الملف المرتبط'),
                  onPressed: () => context.go(_linkedEntityRoute(d)!),
                ),
            ],
          ),
          if (d.notes.contains('الأصل الورقي')) ...[
            const SizedBox(height: 10),
            _paperArchiveBox(context, ref, d),
          ],
          if (d.notes.contains('بيانات صف CSV:')) ...[
            const SizedBox(height: 10),
            _csvDataBox(d.notes),
          ] else if (d.notes.isNotEmpty && !d.notes.contains('الأصل الورقي')) ...[
            const SizedBox(height: 8),
            Text('ملاحظات: ${d.notes}', style: AppTextStyles.bodySmallSecondary),
          ],
        ],
      ),
    );
  }

  Widget _paperArchiveBox(BuildContext context, WidgetRef ref, DocumentItem doc) {
    final lines = doc.notes.split('\n').where((line) => line.trim().isNotEmpty).toList();
    String pick(String prefix) {
      final line = lines.firstWhere((item) => item.startsWith(prefix), orElse: () => '');
      return line.replaceFirst(prefix, '').trim();
    }

    final locationParts = [
      pick('مكان الأصل:'),
      if (pick('الصندوق:').isNotEmpty) 'صندوق ${pick('الصندوق:')}',
      if (pick('الرف:').isNotEmpty) 'رف ${pick('الرف:')}',
      if (pick('المجلد الورقي:').isNotEmpty) 'مجلد ${pick('المجلد الورقي:')}',
    ].where((value) => value.isNotEmpty).toList();
    final extraLines = lines.where((line) =>
        !line.startsWith('مكان الأصل:') &&
        !line.startsWith('الصندوق:') &&
        !line.startsWith('الرف:') &&
        !line.startsWith('المجلد الورقي:'));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('بيانات الأصل الورقي', style: AppTextStyles.labelLarge.copyWith(color: AppColors.info, fontWeight: FontWeight.bold))),
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('تعديل'),
                onPressed: () => _editDocumentPaperMetadata(context, ref, doc),
              ),
              if (pick('راجع النسخة الرقمية:').isEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.fact_check, size: 16),
                  label: const Text('تعليم كمراجع'),
                  onPressed: () => _markDocumentPaperReviewed(context, ref, doc),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (locationParts.isNotEmpty)
            Text('الموقع الكامل: ${locationParts.join(' • ')}', style: AppTextStyles.bodySmallSecondary.copyWith(fontWeight: FontWeight.bold)),
          if (locationParts.isNotEmpty) const SizedBox(height: 6),
          ...extraLines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(line, style: AppTextStyles.bodySmallSecondary),
              )),
        ],
      ),
    );
  }

  Widget _csvDataBox(String notes) {
    final start = notes.indexOf('بيانات صف CSV:');
    if (start == -1) return const SizedBox.shrink();
    final lines = notes.substring(start).split('\n').skip(1).where((line) => line.trim().isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryNavy.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('بيانات صف CSV', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...lines.map((line) {
            final split = line.indexOf(':');
            final key = split == -1 ? '' : line.substring(0, split).trim();
            final value = split == -1 ? line : line.substring(split + 1).trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (key.isNotEmpty) SizedBox(width: 170, child: Text(key, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary))),
                  Expanded(child: SelectableText(value.isEmpty ? '—' : value, style: AppTextStyles.bodySmall)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _pickNoteValue(String notes, String prefix) {
    for (final line in notes.split('\n')) {
      if (line.trim().startsWith(prefix)) {
        return line.replaceFirst(prefix, '').trim();
      }
    }
    return '';
  }

  Future<void> _editDocumentPaperMetadata(BuildContext context, WidgetRef ref, DocumentItem doc) async {
    final id = int.tryParse(doc.id);
    if (id == null) return;
    bool paperSaved = (_pickNoteValue(doc.notes, 'الأصل الورقي محفوظ:')).contains('نعم');
    bool canDestroy = (_pickNoteValue(doc.notes, 'يجوز إتلاف الأصل:')).contains('نعم');
    final location = TextEditingController(text: _pickNoteValue(doc.notes, 'مكان الأصل:'));
    final box = TextEditingController(text: _pickNoteValue(doc.notes, 'الصندوق:'));
    final shelf = TextEditingController(text: _pickNoteValue(doc.notes, 'الرف:'));
    final folder = TextEditingController(text: _pickNoteValue(doc.notes, 'المجلد الورقي:'));
    final reviewedBy = TextEditingController(text: _pickNoteValue(doc.notes, 'راجع النسخة الرقمية:'));
    final paperNotes = TextEditingController();

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
              title: Text('تعديل بيانات الأصل الورقي — ${doc.title}'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: paperSaved,
                        title: const Text('الأصل الورقي محفوظ'),
                        onChanged: (v) => setDialog(() => paperSaved = v ?? false),
                      ),
                      TextField(controller: location, decoration: const InputDecoration(labelText: 'مكان الأصل')),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: box, decoration: const InputDecoration(labelText: 'الصندوق'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: shelf, decoration: const InputDecoration(labelText: 'الرف'))),
                      ]),
                      const SizedBox(height: 8),
                      TextField(controller: folder, decoration: const InputDecoration(labelText: 'المجلد الورقي')),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canDestroy,
                        title: const Text('يجوز إتلاف الأصل لاحقاً'),
                        onChanged: (v) => setDialog(() => canDestroy = v ?? false),
                      ),
                      TextField(controller: reviewedBy, decoration: const InputDecoration(labelText: 'من راجع النسخة الرقمية؟')),
                      const SizedBox(height: 8),
                      TextField(controller: paperNotes, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات إضافية للأصل الورقي')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok) return;
    final db = ref.read(databaseProvider);
    await db.ensureArchiveTables();
    await db.customStatement('''
      INSERT OR REPLACE INTO document_paper_metadata(
        document_id, paper_original_saved, paper_location, box, shelf, paper_folder,
        can_destroy_original, reviewed_by, reviewed_at, notes, updated_at
      ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, CURRENT_TIMESTAMP)
    ''', [
      id,
      paperSaved ? 1 : 0,
      location.text.trim().isEmpty ? null : location.text.trim(),
      box.text.trim().isEmpty ? null : box.text.trim(),
      shelf.text.trim().isEmpty ? null : shelf.text.trim(),
      folder.text.trim().isEmpty ? null : folder.text.trim(),
      canDestroy ? 1 : 0,
      reviewedBy.text.trim().isEmpty ? null : reviewedBy.text.trim(),
      paperNotes.text.trim().isEmpty ? doc.notes : paperNotes.text.trim(),
    ]);
    await ref.read(auditServiceProvider).log(action: 'edit', category: 'archive', entityType: 'paper_archive', entityId: doc.id, entityTitle: doc.title, description: 'تعديل بيانات الأصل الورقي من عارض المستند', after: {'paperSaved': paperSaved, 'location': location.text.trim(), 'box': box.text.trim(), 'shelf': shelf.text.trim(), 'folder': folder.text.trim(), 'canDestroy': canDestroy, 'reviewedBy': reviewedBy.text.trim()}, severity: 'info');
    ref.invalidate(documentsFutureProvider);
    ref.invalidate(uiDocumentsProvider);
    ref.invalidate(uiFilesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تم تحديث بيانات الأصل الورقي'), backgroundColor: AppColors.success));
    }
  }

  Future<void> _markDocumentPaperReviewed(BuildContext context, WidgetRef ref, DocumentItem doc) async {
    final id = int.tryParse(doc.id);
    if (id == null) return;
    final user = ref.read(authControllerProvider).user?.fullName ?? 'المكتب';
    final db = ref.read(databaseProvider);
    await db.ensureArchiveTables();
    await db.customStatement('''
      UPDATE document_paper_metadata
      SET reviewed_by = ?, reviewed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE document_id = ?
    ''', [user, id]);
    await ref.read(auditServiceProvider).log(action: 'review', category: 'archive', entityType: 'paper_archive', entityId: doc.id, entityTitle: doc.title, description: 'تعليم الأصل الورقي كمراجع رقمياً من عارض المستند', after: {'reviewedBy': user}, severity: 'info');
    ref.invalidate(documentsFutureProvider);
    ref.invalidate(uiDocumentsProvider);
    ref.invalidate(uiFilesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعليم الأصل كمراجع بواسطة $user'), backgroundColor: AppColors.success));
    }
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmallSecondary),
      ],
    );
  }

  Widget _buildViewer(DocumentItem d, BuildContext c) {
    if (d.filePath.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.table_chart, size: 64, color: AppColors.primaryNavy),
              const SizedBox(height: 16),
              Text('بيانات أرشيفية بلا ملف مرفق', style: AppTextStyles.headline5),
              const SizedBox(height: 8),
              Text(
                'هذا السجل يمثل بيانات مستوردة أو معلومة أرشيفية مرتبطة بالملف، وليس ملف PDF أو صورة محفوظة على القرص.',
                style: AppTextStyles.bodyMediumSecondary,
                textAlign: TextAlign.center,
              ),
              if (d.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: 720,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
                  child: SelectableText(d.notes, style: AppTextStyles.bodySmallSecondary),
                ),
              ],
            ],
          ),
        ),
      );
    }
    IconData icon;
    String title;
    String subtitle;
    switch (d.fileType) {
      case FileType.pdf:
        icon = Icons.picture_as_pdf;
        title = 'ملف PDF';
        subtitle = 'فتح في معاين PDF';
        break;
      case FileType.docx:
      case FileType.doc:
        icon = Icons.description;
        title = 'ملف Word';
        subtitle = 'فتح في Word';
        break;
      case FileType.jpg:
      case FileType.png:
        icon = Icons.image;
        title = 'صورة';
        subtitle = 'فتح الصورة';
        break;
      case FileType.txt:
      case FileType.rtf:
        icon = Icons.text_snippet;
        title = 'ملف نصي';
        subtitle = 'فتح الملف';
        break;
      default:
        icon = Icons.insert_drive_file;
        title = 'ملف';
        subtitle = 'فتح الملف الخارجي';
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.primaryNavy),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.headline5),
          const SizedBox(height: 8),
          Text(d.fileName, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: () => _showMsg(c, 'تم فتح ${d.fileName}'), icon: const Icon(Icons.open_in_new), label: Text(subtitle)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => _showMsg(c, 'تم تنزيل ${d.fileName}'), icon: const Icon(Icons.download), label: const Text('تنزيل')),
        ],
      ),
    );
  }

  void _showMsg(BuildContext c, String msg) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));

  String? _linkedEntityRoute(DocumentItem doc) {
    if (doc.entityId == '0') return null;
    switch (doc.entityType) {
      case 'case':
        return '/cases/${doc.entityId}';
      case 'contract':
        return '/contracts/${doc.entityId}';
      case 'company':
        return '/companies/${doc.entityId}';
      case 'adminProcedure':
        return '/procedures/${doc.entityId}';
      case 'poa':
        return '/poa/${doc.entityId}';
      case 'person':
        return '/persons/${doc.entityId}';
      default:
        return null;
    }
  }

  DocumentItem? _getDoc(List<DocumentItem> docs, String id) {
    for (final doc in docs) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

void openDocument(BuildContext context, String documentId) => GoRouter.of(context).push('/documents/$documentId');
