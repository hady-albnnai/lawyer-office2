import '../../theme/app_colors.dart';
import '../../theme/glassmorphism_helpers.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';

/// شاشة تفاصيل العقد الموحد بتبويباته السبعة ومحرر Word (ContractDetailScreen V6.2)
class ContractDetailScreen extends ConsumerStatefulWidget {
  final int contractId;
  const ContractDetailScreen({super.key, required this.contractId});

  @override
  ConsumerState<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends ConsumerState<ContractDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contractRepo = ref.watch(contractRepositoryProvider);

    return FutureBuilder<Contract?>(
      future: contractRepo.getContractById(widget.contractId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final c = snapshot.data;
        if (c == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('العقد غير موجود')),
            body: const Center(child: Text('لم يتم العثور على هذا العقد في أرشيف المكتب.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('عقد رقم: [${c.internalNumber}] • ${c.title}'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.secondaryGold,
              labelColor: AppColors.secondaryGold,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: '1️⃣ الملخص'),
                Tab(text: '2️⃣ العقد ومحرر Word'),
                Tab(text: '3️⃣ الأطراف'),
                Tab(text: '4️⃣ التذكيرات الزمنية ⏰'),
                Tab(text: '5️⃣ المستندات والنسخ'),
                Tab(text: '6️⃣ المالية'),
                Tab(text: '7️⃣ الخط الزمني'),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildStatusBar(c),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(c),
                    _buildWordEditorTab(c.id),
                    _buildPartiesTab(c.id),
                    _buildRemindersTab(c.id),
                    _buildDocumentsTab(c.id),
                    _buildFinancesTab(c.id),
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

  Widget _buildStatusBar(Contract c) {
    final isActive = c.status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withOpacity(0.08),
        border: Border(bottom: BorderSide(color: AppColors.primaryNavy.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          _statusItem(Icons.description, 'النوع:', c.contractType),
          _statusItem(Icons.flag, 'الحالة:', isActive ? 'ساري المفعول ✓' : c.status),
          _statusItem(Icons.calendar_today, 'تاريخ الإبرام:', c.dateSigned?.toString().substring(0, 10) ?? '---'),
          _statusItem(Icons.event_busy, 'انتهاء العقد:', c.dateEnd?.toString().substring(0, 10) ?? 'غير محدد / دائم'),
          const Spacer(),
          if (c.needsFollowup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(12)),
              child: const Text('مرتبط بتنبيه أتمتة ⏰', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(12)),
              child: const Text('عقد منجز لا يحتاج تنبيه', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
          Icon(icon, size: 18, color: AppColors.secondaryGold),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(Contract c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassmorphicCard(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('البيانات المالية والقانونية للعقد:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                  const Divider(height: 24),
                  _row('القيمة المالية الإجمالية:', '${c.financialValue ?? 0} ${c.currency}'),
                  _row('مكان الإبرام والتوقيع:', c.location ?? '---'),
                  _row('نوع التوثيق:', c.notarizationType ?? 'عقد عرفي / توثيق نقابة'),
                  _row('هل العقد قابل للتجديد؟:', c.isRenewable ? 'نعم - قابل للتجديد (${c.renewalType ?? "تلقائي"})' : 'لا - محدد المدة'),
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
          SizedBox(width: 180, child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2️⃣ تبويب العقد ومحرر Word (Word Editor & External Open)
  // ---------------------------------------------------------------------------
  Widget _buildWordEditorTab(int contractId) {
    final versionsStream = ref.watch(contractRepositoryProvider).watchContractVersions(contractId);

    return StreamBuilder<List<ContractVersion>>(
      stream: versionsStream,
      builder: (context, snapshot) {
        final versions = snapshot.data ?? [];
        final latest = versions.isNotEmpty ? versions.first : null;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassmorphicCard(
                color: AppColors.primaryNavy,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.description, size: 48, color: AppColors.secondaryGold),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              latest?.filePath != null ? 'ملف العقد مرفق أصولاً (النسخة رقم ${latest!.versionNumber})' : 'لم يتم إرفاق ملف Word لهذا العقد بعد',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'يمكنك فتح الملف مباشرة في برنامج Microsoft Word على Windows، وسيتم حفظ أي تعديلات تقوم بها تلقائياً في المكتب.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (latest?.filePath != null)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryGold, foregroundColor: AppColors.primaryNavy, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('فتح وتحرير في Word 📝', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          onPressed: () => _openVersionFile(latest!.filePath!),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryGold, foregroundColor: AppColors.primaryNavy),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('رفع ملف Word الآن'),
                          onPressed: () => _uploadVersionFile(contractId),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('سجل النسخ والتعديلات السابقة للعقد:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: versions.length,
                  itemBuilder: (context, index) {
                    final v = versions[index];
                    return GlassmorphicCard(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: AppColors.primaryNavy, child: Text('v${v.versionNumber}', style: const TextStyle(color: AppColors.secondaryGold, fontWeight: FontWeight.bold))),
                        title: Text('تعديل بواسطة: ${v.editedBy ?? "المكتب"} • التاريخ: ${v.editDate.toString().substring(0, 16)}'),
                        subtitle: Text('ملاحظات التعديل: ${v.notes ?? "---"}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.download_outlined, color: AppColors.primaryNavy),
                          onPressed: v.filePath == null
                              ? null
                              : () => _openVersionFile(v.filePath!),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartiesTab(int contractId) {
    final stream = ref.watch(contractRepositoryProvider).watchContractParties(contractId);
    return StreamBuilder<List<ContractParty>>(
      stream: stream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const Center(child: Text('لا يوجد أطراف مضافون'));
        return ListView(
          padding: const EdgeInsets.all(24),
          children: list.map((p) => GlassmorphicCard(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: AppColors.primaryNavy, child: Icon(Icons.person, color: AppColors.secondaryGold)),
                  title: Text('طرف رقم ID: ${p.personId} • الدور: ${p.partyRole}'),
                ),
              )).toList(),
        );
      },
    );
  }

  Widget _buildRemindersTab(int contractId) {
    final stream = ref.watch(contractRepositoryProvider).watchContractReminders(contractId);
    return StreamBuilder<List<ContractReminder>>(
      stream: stream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const Center(child: Text('لا توجد تذكيرات زمنية مضبوطة لهذا العقد'));
        return ListView(
          padding: const EdgeInsets.all(24),
          children: list.map((r) => GlassmorphicCard(
                color: AppColors.warning.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.warning)),
                child: ListTile(
                  leading: const Icon(Icons.alarm, size: 36, color: AppColors.warning),
                  title: Text('تذكير مجدول في: ${r.reminderDate.toString().substring(0, 10)} • النوع: ${r.reminderType}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('هاتف التواصل: ${r.contactPhone ?? "---"} • الملاحظة: ${r.reminderNote ?? ""}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(16)),
                    child: Text('مرتبط بمهمة يومية رقم [ID: ${r.autoTaskId ?? "-"}]', style: const TextStyle(color: AppColors.secondaryGold, fontSize: 12)),
                  ),
                ),
              )).toList(),
        );
      },
    );
  }

  Widget _buildDocumentsTab(int contractId) {
    return const Center(child: Text('النسخ المصدقة والعقود المرفقة في الأرشيف'));
  }

  Widget _buildFinancesTab(int contractId) {
    return const Center(child: Text('أتعاب تنظيم العقد والدفعات المستلمة من الأطراف'));
  }

  Widget _buildTimelineTab(int contractId) {
    final stream = ref.watch(taskRepositoryProvider).watchTimelineEvents(EntityType.contract, contractId);
    return StreamBuilder<List<TimelineEvent>>(
      stream: stream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const Center(child: Text('لا توجد أحداث في الخط الزمني'));
        return ListView(
          padding: const EdgeInsets.all(24),
          children: list.map((e) => GlassmorphicCard(
                child: ListTile(
                  leading: const Icon(Icons.history, color: AppColors.primaryNavy),
                  title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${e.eventType} • ${e.eventDate.toString().substring(0, 16)}'),
                ),
              )).toList(),
        );
      },
    );
  }

  /// رفع ملف Word كنسخة جديدة للعقد.
  ///
  /// كان الزر يحمل جسماً فارغاً بتعليق «إمكانية رفع ملف للنسخة»،
  /// فيضغط المستخدم بلا أثر ويبقى العقد بلا ملف.
  Future<void> _uploadVersionFile(int contractId) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['docx', 'doc', 'rtf', 'pdf'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    try {
      await ref.read(contractRepositoryProvider).addContractVersion(
            contractId: contractId,
            wordFile: File(path),
            userRef: ref.read(authControllerProvider).user?.fullName,
            notes: 'رفع ملف للنسخة من شاشة تفاصيل العقد',
          );
      // سجل النسخ Stream حيّ فيتحدّث تلقائياً.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفع الملف كنسخة جديدة'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر الرفع: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }


  /// فتح ملف نسخة العقد.
  ///
  /// المرفقات تُخزَّن مشفّرة (AES) بلاحقة .enc عبر saveAttachment، لذا
  /// تسليم المسار الخام إلى OpenFilex كان يفتح ملفاً مشفّراً لا يقرأه
  /// Word. AttachmentService تفكّ التشفير إلى ملف مؤقت أولاً.
  Future<void> _openVersionFile(String relativePath) async {
    final result = await ref
        .read(attachmentServiceProvider)
        .openStoredAttachment(relativePath);
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'تعذّر فتح الملف'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

}
