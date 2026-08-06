import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../../data/database/database.dart' as db;
import '../../providers/auth_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';
import '../../theme/app_theme.dart';
import '../agenda/result_entry_dialog.dart';
import '../cases/case_models.dart';
import '../persons/person_models.dart' show PersonDirectoryRole;
import '../work_orders/work_order_dialogs.dart';
import '../work_orders/work_order_models.dart';

class DailyWorkCenterScreen extends ConsumerStatefulWidget {
  const DailyWorkCenterScreen({super.key});

  @override
  ConsumerState<DailyWorkCenterScreen> createState() => _DailyWorkCenterScreenState();
}

class _DailyWorkCenterScreenState extends ConsumerState<DailyWorkCenterScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  DateTime _calendarDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.cardBackground,
          appBar: AppBar(
            title: const Text('مكتب العمل'),
            actions: [
              _AddWorkButton(),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'طباعة لائحة العمل',
                icon: const Icon(Icons.print),
                onPressed: () => _showPrintOptions(context),
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              indicatorColor: AppColors.secondaryGold,
              labelColor: AppColors.secondaryGold,
              unselectedLabelColor: AppColors.textOnLight.withOpacity(0.75),
              tabs: const [
                Tab(text: 'اليوم'),
                Tab(text: 'الغد'),
                Tab(text: 'الأسبوع'),
                Tab(text: 'التقويم'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _DayWorkView(day: DateTime.now(), mode: _WorkViewMode.today),
              _DayWorkView(day: DateTime.now().add(const Duration(days: 1)), mode: _WorkViewMode.tomorrow),
              _WeekWorkView(startDay: DateTime.now()),
              _CalendarWorkView(
                selectedDay: _calendarDay,
                onChanged: (d) => setState(() => _calendarDay = d),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({String title, DateTime date, List<_WorkItem> items}) _currentWorkListData() {
    final index = _tabs.index;
    if (index == 0) {
      final date = DateTime.now();
      return (title: 'لائحة عمل اليوم', date: date, items: _collectItemsForDay(context, ref, date, includeAttention: true));
    }
    if (index == 1) {
      final date = DateTime.now().add(const Duration(days: 1));
      return (title: 'لائحة عمل الغد', date: date, items: _collectItemsForDay(context, ref, date));
    }
    if (index == 2) {
      final date = DateTime.now();
      final items = <_WorkItem>[];
      for (var i = 0; i < 7; i++) {
        items.addAll(_collectItemsForDay(context, ref, DateTime.now().add(Duration(days: i))));
      }
      return (title: 'لائحة عمل الأسبوع', date: date, items: items);
    }
    return (
      title: 'لائحة عمل يوم ${_date(_calendarDay)}',
      date: _calendarDay,
      items: _collectItemsForDay(context, ref, _calendarDay),
    );
  }

  Future<void> _showPrintOptions(BuildContext context) async {
    final data = _currentWorkListData();
    final assignees = <String>{'all', ...data.items.map((i) => i.assignedTo.trim()).where((v) => v.isNotEmpty)}.toList();
    final types = <String>{'all', ...data.items.map((i) => i.type)}.toList();
    String assignee = 'all';
    String type = 'all';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final filtered = data.items.where((i) {
            final assigneeOk = assignee == 'all' || i.assignedTo == assignee;
            final typeOk = type == 'all' || i.type == type;
            return assigneeOk && typeOk;
          }).toList();
          return AlertDialog(
            title: const Text('طباعة لائحة العمل'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data.title, style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: assignee,
                    decoration: const InputDecoration(labelText: 'المكلف'),
                    items: assignees
                        .map((a) => DropdownMenuItem(value: a, child: Text(a == 'all' ? 'كل المكلفين' : a)))
                        .toList(),
                    onChanged: (v) => setDialog(() => assignee = v ?? 'all'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'نوع العمل'),
                    items: types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t == 'all' ? 'كل الأنواع' : t)))
                        .toList(),
                    onChanged: (v) => setDialog(() => type = v ?? 'all'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('عدد العناصر في اللائحة: ${filtered.length}', style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('تصدير PDF'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _exportWorkList(data.title, data.date, filtered);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportWorkList(String title, DateTime date, List<_WorkItem> items) async {
    final bytes = await _DailyWorkPdfBuilder.build(title: title, date: date, items: items);
    await ref.read(auditServiceProvider).log(
      action: 'print',
      category: 'daily_work',
      entityType: 'work_list',
      entityTitle: title,
      description: 'طباعة/تصدير لائحة عمل من مكتب العمل',
      after: {'count': items.length, 'date': date.toIso8601String()},
      severity: 'info',
    );
    await Printing.sharePdf(bytes: bytes, filename: 'daily_work_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

enum _WorkViewMode { today, tomorrow, week, calendar }

class _WorkItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String entityRoute;
  final String assignedTo;
  final DateTime date;
  final TimeOfDay? time;
  final Color color;
  final IconData icon;
  final String priority;
  final String status;
  final bool needsResult;
  final VoidCallback? onResult;

  /// إجراء التحضير/التعيين في تبويب الغد. يبقى null للعناصر غير القابلة للتعيين.
  final VoidCallback? onPrepare;

  const _WorkItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.entityRoute,
    required this.assignedTo,
    required this.date,
    this.time,
    required this.color,
    required this.icon,
    this.priority = 'عادية',
    this.status = 'مجدول',
    this.needsResult = false,
    this.onResult,
    this.onPrepare,
  });
}

class _DayWorkView extends ConsumerWidget {
  final DateTime day;
  final _WorkViewMode mode;
  const _DayWorkView({required this.day, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _collectItemsForDay(context, ref, day, includeAttention: mode == _WorkViewMode.today);
    return _WorkList(
      title: mode == _WorkViewMode.today ? 'أعمال اليوم — إدخال النتائج' : 'أعمال الغد — التحضير والتوزيع',
      subtitle: mode == _WorkViewMode.today
          ? 'كل ما تاريخه اليوم يظهر هنا حسب صلاحياتك لإدخال النتائج والمتابعة.'
          : 'جهّز ملفات الغد ووزّع العمل قبل موعده.',
      day: day,
      items: items,
      mode: mode,
    );
  }
}

class _WeekWorkView extends ConsumerWidget {
  final DateTime startDay;
  const _WeekWorkView({required this.startDay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = <_WorkItem>[];
    for (var i = 0; i < 7; i++) {
      final day = DateTime(startDay.year, startDay.month, startDay.day).add(Duration(days: i));
      all.addAll(_collectItemsForDay(context, ref, day));
    }
    return _WorkList(
      title: 'أعمال الأسبوع',
      subtitle: 'رؤية قريبة للأعمال القادمة خلال سبعة أيام.',
      day: startDay,
      items: all,
      mode: _WorkViewMode.week,
      groupByDay: true,
    );
  }
}

class _CalendarWorkView extends StatelessWidget {
  final DateTime selectedDay;
  final ValueChanged<DateTime> onChanged;
  const _CalendarWorkView({required this.selectedDay, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 360,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: CalendarDatePicker(
              initialDate: selectedDay,
              firstDate: DateTime(DateTime.now().year - 5),
              lastDate: DateTime(DateTime.now().year + 5),
              onDateChanged: onChanged,
            ),
          ),
        ),
        Expanded(
          child: _DayWorkView(day: selectedDay, mode: _WorkViewMode.calendar),
        ),
      ],
    );
  }
}

class _WorkList extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime day;
  final List<_WorkItem> items;
  final _WorkViewMode mode;
  final bool groupByDay;

  const _WorkList({
    required this.title,
    required this.subtitle,
    required this.day,
    required this.items,
    required this.mode,
    this.groupByDay = false,
  });

  @override
  Widget build(BuildContext context) {
    final attention = items.where((i) => i.priority == 'حرجة' || i.status.contains('متأخر') || i.type == 'نقص').toList();
    final regular = items.where((i) => !attention.contains(i)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: title, subtitle: subtitle, items: items),
        Expanded(
          child: items.isEmpty
              ? _empty(context)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (attention.isNotEmpty) ...[
                      _sectionTitle('يحتاج انتباه', AppColors.error),
                      ...attention.map((i) => _WorkItemCard(item: i, mode: mode)),
                      const SizedBox(height: 12),
                    ],
                    if (groupByDay)
                      ..._groupedByDate(regular)
                    else
                      ..._groupedByType(regular),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('لا توجد أعمال ضمن هذا اليوم', style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
            const SizedBox(height: 8),
            Text('ستظهر هنا الجلسات والمراجعات وأوامر العمل والنواقص والمهام حسب تاريخها.', style: AppTextStyles.bodySmallSecondary, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/new-work'),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('إنشاء عمل جديد', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: AppColors.secondaryGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupedByType(List<_WorkItem> source) {
    final order = ['جلسة', 'تحضير', 'إجراء', 'أمر عمل', 'نقص', 'مهمة'];
    final widgets = <Widget>[];
    for (final type in order) {
      final group = source.where((i) => i.type == type).toList();
      if (group.isEmpty) continue;
      widgets.add(_sectionTitle(_labelForType(type), group.first.color));
      widgets.addAll(group.map((i) => _WorkItemCard(item: i, mode: mode)));
      widgets.add(const SizedBox(height: 10));
    }
    final rest = source.where((i) => !order.contains(i.type)).toList();
    if (rest.isNotEmpty) {
      widgets.add(_sectionTitle('أعمال أخرى', AppColors.primaryNavy));
      widgets.addAll(rest.map((i) => _WorkItemCard(item: i, mode: mode)));
    }
    return widgets;
  }

  List<Widget> _groupedByDate(List<_WorkItem> source) {
    final days = <String, List<_WorkItem>>{};
    for (final item in source) {
      final key = _date(item.date);
      days.putIfAbsent(key, () => []).add(item);
    }
    final widgets = <Widget>[];
    for (final entry in days.entries) {
      widgets.add(_sectionTitle(entry.key, AppColors.primaryNavy));
      widgets.addAll(entry.value.map((i) => _WorkItemCard(item: i, mode: mode)));
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Widget _sectionTitle(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text, style: AppTextStyles.headline6.copyWith(color: color, fontWeight: FontWeight.bold)),
      );

  String _labelForType(String type) {
    switch (type) {
      case 'جلسة':
        return 'الجلسات';
      case 'تحضير':
        return 'تحضيرات ومراجعات';
      case 'إجراء':
        return 'الإجراءات والمعاملات';
      case 'أمر عمل':
        return 'أوامر العمل';
      case 'نقص':
        return 'النواقص';
      case 'مهمة':
        return 'مهام مخصصة';
      default:
        return type;
    }
  }

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_WorkItem> items;
  const _Header({required this.title, required this.subtitle, required this.items});

  @override
  Widget build(BuildContext context) {
    final sessions = items.where((i) => i.type == 'جلسة').length;
    final workOrders = items.where((i) => i.type == 'أمر عمل').length;
    final deficiencies = items.where((i) => i.type == 'نقص').length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headline5.copyWith(color: AppColors.primaryNavy)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
          _metric('الأعمال', items.length, Icons.task_alt, AppColors.primaryNavy),
          const SizedBox(width: 8),
          _metric('جلسات', sessions, Icons.gavel, AppColors.secondaryGold),
          const SizedBox(width: 8),
          _metric('أوامر', workOrders, Icons.assignment_ind, AppColors.primaryNavy),
          const SizedBox(width: 8),
          _metric('نواقص', deficiencies, Icons.warning_amber, AppColors.secondaryGold),
        ],
      ),
    );
  }

  Widget _metric(String label, int count, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: color), const SizedBox(width: 5), Text('$label: $count')]),
      );
}

class _WorkItemCard extends StatelessWidget {
  final _WorkItem item;
  final _WorkViewMode mode;
  const _WorkItemCard({required this.item, required this.mode});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: item.color.withOpacity(0.12), child: Icon(item.icon, color: item.color)),
                const SizedBox(width: 10),
                Expanded(child: Text(item.title, style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.bold))),
                _tag(item.type, item.color),
                const SizedBox(width: 6),
                _tag(item.status, AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.subtitle, style: AppTextStyles.bodySmallSecondary),
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _mini(Icons.event, _date(item.date)),
                if (item.time != null) _mini(Icons.access_time, item.time!.format(context)),
                _mini(Icons.person, item.assignedTo.isEmpty ? 'غير مكلف' : item.assignedTo),
                _mini(Icons.flag, item.priority),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (item.entityRoute.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('فتح الملف'),
                    onPressed: () => context.go(item.entityRoute),
                  ),
                if (item.needsResult && mode == _WorkViewMode.today && item.onResult != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.fact_check, size: 16),
                    label: const Text('إدخال نتيجة'),
                    onPressed: item.onResult,
                  ),
                if (mode == _WorkViewMode.tomorrow && item.onPrepare != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.assignment_ind, size: 16),
                    label: const Text('تعيين / تحضير'),
                    onPressed: item.onPrepare,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
      );

  Widget _mini(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 15, color: AppColors.textSecondary), const SizedBox(width: 4), Text(text, style: AppTextStyles.bodySmallSecondary)],
      );

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _AddWorkButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    return PopupMenuButton<String>(
      tooltip: 'إنشاء جديد',
      onSelected: (value) {
        switch (value) {
          case 'case':
            context.push('/cases/create');
            break;
          case 'procedure':
            context.push('/procedures/create');
            break;
          case 'company':
            context.push('/companies/create');
            break;
          case 'contract':
            context.push('/contracts/create');
            break;
          case 'work_order':
            showDialog(context: context, builder: (_) => const CreateWorkOrderDialog());
            break;
          case 'manual':
            showDialog(context: context, builder: (_) => const _ManualTaskDialog());
            break;
        }
      },
      itemBuilder: (_) => [
        if (permissions.can(PermissionKeys.casesCreateNew)) const PopupMenuItem(value: 'case', child: Text('دعوى جديدة')),
        if (permissions.can(PermissionKeys.proceduresCreate)) const PopupMenuItem(value: 'procedure', child: Text('إجراء / معاملة')),
        if (permissions.can(PermissionKeys.companiesCreate)) const PopupMenuItem(value: 'company', child: Text('شركة')),
        if (permissions.can(PermissionKeys.contractsCreate)) const PopupMenuItem(value: 'contract', child: Text('عقد')),
        if (permissions.can(PermissionKeys.workOrdersCreate)) const PopupMenuItem(value: 'work_order', child: Text('أمر عمل')),
        if (permissions.can(PermissionKeys.tasksCreate)) const PopupMenuItem(value: 'manual', child: Text('مهمة مخصصة')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton.icon(
          onPressed: () {}, // no-op — PopupMenuButton يلتقط الضغط
          icon: const Icon(Icons.add),
          label: const Text('إنشاء جديد'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryGold,
            foregroundColor: AppColors.primaryNavy,
          ),
        ),
      ),
    );
  }
}

List<_WorkItem> _collectItemsForDay(BuildContext context, WidgetRef ref, DateTime day, {bool includeAttention = false}) {
  final permissions = ref.watch(permissionServiceProvider);
  final items = <_WorkItem>[];

  bool sameDay(DateTime d) => d.year == day.year && d.month == day.month && d.day == day.day;

  if (permissions.can(PermissionKeys.casesView)) {
    final cases = ref.watch(uiCasesProvider).maybeWhen(data: (v) => v, orElse: () => const []);
    for (final c in cases) {
      for (final s in c.sessions) {
        if (sameDay(s.sessionDate)) {
          items.add(_WorkItem(
            id: 'session_${s.id}',
            type: 'جلسة',
            title: 'جلسة: ${c.caseNumber}',
            subtitle: '${c.title} • ${s.court}',
            entityRoute: '/cases/${c.id}',
            assignedTo: '',
            date: s.sessionDate,
            time: s.sessionTime,
            color: AppColors.primaryNavy,
            icon: Icons.gavel,
            priority: c.status == CaseStatus.completed ? 'عادية' : 'هامة',
            status: s.status.displayName,
            needsResult: permissions.can(PermissionKeys.casesResultEnter),
            // إدخال نتيجة الجلسة فعلياً من مكتب العمل، مع تمرير سياق الدعوى
            // حتى تُحدَّث الجلسة والنواقص وموعد الجلسة القادمة.
            onResult: () => showDialog<void>(
              context: context,
              builder: (_) => ResultEntryDialog(
                entityId: int.tryParse(c.id),
                entityType: 'case',
                initialTitle: 'نتيجة جلسة ${c.caseNumber}',
              ),
            ),
          ));
        }
      }
    }
  }

  final tasks = ref.watch(tasksByDateProvider(day)).maybeWhen(data: (v) => v, orElse: () => const <db.DailyTask>[]);
  for (final t in tasks) {
    final allowed = switch (t.taskType) {
      'work_order_followup' => permissions.can(PermissionKeys.workOrdersView),
      'contract_reminder' => permissions.can(PermissionKeys.contractsView),
      'company_phase' => permissions.can(PermissionKeys.companiesView),
      'admin_step' => permissions.can(PermissionKeys.proceduresView),
      'session' => permissions.can(PermissionKeys.casesView),
      _ => true,
    };
    if (!allowed) continue;
    items.add(_WorkItem(
      id: 'task_${t.id}',
      type: _taskTypeLabel(t.taskType),
      title: t.title,
      subtitle: t.notes ?? t.taskType,
      entityRoute: _taskRoute(t),
      assignedTo: t.assignedTo ?? '',
      date: t.taskDate,
      time: _parseTime(t.taskTime),
      color: _taskColor(t.taskType),
      icon: _taskIcon(t.taskType),
      priority: t.priority >= 2 ? 'حرجة' : 'عادية',
      status: t.status == 2 ? 'تم' : 'مجدول',
      needsResult: permissions.can(PermissionKeys.tasksResultEnter),
      onResult: () => _showTaskResultDialog(context, ref, t),
      onPrepare: permissions.can(PermissionKeys.tasksAssign)
          ? () => _showPrepareTaskDialog(context, ref, t)
          : null,
    ));
  }

  if (permissions.can(PermissionKeys.workOrdersView)) {
    final workOrders = ref.watch(uiWorkOrdersProvider).maybeWhen(data: (v) => v, orElse: () => const <WorkOrder>[]);
    for (final w in workOrders) {
      if (!sameDay(w.dueDate)) continue;
      items.add(_WorkItem(
        id: 'wo_${w.id}',
        type: 'أمر عمل',
        title: '${w.internalNumber} — ${w.orderTypeText}',
        subtitle: '${w.instructions} • المكلف: ${w.assignedToName}',
        entityRoute: '/work-orders',
        assignedTo: w.assignedToName,
        date: w.dueDate,
        color: AppColors.success,
        icon: Icons.assignment_ind,
        priority: w.priorityText,
        status: w.statusText,
        needsResult: permissions.can(PermissionKeys.workOrdersResultEnter),
        onResult: () => showDialog(context: context, builder: (_) => EnterWorkOrderResultDialog(workOrder: w)),
      ));
    }
  }

  if (includeAttention) {
    final deficiencies = ref.watch(openDeficienciesProvider(null)).maybeWhen(data: (v) => v, orElse: () => const <db.Deficiency>[]);
    for (final d in deficiencies.take(8)) {
      final allowed = d.entityType == 0 ? permissions.can(PermissionKeys.casesView) : true;
      if (!allowed) continue;
      items.add(_WorkItem(
        id: 'def_${d.id}',
        type: 'نقص',
        title: d.description,
        subtitle: d.fieldName,
        entityRoute: _deficiencyRoute(d.entityType, d.entityId),
        assignedTo: '',
        date: day,
        color: AppColors.error,
        icon: Icons.warning_amber,
        priority: 'حرجة',
        status: 'مفتوح',
        needsResult: true,
        onResult: () => _showDeficiencyResultDialog(context, ref, d),
      ));
    }
  }

  items.sort((a, b) {
    final at = a.time == null ? 9999 : a.time!.hour * 60 + a.time!.minute;
    final bt = b.time == null ? 9999 : b.time!.hour * 60 + b.time!.minute;
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : at.compareTo(bt);
  });
  return items;
}

/// تحضير مهمة الغد: تعيين المكلف وإضافة ملاحظة تحضير.
///
/// ينفذ البند 22 من خطة مكتب العمل (توزيع العمل وتأكيد المكلفين).
Future<void> _showPrepareTaskDialog(BuildContext context, WidgetRef ref, db.DailyTask task) async {
  final assignee = TextEditingController(text: task.assignedTo ?? '');
  final notes = TextEditingController(text: task.notes ?? '');

  // أسماء فريق المكتب تُقترح من الدليل المركزي، مع إبقاء الإدخال الحر متاحاً
  // للمكلفين من خارج المكتب (معقب، مندوب).
  final teamNames = ref
      .read(uiPersonsDirectoryProvider)
      .maybeWhen(
        data: (state) => state.persons
            .where((p) => p.roles.contains(PersonDirectoryRole.teamMember))
            .map((p) => p.fullName)
            .toList(),
        orElse: () => const <String>[],
      );

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تعيين وتحضير مهمة الغد'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: AppTextStyles.labelLarge),
              const SizedBox(height: 12),
              TextField(
                controller: assignee,
                decoration: const InputDecoration(
                  labelText: 'المكلف بالتنفيذ',
                  helperText: 'اسم من فريق المكتب أو مكلف خارجي',
                ),
              ),
              if (teamNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: teamNames
                      .take(8)
                      .map((name) => ActionChip(
                            label: Text(name),
                            onPressed: () => assignee.text = name,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظة تحضير'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () async {
            final userRef = ref.read(authControllerProvider).user?.fullName ?? 'المكتب';
            await ref.read(taskRepositoryProvider).assignTask(
                  taskId: task.id,
                  assignedTo: assignee.text.trim(),
                  preparationNotes: notes.text.trim(),
                  userRef: userRef,
                );
            await ref.read(auditServiceProvider).log(
                  action: 'assign',
                  category: 'daily_work',
                  entityType: 'daily_task',
                  entityId: '${task.id}',
                  entityTitle: task.title,
                  description: 'تعيين وتحضير مهمة الغد',
                  after: {'assignedTo': assignee.text.trim(), 'notes': notes.text.trim()},
                  severity: 'info',
                );
            ref.invalidate(tasksByDateProvider(task.taskDate));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('حفظ التحضير'),
        ),
      ],
    ),
  );
}

/// معالجة نقص من مكتب العمل:
/// - "استكمال" → يفتح ملف الكيان المرتبط (الدعوى/العقد/الشركة) لتعبئة النقص من مصدره
/// - "تجاهل" → يتطلب سبباً مسجلاً
Future<void> _showDeficiencyResultDialog(BuildContext context, WidgetRef ref, db.Deficiency deficiency) async {
  final reason = TextEditingController();
  final entityRoute = _deficiencyRoute(deficiency.entityType, deficiency.entityId);
  final entityLabel = switch (deficiency.entityType) {
    0 => 'الدعوى',
    1 => 'العقد',
    2 => 'الشركة',
    3 => 'الإجراء',
    4 => 'الشخص',
    5 => 'الوكالة',
    _ => 'الملف',
  };

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: AppColors.secondaryGold, size: 24),
          const SizedBox(width: 8),
          const Text('معالجة نقص'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // وصف النقص
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deficiency.description, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('الحقل: ${deficiency.fieldName}', style: AppTextStyles.bodySmallSecondary),
                Text('الملف: $entityLabel', style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // خيار الاستكمال
          if (entityRoute.isNotEmpty)
            Text('الطريقة الصحيحة لمعالجة هذا النقص هي فتح $entityLabel وتعبئة البيانات الناقصة.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          // خيار التجاهل
          Text('أو يمكنك تجاهل هذا النقص مع تسجيل السبب:', style: AppTextStyles.bodySmallSecondary),
          const SizedBox(height: 8),
          TextField(
            controller: reason,
            decoration: InputDecoration(
              labelText: 'سبب التجاهل',
              hintText: 'مثال: تم استكماله خارج النظام',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        TextButton(
          onPressed: () async {
            final text = reason.text.trim();
            if (text.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: const Text('اكتب سبب التجاهل أولاً'), backgroundColor: AppColors.error),
              );
              return;
            }
            final userRef = ref.read(authControllerProvider).user?.fullName ?? 'المكتب';
            await ref.read(taskRepositoryProvider).ignoreDeficiency(deficiency.id, text, userRef);
            await ref.read(auditServiceProvider).log(
                  action: 'ignore', category: 'deficiencies', entityType: 'deficiency',
                  entityId: '${deficiency.id}', entityTitle: deficiency.description,
                  description: 'تجاهل نقص: $text', severity: 'warning',
                );
            ref.invalidate(openDeficienciesProvider(null));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('تجاهل'),
        ),
        if (entityRoute.isNotEmpty)
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text('فتح $entityLabel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: AppColors.secondaryGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go(entityRoute);
            },
          ),
      ],
    ),
  );
}

String _taskTypeLabel(String raw) {
  switch (raw) {
    case 'session':
      return 'جلسة';
    case 'contract_reminder':
      return 'تذكير عقد';
    case 'company_phase':
      return 'تحضير';
    case 'admin_step':
      return 'إجراء';
    case 'work_order_followup':
      return 'أمر عمل';
    default:
      return 'مهمة';
  }
}

IconData _taskIcon(String raw) {
  switch (raw) {
    case 'session':
      return Icons.gavel;
    case 'contract_reminder':
      return Icons.description;
    case 'company_phase':
      return Icons.business;
    case 'admin_step':
      return Icons.assignment;
    case 'work_order_followup':
      return Icons.assignment_ind;
    default:
      return Icons.task_alt;
  }
}

Color _taskColor(String raw) {
  switch (raw) {
    case 'session':
      return AppColors.primaryNavy;
    case 'contract_reminder':
      return AppColors.info;
    case 'company_phase':
      return AppColors.secondaryGold;
    case 'admin_step':
      return AppColors.warning;
    case 'work_order_followup':
      return AppColors.success;
    default:
      return AppColors.textSecondary;
  }
}

String _taskRoute(db.DailyTask t) {
  switch (t.sourceType) {
    case 'cases':
      return '/cases/${t.sourceId ?? 0}';
    case 'contracts':
      return '/contracts/${t.sourceId ?? 0}';
    case 'companies':
      return '/companies/${t.sourceId ?? 0}';
    case 'admin_procedures':
      return '/procedures/${t.sourceId ?? 0}';
    case 'work_order':
      return '/work-orders';
    default:
      return '';
  }
}

/// مسار فتح ملف النقص حسب نوع الكيان المرتبط
String _deficiencyRoute(int entityType, int entityId) {
  switch (entityType) {
    case 0: return '/cases/$entityId';
    case 1: return '/contracts/$entityId';
    case 2: return '/companies/$entityId';
    case 3: return '/procedures/$entityId';
    case 4: return '/persons/$entityId';
    case 5: return '/poa/$entityId';
    default: return '';
  }
}

TimeOfDay? _parseTime(String? raw) {
  if (raw == null || !raw.contains(':')) return null;
  final parts = raw.split(':');
  return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
}

Future<void> _showTaskResultDialog(BuildContext context, WidgetRef ref, db.DailyTask task) async {
  final reason = TextEditingController();
  DateTime newDate = task.taskDate.add(const Duration(days: 1));
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: Text('نتيجة المهمة: ${task.title}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(task.notes ?? 'اختر نتيجة المهمة المطلوبة.', style: AppTextStyles.bodySmallSecondary),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظة / سبب التأجيل أو الإلغاء'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('تاريخ التأجيل: ${_formatDateOnly(newDate)}')),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('اختيار'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: newDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked != null) setDialog(() => newDate = picked);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          TextButton.icon(
            icon: const Icon(Icons.block),
            label: const Text('إلغاء'),
            onPressed: () async {
              final note = reason.text.trim();
              if (note.isEmpty) return;
              await ref.read(taskRepositoryProvider).cancelTask(
                    taskId: task.id,
                    reason: note,
                    userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
                  );
              await ref.read(auditServiceProvider).log(action: 'cancel', category: 'daily_work', entityType: 'daily_task', entityId: '${task.id}', entityTitle: task.title, description: 'إلغاء مهمة من مكتب العمل', severity: 'warning');
              ref.invalidate(tasksByDateProvider(task.taskDate));
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: const Text('تأجيل'),
            onPressed: () async {
              final note = reason.text.trim();
              if (note.isEmpty) return;
              await ref.read(taskRepositoryProvider).postponeTask(
                    taskId: task.id,
                    newDate: newDate,
                    reason: note,
                    userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
                  );
              await ref.read(auditServiceProvider).log(action: 'postpone', category: 'daily_work', entityType: 'daily_task', entityId: '${task.id}', entityTitle: task.title, description: 'تأجيل مهمة من مكتب العمل', after: {'newDate': newDate.toIso8601String()}, severity: 'info');
              ref.invalidate(tasksByDateProvider(task.taskDate));
              ref.invalidate(tasksByDateProvider(newDate));
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('تم الإنجاز'),
            onPressed: () async {
              await ref.read(taskRepositoryProvider).completeTask(task.id, ref.read(authControllerProvider).user?.fullName ?? 'المكتب');
              await ref.read(auditServiceProvider).log(action: 'complete', category: 'daily_work', entityType: 'daily_task', entityId: '${task.id}', entityTitle: task.title, description: 'إنجاز مهمة من مكتب العمل', severity: 'info');
              ref.invalidate(tasksByDateProvider(task.taskDate));
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}

class _ManualTaskDialog extends ConsumerStatefulWidget {
  const _ManualTaskDialog();

  @override
  ConsumerState<_ManualTaskDialog> createState() => _ManualTaskDialogState();
}

class _ManualTaskDialogState extends ConsumerState<_ManualTaskDialog> {
  final _title = TextEditingController();
  final _assignedTo = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay? _time;
  int _priority = 1;

  @override
  void dispose() {
    _title.dispose();
    _assignedTo.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('مهمة مخصصة'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'عنوان المهمة *')),
              const SizedBox(height: 12),
              TextField(controller: _assignedTo, decoration: const InputDecoration(labelText: 'المكلف / جهة خارجية')),
              const SizedBox(height: 12),
              TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('التاريخ: ${_formatDateOnly(_date)}')),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('اختيار'),
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(DateTime.now().year + 5));
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('الوقت: ${_time == null ? 'بدون وقت' : _time!.format(context)}')),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: const Text('اختيار'),
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
                      if (picked != null) setState(() => _time = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'الأولوية'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('عادية')),
                  DropdownMenuItem(value: 2, child: Text('حرجة')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 1),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('حفظ'),
          onPressed: _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final timeValue = _time == null ? null : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    final id = await ref.read(taskRepositoryProvider).createManualTask(
          db.DailyTasksCompanion.insert(
            taskType: 'manual',
            title: title,
            taskDate: DateTime(_date.year, _date.month, _date.day),
            taskTime: Value(timeValue),
            assignedTo: Value(_assignedTo.text.trim().isEmpty ? null : _assignedTo.text.trim()),
            priority: Value(_priority),
            sourceType: const Value('manual'),
            notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
          ),
        );
    await ref.read(auditServiceProvider).log(action: 'create', category: 'daily_work', entityType: 'daily_task', entityId: '$id', entityTitle: title, description: 'إنشاء مهمة مخصصة من مكتب العمل', severity: 'info');
    ref.invalidate(tasksByDateProvider(_date));
    if (mounted) Navigator.pop(context);
  }
}

class _DailyWorkPdfBuilder {
  static Future<Uint8List> build({required String title, required DateTime date, required List<_WorkItem> items}) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (_) => [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue900)),
          pw.SizedBox(height: 4),
          pw.Text('التاريخ: ${_formatDateOnly(date)}', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 12),
          if (items.isEmpty)
            pw.Text('لا توجد أعمال ضمن هذه اللائحة.')
          else
            pw.Table.fromTextArray(
              headers: const ['النوع', 'العنوان', 'المكلف', 'التاريخ', 'الأولوية', 'الحالة'],
              data: items
                  .map((i) => [
                        i.type,
                        i.title,
                        i.assignedTo.isEmpty ? 'غير مكلف' : i.assignedTo,
                        _formatDateOnly(i.date),
                        i.priority,
                        i.status,
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.centerRight,
            ),
        ],
      ),
    );
    return pdf.save();
  }
}

String _formatDateOnly(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
