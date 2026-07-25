/// لوحة اليوم الذكية (Smart Dashboard) - Split Layout
/// بناءً على الخطة الماسية لإعادة الهيكلة 2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../agenda/result_entry_dialog.dart';
import '../work_orders/work_order_dialogs.dart';
import '../work_orders/work_order_models.dart';
import '../cases/case_models.dart';

class TodayDashboardScreen extends ConsumerWidget {
  const TodayDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(uiCasesProvider);
    final woAsync = ref.watch(uiWorkOrdersProvider);
    final tasksAsync = ref.watch(tasksByDateProvider(DateTime.now()));
    final deficienciesAsync = ref.watch(openDeficienciesProvider(null));

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.cardBackground,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              
              Widget timelineContent = _buildTimelinePanel(context, casesAsync, tasksAsync, woAsync);
              Widget alertsContent = _buildAlertsPanel(context, deficienciesAsync, casesAsync, woAsync);

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // القسم الرئيسي: خط السير اليومي والأجندة
                    Expanded(
                      flex: 7,
                      child: timelineContent,
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: AppColors.cardBorder),
                    // الشريط الجانبي: النواقص والتنبيهات
                    Expanded(
                      flex: 3,
                      child: alertsContent,
                    ),
                  ],
                );
              }

              // للموبايل والشاشات الصغيرة
              return SingleChildScrollView(
                child: Column(
                  children: [
                    alertsContent, // التنبيهات أهم، تظهر أولاً في الموبايل
                    const Divider(height: 1, thickness: 1),
                    timelineContent,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// بناء خط السير الزمني (Timeline & Agenda)
  Widget _buildTimelinePanel(BuildContext context, AsyncValue casesAsync, AsyncValue tasksAsync, AsyncValue woAsync) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أجندة اليوم — ${DateTime.now().toString().substring(0, 10)}',
                style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const ResultEntryDialog()),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('إدخال نتيجة سريعة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: casesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
              data: (cases) {
                final today = DateTime.now();
                bool sameDay(DateTime d) => d.year == today.year && d.month == today.month && d.day == today.day;

                final List<Widget> timelineItems = [];

                // 1. استخراج جلسات اليوم
                for (final c in cases) {
                  for (final s in c.sessions) {
                    if (sameDay(s.sessionDate)) {
                      timelineItems.add(_buildTimelineCard(
                        time: s.sessionTime.format(context),
                        title: 'جلسة محكمة: ${c.caseNumber}',
                        subtitle: '${c.title} • ${s.court}',
                        icon: Icons.gavel,
                        color: AppColors.primaryNavy,
                      ));
                    }
                  }
                }

                // 2. مهام اليوم (من Tasks)
                tasksAsync.whenData((tasks) {
                  for (final t in tasks) {
                    timelineItems.add(_buildTimelineCard(
                      time: 'مهمة',
                      title: t.title,
                      subtitle: t.taskType == 'company_phase' ? 'مراحل تأسيس شركة' : 'مهمة إدارية',
                      icon: Icons.task_alt,
                      color: AppColors.info,
                    ));
                  }
                });

                if (timelineItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('لا يوجد جلسات أو مهام مجدولة لهذا اليوم.', style: AppTextStyles.headline6.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: timelineItems.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => timelineItems[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// بناء لوحة الإنذارات والنواقص (Alerts & Deficiencies)
  Widget _buildAlertsPanel(BuildContext context, AsyncValue deficienciesAsync, AsyncValue casesAsync, AsyncValue woAsync) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'الإنذارات والنواقص',
                style: AppTextStyles.headline6.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                // 1. النواقص الحرجة
                deficienciesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (defs) {
                    if (defs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('النواقص الحرجة (${defs.length})', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        ...defs.take(5).map((d) => _buildAlertCard(
                          title: d.description ?? 'نقص في الملف',
                          description: d.fieldName ?? 'الرجاء المراجعة والإكمال',
                          actionText: 'معالجة',
                          onAction: () {
                            if (d.entityType == 0) { // caseEntity
                              context.go('/cases/${d.entityId}');
                            } else if (d.entityType == 2) { // company
                              context.go('/companies/${d.entityId}');
                            } else if (d.entityType == 1) { // contract
                              context.go('/contracts/${d.entityId}');
                            } else {
                              context.go('/cases');
                            }
                          },
                          isCritical: true,
                        )),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // 2. أوامر عمل بانتظار الاعتماد
                woAsync.whenData((workOrders) {
                  final pending = workOrders.where((w) => w.status == WorkOrderStatus.resultEntered || w.status == WorkOrderStatus.waitingForApproval).toList();
                  if (pending.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نتائج تحتاج اعتماد (${pending.length})', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      ...pending.take(3).map((w) => _buildAlertCard(
                        title: w.internalNumber,
                        description: 'تم التنفيذ بواسطة ${w.assignedToName}. بانتظار اعتماد النتيجة.',
                        actionText: 'مراجعة',
                        onAction: () => context.go('/work-orders'),
                        isCritical: false,
                        icon: Icons.fact_check,
                        color: AppColors.warning,
                      )),
                      const SizedBox(height: 16),
                    ],
                  );
                }).value ?? const SizedBox.shrink(),
                
                // 3. المتأخرات (Overdue Cases)
                casesAsync.whenData((cases) {
                  final overdue = cases.where((c) {
                    final n = c.nextSession?.sessionDate;
                    return n != null && n.isBefore(DateTime.now()) && c.status != CaseStatus.completed;
                  }).toList();
                  if (overdue.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ملفات متأخرة المتابعة (${overdue.length})', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      ...overdue.take(3).map((c) => _buildAlertCard(
                        title: 'دعوى: ${c.caseNumber}',
                        description: 'تجاوزت تاريخ الجلسة القادمة المبرمج.',
                        actionText: 'تحديث',
                        onAction: () => context.go('/cases'),
                        isCritical: true,
                      )),
                    ],
                  );
                }).value ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard({required String time, required String title, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16)),
            child: Text(time, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({required String title, required String description, required String actionText, required VoidCallback onAction, bool isCritical = false, IconData? icon, Color? color}) {
    final alertColor = color ?? (isCritical ? AppColors.error : AppColors.secondaryGold);
    final alertIcon = icon ?? (isCritical ? Icons.warning_amber_rounded : Icons.info_outline);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alertIcon, color: alertColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTextStyles.labelLarge.copyWith(color: alertColor, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: AppTextStyles.bodySmallSecondary),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: alertColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionText),
            ),
          ),
        ],
      ),
    );
  }
}
