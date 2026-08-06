import '../../theme/glassmorphism_helpers.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';

/// شاشة إدارة نماذج وقوالب Word الجاهزة للعقود (TemplatesManagementScreen)
class TemplatesManagementScreen extends ConsumerStatefulWidget {
  const TemplatesManagementScreen({super.key});

  @override
  ConsumerState<TemplatesManagementScreen> createState() => _TemplatesManagementScreenState();
}

class _TemplatesManagementScreenState extends ConsumerState<TemplatesManagementScreen> {
  String _selectedCategory = 'الكل';
  final List<String> _categories = ['الكل', 'عقد بيع عقاري', 'عقد إيجار سكني / تجاري', 'عقد عمل وخدمات مهنية', 'عقد شراكة تجارية'];

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(contractRepositoryProvider).watchContractTemplates(type: _selectedCategory == 'الكل' ? null : _selectedCategory);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة قوالب ونماذج Word للعقود (Templates Library)'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentGold, foregroundColor: AppConstants.primaryNavy),
            icon: const Icon(Icons.upload_file),
            label: const Text('رفع قالب Word جديد'),
            onPressed: _openUploadDialog,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppConstants.surfaceWhite,
            child: Row(
              children: [
                const Text('فلترة حسب تصنيف العقد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedCategory,
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ContractTemplate>>(
              stream: stream,
              builder: (context, snapshot) {
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_books_outlined, size: 64, color: AppConstants.textMuted),
                        SizedBox(height: 16),
                        Text('مكتبة القوالب فارغة حالياً. يمكنك رفع ملفات .docx الجاهزة من جهازك.', style: TextStyle(fontSize: 16, color: AppConstants.textMuted)),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final t = list[index];
                    return GlassmorphicCard(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppConstants.primaryNavy.withOpacity(0.2))),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(backgroundColor: AppConstants.primaryNavy, child: Icon(Icons.description, color: AppConstants.accentGold)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(t.templateName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.primaryNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Text('التصنيف: ${t.contractType}', style: const TextStyle(color: AppConstants.textMuted)),
                            const SizedBox(height: 4),
                            Text('مسار الملف: ${t.filePath.split("/").last}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                            const Spacer(),
                            Row(
                              children: [
                                if (t.isDefault)
                                  const Chip(label: Text('افتراضي ⭐'), backgroundColor: AppConstants.accentGold)
                                else
                                  TextButton(
                                    onPressed: () => _setDefault(t),
                                    child: const Text('تعيين كافتراضي'),
                                  ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: AppConstants.statusDanger),
                                  tooltip: 'حذف القالب',
                                  onPressed: () => _deleteTemplate(t),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openUploadDialog() {
    String type = 'عقد بيع عقاري';
    final nameController = TextEditingController();
    File? docxFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('رفع قالب Word جديد للمكتب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'تصنيف العقد'),
                items: _categories.where((c) => c != 'الكل').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setDialogState(() => type = val!),
              ),
              const SizedBox(height: 12),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم القالب (مثال: نموذج بيع محل تجاري)')),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: AppConstants.accentGold), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(child: Text(docxFile == null ? 'لم يتم اختيار ملف .docx' : docxFile!.path.split("/").last.split("\\").last)),
                    ElevatedButton(
                      child: const Text('اختيار'),
                      onPressed: () async {
                        final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['docx', 'doc', 'rtf']);
                        if (res != null && res.files.single.path != null) {
                          setDialogState(() => docxFile = File(res.files.single.path!));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              child: const Text('حفظ في المكتبة'),
              onPressed: () async {
                if (docxFile == null || nameController.text.trim().isEmpty) return;
                final storage = ref.read(fileStorageServiceProvider);
                final path = await storage.saveTemplate(docxFile!, nameController.text.trim());

                await ref.read(contractRepositoryProvider).createContract(
                  contract: ContractsCompanion.insert(
                    internalNumber: 'TEMPLATE-${DateTime.now().microsecondsSinceEpoch}',
                    title: 'قالب مرجعي: ${nameController.text.trim()}',
                    contractType: type,
                    status: const drift.Value('template_only'),
                  ),
                  parties: [],
                  userRef: AppConstants.defaultLawyerName,
                );

                await ref.read(databaseProvider).into(ref.read(databaseProvider).contractTemplates).insert(
                  ContractTemplatesCompanion.insert(
                    contractType: type,
                    templateName: nameController.text.trim(),
                    filePath: path,
                    isDefault: const drift.Value(false),
                  ),
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ القالب بنجاح!'), backgroundColor: AppConstants.statusSuccess));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// تعيين قالب كافتراضي لنوعه.
  ///
  /// كان الزر يحمل جسماً فارغاً بتعليق فقط، فلا يتغيّر شيء عند الضغط.
  Future<void> _setDefault(ContractTemplate t) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(databaseProvider).contractDao.setDefaultTemplate(t.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم تعيين «${t.templateName}» افتراضياً لعقود ${t.contractType}'),
          backgroundColor: AppConstants.statusSuccess,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تعذّر التعيين: $e'),
          backgroundColor: AppConstants.statusDanger,
        ),
      );
    }
  }

  /// حذف قالب بعد تأكيد صريح.
  Future<void> _deleteTemplate(ContractTemplate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القالب'),
        content: Text(
          'سيُحذف «${t.templateName}» من قائمة القوالب.\n'
          'لن يتأثر أي عقد أُنشئ منه سابقاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.statusDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final removed = await ref
          .read(databaseProvider)
          .contractDao
          .deleteContractTemplate(t.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(removed > 0
              ? 'تم حذف «${t.templateName}»'
              : 'لم يُعثر على القالب'),
          backgroundColor: removed > 0
              ? AppConstants.statusSuccess
              : AppConstants.statusWarning,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر الحذف: $e'),
          backgroundColor: AppConstants.statusDanger,
        ),
      );
    }
  }

}
