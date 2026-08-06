import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/services/data_reset_service.dart';
import '../../../data/services/storage_location_service.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';

/// إدارة مكان تخزين بيانات المكتب وتصفيرها.
///
/// المسار يُقرأ عند الإقلاع قبل فتح قاعدة البيانات، لذا أي تغيير
/// يستوجب إعادة تشغيل التطبيق ليأخذ مفعوله.
class StorageSettingsCard extends ConsumerStatefulWidget {
  const StorageSettingsCard({super.key});

  @override
  ConsumerState<StorageSettingsCard> createState() =>
      _StorageSettingsCardState();
}

class _StorageSettingsCardState extends ConsumerState<StorageSettingsCard> {
  bool _busy = false;
  int? _sizeBytes;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final size =
        await StorageLocationService.folderSize(StorageLocationService.activeRoot);
    if (mounted) setState(() => _sizeBytes = size);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final root = StorageLocationService.activeRoot;

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_special, color: AppColors.primaryNavy),
                const SizedBox(width: 10),
                Text('مكان حفظ بيانات المكتب',
                    style: AppTextStyles.cardTitle),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBorder.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(root, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 6),
                  Text(
                    [
                      StorageLocationService.isCustomPath
                          ? 'مسار مخصَّص'
                          : 'المسار الافتراضي',
                      if (_sizeBytes != null)
                        'الحجم: ${StorageLocationService.formatSize(_sizeBytes!)}',
                    ].join('  •  '),
                    style: AppTextStyles.bodySmallSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Text(
              'يشمل قاعدة البيانات (${AppConstants.defaultDatabaseName}) '
              'والمرفقات المشفّرة والنسخ الاحتياطية.',
              style: AppTextStyles.bodySmallSecondary,
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _openFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('فتح المجلد'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _changeLocation,
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: const Text('تغيير المكان'),
                ),
                if (StorageLocationService.isCustomPath)
                  TextButton.icon(
                    onPressed: _busy ? null : _resetLocation,
                    icon: const Icon(Icons.restore),
                    label: const Text('العودة للافتراضي'),
                  ),
              ],
            ),

            const Divider(height: 32),

            Row(
              children: [
                const Icon(Icons.delete_forever, color: AppColors.error),
                const SizedBox(width: 10),
                Text('تصفير البيانات', style: AppTextStyles.cardTitle),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'يحذف كل الدعاوى والشركات والعقود والوكالات والأشخاص '
              'والمرفقات، ويعيد ترقيم الملفات إلى الصفر. '
              'لا يمكن التراجع.',
              style: AppTextStyles.bodySmallSecondary,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: _busy ? null : _confirmReset,
              icon: const Icon(Icons.delete_forever),
              label: const Text('حذف كل البيانات وتصفير العدادات'),
            ),

            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openFolder() async {
    final root = StorageLocationService.activeRoot;
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [root]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [root]);
      } else {
        await Process.run('xdg-open', [root]);
      }
    } catch (e) {
      _snack('تعذّر فتح المجلد: $e', error: true);
    }
  }

  Future<void> _changeLocation() async {
    final picked = await FilePicker.getDirectoryPath(
      dialogTitle: 'اختر مجلد حفظ بيانات المكتب',
    );
    if (picked == null) return;

    setState(() => _busy = true);
    final error = await StorageLocationService.validate(picked);
    if (error != null) {
      setState(() => _busy = false);
      _snack(error, error: true);
      return;
    }

    final oldRoot = StorageLocationService.activeRoot;
    final size = await StorageLocationService.folderSize(oldRoot);
    if (!mounted) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير مكان البيانات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('من: $oldRoot', style: AppTextStyles.bodySmall),
            const SizedBox(height: 6),
            Text('إلى: $picked', style: AppTextStyles.bodySmall),
            const SizedBox(height: 14),
            Text(
              'حجم البيانات الحالية: '
              '${StorageLocationService.formatSize(size)}',
              style: AppTextStyles.bodySmallSecondary,
            ),
            const SizedBox(height: 14),
            const Text(
              'النقل ينسخ البيانات أولاً ثم يتحقق منها قبل حذف الأصل، '
              'فلا تضيع البيانات إن انقطعت العملية.\n\n'
              'سيلزم إعادة تشغيل التطبيق بعد التغيير.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'switch'),
            child: const Text('تغيير دون نقل'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'migrate'),
            child: const Text('نقل البيانات'),
          ),
        ],
      ),
    );

    if (choice == null) {
      setState(() => _busy = false);
      return;
    }

    try {
      if (choice == 'migrate') {
        final warnings = await DataResetService.migrateData(
          fromRoot: oldRoot,
          toRoot: picked,
          // لا يُحذف المصدر تلقائياً: بقاء نسخة احتياطية حتى يتأكد
          // المستخدم من سلامة النقل أأمن من حذف فوري لا رجعة فيه.
          deleteSource: false,
        );
        if (warnings.isNotEmpty) {
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('اكتمل النقل مع ملاحظات'),
              content: SingleChildScrollView(
                child: Text(warnings.join('\n\n')),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        }
      }

      await StorageLocationService.persist(picked);
      if (!mounted) return;
      setState(() => _busy = false);
      await _showRestartDialog(
        choice == 'migrate'
            ? 'نُقلت البيانات إلى المسار الجديد. المجلد القديم لم يُحذف '
                'ويمكنك حذفه يدوياً بعد التأكد.'
            : 'حُدِّد المسار الجديد. البيانات القديمة بقيت في مكانها.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('تعذّر تغيير المسار: $e', error: true);
    }
  }

  Future<void> _resetLocation() async {
    setState(() => _busy = true);
    try {
      await StorageLocationService.resetToDefault();
      if (!mounted) return;
      setState(() => _busy = false);
      await _showRestartDialog('أُعيد المسار إلى الافتراضي.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('تعذّر: $e', error: true);
    }
  }

  Future<void> _showRestartDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('يلزم إعادة التشغيل'),
        content: Text('$message\n\n'
            'أغلق التطبيق وافتحه ليعمل على المسار الجديد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    // تأكيد بكتابة كلمة: الضغط المتتابع على "موافق" لا يكفي لعملية
    // تمحو كل بيانات المكتب دون رجعة.
    final controller = TextEditingController();
    const phrase = 'حذف';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('حذف كل البيانات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'سيُحذف نهائياً:\n'
                '• كل الدعاوى والجلسات والمراحل\n'
                '• الشركات والعقود والوكالات والمعاملات\n'
                '• الأشخاص والموكلون والخصوم\n'
                '• كل المرفقات والمستندات\n'
                '• السجلات المالية وسجل النشاط\n\n'
                'وتُصفَّر عدادات ترقيم الملفات لتبدأ من 1.\n'
                'النسخ الاحتياطية تبقى.',
              ),
              const SizedBox(height: 16),
              Text('اكتب «$phrase» للتأكيد:',
                  style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setLocal(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: controller.text.trim() == phrase
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('حذف نهائي'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final report =
          await DataResetService(ref.read(databaseProvider)).resetAll();

      // إبطال كل المزودات ليختفي المحذوف من الشاشات فوراً.
      ref.invalidate(allCasesProvider);
      ref.invalidate(allPersonsProvider); // family: يبطل كل الصيغ
      ref.invalidate(allCompaniesProvider);
      ref.invalidate(allPoasProvider);
      ref.invalidate(activeCourtsProvider);

      await _loadSize();
      if (!mounted) return;
      setState(() => _busy = false);

      if (report.warnings.isEmpty) {
        _snack('تم التصفير: ${report.summary}');
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('اكتمل التصفير مع ملاحظات'),
            content: SingleChildScrollView(
              child: Text(
                '${report.summary}\n\n${report.warnings.join('\n')}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('تعذّر التصفير: $e', error: true);
    }
  }
}
