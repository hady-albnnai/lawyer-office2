/// شاشة أوامر العمل — قائمة من SQLite مع إجراءات حقيقية.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../providers/auth_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'work_order_dialogs.dart';
import 'work_order_models.dart';

final woProvider = Provider<List<WorkOrder>>((ref) {
  final asyncWo = ref.watch(uiWorkOrdersProvider);
  return asyncWo.maybeWhen(data: (items) => items, orElse: () => const <WorkOrder>[]);
});

class WorkOrdersScreen extends ConsumerWidget {
  const WorkOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(uiWorkOrdersProvider).isLoading;
    final permissions = ref.watch(permissionServiceProvider);
    final canCreate = permissions.can(PermissionKeys.workOrdersCreate);
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('أوامر العمل للمعقب'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                isScrollable: true,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: AppColors.secondaryGold, width: 3),
                ),
                labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
                unselectedLabelStyle: AppTextStyles.labelMedium,
                tabs: const [
                  Tab(text: 'جميع الأوامر'),
                  Tab(text: 'مسودة'),
                  Tab(text: 'بانتظار نتيجة'),
                  Tab(text: 'بانتظار اعتماد'),
                  Tab(text: 'معتمدة'),
                  Tab(text: 'أوامر عامة'),
                ],
              ),
            ),
          ),
          actions: [
            if (loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(uiWorkOrdersProvider),
              tooltip: 'تحديث',
            ),
            if (canCreate)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => const CreateWorkOrderDialog(),
                  );
                  if (ok == true) ref.invalidate(uiWorkOrdersProvider);
                },
                tooltip: 'جديد',
              ),
          ],
        ),
        body: const TabBarView(
          children: [
            _WoTab(),
            _WoTab(filter: WorkOrderStatus.draft),
            _WoTab(filter: WorkOrderStatus.waitingForResult),
            _WoTab(filter: WorkOrderStatus.waitingForApproval),
            _WoTab(filter: WorkOrderStatus.approved),
            _WoTab(generalOnly: true),
          ],
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => const CreateWorkOrderDialog(),
                  );
                  if (ok == true) ref.invalidate(uiWorkOrdersProvider);
                },
                icon: const Icon(Icons.add),
                label: const Text('أمر عمل جديد'),
              )
            : null,
      ),
    );
  }
}

class _WoTab extends ConsumerWidget {
  final WorkOrderStatus? filter;
  final bool generalOnly;
  const _WoTab({this.filter, this.generalOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var list = ref.watch(woProvider);
    if (filter != null) {
      list = list.where((w) => w.status == filter).toList();
    }
    if (generalOnly) {
      list = list.where((w) => w.linkedEntityId == '0').toList();
    }
    if (list.isEmpty) {
      return Center(
        child: Text(
          generalOnly ? 'لا توجد أوامر عامة' : (filter == null ? 'لا توجد أوامر عمل — أنشئ أمرًا جديدًا' : 'لا عناصر في هذا التبويب'),
          style: AppTextStyles.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (c, i) => WOCard(wo: list[i]),
    );
  }
}

class WOCard extends ConsumerWidget {
  final WorkOrder wo;
  const WOCard({super.key, required this.wo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                Text(
                  wo.internalNumber,
                  style: AppTextStyles.headline6.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: wo.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    wo.statusText,
                    style: AppTextStyles.labelSmall.copyWith(color: wo.statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('المكلف: ${wo.assignedToName} • ${wo.assignedToPhone}', style: AppTextStyles.bodySmall),
            Text('النوع: ${wo.orderTypeText} • الأولوية: ${wo.priorityText}', style: AppTextStyles.bodySmall),
            const SizedBox(height: 6),
            Text(wo.instructions, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 6),
            Text(
              'الملف: ${wo.linkedEntityType} ${wo.linkedEntityId} • الموعد: ${wo.dueDate.toString().substring(0, 10)}',
              style: AppTextStyles.bodySmallSecondary,
            ),
            if (wo.resultText != null && wo.resultText!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('النتيجة: ${wo.resultText}', style: AppTextStyles.bodySmall),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (wo.status == WorkOrderStatus.draft && permissions.can(PermissionKeys.workOrdersPrint))
                  TextButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (c) => PrintWorkOrderDialog(workOrder: wo),
                    ),
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('طباعة PDF'),
                  ),
                if ((wo.status == WorkOrderStatus.printed || wo.status == WorkOrderStatus.draft) && permissions.can(PermissionKeys.workOrdersSend))
                  TextButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (c) => WhatsAppDialog(workOrder: wo),
                    ),
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('واتساب'),
                  ),
                if ((wo.status == WorkOrderStatus.whatsappSent ||
                    wo.status == WorkOrderStatus.printed ||
                    wo.status == WorkOrderStatus.waitingForResult) &&
                    permissions.can(PermissionKeys.workOrdersResultEnter))
                  TextButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (c) => EnterWorkOrderResultDialog(workOrder: wo),
                    ),
                    icon: const Icon(Icons.input, size: 16),
                    label: const Text('نتيجة'),
                  ),
                if ((wo.status == WorkOrderStatus.resultEntered ||
                    wo.status == WorkOrderStatus.waitingForApproval) &&
                    permissions.can(PermissionKeys.workOrdersApprove))
                  ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (c) => ApproveWorkOrderDialog(workOrder: wo),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('اعتماد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.textOnLight,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
