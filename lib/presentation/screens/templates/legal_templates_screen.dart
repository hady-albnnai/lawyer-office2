import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';

/// مكتبة النماذج القانونية العامة.
///
/// ملاحظة تنفيذية: تستخدم حالياً جدول ContractTemplates القائم كطبقة تخزين
/// مرحلية آمنة دون تعديل قاعدة البيانات. سيتم نقلها لاحقاً إلى جداول
/// نماذج قانونية عامة عند تنفيذ مرحلة النماذج الكاملة.
class LegalTemplatesScreen extends ConsumerStatefulWidget {
  /// التصنيف الابتدائي (من السايدبار: ?category=عقد, لائحة دعوى, etc.)
  final String? initialCategory;
  const LegalTemplatesScreen({super.key, this.initialCategory});

  @override
  ConsumerState<LegalTemplatesScreen> createState() => _LegalTemplatesScreenState();
}

class _LegalTemplatesScreenState extends ConsumerState<LegalTemplatesScreen> {
  String _selectedCategory = 'الكل';
  String _query = '';

  static const _categories = [
    'الكل',
    'لائحة دعوى',
    'مذكرة',
    'طلب إداري',
    'عقد',
    'وكالة',
    'إنذار',
    'إيصال',
    'كتاب رسمي',
    'نموذج شركة',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      // مطابقة النص مع التصنيفات المتاحة
      final match = _categories.where((c) => c == widget.initialCategory).firstOrNull;
      if (match != null) _selectedCategory = match;
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionServiceProvider);
    final stream = ref.watch(databaseProvider).select(ref.watch(databaseProvider).contractTemplates).watch();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('النماذج القانونية'),
          actions: [
            if (permissions.can(PermissionKeys.templatesImport))
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryGold,
                  foregroundColor: AppColors.primaryNavy,
                ),
                icon: const Icon(Icons.upload_file),
                label: const Text('استيراد نموذج'),
                onPressed: _openImportDialog,
              ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            _toolbar(),
            Expanded(
              child: StreamBuilder<List<ContractTemplate>>(
                stream: stream,
                builder: (context, snapshot) {
                  final list = (snapshot.data ?? []).where((t) {
                    final categoryOk = _selectedCategory == 'الكل' || t.contractType == _selectedCategory;
                    final q = _query.trim().toLowerCase();
                    final queryOk = q.isEmpty ||
                        t.templateName.toLowerCase().contains(q) ||
                        t.contractType.toLowerCase().contains(q) ||
                        t.filePath.toLowerCase().contains(q);
                    return categoryOk && queryOk;
                  }).toList();

                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined, size: 72, color: AppColors.textSecondary),
                          const SizedBox(height: 16),
                          Text('لا توجد نماذج قانونية ضمن الفلتر الحالي', style: AppTextStyles.headline6),
                          const SizedBox(height: 8),
                          Text('استورد ملفات Word أو RTF أو TXT لاستخدامها لاحقاً في إنشاء المستندات.', style: AppTextStyles.bodySmallSecondary),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.55,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) => _templateCard(list[index], permissions),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
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
              decoration: const InputDecoration(
                labelText: 'بحث في النماذج',
                hintText: 'اسم النموذج، النوع، أو اسم الملف...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _selectedCategory,
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v ?? 'الكل'),
          ),
        ],
      ),
    );
  }

  Widget _templateCard(ContractTemplate template, dynamic permissions) {
    return GlassmorphicCard(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryNavy,
                  child: Icon(Icons.article, color: AppColors.secondaryGold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    template.templateName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _line(Icons.category, 'النوع: ${template.contractType}'),
            _line(Icons.source, 'المصدر: ${_templateSourceLabel(template.templateSource)}'),
            _line(Icons.insert_drive_file, 'الملف: ${template.filePath.split('/').last.split('\\').last}'),
            const Spacer(),
            Wrap(
              spacing: 8,
              children: [
                if (template.isDefault) _chip('افتراضي', AppColors.secondaryGold),
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('معاينة'),
                  onPressed: () => _showTemplatePath(template),
                ),
                if (permissions.can(PermissionKeys.templatesGenerateDocument))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.description),
                    label: const Text('استخدام'),
                    onPressed: () => _useTemplate(template),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTextStyles.bodySmallSecondary, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  void _showTemplatePath(ContractTemplate template) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(template.templateName),
        content: SelectableText(template.filePath),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  /// تسمية مصدر النموذج للعرض.
  String _templateSourceLabel(String source) {
    switch (source) {
      case 'imported':
        return 'مستورد من المستخدم';
      case 'generated':
        return 'مولّد من ملف';
      default:
        return 'جاهز';
    }
  }

  /// إنشاء نسخة عمل من النموذج وفتحها للتحرير في Word.
  ///
  /// النموذج الأصلي لا يُمس: تُنسخ نسخة مستقلة باسم مؤرخ داخل مجلد
  /// المستندات، ثم تُفتح بالبرنامج الافتراضي.
  Future<void> _useTemplate(ContractTemplate template) async {
    final storage = ref.read(fileStorageServiceProvider);
    try {
      final sourcePath = await storage.getAbsolutePath(template.filePath);
      final source = File(sourcePath);
      if (!await source.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ملف النموذج غير موجود على القرص.'), backgroundColor: AppColors.error),
        );
        return;
      }

      final stamp = DateTime.now();
      final safeName = template.templateName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final extension = template.filePath.contains('.') ? template.filePath.split('.').last : 'docx';
      final targetName =
          '${safeName}_${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}_${stamp.millisecondsSinceEpoch}.$extension';
      final targetPath = await storage.getAbsolutePath('${AppConstants.templatesFolder}/generated/$targetName');
      final target = File(targetPath);
      await target.parent.create(recursive: true);
      await source.copy(targetPath);

      await ref.read(auditServiceProvider).log(
            action: 'generate',
            category: 'templates',
            entityType: 'contract_template',
            entityId: '${template.id}',
            entityTitle: template.templateName,
            description: 'إنشاء نسخة عمل من نموذج وفتحها للتحرير',
            severity: 'info',
          );

      await OpenFilex.open(targetPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء نسخة عمل: $targetName'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء نسخة من النموذج: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _openImportDialog() {
    String category = 'عقد';
    final nameController = TextEditingController();
    File? selectedFile;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('استيراد نموذج قانوني'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'نوع النموذج'),
                  items: _categories.where((c) => c != 'الكل').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم النموذج *')),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.secondaryGold), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(child: Text(selectedFile == null ? 'لم يتم اختيار ملف' : selectedFile!.path.split(Platform.pathSeparator).last)),
                      ElevatedButton(
                        child: const Text('اختيار'),
                        onPressed: () async {
                          final res = await fp.FilePicker.pickFiles(type: fp.FileType.custom, allowedExtensions: ['docx', 'doc', 'rtf', 'txt', 'pdf']);
                          if (res != null && res.files.single.path != null) {
                            setDialogState(() => selectedFile = File(res.files.single.path!));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              child: const Text('حفظ النموذج'),
              onPressed: () async {
                if (selectedFile == null || nameController.text.trim().isEmpty) return;
                final storage = ref.read(fileStorageServiceProvider);
                final storedPath = await storage.saveTemplate(selectedFile!, nameController.text.trim());
                final db = ref.read(databaseProvider);
                final id = await db.into(db.contractTemplates).insert(
                      ContractTemplatesCompanion.insert(
                        contractType: category,
                        templateName: nameController.text.trim(),
                        filePath: storedPath,
                        isDefault: const drift.Value(false),
                        // مصدر النموذج (المرحلة الثالثة عشرة من خارطة التنفيذ).
                        templateSource: const drift.Value('imported'),
                      ),
                    );
                await ref.read(auditServiceProvider).log(
                      action: 'import',
                      category: 'templates',
                      entityType: 'legal_template',
                      entityId: '$id',
                      entityTitle: nameController.text.trim(),
                      description: 'استيراد نموذج قانوني',
                      after: {'category': category, 'filePath': storedPath},
                      severity: 'info',
                    );
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
