import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';

/// شاشة تفاصيل الإجراء الإداري الموحد بتبويباته الستة وخطوات الـ Checklist (ProcedureDetailScreen V6.2)
class ProcedureDetailScreen extends ConsumerStatefulWidget {
  final int procedureId;
  const ProcedureDetailScreen({super.key, required this.procedureId});

  @override
  ConsumerState<ProcedureDetailScreen> createState() => _ProcedureDetailScreenState();
}

class _ProcedureDetailScreenState extends ConsumerState<ProcedureDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminProcedureRepositoryProvider);

    return FutureBuilder<AdminProcedure?>(
      future: repo.getProcedureById(widget.procedureId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final p = snapshot.data;
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('المعاملة غير موجودة')),
            body: const Center(child: Text('لم يتم العثور على هذه المعاملة في الأرشيف.')),
          );
        }

        final statusEnum = LifecycleStatus.values[p.status];

        return Scaffold(
          appBar: AppBar(
            title: Text('معاملة رقم: [${p.internalNumber}] • ${p.title}'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppConstants.accentGold,
              labelColor: AppConstants.accentGold,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: '1️⃣ الملخص'),
                Tab(text: '2️⃣ الموكل والتوكيل'),
                Tab(text: '3️⃣ خطوات التنفيذ (Checklist)'),
                Tab(text: '4️⃣ المستندات المطلوبة'),
                Tab(text: '5️⃣ المالية والرسوم'),
                Tab(text: '6️⃣ النواقص والخط الزمني'),
              ],
            ),
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppConstants.primaryNavy.withOpacity(0.08),
                child: Row(
                  children: [
                    _statusItem(Icons.assignment, 'التصنيف:', p.procedureType),
                    _statusItem(Icons.flag, 'الحالة:', statusEnum.label),
                    _statusItem(Icons.account_balance, 'الدائرة:', p.department ?? '---'),
                    _statusItem(Icons.event, 'الموعد القادم:', p.nextDate?.toString().substring(0, 10) ?? 'غير محدد ⚠️'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: statusEnum == LifecycleStatus.completed ? AppConstants.statusSuccess : AppConstants.statusInfo, borderRadius: BorderRadius.circular(12)),
                      child: Text(statusEnum == LifecycleStatus.completed ? 'منجزة ✓' : 'قيد المتابعة ⏳', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(p),
                    _buildClientTab(p.clientId),
                    _buildStepsTab(p.id),
                    _buildDocsTab(p.id),
                    _buildFinancesTab(p.id),
                    _buildTimelineTab(p.id),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppConstants.accentGold),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppConstants.textMuted)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(AdminProcedure p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تفاصيل ومتابعة المعاملة الإدارية:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
              const Divider(height: 24),
              _row('عنوان المعاملة:', p.title),
              _row('النوع الفرعي:', p.subType ?? '---'),
              _row('رقم الطلب / المعاملة:', p.transactionNumber ?? 'بانتظار الصدور'),
              _row('تاريخ البدء في المكتب:', p.startDate?.toString().substring(0, 10) ?? '---'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String l, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textMuted))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppConstants.textDark))),
        ],
      ),
    );
  }

  Widget _buildClientTab(int clientId) {
    final personAsync = ref.watch(personRepositoryProvider).getPersonById(clientId);
    return FutureBuilder<PersonEntity?>(
      future: personAsync,
      builder: (context, snapshot) {
        final p = snapshot.data;
        if (p == null) return const Center(child: Text('جلب بيانات الموكل...'));
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: AppConstants.primaryNavy, child: Icon(Icons.person, color: AppConstants.accentGold)),
              title: Text('الموكل صاحب المعاملة: ${p.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('الهاتف: ${p.phone1 ?? "---"} • العنوان: ${p.permanentAddress ?? "---"}'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepsTab(int procedureId) {
    final stream = ref.watch(adminProcedureRepositoryProvider).watchSteps(procedureId);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppConstants.surfaceWhite,
          child: const Row(
            children: [
              Icon(Icons.checklist, color: AppConstants.primaryNavy),
              SizedBox(width: 8),
              Text('خطوات الإنجاز وقائمة الـ Checklist التلقائية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminStep>>(
            stream: stream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) return const Center(child: Text('لا توجد خطوات مضافة بعد'));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final step = list[index];
                  final isDone = step.status == LifecycleStatus.completed.index;
                  return Card(
                    color: isDone ? AppConstants.statusSuccess.withOpacity(0.05) : AppConstants.surfaceWhite,
                    child: ListTile(
                      leading: Checkbox(
                        value: isDone,
                        onChanged: (val) async {
                          // تحديث حالة الخطوة
                        },
                      ),
                      title: Text(step.stepTitle, style: TextStyle(fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null)),
                      subtitle: Text('النتيجة: ${step.result ?? "قيد المتابعة"} • المكلف: ${step.assignedTo ?? "المكتب"}'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDocsTab(int procedureId) => const Center(child: Text('قائمة الثبوتيات والمستندات المطلوبة للمعاملة (Checklist)'));
  Widget _buildFinancesTab(int procedureId) => const Center(child: Text('أتعاب المعاملة ومصاريف الرسوم والطوابع في الدائرة'));
  Widget _buildTimelineTab(int procedureId) {
    final stream = ref.watch(taskRepositoryProvider).watchTimelineEvents(EntityType.adminProcedure, procedureId);
    return StreamBuilder<List<TimelineEvent>>(
      stream: stream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const Center(child: Text('لا توجد أحداث في الخط الزمني'));
        return ListView(
          padding: const EdgeInsets.all(24),
          children: list.map((e) => Card(child: ListTile(title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(e.eventDate.toString().substring(0, 16))))).toList(),
        );
      },
    );
  }
}
