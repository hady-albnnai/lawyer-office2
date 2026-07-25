import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';

/// شاشة ملف الشركة الموحد بتبويباته الثمانية وشريط الحالة الدائم (CompanyDetailScreen V6.2)
class CompanyDetailScreen extends ConsumerStatefulWidget {
  final int companyId;
  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  ConsumerState<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends ConsumerState<CompanyDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyRepo = ref.watch(companyRepositoryProvider);

    return FutureBuilder<Company?>(
      future: companyRepo.getCompanyById(widget.companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final c = snapshot.data;
        if (c == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('ملف الشركة غير موجود')),
            body: const Center(child: Text('لم يتم العثور على ملف هذه الشركة في أرشيف المكتب.')),
          );
        }

        final defsAsync = ref.watch(openDeficienciesProvider((type: EntityType.company, id: c.id)));
        final hasDeficiencies = defsAsync.maybeWhen(
          data: (defs) => defs.isNotEmpty,
          orElse: () => false,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('شركة: [${c.name}] • ملف رقم [${c.internalNumber}]'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppConstants.accentGold,
              labelColor: AppConstants.accentGold,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                const Tab(text: '1️⃣ البيانات الأساسية والمقر'),
                const Tab(text: '2️⃣ الشركاء والإدارة'),
                const Tab(text: '3️⃣ مراحل التأسيس (10)'),
                const Tab(text: '4️⃣ إدارة ما بعد التأسيس'),
                const Tab(text: '5️⃣ المستندات'),
                const Tab(text: '6️⃣ المالية'),
                Tab(
                  child: Row(
                    children: [
                      const Text('7️⃣ النواقص '),
                      if (hasDeficiencies) const Icon(Icons.error, color: AppConstants.statusDanger, size: 16),
                    ],
                  ),
                ),
                const Tab(text: '8️⃣ الخط الزمني'),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildStatusBar(c, hasDeficiencies),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicDataTab(c),
                    _buildPartnersTab(c.id),
                    _buildPhasesTab(c.id),
                    _buildManagementTab(c.id),
                    _buildDocumentsTab(c.id),
                    _buildFinancesTab(c.id),
                    _buildDeficienciesTab(c.id),
                    _buildTimelineTab(c.id),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(Company c, bool hasDeficiencies) {
    final isUnderEst = c.legalStatus == 'under_establishment';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.primaryNavy.withOpacity(0.08),
        border: Border(bottom: BorderSide(color: AppConstants.primaryNavy.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          _statusItem(Icons.business, 'الشكل:', c.companyType),
          _statusItem(Icons.flag, 'الحالة:', isUnderEst ? 'قيد التأسيس ⏳' : 'عاملة / نشطة ✓'),
          _statusItem(Icons.numbers, 'السجل التجاري:', c.registrationNumber ?? 'بانتظار الصدور ⚠️'),
          _statusItem(Icons.public, 'إشهار الجريدة الرسمية:', c.registrationNumber != null ? 'تم الإشهار ✓' : 'قيد الإنجاز'),
          const Spacer(),
          if (hasDeficiencies)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppConstants.statusDanger, borderRadius: BorderRadius.circular(12)),
              child: const Text('يوجد نواقص في التأسيس ⚠️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppConstants.statusSuccess, borderRadius: BorderRadius.circular(12)),
              child: const Text('ملف الشركة مكتمل ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
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

  Widget _buildBasicDataTab(Company c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('البيانات الأساسية والقانونية للشركة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                  const Divider(height: 24),
                  _row('الاسم التجاري:', c.name),
                  _row('الشكل القانوني:', c.companyType),
                  _row('نشاط الشركة / الغاية:', c.activity ?? '---'),
                  _row('رأس المال المكتتب به:', '${c.capitalDeclared ?? 0} ل.س'),
                  _row('رأس المال المدفوع:', '${c.capitalPaid ?? 0} ل.س'),
                  _row('مدة الشركة:', '${c.durationYears ?? 99} سنة'),
                  _row('الرقم الوطني للشركة:', c.nationalNumber ?? 'بانتظار التسجيل'),
                  _row('رقم السجل التجاري والتاريخ:', '${c.registrationNumber ?? "غير صادر"} (${c.registrationDate?.toString().substring(0, 10) ?? ""})'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مقر الشركة وبيانات العقار والضرائب:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                  const Divider(height: 24),
                  _row('العنوان التفصيلي:', c.mainAddress ?? '---'),
                  _row('صفة المقر ورقم القيد:', c.propertyDetails ?? '---'),
                  _row('الحالة الضريبية للمقر:', c.taxStatus ?? 'سليمة / قيد المراجعة'),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildPartnersTab(int companyId) {
    final partnersStream = ref.watch(companyRepositoryProvider).watchCompanyPartners(companyId);
    final directorsStream = ref.watch(companyRepositoryProvider).watchCompanyDirectors(companyId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الشركاء وحصص رأس المال:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
          const SizedBox(height: 12),
          StreamBuilder<List<CompanyPartner>>(
            stream: partnersStream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) return const Text('لا يوجد شركاء مضافون');
              return Column(
                children: list.map((p) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: AppConstants.primaryNavy, child: Icon(Icons.person, color: AppConstants.accentGold)),
                        title: Text('شريك رقم ID: ${p.personId} • النسبة: ${p.sharePercentage}%'),
                        subtitle: Text('قيمة الحصة: ${p.shareValue} ل.س • النوع: ${p.shareType == "cash" ? "نقدية" : "عينية/جهد"}'),
                      ),
                    )).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('الإدارة ومجلس الإدارة والمفوضون بالتوقيع:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
          const SizedBox(height: 12),
          StreamBuilder<List<CompanyDirector>>(
            stream: directorsStream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) return const Text('لا يوجد مديرون مضافون');
              return Column(
                children: list.map((d) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: AppConstants.accentGold, child: Icon(Icons.gavel, color: AppConstants.primaryNavy)),
                        title: Text('مدير رقم ID: ${d.personId} • المنصب: ${d.roleType}'),
                        subtitle: Text('نطاق الصلاحيات والتفويض: ${d.authorityScope ?? "---"}'),
                      ),
                    )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhasesTab(int companyId) {
    final phasesStream = ref.watch(companyRepositoryProvider).watchCompanyPhases(companyId);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppConstants.surfaceWhite,
          child: const Row(
            children: [
              Icon(Icons.timeline, color: AppConstants.primaryNavy),
              SizedBox(width: 8),
              Text('مراحل التأسيس الـ 10 (دورة الحياة الموحدة لكل مرحلة):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CompanyPhase>>(
            stream: phasesStream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) return const Center(child: Text('لا توجد مراحل تأسيس مولدة'));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final p = list[index];
                  final statusEnum = LifecycleStatus.values[p.status];
                  final isDone = statusEnum == LifecycleStatus.completed;

                  return Card(
                    color: isDone ? AppConstants.statusSuccess.withOpacity(0.05) : AppConstants.surfaceWhite,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDone ? AppConstants.statusSuccess : AppConstants.primaryNavy,
                        child: Icon(isDone ? Icons.check : Icons.hourglass_top, color: Colors.white),
                      ),
                      title: Text('${p.phaseOrder}. ${p.phaseName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text('الحالة: ${statusEnum.label} • الموعد المحدد: ${p.scheduledDate?.toString().substring(0, 10) ?? "---"}'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: isDone ? Colors.grey : AppConstants.statusSuccess),
                        child: Text(isDone ? 'مكتملة ✓' : 'إتمام المرحلة'),
                        onPressed: isDone ? null : () async {
                          // إتمام المرحلة
                        },
                      ),
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

  Widget _buildManagementTab(int companyId) {
    return const Center(child: Text('إدارة ما بعد التأسيس (اجتماعات، تعديلات، تجديد غرفة التجارة، وتصفية)'));
  }

  Widget _buildDocumentsTab(int companyId) {
    return const Center(child: Text('وثائق ومستندات الشركة (عقد التأسيس، السجل التجاري، الجريدة الرسمية...)'));
  }

  Widget _buildFinancesTab(int companyId) {
    return const Center(child: Text('أتعاب التأسيس ومصاريف رسوم النشر والسجل التجاري'));
  }

  Widget _buildDeficienciesTab(int companyId) {
    final defsStream = ref.watch(taskRepositoryProvider).watchOpenDeficiencies(entityType: EntityType.company, entityId: companyId);

    return StreamBuilder<List<Deficiency>>(
      stream: defsStream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const Center(child: Text('لا توجد نواقص في ملف الشركة ✓', style: TextStyle(color: AppConstants.statusSuccess, fontSize: 18, fontWeight: FontWeight.bold)));
        return ListView(
          padding: const EdgeInsets.all(24),
          children: list.map((d) => Card(
                color: AppConstants.statusDanger.withOpacity(0.08),
                child: ListTile(
                  leading: const Icon(Icons.error, color: AppConstants.statusDanger),
                  title: Text(d.fieldName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.statusDanger)),
                  subtitle: Text(d.description),
                ),
              )).toList(),
        );
      },
    );
  }

  Widget _buildTimelineTab(int companyId) {
    final stream = ref.watch(taskRepositoryProvider).watchTimelineEvents(EntityType.company, companyId);
    return StreamBuilder<List<TimelineEvent>>(
      stream: stream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const Center(child: Text('لا توجد أحداث في الخط الزمني'));
        return ListView(
          padding: const EdgeInsets.all(24),
          children: list.map((e) => Card(
                child: ListTile(
                  leading: const Icon(Icons.history, color: AppConstants.primaryNavy),
                  title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${e.eventType} • ${e.eventDate.toString().substring(0, 16)}'),
                ),
              )).toList(),
        );
      },
    );
  }
}
