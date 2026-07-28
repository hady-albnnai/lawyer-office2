import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// شاشة لوحة التحكم الإحصائية للأجندة
class AgendaStatisticsScreen extends ConsumerWidget {
  const AgendaStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // إحصائيات بسيطة مؤقتة - يمكن توسيعها لاحقاً
    final todayStats = {
      'total': 0,
      'completed': 0,
      'pending': 0,
      'overdue': 0,
    };

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
              _buildSummaryCard(
                context,
                title: 'ملخص اليوم',
                stats: [
                  _StatItem('إجمالي المواعيد', '${todayStats['total']}', Icons.event),
                  _StatItem('منجز', '${todayStats['completed']}', Icons.check_circle, AppColors.success),
                  _StatItem('متبقي', '${todayStats['pending']}', Icons.pending, AppColors.warning),
                  _StatItem('متأخر', '${todayStats['overdue']}', Icons.warning, Colors.red),
                ],
              ),
              const SizedBox(height: 24),
              
              const Center(
                child: Text(
                  'المزيد من الإحصائيات قيد التطوير',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required List<_StatItem> stats,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.headline6.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final stat = stats[index];
                return Container(
                  decoration: BoxDecoration(
                    color: stat.color?.withOpacity(0.1) ?? Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: stat.color ?? AppColors.cardBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        stat.icon,
                        color: stat.color ?? AppColors.primaryNavy,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stat.value,
                        style: AppTextStyles.headline5.copyWith(
                          color: stat.color ?? AppColors.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat.label,
                        style: AppTextStyles.bodySmallSecondary,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  _StatItem(this.label, this.value, this.icon, [this.color]);
}