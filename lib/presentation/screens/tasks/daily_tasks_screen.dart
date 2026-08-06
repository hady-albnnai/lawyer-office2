import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../cases/case_detail_screen.dart';
import '../contracts/contract_detail_screen.dart';
import '../companies/company_detail_screen.dart';
import '../admin_procedures/procedure_detail_screen.dart';

/// شاشة إدارة الأعمال اليومية والأجندة والمواعيد (DailyTasksScreen V6.2)
/// تجمع كافة مهام وجلسات اليوم وتتيح الإتمام أو التأجيل مع ترحيل التواريخ تلقائياً.
class DailyTasksScreen extends ConsumerStatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  ConsumerState<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends ConsumerState<DailyTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // شريط اختيار اليوم والإحصائيات
        Container(
          padding: const EdgeInsets.all(16),
          color: AppConstants.surfaceWhite,
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: AppConstants.primaryNavy, size: 28),
              const SizedBox(width: 12),
              Text(
                'أجندة المكتب ليوم: ${_selectedDate.toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryNavy),
                icon: const Icon(Icons.today),
                label: const Text('اليوم'),
                onPressed: () => setState(() => _selectedDate = DateTime.now()),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: const Text('تغيير التاريخ'),
                onPressed: _pickDate,
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentGold, foregroundColor: AppConstants.primaryNavy),
                icon: const Icon(Icons.add_task),
                label: const Text('إضافة مهمة يدوية'),
                onPressed: _openAddTaskDialog,
              ),
            ],
          ),
        ),

        // تبويبات التصنيف
        Container(
          color: AppConstants.primaryNavy,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppConstants.accentGold,
            labelColor: AppConstants.accentGold,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'مهام اليوم المحددة ⭐'),
              Tab(text: 'المهام المتأخرة (تتطلب معالجة) ⚠️'),
              Tab(text: 'المهام المؤجلة / المنجزة ✓'),
            ],
          ),
        ),

        // قائمة المهام
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTasksList(_selectedDate, onlyPending: true),
              _buildOverdueList(),
              _buildCompletedOrPostponedList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasksList(DateTime date, {bool onlyPending = false}) {
    final stream = ref.watch(tasksByDateProvider(date));

    return stream.when(
      data: (tasks) {
        final list = onlyPending
            ? tasks.where((t) => t.status == LifecycleStatus.scheduled.index || t.status == LifecycleStatus.inProgress.index).toList()
            : tasks;

        if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available, size: 64, color: AppConstants.statusSuccess),
                SizedBox(height: 16),
                Text('لا توجد مهام أو جلسات مجدولة لهذا اليوم في المكتب ✓', style: TextStyle(fontSize: 18, color: AppConstants.statusSuccess, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final t = list[index];
            return _buildTaskCard(t);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ في تحميل مهام اليوم: $err')),
    );
  }

  Widget _buildOverdueList() {
    final stream = ref.watch(tasksByDateProvider(DateTime.now().subtract(const Duration(days: 1))));
    return stream.when(
      data: (tasks) {
        final overdue = tasks.where((t) => t.status == LifecycleStatus.scheduled.index || t.status == LifecycleStatus.inProgress.index).toList();
        if (overdue.isEmpty) return const Center(child: Text('لا توجد مهام متأخرة ✓', style: TextStyle(color: AppConstants.statusSuccess, fontSize: 18, fontWeight: FontWeight.bold)));
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: overdue.length, itemBuilder: (context, idx) => _buildTaskCard(overdue[idx], isOverdue: true));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ: $err')),
    );
  }

  Widget _buildCompletedOrPostponedList() {
    final stream = ref.watch(tasksByDateProvider(_selectedDate));
    return stream.when(
      data: (tasks) {
        final list = tasks.where((t) => t.status == LifecycleStatus.completed.index || t.status == LifecycleStatus.postponed.index || t.status == LifecycleStatus.cancelled.index).toList();
        if (list.isEmpty) return const Center(child: Text('لا توجد مهام منجزة أو مؤجلة اليوم'));
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (context, idx) => _buildTaskCard(list[idx]));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ: $err')),
    );
  }

  Widget _buildTaskCard(DailyTask t, {bool isOverdue = false}) {
    final statusEnum = LifecycleStatus.values[t.status];
    final priorityEnum = TaskPriority.values[t.priority];
    final isDone = statusEnum == LifecycleStatus.completed;

    Color badgeColor = AppConstants.primaryNavy;
    if (priorityEnum == TaskPriority.urgent) badgeColor = AppConstants.statusDanger;
    if (priorityEnum == TaskPriority.high) badgeColor = AppConstants.statusWarning;
    if (isOverdue) badgeColor = AppConstants.statusDanger;

    return Card(
      elevation: isDone ? 1 : 3,
      color: isDone ? Colors.grey.withOpacity(0.08) : (isOverdue ? AppConstants.statusDanger.withOpacity(0.05) : AppConstants.surfaceWhite),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: badgeColor, width: isOverdue || priorityEnum == TaskPriority.urgent ? 1.5 : 0.8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: badgeColor,
                  child: Icon(_getIconForType(t.taskType), color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, decoration: isDone ? TextDecoration.lineThrough : null, color: AppConstants.primaryNavy)),
                      const SizedBox(height: 4),
                      Text('النوع: ${_getLabelForType(t.taskType)} • الوقت: ${t.taskTime ?? "طوال اليوم"} • المكلف: ${t.assignedTo ?? "المكتب"}', style: const TextStyle(fontSize: 12, color: AppConstants.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: badgeColor)),
                  child: Text(isOverdue ? 'متأخرة ⚠️' : priorityEnum.label, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            if (t.notes != null && t.notes!.isNotEmpty) ...[
              const Divider(height: 20),
              Text('ملاحظات / سبب التأجيل: ${t.notes}', style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
            ],
            const Divider(height: 20),
            Row(
              children: [
                if (t.sourceType != null && t.sourceId != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('فتح الملف الأصلي'),
                    onPressed: () => _openSourceEntity(t.sourceType!, t.sourceId!),
                  ),
                const Spacer(),
                if (!isDone && statusEnum != LifecycleStatus.cancelled) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppConstants.statusWarning),
                    icon: const Icon(Icons.schedule),
                    label: const Text('تأجيل الموعد ⏰'),
                    onPressed: () => _openPostponeDialog(t),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.statusSuccess),
                    icon: const Icon(Icons.check),
                    label: const Text('إتمام وإنجاز'),
                    onPressed: () async {
                      await ref.read(taskRepositoryProvider).completeTask(t.id, AppConstants.defaultLawyerName);
                      if (context.mounted) {
                        ref.invalidate(tasksByDateProvider(_selectedDate));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنجاز المهمة بنجاح!'), backgroundColor: AppConstants.statusSuccess));
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'session': return Icons.gavel;
      case 'contract_reminder': return Icons.description;
      case 'company_phase': return Icons.business;
      case 'admin_step': return Icons.assignment;
      default: return Icons.task_alt;
    }
  }

  String _getLabelForType(String type) {
    switch (type) {
      case 'session': return 'جلسة قضائية';
      case 'contract_reminder': return 'تذكير عقد';
      case 'company_phase': return 'مرحلة تأسيس شركة';
      case 'admin_step': return 'خطوة معاملة إدارية';
      default: return 'مهمة يدوية';
    }
  }

  void _openSourceEntity(String type, int id) {
    Widget screen;
    switch (type) {
      case 'cases': screen = CaseDetailScreen(caseId: id); break;
      case 'contracts': screen = ContractDetailScreen(contractId: id); break;
      case 'companies': screen = CompanyDetailScreen(companyId: id); break;
      case 'admin_procedures': screen = ProcedureDetailScreen(procedureId: id); break;
      default: return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openPostponeDialog(DailyTask t) {
    final reasonController = TextEditingController();
    DateTime newDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تأجيل الموعد / الجلسة إلى تاريخ لاحق'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تطبيقاً لدستور المكتب (V6.2): يجب تحديد سبب التأجيل والتاريخ الجديد، وسيحتفظ النظام بالسجل السابق في الأرشيف.', style: TextStyle(fontSize: 13, color: AppConstants.textMuted)),
              const SizedBox(height: 16),
              TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'سبب التأجيل * (مثال: تأجيل لإبراز دفوع الخصم)')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('التاريخ الجديد: ${newDate.toString().substring(0, 10)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton(
                    child: const Text('تغيير التاريخ'),
                    onPressed: () async {
                      final p = await showDatePicker(context: context, initialDate: newDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (p != null) setDialogState(() => newDate = p);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.statusWarning, foregroundColor: Colors.black),
              child: const Text('اعتماد التأجيل وترحيل الموعد'),
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;
                await ref.read(taskRepositoryProvider).postponeTask(
                  taskId: t.id,
                  newDate: newDate,
                  reason: reasonController.text.trim(),
                  userRef: AppConstants.defaultLawyerName,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(tasksByDateProvider(_selectedDate));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تأجيل الموعد وترحيله بنجاح!'), backgroundColor: AppConstants.statusWarning));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openAddTaskDialog() {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    DateTime date = _selectedDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مهمة يدوية جديدة لأجندة المكتب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'عنوان المهمة * (مثال: مراجعة ديوان المحكمة)')),
            const SizedBox(height: 12),
            TextField(controller: notesController, decoration: const InputDecoration(labelText: 'ملاحظات وتفاصيل إضافية')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            child: const Text('حفظ في الأجندة'),
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              await ref.read(taskRepositoryProvider).createManualTask(
                DailyTasksCompanion.insert(
                  taskType: 'manual',
                  title: titleController.text.trim(),
                  taskDate: date,
                  notes: drift.Value(notesController.text.trim()),
                  assignedTo: const drift.Value(AppConstants.defaultLawyerName),
                ),
              );
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(tasksByDateProvider(_selectedDate));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة المهمة بنجاح!'), backgroundColor: AppConstants.statusSuccess));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (p != null) setState(() => _selectedDate = p);
  }
}
