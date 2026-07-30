/// شاشة قائمة الدعاوى.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../documents/document_models.dart';
import '../documents/document_viewer.dart';
import 'case_models.dart';
import '../../providers/ui_data_providers.dart';

class CasesScreen extends ConsumerWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    final canCreate = permissions.can(PermissionKeys.casesCreateNew);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الدعاوى'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.go('/search-reports'),
              tooltip: 'بحث',
            ),
            Consumer(
              builder: (context, ref, _) {
                final filter = ref.watch(casesFilterProvider);
                return IconButton(
                  icon: Badge(
                    isLabelVisible: filter.activeCount > 0,
                    label: Text('${filter.activeCount}'),
                    child: const Icon(Icons.filter_alt),
                  ),
                  tooltip: filter.isEmpty
                      ? 'فلترة'
                      : 'فلترة (${filter.activeCount} مطبّق)',
                  onPressed: () async {
                    final result = await showDialog<CasesFilter>(
                      context: context,
                      builder: (_) => CasesFilterDialog(initial: filter),
                    );
                    if (result == null) return; // إلغاء
                    ref.read(casesFilterProvider.notifier).state = result;
                  },
                );
              },
            ),
            if (canCreate)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.go('/cases/create'),
                tooltip: 'دعوى جديدة',
              ),
          ],
        ),
        body: Column(
          children: [
            _buildQuickFilterBar(context, ref),
            Expanded(child: _buildCaseList(context, ref)),
          ],
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => context.go('/cases/create'),
                tooltip: 'دعوى جديدة',
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _buildQuickFilterBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip(ref, 'الكل', null),
            _buildChip(ref, 'عاملة', CaseStatus.scheduled),
            _buildChip(ref, 'ناقصة', null, deficient: true),
            _buildChip(ref, 'متأخرة', null, overdue: true),
            _buildChip(ref, 'منتهية', CaseStatus.completed),
            _buildChip(ref, 'بانتظار رقم أساس', null, pendingBase: true),
            _buildChip(ref, 'جلسة قريب', null, nearSession: true),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    WidgetRef ref,
    String label,
    CaseStatus? status, {
    bool deficient = false,
    bool overdue = false,
    bool pendingBase = false,
    bool nearSession = false,
  }) {
    // العدّ على القائمة الكاملة لا المفلترة: عدّ المفلترة يجعل الأرقام
    // تتغيّر مع كل فلتر فيصعب معرفة الحجم الحقيقي لكل تصنيف.
    final caseItems = ref.watch(allCasesUnfilteredProvider);
    int count;
    if (status != null) {
      count = caseItems.where((item) => item.status == status).length;
    } else if (deficient) {
      count = caseItems.where((item) => item.openDeficienciesCount > 0).length;
    } else if (overdue) {
      count = caseItems
          .where((item) => item.nextSession?.sessionDate.isBefore(DateTime.now()) ?? false)
          .length;
    } else if (pendingBase) {
      count = caseItems.where((item) => item.baseNumber == null || item.baseNumber!.isEmpty).length;
    } else if (nearSession) {
      count = caseItems.where((item) => item.nextSession != null).length;
    } else {
      count = caseItems.length;
    }

    // هل هذه الشريحة هي الفلتر المطبّق حالياً؟
    final current = ref.watch(casesFilterProvider);
    final isSelected = status != null
        ? current.status == status
        : deficient
            ? current.deficient
            : pendingBase
                ? current.pendingBase
                : nearSession
                    ? current.nearSession
                    : overdue
                        ? current.overdue
                        : false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text('$label${count > 0 ? ' ($count)' : ''}'),
        selected: isSelected,
        // كانت onSelected فارغة: الشريحة تعرض عدداً صحيحاً لكن الضغط
        // عليها لا يفلتر شيئاً.
        onSelected: (_) {
          final notifier = ref.read(casesFilterProvider.notifier);
          if (isSelected) {
            notifier.state = const CasesFilter(); // إلغاء الفلتر
            return;
          }
          notifier.state = CasesFilter(
            status: status,
            deficient: deficient,
            overdue: overdue,
            pendingBase: pendingBase,
            nearSession: nearSession,
          );
        },
        backgroundColor: AppColors.cardBackground,
        selectedColor: AppColors.primaryNavy.withValues(alpha: 0.15),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: count > 0 ? AppColors.primaryNavy : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildCaseList(BuildContext context, WidgetRef ref) {
    final caseItems = [...ref.watch(casesProvider)]
      ..sort(
        (a, b) => (a.nextSession?.sessionDate ?? DateTime(9999))
            .compareTo(b.nextSession?.sessionDate ?? DateTime(9999)),
      );

    if (caseItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('لا يوجد دعاوى', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            Text('اضغط + لإضافة دعوى', style: AppTextStyles.bodySmallSecondary),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: caseItems.length,
      itemBuilder: (context, index) => CaseCard(caseItem: caseItems[index]),
    );
  }
}

/// معايير فلترة الدعاوى المطبَّقة حالياً.
class CasesFilter {
  final CaseType? type;
  final CaseStatus? status;
  final bool deficient;
  final bool nearSession;
  final bool pendingBase;
  final bool overdue;

  const CasesFilter({
    this.type,
    this.status,
    this.deficient = false,
    this.nearSession = false,
    this.pendingBase = false,
    this.overdue = false,
  });

  bool get isEmpty =>
      type == null &&
      status == null &&
      !deficient &&
      !nearSession &&
      !pendingBase &&
      !overdue;

  int get activeCount =>
      (type != null ? 1 : 0) +
      (status != null ? 1 : 0) +
      (deficient ? 1 : 0) +
      (nearSession ? 1 : 0) +
      (pendingBase ? 1 : 0) +
      (overdue ? 1 : 0);
}

/// الفلتر المطبَّق على قائمة الدعاوى.
final casesFilterProvider =
    StateProvider<CasesFilter>((ref) => const CasesFilter());

/// كل الدعاوى دون فلترة.
final allCasesUnfilteredProvider = Provider<List<Case>>((ref) {
  final asyncCases = ref.watch(uiCasesProvider);
  return asyncCases.maybeWhen(data: (items) => items, orElse: () => const <Case>[]);
});

/// الدعاوى بعد تطبيق الفلتر.
///
/// كان زر «تطبيق» في نافذة الفلترة يغلق النافذة ويعرض «تم تطبيق
/// الفلاتر» دون أي أثر، لأن القيم المختارة لم تكن تُمرَّر لأي مكان.
final casesProvider = Provider<List<Case>>((ref) {
  final all = ref.watch(allCasesUnfilteredProvider);
  final f = ref.watch(casesFilterProvider);
  if (f.isEmpty) return all;

  return all.where((c) {
    if (f.type != null && c.type != f.type) return false;
    if (f.status != null && c.status != f.status) return false;
    if (f.deficient && c.openDeficienciesCount == 0) return false;
    if (f.nearSession && c.nextSession == null) return false;
    if (f.pendingBase &&
        !(c.baseNumber == null || c.baseNumber!.isEmpty)) {
      return false;
    }
    if (f.overdue &&
        !(c.nextSession?.sessionDate.isBefore(DateTime.now()) ?? false)) {
      return false;
    }
    return true;
  }).toList();
});


class CaseCard extends StatelessWidget {
  final Case caseItem;

  const CaseCard({super.key, required this.caseItem});

  @override
  Widget build(BuildContext context) {
    final nextSession = caseItem.nextSession;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/cases/${caseItem.id}'),
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
                      caseItem.caseNumber,
                      style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy),
                    ),
                  ),
                  _tag(caseItem.type.displayName, AppColors.primaryNavy),
                  const SizedBox(width: 8),
                  _tag(caseItem.status.displayName, caseItem.status.color),
                ],
              ),
              const SizedBox(height: 8),
              Text(caseItem.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('الموضوع: ${caseItem.subject}', style: AppTextStyles.bodySmall),
              Text('الطلب: ${caseItem.claim}', style: AppTextStyles.bodySmallSecondary),
              const SizedBox(height: 8),
              _iconLine(Icons.balance, caseItem.court),
              if (caseItem.baseNumber == null || caseItem.baseNumber!.isEmpty)
                _warningLine('بانتظار رقم أساس')
              else
                _iconLine(Icons.confirmation_number, 'رقم الأساس: ${caseItem.baseNumber}'),
              if (nextSession != null)
                _iconLine(
                  Icons.calendar_today,
                  'الجلسة: ${_formatDate(nextSession.sessionDate)} ${_formatTime(nextSession.sessionTime)}',
                  color: nextSession.sessionDate.isBefore(DateTime.now()) ? AppColors.error : AppColors.textPrimary,
                ),
              if (caseItem.openDeficienciesCount > 0) _warningLine('نواقص: ${caseItem.openDeficienciesCount}', isError: true),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text('أتعاب: ${caseItem.totalFees.toStringAsFixed(0)} ل.س', style: AppTextStyles.bodySmallSecondary),
                  Text('مصاريف: ${caseItem.totalExpenses.toStringAsFixed(0)} ل.س', style: AppTextStyles.bodySmallSecondary),
                  Text(
                    'الرصيد: ${caseItem.balance.toStringAsFixed(0)} ل.س',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: caseItem.balance >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_file, color: AppColors.textSecondary, size: 16),
                  const SizedBox(width: 4),
                  Text('مستندات: ${caseItem.documentIds.length}', style: AppTextStyles.bodySmallSecondary),
                  const SizedBox(width: 8),
                  if (caseItem.documentIds.isNotEmpty)
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => CaseDocsDialog(caseItem: caseItem),
                      ),
                      child: const Text('عرض المستندات'),
                    ),
                ],
              ),
              Text(
                'آخر تحديث: ${_formatDate(caseItem.lastUpdated ?? caseItem.creationDate)}',
                style: AppTextStyles.bodySmallSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _iconLine(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: color ?? AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _warningLine(String text, {bool isError = false}) {
    final color = isError ? AppColors.error : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: color)),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class CaseDocsDialog extends ConsumerWidget {
  final Case caseItem;

  const CaseDocsDialog({super.key, required this.caseItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // مستندات الدعوى الحقيقية من الأرشيف بدل بيانات مُصطنعة عن كل معرّف.
    final all = ref.watch(uiDocumentsProvider).maybeWhen(
          data: (items) => items,
          orElse: () => const <DocumentItem>[],
        );
    final docs = all
        .where((d) => d.entityType == 'case' && d.entityId == caseItem.id)
        .toList()
      ..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));

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
                      'مستندات الدعوى: ${caseItem.caseNumber}',
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
                  subtitle: Text(
                    '${docs[index].fileType.displayName} - ${docs[index].formattedSize}',
                    style: AppTextStyles.bodySmallSecondary,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openDocument(context, docs[index].id),
                    tooltip: 'فتح',
                  ),
                  onTap: () => openDocument(context, docs[index].id),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CasesFilterDialog extends StatefulWidget {
  const CasesFilterDialog({super.key, this.initial = const CasesFilter()});

  final CasesFilter initial;

  @override
  State<CasesFilterDialog> createState() => _CasesFilterDialogState();
}

class _CasesFilterDialogState extends State<CasesFilterDialog> {
  late CaseType? _type = widget.initial.type;
  late CaseStatus? _status = widget.initial.status;
  late bool _deficient = widget.initial.deficient;
  late bool _nearSession = widget.initial.nearSession;
  late bool _pendingBase = widget.initial.pendingBase;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('فلترة الدعاوى', style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy)),
            const SizedBox(height: 24),
            DropdownButtonFormField<CaseType?>(
              value: _type,
              items: [
                const DropdownMenuItem<CaseType?>(value: null, child: Text('جميع الأنواع')),
                ...CaseType.values.map((type) => DropdownMenuItem<CaseType?>(value: type, child: Text(type.displayName))),
              ],
              onChanged: (value) => setState(() => _type = value),
              decoration: const InputDecoration(labelText: 'نوع الدعوى'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CaseStatus?>(
              value: _status,
              items: [
                const DropdownMenuItem<CaseStatus?>(value: null, child: Text('جميع الحالات')),
                ...CaseStatus.values.map((status) => DropdownMenuItem<CaseStatus?>(value: status, child: Text(status.displayName))),
              ],
              onChanged: (value) => setState(() => _status = value),
              decoration: const InputDecoration(labelText: 'حالة الدعوى'),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('الدعاوى الناقصة'),
              value: _deficient,
              onChanged: (value) => setState(() => _deficient = value ?? false),
            ),
            CheckboxListTile(
              title: const Text('جلسة قريب'),
              value: _nearSession,
              onChanged: (value) => setState(() => _nearSession = value ?? false),
            ),
            CheckboxListTile(
              title: const Text('بانتظار رقم أساس'),
              value: _pendingBase,
              onChanged: (value) => setState(() => _pendingBase = value ?? false),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const CasesFilter()),
                  child: const Text('مسح الكل'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(CasesFilter(
                    type: _type,
                    status: _status,
                    deficient: _deficient,
                    nearSession: _nearSession,
                    pendingBase: _pendingBase,
                  )),
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
