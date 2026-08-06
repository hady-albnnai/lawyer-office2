/// شاشة الأجندة الموحدة (Unified Agenda)
/// دمج الجلسات والمهام في تقويم تفاعلي واحد بناءً على الخطة الماسية
library;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/enums/app_enums.dart';
import '../../../data/database/daos/task_dao.dart';
import '../../../data/services/automation_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/report_service.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';
import 'agenda_statistics_screen.dart';
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
final searchQueryProvider = StateProvider<String>((ref) => '');
final filterTypeProvider = StateProvider<AgendaItemType?>((ref) => null);
final darkModeProvider = StateProvider<bool>((ref) => false);
final viewModeProvider = StateProvider<AgendaViewMode>((ref) => AgendaViewMode.weekly);
final showRichContextProvider = StateProvider<bool>((ref) => false);

enum AgendaViewMode { weekly, monthly }

/// Provider حقيقي للأجندة من قاعدة البيانات (case_sessions + daily_tasks)
DateTime _agendaDate(Object? value, DateTime fallback) {
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value is int) {
    // Unix epoch seconds → DateTime (تطبيع لليوم فقط بدون وقت)
    final dt = DateTime.fromMillisecondsSinceEpoch(value * 1000);
    return DateTime(dt.year, dt.month, dt.day);
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
  }
  return DateTime(fallback.year, fallback.month, fallback.day);
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
  final searchQuery = ref.watch(searchQueryProvider);
  final filterType = ref.watch(filterTypeProvider);
  
  final agendaAsync = ref.watch(unifiedAgendaFromDBProvider(targetDate));
  
  return agendaAsync.whenData((items) {
    var filteredItems = items;
    
    // تطبيق البحث
    if (searchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) =>
        item.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
        item.subtitle.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }
    
    // تطبيق الفلترة حسب النوع
    if (filterType != null) {
      filteredItems = filteredItems.where((item) => item.type == filterType).toList();
    }
    
    return filteredItems;
  });
});

/// Provider لجلب بيانات الشهر كامل للتقويم الشهري
final monthlyAgendaProvider = FutureProvider.family<Map<DateTime, List<UnifiedAgendaItem>>, DateTime>((ref, monthDate) async {
  final db = ref.watch(databaseProvider);
  await db.ensureOfficeFileTables();

  // حساب بداية ونهاية الشهر
  final firstDay = DateTime(monthDate.year, monthDate.month, 1);
  final lastDay = DateTime(monthDate.year, monthDate.month + 1, 0);

  final monthlyItems = <DateTime, List<UnifiedAgendaItem>>{};

  // 1. جلسات الدعاوى للشهر
  final sessions = await db.customSelect('''
    SELECT cs.id, cs.case_id, cs.session_date, cs.session_time, cs.session_type, cs.status, c.subject, c.internal_number
    FROM case_sessions cs
    LEFT JOIN cases c ON c.id = cs.case_id
    WHERE cs.session_date >= ? AND cs.session_date <= ?
    ORDER BY cs.session_date, cs.session_time
  ''', variables: [
    Variable.withDateTime(firstDay),
    Variable.withDateTime(lastDay),
  ]).get();

  for (final row in sessions) {
    final data = row.data;
    final date = _agendaDate(data['session_date'], monthDate);
    final time = data['session_time'] as String? ?? '09:00';
    
    monthlyItems.putIfAbsent(date, () => []);
    monthlyItems[date]!.add(UnifiedAgendaItem(
      id: 'session_${data['id']}',
      date: date,
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

  // 2. المهام اليومية للشهر
  final tasks = await db.customSelect('''
    SELECT id, task_date, task_time, title, notes, status, task_type, source_type, source_id
    FROM daily_tasks
    WHERE task_date >= ? AND task_date <= ?
    ORDER BY task_date, task_time
  ''', variables: [
    Variable.withDateTime(firstDay),
    Variable.withDateTime(lastDay),
  ]).get();

  for (final row in tasks) {
    final data = row.data;
    final date = _agendaDate(data['task_date'], monthDate);
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

    monthlyItems.putIfAbsent(date, () => []);
    monthlyItems[date]!.add(UnifiedAgendaItem(
      id: 'task_${data['id']}',
      date: date,
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

  return monthlyItems;
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
    final isDarkMode = ref.watch(darkModeProvider);
    final viewMode = ref.watch(viewModeProvider);

    // تحميل إعدادات Dark Mode عند البناء الأول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDarkModePreference().then((savedMode) {
        if (ref.read(darkModeProvider) != savedMode) {
          ref.read(darkModeProvider.notifier).state = savedMode;
        }
      });
    });

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0D1B2A) : AppColors.cardBackground,
      appBar: AppBar(
        title: const Text('الأجندة الموحدة'),
        backgroundColor: isDarkMode ? AppColors.primaryNavy : null,
        actions: [
            // زر تبديل وضع العرض
            IconButton(
              icon: Icon(viewMode == AgendaViewMode.weekly ? Icons.calendar_month : Icons.view_week),
              tooltip: viewMode == AgendaViewMode.weekly ? 'عرض شهري' : 'عرض أسبوعي',
              onPressed: () {
                ref.read(viewModeProvider.notifier).state = 
                    viewMode == AgendaViewMode.weekly ? AgendaViewMode.monthly : AgendaViewMode.weekly;
              },
            ),
            // زر تفعيل الإشعارات
            IconButton(
              icon: const Icon(Icons.notifications_active),
              tooltip: 'تفعيل الإشعارات الذكية',
              onPressed: () => _enableSmartNotifications(context, ref),
            ),
            // توليد المهام المتكررة تلقائياً
            IconButton(
              icon: const Icon(Icons.auto_mode),
              tooltip: 'توليد المهام المتكررة',
              onPressed: () => _runAutomation(context, ref),
            ),
            // زر تبديل السياق الغني
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'السياق الغني',
              onPressed: () => ref.read(showRichContextProvider.notifier).state = !ref.read(showRichContextProvider),
            ),
            // زر تبديل Dark Mode
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              tooltip: isDarkMode ? 'وضع النهار' : 'وضع الليل',
              onPressed: () {
                ref.read(darkModeProvider.notifier).state = !isDarkMode;
                _saveDarkModePreference(!isDarkMode);
              },
            ),
            // عداد المواعيد اليومية
            agendaAsync.when(
              data: (items) {
                final todayCount = items.length;
                final completedCount = items.where((item) => item.statusIndex == LifecycleStatus.completed.index).length;
                final pendingCount = todayCount - completedCount;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: pendingCount > 0 ? AppColors.warning.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: pendingCount > 0 ? AppColors.warning : AppColors.success,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pendingCount > 0 ? Icons.pending : Icons.check_circle,
                          size: 16,
                          color: pendingCount > 0 ? AppColors.warning : AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$pendingCount/$todayCount',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: pendingCount > 0 ? AppColors.warning : AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
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
            IconButton(
              icon: const Icon(Icons.analytics),
              tooltip: 'لوحة التحكم الإحصائية',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AgendaStatisticsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'تصدير التقرير',
              onPressed: () => _exportReport(context, ref),
            ),
          ],
        ),
        body: Column(
          children: [
            viewMode == AgendaViewMode.weekly 
                ? _buildDateSelector(context, ref, selectedDate)
                : _buildMonthSelector(context, ref, selectedDate),
            _buildSearchAndFilterBar(context, ref),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: viewMode == AgendaViewMode.weekly
                  ? _buildWeeklyView(context, ref, agendaAsync)
                  : _buildMonthlyView(context, ref, selectedDate),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showQuickAdd(context),
          icon: const Icon(Icons.add),
          label: const Text('إضافة موعد/مهمة'),
          backgroundColor: AppColors.primaryNavy,
        ),
      );
  }

  Widget _buildDateSelector(BuildContext context, WidgetRef ref, DateTime currentDate) {
    final isDarkMode = ref.watch(darkModeProvider);
    // بناء شريط أسبوعي بسيط
    final weekDates = List.generate(7, (index) => currentDate.subtract(Duration(days: 3)).add(Duration(days: index)));

    return Container(
      color: isDarkMode ? AppColors.primaryNavy : Colors.white,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppColors.primaryNavy : (isDarkMode ? const Color(0xFF4A6274) : AppColors.cardBorder)),
              ),
              child: Column(
                children: [
                  Text(
                    _getWeekdayName(date.weekday),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isSelected ? Colors.white : (isDarkMode ? const Color(0xFFAABBCC) : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: AppTextStyles.headline5.copyWith(
                      color: isSelected ? Colors.white : (isToday ? AppColors.primaryNavy : (isDarkMode ? Colors.white : AppColors.textPrimary)),
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
    const names = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];
    return names[weekday - 1];
  }

  Widget _buildSearchAndFilterBar(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final filterType = ref.watch(filterTypeProvider);
    final isDarkMode = ref.watch(darkModeProvider);
    
    return Container(
      color: isDarkMode ? AppColors.primaryNavy : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // شريط البحث
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2C3E50) : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'بحث في المواعيد والمهام...',
                hintStyle: TextStyle(color: isDarkMode ? const Color(0xFF8899AA) : AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: isDarkMode ? const Color(0xFF8899AA) : AppColors.textSecondary),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: isDarkMode ? const Color(0xFF8899AA) : AppColors.textSecondary),
                        onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // أزرار الفلترة
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  label: 'الكل',
                  icon: Icons.list,
                  isSelected: filterType == null,
                  onTap: () => ref.read(filterTypeProvider.notifier).state = null,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: 'جلسات',
                  icon: Icons.gavel,
                  isSelected: filterType == AgendaItemType.session,
                  onTap: () => ref.read(filterTypeProvider.notifier).state = AgendaItemType.session,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: 'عقود',
                  icon: Icons.description,
                  isSelected: filterType == AgendaItemType.contractReminder,
                  onTap: () => ref.read(filterTypeProvider.notifier).state = AgendaItemType.contractReminder,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: 'شركات',
                  icon: Icons.business,
                  isSelected: filterType == AgendaItemType.companyPhase,
                  onTap: () => ref.read(filterTypeProvider.notifier).state = AgendaItemType.companyPhase,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: 'مهام',
                  icon: Icons.task_alt,
                  isSelected: filterType == AgendaItemType.task,
                  onTap: () => ref.read(filterTypeProvider.notifier).state = AgendaItemType.task,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isDarkMode ? Colors.white : null),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: isDarkMode ? Colors.white : null)),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryNavy.withOpacity(0.2),
      checkmarkColor: AppColors.primaryNavy,
      backgroundColor: isDarkMode ? const Color(0xFF2C3E50) : AppColors.cardBackground,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryNavy : (isDarkMode ? const Color(0xFFAABBCC) : AppColors.textSecondary),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildAgendaItem(BuildContext context, WidgetRef ref, UnifiedAgendaItem item) {
    final isCompleted = item.statusIndex == LifecycleStatus.completed.index;
    final isOverdue = item.date.isBefore(DateTime.now()) && !isCompleted;
    final isDarkMode = ref.watch(darkModeProvider);
    final showRichContext = ref.watch(showRichContextProvider);

    return Container(
      decoration: BoxDecoration(
        color: isCompleted 
            ? (isDarkMode ? AppColors.success.withOpacity(0.15) : AppColors.success.withOpacity(0.05))
            : (isOverdue 
                ? (isDarkMode ? AppColors.error.withOpacity(0.15) : AppColors.error.withOpacity(0.08)) 
                : (isDarkMode ? AppColors.primaryNavy : Colors.white)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted 
              ? AppColors.success.withOpacity(0.3) 
              : (isOverdue ? AppColors.error.withOpacity(0.4) : (isDarkMode ? const Color(0xFF4A6274) : AppColors.cardBorder)),
          width: isOverdue ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isOverdue ? 0.08 : 0.02), 
            blurRadius: isOverdue ? 8 : 4, 
            offset: const Offset(0, 2)
          ),
        ],
      ),
      child: Column(
        children: [
          // المحتوى الرئيسي
          Row(
            children: [
              // شريط التمييز اللوني المحسّن
              Container(
                width: 8,
                height: showRichContext ? 120 : 90,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : item.color,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isCompleted ? AppColors.success : item.color,
                      isCompleted ? AppColors.success.withOpacity(0.7) : item.color.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // الوقت مع أيقونة محسّنة
              SizedBox(
                width: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isCompleted ? AppColors.success : item.color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        item.timeString,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isCompleted 
                              ? (isDarkMode ? const Color(0xFF8899AA) : AppColors.textSecondary) 
                              : (isDarkMode ? Colors.white : AppColors.primaryNavy),
                          fontWeight: FontWeight.bold,
                          fontStyle: isCompleted ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.warning, size: 12, color: AppColors.error),
                            const SizedBox(width: 4),
                            Text(
                              'متأخر',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // التفاصيل مع أيقونات محسّنة
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (isCompleted ? AppColors.textSecondary : item.color).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              item.icon, 
                              size: 18, 
                              color: isCompleted ? AppColors.textSecondary : item.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTextStyles.labelLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isCompleted 
                                    ? (isDarkMode ? const Color(0xFF8899AA) : AppColors.textSecondary) 
                                    : (isDarkMode ? Colors.white : AppColors.textPrimary),
                                fontStyle: isCompleted ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ),
                          // زر تبديل السياق الغني
                          InkWell(
                            onTap: () => ref.read(showRichContextProvider.notifier).state = !showRichContext,
                            child: Icon(
                              showRichContext ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                              color: isDarkMode ? const Color(0xFF8899AA) : const Color(0xFF4A6274),
                            ),
                          ),
                          // زر المشاركة
                          InkWell(
                            onTap: () => _showCollaborationMenu(context, ref, item),
                            child: Icon(
                              Icons.people_outline,
                              size: 20,
                              color: isDarkMode ? const Color(0xFF8899AA) : const Color(0xFF4A6274),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            _getPriorityIcon(item.type),
                            size: 14,
                            color: _getPriorityColor(item.type),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.subtitle,
                              style: AppTextStyles.bodySmallSecondary.copyWith(
                                color: isDarkMode ? const Color(0xFFAABBCC) : null,
                                fontStyle: isCompleted ? FontStyle.italic : FontStyle.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // أزرار الإجراء المحسّنة
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // زر الانتقال للملف المرتبط
                    if (item.entityId != null && item.entityType != null)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.folder_open, color: AppColors.primaryNavy, size: 24),
                          tooltip: 'فتح الملف المرتبط',
                          onPressed: () => _navigateToRelatedFile(context, item),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // زر تسجيل النتيجة — يظهر فقط للمواعيد اليوم أو الماضية
                    if (!isCompleted && !item.date.isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(const Duration(days: 1))))
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 28),
                          tooltip: 'تسجيل نتيجة (Transaction)',
                          onPressed: () async {
                            final result = await showDialog(
                              context: context,
                              builder: (_) => ResultEntryDialog(entityId: item.entityId, entityType: item.entityType ?? 'task', initialTitle: item.title),
                            );
                            
                            // إرسال إشعار عند إتمام المهمة
                            if (result == true) {
                              final notificationService = NotificationService();
                              await notificationService.initialize();
                              await notificationService.sendStatusChangeNotification(
                                appointmentTitle: item.title,
                                newStatus: 'منجز',
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // السياق الغني (يظهر عند التفعيل)
          if (showRichContext)
            _buildRichContext(context, ref, item, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildRichContext(BuildContext context, WidgetRef ref, UnifiedAgendaItem item, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.primaryNavy : AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // تفاصيل الملف المرتبط
          if (item.entityId != null && item.entityType != null)
            _buildFileContext(context, ref, item, isDarkMode),
          
          const SizedBox(height: 12),
          
          // المستندات المرتبطة
          _buildDocumentsContext(item, isDarkMode),
          
          const SizedBox(height: 12),
          
          // المواعيد السابقة
          _buildPreviousAppointmentsContext(item, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildFileContext(BuildContext context, WidgetRef ref, UnifiedAgendaItem item, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description, size: 16, color: isDarkMode ? const Color(0xFF8899AA) : const Color(0xFF4A6274)),
            const SizedBox(width: 8),
            Text(
              'تفاصيل الملف',
              style: AppTextStyles.labelSmall.copyWith(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C3E50) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رقم الملف: ${item.entityId ?? "غير محدد"}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDarkMode ? const Color(0xFFAABBCC) : const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'نوع الكيان: ${item.entityType ?? "غير محدد"}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDarkMode ? const Color(0xFFAABBCC) : const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsContext(UnifiedAgendaItem item, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file, size: 16, color: isDarkMode ? const Color(0xFF8899AA) : const Color(0xFF4A6274)),
            const SizedBox(width: 8),
            Text(
              'المستندات المرتبطة',
              style: AppTextStyles.labelSmall.copyWith(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C3E50) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'لا توجد مستندات مرتبطة حالياً',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDarkMode ? const Color(0xFF8899AA) : AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviousAppointmentsContext(UnifiedAgendaItem item, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 16, color: isDarkMode ? const Color(0xFF8899AA) : const Color(0xFF4A6274)),
            const SizedBox(width: 8),
            Text(
              'المواعيد السابقة',
              style: AppTextStyles.labelSmall.copyWith(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C3E50) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'لا توجد مواعيد سابقة مسجلة',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDarkMode ? const Color(0xFF8899AA) : AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getPriorityIcon(AgendaItemType type) {
    switch (type) {
      case AgendaItemType.session:
        return Icons.priority_high;
      case AgendaItemType.companyPhase:
        return Icons.business_center;
      case AgendaItemType.contractReminder:
        return Icons.description;
      case AgendaItemType.task:
        return Icons.task_alt;
    }
  }

  Color _getPriorityColor(AgendaItemType type) {
    switch (type) {
      case AgendaItemType.session:
        return AppColors.error;
      case AgendaItemType.companyPhase:
        return AppColors.warning;
      case AgendaItemType.contractReminder:
        return AppColors.warning;
      case AgendaItemType.task:
        return AppColors.info;
    }
  }

  void _showQuickAdd(BuildContext context) {
    // يوجه لشاشة عمل جديد — لا SnackBar وهمي
    context.go('/new-work');
  }

  Widget _buildWeeklyView(BuildContext context, WidgetRef ref, AsyncValue<List<UnifiedAgendaItem>> agendaAsync) {
    return agendaAsync.when(
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
          itemBuilder: (context, index) => _buildAgendaItem(context, ref, items[index]),
        );
      },
    );
  }

  Widget _buildMonthlyView(BuildContext context, WidgetRef ref, DateTime selectedDate) {
    final monthlyAsync = ref.watch(monthlyAgendaProvider(selectedDate));

    // أسماء الأيام (السبت أولاً — الأسبوع العربي)
    const dayNames = ['سبت', 'أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع'];

    return monthlyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('خطأ في جلب البيانات: $err')),
      data: (monthlyItems) {
        final firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
        final lastDay = DateTime(selectedDate.year, selectedDate.month + 1, 0);
        final daysInMonth = lastDay.day;
        // تحويل weekday (Mon=1..Sun=7) إلى فهرس الشبكة (Sat=0..Fri=6)
        final startOffset = (firstDay.weekday + 1) % 7;
        final totalCells = startOffset + daysInMonth;
        final rows = (totalCells / 7).ceil();

        final now = DateTime.now();
        final todayNorm = DateTime(now.year, now.month, now.day);

        return Column(
          children: [
            // صف أسماء الأيام
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: dayNames.map((name) => Expanded(
                  child: Center(
                    child: Text(name, style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.secondaryGold,
                      fontWeight: FontWeight.bold,
                    )),
                  ),
                )).toList(),
              ),
            ),
            // شبكة الأيام
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.6,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: rows * 7,
                itemBuilder: (context, index) {
                  final dayNum = index - startOffset + 1;

                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox.shrink();
                  }

                  final date = DateTime(selectedDate.year, selectedDate.month, dayNum);
                  final dayItems = monthlyItems[date] ?? [];
                  final isToday = date == todayNorm;
                  final isSelected = date.year == selectedDate.year &&
                      date.month == selectedDate.month &&
                      date.day == selectedDate.day;

                  return InkWell(
                    onTap: () => ref.read(selectedAgendaDateProvider.notifier).state = date,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryNavy.withOpacity(0.12)
                            : (isToday ? AppColors.secondaryGold.withOpacity(0.08) : AppColors.cardBackground),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryNavy
                              : (isToday ? AppColors.secondaryGold : AppColors.cardBorder),
                          width: isSelected ? 2 : (isToday ? 1.5 : 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // رقم اليوم + عداد
                          Row(
                            children: [
                              Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: isToday ? AppColors.secondaryGold : (isSelected ? AppColors.primaryNavy : Colors.transparent),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text('$dayNum', style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: (isToday || isSelected) ? Colors.white : AppColors.textPrimary,
                                  )),
                                ),
                              ),
                              const Spacer(),
                              if (dayItems.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryNavy.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${dayItems.length}', style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryNavy,
                                  )),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // عناصر اليوم (عناوين مختصرة ملونة)
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              children: dayItems.take(3).map((item) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 1),
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: item.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border(
                                      right: BorderSide(color: item.color, width: 2),
                                    ),
                                  ),
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 8, color: item.color, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          if (dayItems.length > 3)
                            Text('+${dayItems.length - 3}', style: TextStyle(
                              fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.bold,
                            )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthSelector(BuildContext context, WidgetRef ref, DateTime currentDate) {
    final isDarkMode = ref.watch(darkModeProvider);
    final arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    return Container(
      color: isDarkMode ? AppColors.primaryNavy : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final newDate = DateTime(currentDate.year, currentDate.month - 1, 1);
              ref.read(selectedAgendaDateProvider.notifier).state = newDate;
            },
          ),
          Text(
            '${arabicMonths[currentDate.month - 1]} ${currentDate.year}',
            style: AppTextStyles.headline6.copyWith(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final newDate = DateTime(currentDate.year, currentDate.month + 1, 1);
              ref.read(selectedAgendaDateProvider.notifier).state = newDate;
            },
          ),
        ],
      ),
    );
  }

  void _navigateToRelatedFile(BuildContext context, UnifiedAgendaItem item) {
    if (item.entityId == null || item.entityType == null) return;
    
    // التنقل بناءً على نوع الكيان
    switch (item.entityType) {
      case 'case':
        context.go('/cases/${item.entityId}');
        break;
      case 'contract':
        context.go('/contracts/${item.entityId}');
        break;
      case 'company':
        context.go('/companies/${item.entityId}');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('التنقل إلى ${item.entityType} غير مدعوم حالياً')),
        );
    }
  }

  Future<void> _saveDarkModePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDarkMode);
  }

  Future<bool> _loadDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('darkMode') ?? false;
  }

  /// توليد المهام المتكررة (جلسات دورية، تذكيرات عقود، مراحل شركات).
  ///
  /// إجراء صريح بطلب المستخدم لا تلقائي عند الإقلاع: العملية تنشئ
  /// سجلات فعلية في قاعدة البيانات، وتشغيلها الصامت يملأ الأجندة
  /// بمهام لم يطلبها أحد.
  Future<void> _runAutomation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('توليد المهام المتكررة'),
        content: const Text(
          'سيفحص النظام الجلسات الدورية، والعقود التي تقترب من الانتهاء، '
          'ومراحل الشركات المستحقة، ثم ينشئ مهام الأجندة المقابلة.\n\n'
          'قد تُضاف مهام جديدة إلى جدولك. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('توليد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جارٍ توليد المهام المتكررة...')),
      );
    }

    try {
      await AutomationService().autoRecurringAppointments(
        db: ref.read(databaseProvider),
        currentDate: DateTime.now(),
      );
      ref.invalidate(unifiedAgendaFromDBProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتمل توليد المهام المتكررة.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر توليد المهام: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _enableSmartNotifications(BuildContext context, WidgetRef ref) async {
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    // إرسال ملخص اليوم كإشعار تجريبي
    final agendaAsync = ref.read(unifiedAgendaProvider);
    agendaAsync.whenData((items) async {
      final totalCount = items.length;
      final completedCount = items.where((item) => item.statusIndex == LifecycleStatus.completed.index).length;
      final pendingCount = totalCount - completedCount;
      
      await notificationService.sendDailySummaryNotification(
        totalAppointments: totalCount,
        completedCount: completedCount,
        pendingCount: pendingCount,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تفعيل الإشعارات الذكية وإرسال ملخص اليوم')),
        );
      }
    });
  }

  Future<void> _exportReport(BuildContext context, WidgetRef ref) async {
    final reportService = ReportService();
    final selectedDate = ref.read(selectedAgendaDateProvider);
    final agendaAsync = ref.read(unifiedAgendaProvider);
    
    // عرض خيارات التصدير
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تصدير التقرير'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('تصدير إلى PDF'),
              onTap: () async {
                Navigator.pop(context);
                
                agendaAsync.whenData((items) async {
                  final appointments = items.map((item) => {
                    'time': item.timeString,
                    'title': item.title,
                    'type': item.type.toString(),
                    'status': item.statusIndex == 0 ? 'مجدول' : 'منجز',
                  }).toList();
                  
                  await reportService.exportDailyAgendaToPDF(
                    appointments: appointments,
                    date: selectedDate,
                  );
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تصدير التقرير إلى PDF')),
                    );
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('تصدير إلى CSV'),
              onTap: () async {
                Navigator.pop(context);
                
                agendaAsync.whenData((items) async {
                  final appointments = items.map((item) => {
                    'time': item.timeString,
                    'title': item.title,
                    'type': item.type.toString(),
                    'status': item.statusIndex == 0 ? 'مجدول' : 'منجز',
                  }).toList();
                  
                  await reportService.exportToCSV(
                    data: appointments,
                    fileName: 'تقرير_المواعيد_${'${selectedDate.year}_${selectedDate.month.toString().padLeft(2, '0')}_${selectedDate.day.toString().padLeft(2, '0')}'}',
                  );
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تصدير التقرير إلى CSV')),
                    );
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCollaborationMenu(
      BuildContext context, WidgetRef ref, UnifiedAgendaItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'خيارات المشاركة',
              style: AppTextStyles.headline6.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('تعيين موظف'),
              subtitle: const Text('تعيين موظف مسؤول عن هذا الموعد'),
              onTap: () {
                Navigator.pop(context);
                _showAssignStaffDialog(context, ref, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('إضافة ملاحظة مشتركة'),
              subtitle: const Text('إضافة ملاحظة يمكن للموظفين رؤيتها'),
              onTap: () {
                Navigator.pop(context);
                _showSharedNoteDialog(context, ref, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('سجل التغييرات'),
              subtitle: const Text('عرض سجل التغييرات لهذا الموعد'),
              onTap: () {
                Navigator.pop(context);
                _showChangeHistoryDialog(context, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// معرّف المهمة الحقيقي من معرّف عنصر الأجندة (task_<id>).
  /// يرجع null لعناصر ليست مهام (جلسات مثلاً) فلا تُحفظ عليها.
  int? _taskIdOf(UnifiedAgendaItem item) {
    if (!item.id.startsWith('task_')) return null;
    return int.tryParse(item.id.substring('task_'.length));
  }

  void _showAssignStaffDialog(
      BuildContext context, WidgetRef ref, UnifiedAgendaItem item) {
    final TextEditingController staffController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعيين موظف'),
        content: TextField(
          controller: staffController,
          decoration: const InputDecoration(
            labelText: 'اسم الموظف',
            hintText: 'أدخل اسم الموظف المسؤول',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final name = staffController.text.trim();
              if (name.isEmpty) return;

              final taskId = _taskIdOf(item);
              if (taskId == null) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تعيين الموظف متاح للمهام فقط، لا للجلسات.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              // الحفظ الفعلي: سابقاً كان الزر يعرض رسالة نجاح فقط
              // ويضيع التعيين عند إغلاق النافذة.
              try {
                final db = ref.read(databaseProvider);
                await TaskDao(db).assignTask(taskId, assignedTo: name);
                ref.invalidate(unifiedAgendaFromDBProvider);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم تعيين $name للموعد: ${item.title}'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تعذّر حفظ التعيين: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showSharedNoteDialog(
      BuildContext context, WidgetRef ref, UnifiedAgendaItem item) {
    final TextEditingController noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة ملاحظة مشتركة'),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'الملاحظة',
            hintText: 'أدخل ملاحظة مشتركة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final note = noteController.text.trim();
              if (note.isEmpty) return;

              final taskId = _taskIdOf(item);
              if (taskId == null) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الملاحظات متاحة للمهام فقط، لا للجلسات.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              try {
                final db = ref.read(databaseProvider);
                await TaskDao(db).assignTask(taskId, notes: note);
                ref.invalidate(unifiedAgendaFromDBProvider);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حفظ الملاحظة للموعد: ${item.title}'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تعذّر حفظ الملاحظة: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showChangeHistoryDialog(BuildContext context, UnifiedAgendaItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سجل التغييرات'),
        content: SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 48, color: const Color(0xFF8899AA)),
                const SizedBox(height: 16),
                Text(
                  'لا توجد تغييرات مسجلة',
                  style: AppTextStyles.bodySmallSecondary,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
