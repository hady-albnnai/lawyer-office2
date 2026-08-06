/// شاشة لوحة التحكم الإحصائية للأجندة
///
/// تستخدم بيانات حقيقية من قاعدة البيانات عبر unifiedAgendaFromDBProvider
/// لعرض إحصائيات اليوم، الأسبوع، والشهر.
///
/// آخر تحديث: 2026-08-06
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agenda_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';

class AgendaStatisticsScreen extends ConsumerWidget {
  const AgendaStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // بيانات اليوم
    final todayAsync = ref.watch(unifiedAgendaFromDBProvider(today));
    // بيانات الغد
    final tomorrowAsync = ref.watch(unifiedAgendaFromDBProvider(today.add(const Duration(days: 1))));

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      appBar: AppBar(
        title: const Text('لوحة التحكم الإحصائية'),
        backgroundColor: AppColors.primaryNavy,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ملخص اليوم
            todayAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ: $e'),
              data: (todayItems) => _buildSummaryCard(
                context,
                title: 'ملخص اليوم',
                icon: Icons.today,
                stats: _computeStats(todayItems),
              ),
            ),
            const SizedBox(height: 20),

            // ملخص الغد
            tomorrowAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (tomorrowItems) => _buildSummaryCard(
                context,
                title: 'ملخص الغد',
                icon: Icons.event,
                stats: _computeStats(tomorrowItems),
              ),
            ),
            const SizedBox(height: 20),

            // توزيع الأنواع
            todayAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (items) => _buildTypeDistribution(context, items),
            ),
          ],
        ),
      ),
    );
  }

  List<_StatItem> _computeStats(List<UnifiedAgendaItem> items) {
    final total = items.length;
    final completed = items.where((i) => i.statusIndex == 2).length; // completed
    final pending = items.where((i) => i.statusIndex == 0).length; // scheduled
    final overdue = items.where((i) {
      if (i.statusIndex == 2 || i.statusIndex == 4) return false; // completed or cancelled
      return i.date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    }).length;

    return [
      _StatItem('إجمالي المواعيد', '$total', Icons.event, AppColors.primaryNavy),
      _StatItem('منجز', '$completed', Icons.check_circle, AppColors.success),
      _StatItem('مجدول', '$pending', Icons.schedule, AppColors.info),
      _StatItem('متأخر', '$overdue', Icons.warning, AppColors.error),
    ];
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_StatItem> stats,
  }) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryNavy, size: 22),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: stats.map((stat) => Expanded(
              child: _buildStatTile(stat),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(_StatItem stat) {
    final color = stat.color ?? AppColors.primaryNavy;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(stat.icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(stat.value, style: AppTextStyles.headline5.copyWith(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(stat.label, style: AppTextStyles.bodySmallSecondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTypeDistribution(BuildContext context, List<UnifiedAgendaItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // حساب توزيع الأنواع
    final typeCounts = <AgendaItemType, int>{};
    for (final item in items) {
      typeCounts[item.type] = (typeCounts[item.type] ?? 0) + 1;
    }

    final typeLabels = {
      AgendaItemType.session: ('جلسات', Icons.gavel, AppColors.primaryNavy),
      AgendaItemType.contractReminder: ('تذكيرات عقود', Icons.description, AppColors.warning),
      AgendaItemType.companyPhase: ('مراحل شركات', Icons.business, AppColors.secondaryGold),
      AgendaItemType.task: ('مهام', Icons.task_alt, AppColors.info),
    };

    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart, color: AppColors.primaryNavy, size: 22),
              const SizedBox(width: 8),
              Text('توزيع المواعيد حسب النوع',
                  style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
            ],
          ),
          const SizedBox(height: 16),
          ...typeCounts.entries.map((entry) {
            final info = typeLabels[entry.key] ?? ('أخرى', Icons.help, AppColors.textSecondary);
            final percentage = items.isEmpty ? 0 : (entry.value / items.length * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(info.$2, color: info.$3, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(info.$1, style: AppTextStyles.bodyMedium)),
                  Text('${entry.value}', style: AppTextStyles.labelLarge.copyWith(color: info.$3)),
                  const SizedBox(width: 8),
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: info.$3.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('$percentage%', style: AppTextStyles.labelSmall.copyWith(color: info.$3), textAlign: TextAlign.center),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem(this.label, this.value, this.icon, [this.color]);
}
