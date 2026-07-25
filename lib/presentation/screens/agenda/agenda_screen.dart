/// شاشة الأجندة الموحدة (Unified Agenda)
/// دمج الجلسات والمهام في تقويم تفاعلي واحد بناءً على الخطة الماسية

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/app_enums.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'result_entry_dialog.dart';

// -----------------------------------------------------------------------------
// 1. Unified Agenda Models
// -----------------------------------------------------------------------------

enum AgendaItemType { session, task, companyPhase, contractReminder }

class UnifiedAgendaItem {
  final String id;
  final DateTime date;
  final String timeString;
  final String title;
  final String subtitle;
  final AgendaItemType type;
  final int statusIndex; // 0=scheduled, 1=completed, etc.
  final Color color;
  final IconData icon;
  final int? entityId;
  final String? entityType;

  UnifiedAgendaItem({
    required this.id,
    required this.date,
    required this.timeString,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.statusIndex,
    required this.color,
    required this.icon,
    this.entityId,
    this.entityType,
  });
}

// -----------------------------------------------------------------------------
// 2. State & Providers
// -----------------------------------------------------------------------------

final selectedAgendaDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Provider حقيقي للأجندة من قاعدة البيانات (case_sessions + daily_tasks)
DateTime _agendaDate(Object? value, DateTime fallback) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? fallback;
  return fallback;
}

final unifiedAgendaFromDBProvider = FutureProvider.family<List<UnifiedAgendaItem>, DateTime>((ref, targetDate) async {
  final db = ref.watch(databaseProvider);
  await db.ensureOfficeFileTables(); // لضمان الجداول

  // التواريخ مخزّنة كأعداد Unix epoch؛ لذلك تُقارن بمجال يوم كامل
  // [بداية اليوم، بداية الغد) لأن DATE() تُرجع NULL على الأعداد.
  final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final items = <UnifiedAgendaItem>[];

  // 1. جلسات الدعاوى (من next_session_date + case_sessions)
  final sessions = await db.customSelect('''
    SELECT cs.id, cs.case_id, cs.session_date, cs.session_time, cs.session_type, cs.status, c.subject, c.internal_number
    FROM case_sessions cs
    LEFT JOIN cases c ON c.id = cs.case_id
    WHERE cs.session_date >= ? AND cs.session_date < ?
    ORDER BY cs.session_time
  ''', variables: [
    Variable.withDateTime(dayStart),
    Variable.withDateTime(dayEnd),
  ]).get();

  for (final row in sessions) {
    final data = row.data;
    final time = data['session_time'] as String? ?? '09:00';
    items.add(UnifiedAgendaItem(
      id: 'session_${data['id']}',
      date: _agendaDate(data['session_date'], targetDate),
      timeString: time,
      title: 'جلسة ${data['session_type'] ?? 'مرافعة'} - ${data['internal_number'] ?? ''}',
      subtitle: data['subject'] ?? 'دعوى',
      type: AgendaItemType.session,
      statusIndex: (data['status'] as int? ?? 0),
      color: AppColors.primaryNavy,
      icon: Icons.gavel,
      entityId: data['case_id'] as int?,
      entityType: 'case',
    ));
  }

  // 2. المهام اليومية (daily_tasks)
  final tasks = await db.customSelect('''
    SELECT id, task_date, task_time, title, notes, status, task_type, source_type, source_id
    FROM daily_tasks
    WHERE task_date >= ? AND task_date < ?
    ORDER BY task_time
  ''', variables: [
    Variable.withDateTime(dayStart),
    Variable.withDateTime(dayEnd),
  ]).get();

  for (final row in tasks) {
    final data = row.data;
    final time = data['task_time'] as String? ?? 'طوال اليوم';
    final taskType = data['task_type'] as String? ?? '';

    AgendaItemType type = AgendaItemType.task;
    Color color = AppColors.info;
    IconData icon = Icons.task_alt;

    if (taskType.contains('company')) {
      type = AgendaItemType.companyPhase;
      color = AppColors.secondaryGold;
      icon = Icons.business;
    } else if (taskType.contains('contract')) {
      type = AgendaItemType.contractReminder;
      color = AppColors.warning;
      icon = Icons.description;
    } else if ((data['title'] as String).contains('جلسة')) {
      type = AgendaItemType.session;
      color = AppColors.primaryNavy;
      icon = Icons.gavel;
    }

    items.add(UnifiedAgendaItem(
      id: 'task_${data['id']}',
      date: _agendaDate(data['task_date'], targetDate),
      timeString: time,
      title: data['title'] as String,
      subtitle: data['notes'] as String? ?? 'مهمة يومية',
      type: type,
      statusIndex: data['status'] as int? ?? 0,
      color: color,
      icon: icon,
      entityId: (data['source_id'] as int?) ?? (data['id'] as int?),
      entityType: data['source_type'] == 'cases' ? 'case' : 'task',
    ));
  }

  // فرز حسب الوقت
  items.sort((a, b) => a.timeString.compareTo(b.timeString));
  return items;
});

final unifiedAgendaProvider = Provider<AsyncValue<List<UnifiedAgendaItem>>>((ref) {
  final targetDate = ref.watch(selectedAgendaDateProvider);
  return ref.watch(unifiedAgendaFromDBProvider(targetDate));
});

// -----------------------------------------------------------------------------
// 3. UI
// -----------------------------------------------------------------------------

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedAgendaDateProvider);
    final agendaAsync = ref.watch(unifiedAgendaProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.cardBackground,
        appBar: AppBar(
          title: const Text('الأجندة الموحدة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.today),
              tooltip: 'العودة لليوم',
              onPressed: () => ref.read(selectedAgendaDateProvider.notifier).state = DateTime.now(),
            ),
            IconButton(
              icon: const Icon(Icons.dashboard),
              tooltip: 'لوحة اليوم',
              onPressed: () => context.go('/today'),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildDateSelector(context, ref, selectedDate),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: agendaAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ في جلب البيانات: $err')),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available, size: 80, color: AppColors.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('لا توجد جلسات أو مهام في هذا اليوم.', style: AppTextStyles.headline6.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildAgendaItem(context, items[index]),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showQuickAdd(context),
          icon: const Icon(Icons.add),
          label: const Text('إضافة موعد/مهمة'),
          backgroundColor: AppColors.primaryNavy,
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, WidgetRef ref, DateTime currentDate) {
    // بناء شريط أسبوعي بسيط
    final weekDates = List.generate(7, (index) => currentDate.subtract(Duration(days: 3)).add(Duration(days: index)));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: weekDates.map((date) {
          final isSelected = date.year == currentDate.year && date.month == currentDate.month && date.day == currentDate.day;
          final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
          
          return InkWell(
            onTap: () => ref.read(selectedAgendaDateProvider.notifier).state = date,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppColors.primaryNavy : AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Text(
                    _getWeekdayName(date.weekday),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: AppTextStyles.headline5.copyWith(
                      color: isSelected ? Colors.white : (isToday ? AppColors.primaryNavy : AppColors.textPrimary),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    const names = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return names[weekday - 1];
  }

  Widget _buildAgendaItem(BuildContext context, UnifiedAgendaItem item) {
    final isCompleted = item.statusIndex == LifecycleStatus.completed.index;
    
    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.success.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCompleted ? AppColors.success.withOpacity(0.3) : AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // شريط التمييز اللوني
          Container(
            width: 6,
            height: 80,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.success : item.color,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            ),
          ),
          const SizedBox(width: 16),
          // الوقت
          SizedBox(
            width: 70,
            child: Text(
              item.timeString,
              style: AppTextStyles.headline6.copyWith(
                color: isCompleted ? AppColors.textSecondary : AppColors.primaryNavy,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          // التفاصيل
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 16, color: isCompleted ? AppColors.textSecondary : item.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: AppTextStyles.bodySmallSecondary.copyWith(
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // زر الإجراء
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 28),
                tooltip: 'تسجيل نتيجة (Transaction)',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ResultEntryDialog(entityId: item.entityId, entityType: item.entityType ?? 'task', initialTitle: item.title),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showQuickAdd(BuildContext context) {
    // يمكن ربطه بمعالج إضافة مهمة أو جلسة سريع
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('استخدم زر "الإضافة السريع +" في الشريط العلوي لتسجيل المهام والجلسات.')),
    );
  }
}
