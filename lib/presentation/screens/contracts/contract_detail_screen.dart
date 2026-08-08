import '../../theme/app_colors.dart';
import '../../theme/glassmorphism_helpers.dart';
import 'dart:io';
import 'package:drift/drift.dart' show Value, Variable, QueryRow;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';

/// Provider لجلب المستندات المرتبطة بكيان معين
final documentsByEntityProvider = StreamProvider.family<List<Document>, (EntityType, int)>((ref, params) {
  final db = ref.watch(databaseProvider);
  return db.customSelect(
    '''
    SELECT d.* FROM documents d
    INNER JOIN document_links dl ON d.id = dl.document_id
    WHERE dl.entity_type = ? AND dl.entity_id = ?
    ORDER BY d.date_added DESC
    ''',
    variables: [Variable.withInt(params.$1.index), Variable.withInt(params.$2)],
  ).watch().map((rows) => rows.map<Document>((row) {
    final data = row.data;
    return Document(
      id: data['id'] as int,
      docName: data['doc_name'] as String,
      docType: data['doc_type'] as String?,
      dateIssued: data['date_issued'] as DateTime?,
      dateAdded: data['date_added'] as DateTime,
      issuer: data['issuer'] as String?,
      filePath: data['file_path'] as String?,
      fileType: data['file_type'] as String?,
      status: data['status'] as int,
      physicalLocation: data['physical_location'] as int,
      summary: data['summary'] as String?,
      notes: data['notes'] as String?,
      createdAt: data['created_at'] as DateTime,
    );
  }).toList());
});

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
    _tabController = TabController(length: 4, vsync: this);
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
                Tab(text: '2️⃣ الأطراف والتذكيرات'),
                Tab(text: '3️⃣ المستندات والمالية'),
                Tab(text: '4️⃣ التحرير'),
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
                    _buildPartiesAndRemindersTab(c.id),
                    _buildDocumentsAndFinancesTab(c.id),
                    _buildWordEditorTab(c.id),
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
    final personsAsync = ref.watch(allPersonsProvider(null));
    
    return StreamBuilder<List<ContractParty>>(
      stream: stream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const Center(child: Text('لا يوجد أطراف مضافون'));
        
        return personsAsync.when(
          data: (persons) => ListView(
            padding: const EdgeInsets.all(24),
            children: list.map((p) {
              final person = persons.where((per) => per.id == p.personId).firstOrNull;
              final personName = person?.fullName ?? 'شخص غير معروف (ID: ${p.personId})';
              final personPhone = person?.phone1 ?? '---';
              
              return GlassmorphicCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryNavy,
                    child: Icon(Icons.person, color: AppColors.secondaryGold),
                  ),
                  title: Text(
                    personName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الصفة: ${p.partyCapacity ?? p.partyRole ?? "---"}'),
                      Text('الهاتف: $personPhone'),
                      if (p.partyOrder != null) Text('الترتيب: الطرف ${p.partyOrder}'),
                    ],
                  ),
                  trailing: p.poaId != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'وكالة #${p.poaId}',
                            style: const TextStyle(fontSize: 11, color: AppColors.info),
                          ),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ في تحميل الأطراف: $e')),
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
        
        return Column(
          children: [
            // زر إضافة تذكير جديد
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddReminderDialog(contractId),
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('إضافة تذكير جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.secondaryGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            
            // قائمة التذكيرات
            if (list.isEmpty)
              const Expanded(child: Center(child: Text('لا توجد تذكيرات زمنية مضبوطة لهذا العقد')))
            else
              Expanded(
                child: ListView(
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
                ),
              ),
          ],
        );
      },
    );
  }
  
  Future<void> _showAddReminderDialog(int contractId) async {
    final reminderTypeController = TextEditingController(text: 'expiry');
    final reminderDateController = TextEditingController();
    final contactPhoneController = TextEditingController();
    final reminderNoteController = TextEditingController();
    DateTime? selectedDate;
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إضافة تذكير جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: reminderTypeController.text,
                  decoration: const InputDecoration(labelText: 'نوع التذكير'),
                  items: const [
                    DropdownMenuItem(value: 'expiry', child: Text('تذكير انتهاء')),
                    DropdownMenuItem(value: 'renewal', child: Text('تذكير تجديد')),
                    DropdownMenuItem(value: 'followup', child: Text('متابعة عامة')),
                  ],
                  onChanged: (v) => setState(() => reminderTypeController.text = v ?? 'expiry'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                        reminderDateController.text = picked.toString().substring(0, 10);
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'تاريخ التذكير'),
                    child: Text(selectedDate == null ? 'اختر التاريخ' : selectedDate.toString().substring(0, 10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactPhoneController,
                  decoration: const InputDecoration(labelText: 'هاتف التواصل (اختياري)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reminderNoteController,
                  decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (selectedDate == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار تاريخ التذكير'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                
                try {
                  final db = ref.read(databaseProvider);
                  final taskSyncService = ref.read(taskSyncServiceProvider);
                  
                  final reminder = ContractRemindersCompanion.insert(
                    contractId: contractId,
                    reminderType: reminderTypeController.text,
                    reminderDate: selectedDate!,
                    contactPhone: Value(contactPhoneController.text.trim().isEmpty ? null : contactPhoneController.text.trim()),
                    reminderNote: Value(reminderNoteController.text.trim().isEmpty ? null : reminderNoteController.text.trim()),
                  );
                  
                  await taskSyncService.syncContractReminder(
                    reminder: reminder,
                    contractTitle: 'عقد',
                    contractId: contractId,
                  );
                  
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إضافة التذكير بنجاح'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsTab(int contractId) {
    final documentsStream = ref.watch(documentsByEntityProvider((EntityType.contract, contractId)));
    
    return documentsStream.when(
      data: (documents) {
        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_open, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text('لا توجد مستندات مرفقة لهذا العقد'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddDocumentDialog(contractId),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('إرفاق مستند'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.secondaryGold,
                  ),
                ),
              ],
            ),
          );
        }
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddDocumentDialog(contractId),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('إرفاق مستند جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.secondaryGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final doc = documents[index];
                  return GlassmorphicCard(
                    child: ListTile(
                      leading: Icon(
                        _getDocumentIcon(doc.fileType ?? ''),
                        color: AppColors.primaryNavy,
                        size: 32,
                      ),
                      title: Text(doc.docName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('النوع: ${doc.docType ?? "---"}'),
                          Text('تاريخ الإضافة: ${doc.dateAdded.toString().substring(0, 10)}'),
                          if (doc.summary != null && doc.summary!.isNotEmpty)
                            Text('ملاحظة: ${doc.summary}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new, color: AppColors.primaryNavy),
                        onPressed: () => _openDocument(doc),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ في تحميل المستندات: $e')),
    );
  }
  
  IconData _getDocumentIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  Future<void> _showAddDocumentDialog(int contractId) async {
    final docNameController = TextEditingController();
    final docTypeController = TextEditingController(text: 'مستند عقد');
    final summaryController = TextEditingController();
    File? selectedFile;
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إرفاق مستند جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: docNameController,
                  decoration: const InputDecoration(labelText: 'اسم المستند *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: docTypeController,
                  decoration: const InputDecoration(labelText: 'نوع المستند'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
                    );
                    if (result != null && result.files.single.path != null) {
                      setState(() => selectedFile = File(result.files.single.path!));
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'الملف *'),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedFile == null ? 'اختر ملف' : selectedFile!.path.split('/').last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (docNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم المستند'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                if (selectedFile == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار ملف'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                
                try {
                  final docRepo = ref.read(documentRepositoryProvider);
                  final userRef = ref.read(authControllerProvider).user?.fullName ?? 'المكتب';
                  
                  await docRepo.addDocument(
                    docName: docNameController.text.trim(),
                    docType: docTypeController.text.trim().isEmpty ? 'مستند عقد' : docTypeController.text.trim(),
                    fileType: selectedFile!.path.split('.').last,
                    summary: summaryController.text.trim().isEmpty ? null : summaryController.text.trim(),
                    sourceFile: selectedFile!,
                    entityType: EntityType.contract.index,
                    entityId: contractId,
                    userRef: userRef,
                  );
                  
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إرفاق المستند بنجاح'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _openDocument(Document doc) async {
    if (doc.filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يوجد ملف مرفق'), backgroundColor: AppColors.error),
      );
      return;
    }
    try {
      final result = await ref
          .read(attachmentServiceProvider)
          .openStoredAttachment(doc.filePath!);
      if (!mounted) return;
      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'تعذّر فتح الملف'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildFinancesTab(int contractId) {
    final db = ref.watch(databaseProvider);
    
    return FutureBuilder(
      future: Future.wait([
        db.customSelect(
          'SELECT * FROM expenses WHERE entity_type = ? AND entity_id = ?',
          variables: [Variable.withInt(EntityType.contract.index), Variable.withInt(contractId)],
        ).get(),
        db.customSelect(
          'SELECT * FROM fee_payments WHERE entity_type = ? AND entity_id = ?',
          variables: [Variable.withInt(EntityType.contract.index), Variable.withInt(contractId)],
        ).get(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final results = snapshot.data as List<List<QueryRow>>?;
        final expenses = results?[0] ?? [];
        final payments = results?[1] ?? [];
        
        if (expenses.isEmpty && payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text('لا توجد حركات مالية لهذا العقد'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/finance?entityType=contract&entityId=$contractId');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة حركة مالية'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.secondaryGold,
                  ),
                ),
              ],
            ),
          );
        }
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/finance?entityType=contract&entityId=$contractId');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة حركة مالية'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.secondaryGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (payments.isNotEmpty) ...[
                    const Text('سندات القبض', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                    const SizedBox(height: 8),
                    ...payments.map((row) {
                      final data = row.data;
                      return GlassmorphicCard(
                        color: AppColors.success.withOpacity(0.08),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long, color: AppColors.success, size: 32),
                          title: Text('سند قبض #${data['receipt_number'] ?? "---"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('المبلغ: ${data['amount'] ?? 0} ${data['currency'] ?? "ل.س"}'),
                              Text('التاريخ: ${data['payment_date']?.toString().substring(0, 10) ?? "---"}'),
                              if ((data['notes'] != null) == true && data['notes'].toString().isNotEmpty)
                                Text('ملاحظة: ${data['notes']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  if (expenses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('المصاريف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                    const SizedBox(height: 8),
                    ...expenses.map((row) {
                      final data = row.data;
                      return GlassmorphicCard(
                        color: AppColors.error.withOpacity(0.08),
                        child: ListTile(
                          leading: const Icon(Icons.money_off, color: AppColors.error, size: 32),
                          title: Text(data['description'] ?? 'مصروف', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('المبلغ: ${data['amount'] ?? 0} ${data['currency'] ?? "ل.س"}'),
                              Text('التاريخ: ${data['expense_date']?.toString().substring(0, 10) ?? "---"}'),
                              if ((data['notes'] != null) == true && data['notes'].toString().isNotEmpty)
                                Text('ملاحظة: ${data['notes']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
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

  // تبويب 2: الأطراف والتذكيرات (مدمج)
  // ---------------------------------------------------------------------------
  Widget _buildPartiesAndRemindersTab(int contractId) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppColors.primaryNavy.withOpacity(0.05),
            child: const TabBar(
              tabs: [
                Tab(text: 'الأطراف', icon: Icon(Icons.people)),
                Tab(text: 'التذكيرات الزمنية', icon: Icon(Icons.alarm)),
              ],
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.secondaryGold,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPartiesTab(contractId),
                _buildRemindersTab(contractId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // تبويب 3: المستندات والمالية (مدمج)
  // ---------------------------------------------------------------------------
  Widget _buildDocumentsAndFinancesTab(int contractId) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppColors.primaryNavy.withOpacity(0.05),
            child: const TabBar(
              tabs: [
                Tab(text: 'المستندات', icon: Icon(Icons.attach_file)),
                Tab(text: 'المالية والأقساط', icon: Icon(Icons.account_balance)),
              ],
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.secondaryGold,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDocumentsTab(contractId),
                _buildFinancesWithInstallmentsTab(contractId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // المالية مع الأقساط (متابعة التنفيذ)
  // ---------------------------------------------------------------------------
  Widget _buildFinancesWithInstallmentsTab(int contractId) {
    final repo = ref.watch(contractRepositoryProvider);
    final installmentsStream = repo.watchContractInstallments(contractId);
    
    return StreamBuilder<List<ContractInstallment>>(
      stream: installmentsStream,
      builder: (context, snapshot) {
        final installments = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // قسم الأقساط
              if (installments.isNotEmpty) ...[
                Text('متابعة الأقساط', style: TextStyle(fontSize: 18, color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...installments.map((inst) => _buildInstallmentCard(inst, contractId)),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
              ],
              
              // قسم المالية الأصلي
              _buildFinancesTab(contractId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstallmentCard(ContractInstallment inst, int contractId) {
    final isPaid = inst.paidDate != null;
    final isOverdue = !isPaid && inst.dueDate.isBefore(DateTime.now());
    
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 12),
      color: isPaid ? AppColors.success.withOpacity(0.1) : isOverdue ? AppColors.error.withOpacity(0.1) : null,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.primaryNavy,
            child: Text('${inst.installmentNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('القسط ${inst.installmentNumber}: ${inst.amount} ل.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('الاستحقاق: ${inst.dueDate.toString().substring(0, 10)}'),
                if (isPaid)
                  Text('✅ تم التسديد في: ${inst.paidDate!.toString().substring(0, 10)}', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                if (isOverdue)
                  Text('⚠️ متأخر', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (!isPaid)
            ElevatedButton.icon(
              onPressed: () => _markInstallmentAsPaid(inst),
              icon: const Icon(Icons.check),
              label: const Text('تسجيل تسديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _markInstallmentAsPaid(ContractInstallment inst) async {
    final db = ref.read(databaseProvider);
    await db.contractDao.updateContractInstallment(
      ContractInstallmentsCompanion(
        id: Value(inst.id),
        contractId: Value(inst.contractId),
        installmentNumber: Value(inst.installmentNumber),
        amount: Value(inst.amount),
        dueDate: Value(inst.dueDate),
        paidDate: Value(DateTime.now()),
        paidAmount: Value(inst.amount),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل التسديد بنجاح'), backgroundColor: AppColors.success),
      );
    }
  }
}
