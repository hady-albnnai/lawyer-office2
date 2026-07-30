import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/archive_context_banner.dart';
import '../../widgets/common/searchable_picker.dart';

/// شاشة تنظيم وإبرام عقد جديد أو رفع عقد سابق للتحرير والربط (CreateContractScreen V6.2)
class CreateContractScreen extends ConsumerStatefulWidget {
  final ArchiveEntryContext? archiveContext;
  const CreateContractScreen({super.key, this.archiveContext});

  @override
  ConsumerState<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends ConsumerState<CreateContractScreen> {
  final _formKey = GlobalKey<FormState>();

  String _contractType = 'عقد بيع عقاري';
  final _titleController = TextEditingController();
  final _locationController = TextEditingController(text: 'سوريا - دمشق');
  final _valueController = TextEditingController(text: '0');
  String _currency = 'ل.س';

  /// SearchablePicker ليس FormField، فالتحقق يجري يدوياً عند الحفظ.
  bool _partiesTouched = false;
  int? _party1PersonId;
  int? _party2PersonId;

  bool _isRenewable = false;
  bool _needsFollowup = true;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));

  // التذكيرات الملتصقة
  int _expiryDaysBefore = 30;
  final _reminderPhoneController = TextEditingController();
  final _reminderNoteController = TextEditingController(text: 'تذكير بموعد انتهاء/تجديد العقد وتحديد الموقف القانوني');

  File? _wordFile;
  bool _isSaving = false;

  final List<String> _types = [
    'عقد بيع عقاري',
    'عقد إيجار سكني / تجاري',
    'عقد عمل وخدمات مهنية',
    'عقد شراكة تجارية',
    'عقد مقاولة وتعهدات',
    'عقد صلح وتسوية منازعات',
  ];

  @override
  void initState() {
    super.initState();
    final archive = widget.archiveContext;
    if (archive != null) {
      if ((archive.contractType ?? '').isNotEmpty) {
        _contractType = archive.contractType!;
        if (!_types.contains(_contractType)) _types.add(_contractType);
      }
      _titleController.text = archive.isClosed ? 'أرشفة عقد منتهٍ - $_contractType' : 'إدخال عقد جارٍ - $_contractType';
      if (archive.isClosed) _needsFollowup = false;
    }
  }

  Future<String?> _askCustomValue(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'القيمة الجديدة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personsAsync = ref.watch(allPersonsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.archiveContext == null ? 'تنظيم عقد جديد في المكتب مع ربط التنبيهات ونماذج Word' : (widget.archiveContext!.isRunning ? 'إدخال عقد أرشيفي جارٍ' : 'أرشفة عقد منتهٍ')),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArchiveContextBanner(contextInfo: widget.archiveContext),
                const Text('1. تصنيف العقد والعنوان:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _contractType,
                        decoration: const InputDecoration(labelText: 'نوع العقد *'),
                        items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => setState(() => _contractType = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'عنوان العقد المميز * (مثال: عقد بيع شقة بدمشق - المزة)'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'عنوان العقد إلزامي' : null,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة نوع عقد غير موجود'),
                    onPressed: () async {
                      final value = await _askCustomValue('إضافة نوع عقد');
                      if (value == null || value.isEmpty) return;
                      setState(() {
                        if (!_types.contains(value)) _types.add(value);
                        _contractType = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),

                const Text('2. الأطراف المتعاقدة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const SizedBox(height: 12),
                personsAsync.when(
                  data: (persons) => Row(
                    children: [
                      Expanded(
                        child: SearchablePicker<PersonEntity>(
                          label: 'الطرف الأول (البائع / المؤجر / صاحب العمل) *',
                          hintText: 'ابحث بالاسم أو الهاتف',
                          prefixIcon: const Icon(Icons.person_search),
                          items: persons,
                          labelOf: (p) => p.fullName,
                          searchTermsOf: (p) =>
                              [p.phone1 ?? '', p.nationalId ?? ''],
                          subtitleOf: (p) => p.phone1,
                          errorText: _partiesTouched && _party1PersonId == null
                              ? 'إلزامي'
                              : null,
                          value: _party1PersonId == null
                              ? null
                              : persons
                                  .where((p) => p.id == _party1PersonId)
                                  .firstOrNull,
                          onSelected: (p) =>
                              setState(() => _party1PersonId = p.id),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SearchablePicker<PersonEntity>(
                          label: 'الطرف الثاني (المشتري / المستأجر / العامل) *',
                          hintText: 'ابحث بالاسم أو الهاتف',
                          prefixIcon: const Icon(Icons.person_search),
                          items: persons,
                          labelOf: (p) => p.fullName,
                          searchTermsOf: (p) =>
                              [p.phone1 ?? '', p.nationalId ?? ''],
                          subtitleOf: (p) => p.phone1,
                          errorText: _partiesTouched && _party2PersonId == null
                              ? 'إلزامي'
                              : null,
                          value: _party2PersonId == null
                              ? null
                              : persons
                                  .where((p) => p.id == _party2PersonId)
                                  .firstOrNull,
                          onSelected: (p) =>
                              setState(() => _party2PersonId = p.id),
                        ),
                      ),
                    ],
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('خطأ في تحميل أسماء الأطراف'),
                ),
                const SizedBox(height: 24),

                const Text('2.5. التواريخ:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectStartDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'تاريخ البدء *',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '${_startDate.year}/${_startDate.month}/${_startDate.day}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectEndDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'تاريخ الانتهاء *',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorText: _endDate.isBefore(_startDate) ? 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء' : null,
                          ),
                          child: Text(
                            '${_endDate.year}/${_endDate.month}/${_endDate.day}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text('3. القيم المالية والإبرام:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _valueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'القيمة المالية الإجمالية *'),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) return 'القيمة المالية إلزامية';
                          final numericValue = double.tryParse(value!.trim());
                          if (numericValue == null || numericValue < 0) return 'يرجى إدخال قيمة صالحة أكبر من أو تساوي صفر';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: const InputDecoration(labelText: 'العملة'),
                        items: ['ل.س', 'دولار', 'يورو'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) => setState(() => _currency = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(labelText: 'مكان إبرام العقد'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(widget.archiveContext?.isClosed == true ? '4. أثر الأرشيف المنتهي:' : '4. التذكيرات والمتابعة الزمنية (الأتمتة مع جدول الأعمال اليومية):', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const SizedBox(height: 12),
                if (widget.archiveContext?.isClosed == true)
                  Card(
                    color: AppConstants.primaryNavy.withOpacity(0.04),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2, color: AppConstants.primaryNavy),
                          SizedBox(width: 12),
                          Expanded(child: Text('هذا العقد محفوظ للأرشيف والبحث فقط، لذلك لن يتم إنشاء تذكير انتهاء أو تجديد في مكتب العمل.')),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    color: AppConstants.primaryNavy.withOpacity(0.04),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: _needsFollowup,
                            title: const Text('هذا العقد يحتاج متابعة وتذكير بموعد انتهائه أو تجديده ⏰', style: TextStyle(fontWeight: FontWeight.bold)),
                            onChanged: (val) => setState(() => _needsFollowup = val ?? false),
                          ),
                          if (_needsFollowup) ...[
                            Row(
                              children: [
                                const Text('التذكير قبل: '),
                                const SizedBox(width: 12),
                                DropdownButton<int>(
                                  value: _expiryDaysBefore,
                                  items: [7, 15, 30, 60, 90].map((d) => DropdownMenuItem(value: d, child: Text('$d يوماً من الانتهاء'))).toList(),
                                  onChanged: (val) => setState(() => _expiryDaysBefore = val!),
                                ),
                                const SizedBox(width: 24),
                                Checkbox(value: _isRenewable, onChanged: (val) => setState(() => _isRenewable = val ?? false)),
                                const Text('العقد قابل للتجديد (إضافة تنبيه تجديد أيضاً)'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _reminderPhoneController,
                              decoration: const InputDecoration(labelText: 'رقم هاتف التواصل عند التذكير', prefixIcon: Icon(Icons.phone_in_talk)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _reminderNoteController,
                              decoration: const InputDecoration(labelText: 'ملاحظة التذكير (ستظهر في مهام اليوم عندما يحين الموعد)'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                const Text('5. إرفاق ملف العقد (نموذج Word أو PDF):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: AppConstants.accentGold), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: AppConstants.accentGold, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_wordFile == null
                            ? 'لم يتم رفع ملف (يمكنك الاختيار من القوالب أو رفع ملف .docx/.pdf خارجي)'
                            : 'تم اختيار الملف: ${path.basename(_wordFile!.path)}'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentGold),
                        onPressed: _pickFile,
                        child: const Text('اختيار ملف Word'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle),
                    label: Text(_isSaving
                        ? (widget.archiveContext?.isClosed == true ? 'جارٍ حفظ العقد في الأرشيف...' : 'جارٍ حفظ وتنظيم العقد...')
                        : (widget.archiveContext?.isClosed == true ? 'حفظ العقد في الأرشيف المنتهي' : 'اعتماد وحفظ العقد وتفعيل التذكيرات الزمنية')),
                    onPressed: _isSaving ? null : _saveContract,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['docx', 'doc', 'pdf', 'rtf']);
    if (res != null && res.files.single.path != null) {
      setState(() => _wordFile = File(res.files.single.path!));
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime(DateTime.now().year + 20),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _saveContract() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.contractsCreate)) {
      await ref.read(auditServiceProvider).log(
        action: 'access_denied',
        category: 'contracts',
        entityType: 'contract',
        description: 'محاولة إنشاء عقد دون صلاحية',
        severity: 'warning',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا تملك صلاحية إنشاء عقد'), backgroundColor: AppConstants.statusDanger));
      }
      return;
    }
    // إظهار خطأ حقلي الطرفين لأنهما ليسا FormField ولا يلتقطهما validate.
    setState(() => _partiesTouched = true);
    if (!_formKey.currentState!.validate() || _party1PersonId == null || _party2PersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار الأطراف المتعاقدة وتعبئة الحقول المطلوبة!'), backgroundColor: AppConstants.statusDanger));
      return;
    }
    
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء!'), backgroundColor: AppConstants.statusDanger));
      return;
    }

    // التحقق من عدم تكرار العقد
    final contractsAsync = ref.read(allContractsProvider);
    final contracts = contractsAsync.value ?? [];
    final isDuplicate = contracts.any((contract) => 
      contract.title.toLowerCase().trim() == _titleController.text.toLowerCase().trim()
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عقد بهذا العنوان موجود مسبقاً!'), backgroundColor: AppConstants.statusDanger));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(contractRepositoryProvider);

      final contractCompanion = ContractsCompanion.insert(
        internalNumber: 'TEMP-${DateTime.now().microsecondsSinceEpoch}',
        title: _titleController.text.trim(),
        contractType: _contractType,
        status: drift.Value(widget.archiveContext?.isClosed == true ? 'archived' : 'active'),
        dateSigned: drift.Value(_startDate),
        dateStart: drift.Value(_startDate),
        dateEnd: drift.Value(_endDate),
        location: drift.Value(_locationController.text.trim()),
        financialValue: drift.Value(double.tryParse(_valueController.text.trim()) ?? 0),
        currency: drift.Value(_currency),
        isRenewable: drift.Value(widget.archiveContext?.isClosed == true ? false : _isRenewable),
        needsFollowup: drift.Value(widget.archiveContext?.isClosed == true ? false : _needsFollowup),
        summary: drift.Value(widget.archiveContext?.summary),
        notes: drift.Value(widget.archiveContext == null ? null : 'سياق الأرشيف: ${widget.archiveContext!.summary}\nالحالة: ${widget.archiveContext!.statusLabel}'),
      );

      final parties = [
        ContractPartiesCompanion.insert(contractId: 0, personId: _party1PersonId!, partyRole: const drift.Value('الطرف الأول (بائع/مؤجر/صاحب عمل)'), partyOrder: const drift.Value(1)),
        ContractPartiesCompanion.insert(contractId: 0, personId: _party2PersonId!, partyRole: const drift.Value('الطرف الثاني (مشتري/مستأجر/عامل)'), partyOrder: const drift.Value(2)),
      ];

      final List<ContractRemindersCompanion> reminders = [];
      if (_needsFollowup) {
        final reminderDate = _endDate.subtract(Duration(days: _expiryDaysBefore));
        reminders.add(ContractRemindersCompanion.insert(
          contractId: 0,
          reminderType: 'expiry',
          reminderDate: reminderDate,
          daysBefore: drift.Value(_expiryDaysBefore),
          contactPhone: drift.Value(_reminderPhoneController.text.trim()),
          reminderNote: drift.Value(_reminderNoteController.text.trim()),
        ));
      }

      final contractId = await repo.createContract(
        contract: contractCompanion,
        parties: parties,
        reminders: reminders,
        wordFile: _wordFile,
        userRef: ref.read(authControllerProvider).user?.fullName ?? AppConstants.defaultLawyerName,
      );
      await ref.read(auditServiceProvider).log(
        action: 'create',
        category: 'contracts',
        entityType: 'contract',
        entityId: '$contractId',
        entityTitle: _titleController.text.trim(),
        description: 'إنشاء عقد جديد',
        after: {'title': _titleController.text.trim(), 'type': _contractType, 'value': _valueController.text.trim(), if (widget.archiveContext != null) 'archive': widget.archiveContext!.summary, if (widget.archiveContext != null) 'archiveStatus': widget.archiveContext!.status},
        severity: 'info',
      );

      if (mounted) {
        ref.invalidate(allContractsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.archiveContext?.isClosed == true ? 'تم حفظ العقد في الأرشيف المنتهي بنجاح!' : 'تم تنظيم وحفظ العقد وتوليد التذكيرات بنجاح!'), backgroundColor: AppConstants.statusSuccess));
        GoRouter.of(context).pushReplacement('/contracts/$contractId');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e.toString().contains('UNIQUE constraint')) {
          errorMessage = 'العقد موجود مسبقاً';
        } else if (e.toString().contains('FOREIGN KEY')) {
          errorMessage = 'مرجع غير صالح (الأطراف)';
        } else if (e.toString().contains('NOT NULL')) {
          errorMessage = 'حقل إلزامي فارغ';
        } else {
          errorMessage = 'خطأ أثناء تنظيم العقد';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: AppConstants.statusDanger));
        
        // تسجيل الخطأ التفصيلي
        await ref.read(auditServiceProvider).log(
          action: 'error',
          category: 'contracts',
          entityType: 'contract',
          description: 'فشل حفظ العقد: $e',
          severity: 'error',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
