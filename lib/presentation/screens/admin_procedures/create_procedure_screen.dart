import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/archive_context_banner.dart';
import 'procedure_detail_screen.dart';

/// شاشة تسجيل معاملة وإجراء إداري جديد مع توليد الـ Checklist التلقائي (CreateProcedureScreen V6.2)
class CreateProcedureScreen extends ConsumerStatefulWidget {
  final ArchiveEntryContext? archiveContext;
  const CreateProcedureScreen({super.key, this.archiveContext});

  @override
  ConsumerState<CreateProcedureScreen> createState() => _CreateProcedureScreenState();
}

class _CreateProcedureScreenState extends ConsumerState<CreateProcedureScreen> {
  final _formKey = GlobalKey<FormState>();

  String _category = 'أحوال شخصية';
  String _subType = 'حصر إرث شرعي / مدني';
  int? _selectedClientId;

  final _titleController = TextEditingController();
  final _transNumController = TextEditingController();
  final _deptController = TextEditingController(text: 'محكمة الصلح / السجل المدني');
  DateTime _startDate = DateTime.now();
  DateTime? _nextDate = DateTime.now().add(const Duration(days: 3));

  bool _isSaving = false;

  final Map<String, List<String>> _subTypesMap = {
    'أحوال شخصية': ['حصر إرث شرعي / مدني', 'تصحيح قيد مدني', 'تغيير اسم أو كنية', 'وصاية / ولاية قاصر', 'إذن سفر قاصر', 'بيان قيد عائلي / فردي'],
    'إجراءات عقارية': ['نقل ملكية وفراغ عقاري', 'رهن عقاري / فك رهن', 'إفراز وضم عقاري', 'تسجيل عقار في السجل المؤقت', 'بيان قيد عقاري / مساحة', 'تسوية عقارية'],
    'إجراءات تجارية': ['تسجيل في السجل التجاري', 'تعديل أو شطب سجل تجاري', 'تسجيل علامة تجارية / براءة اختراع', 'تجديد علامة تجارية', 'ترخيص وكالة تجارية', 'ترخيص استيراد وتصدير'],
  };

  @override
  void initState() {
    super.initState();
    _titleController.text = 'معاملة حصر إرث وتصحيح قيد';
    final archive = widget.archiveContext;
    if (archive != null && (archive.procedureType ?? '').isNotEmpty) {
      final type = archive.procedureType!;
      if (!_subTypesMap.containsKey(type)) {
        _subTypesMap[type] = [type];
      }
      _category = type;
      _subType = _subTypesMap[type]!.first;
      _titleController.text = archive.isClosed ? 'أرشفة إجراء منتهٍ - $type' : 'إدخال إجراء جارٍ - $type';
      if (archive.isClosed) _nextDate = null;
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
        title: Text(widget.archiveContext == null ? 'تسجيل معاملة وإجراء إداري جديد في المكتب (V6.2)' : (widget.archiveContext!.isRunning ? 'إدخال إجراء أرشيفي جارٍ' : 'أرشفة إجراء منتهٍ')),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArchiveContextBanner(contextInfo: widget.archiveContext),
                const Text('1. تصنيف الإجراء والنوع الفرعي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'التصنيف الرئيسي *'),
                        items: _subTypesMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _category = val!;
                            _subType = _subTypesMap[_category]!.first;
                            if (_category == 'إجراءات عقارية') _deptController.text = 'مديرية المصالح العقارية / المالية';
                            if (_category == 'إجراءات تجارية') _deptController.text = 'مديرية الشركات / غرفة التجارة';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _subType,
                        decoration: const InputDecoration(labelText: 'النوع الفرعي *'),
                        items: _subTypesMap[_category]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setState(() => _subType = val!),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة تصنيف رئيسي'),
                        onPressed: () async {
                          final value = await _askCustomValue('إضافة تصنيف إجراء');
                          if (value == null || value.isEmpty) return;
                          setState(() {
                            _subTypesMap[value] = [value];
                            _category = value;
                            _subType = value;
                          });
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة نوع فرعي'),
                        onPressed: () async {
                          final value = await _askCustomValue('إضافة نوع فرعي للإجراء');
                          if (value == null || value.isEmpty) return;
                          setState(() {
                            final list = _subTypesMap[_category]!;
                            if (!list.contains(value)) list.add(value);
                            _subType = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text('2. الموكل والعنوان والدائرة المختصة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const SizedBox(height: 12),
                personsAsync.when(
                  data: (persons) => DropdownButtonFormField<int>(
                    value: _selectedClientId,
                    decoration: const InputDecoration(labelText: 'الموكل صاحب المعاملة *', prefixIcon: Icon(Icons.person)),
                    items: persons.map((p) => DropdownMenuItem(value: p.id, child: Text(p.fullName))).toList(),
                    onChanged: (val) => setState(() => _selectedClientId = val),
                    validator: (val) => val == null ? 'يجب اختيار الموكل' : null,
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('خطأ في تحميل أسماء الموكلين'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'عنوان المعاملة *', prefixIcon: Icon(Icons.title)),
                  validator: (val) => val == null || val.trim().isEmpty ? 'العنوان إلزامي' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _deptController,
                        decoration: const InputDecoration(labelText: 'الدائرة أو الجهة المسجل لديها *', prefixIcon: Icon(Icons.account_balance)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _transNumController,
                        decoration: const InputDecoration(labelText: 'رقم الطلب / المعاملة (إن وجد)', prefixIcon: Icon(Icons.numbers)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(widget.archiveContext?.isClosed == true ? '3. أثر الأرشيف المنتهي:' : '3. ★ الموعد القادم للمراجعة (إلزامي وفقاً للدستور V6.2) ★:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                const SizedBox(height: 12),
                if (widget.archiveContext?.isClosed == true)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryNavy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppConstants.primaryNavy.withOpacity(0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.inventory_2, color: AppConstants.primaryNavy),
                        SizedBox(width: 12),
                        Expanded(child: Text('هذا الإجراء محفوظ للأرشيف والبحث فقط، ولن يتم تسجيل موعد مراجعة قادم أو توليد مهمة في مكتب العمل.')),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _nextDate != null ? AppConstants.statusSuccess.withOpacity(0.1) : AppConstants.statusDanger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _nextDate != null ? AppConstants.statusSuccess : AppConstants.statusDanger),
                    ),
                    child: Row(
                      children: [
                        Icon(_nextDate != null ? Icons.check_circle : Icons.warning_amber, color: _nextDate != null ? AppConstants.statusSuccess : AppConstants.statusDanger),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _nextDate != null ? 'موعد المراجعة القادم: ${_nextDate!.toString().substring(0, 10)}' : 'لم يتم تحديد موعد (سيولد إشعار نقص في تبويب النواقص)',
                            style: TextStyle(fontWeight: FontWeight.bold, color: _nextDate != null ? AppConstants.statusSuccess : AppConstants.statusDanger),
                          ),
                        ),
                        ElevatedButton(
                          child: const Text('تحديد التاريخ'),
                          onPressed: () async {
                            final p = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 3)), firstDate: DateTime.now(), lastDate: DateTime(2030));
                            if (p != null) setState(() => _nextDate = p);
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_isSaving
                        ? (widget.archiveContext?.isClosed == true ? 'جارٍ حفظ الإجراء في الأرشيف...' : 'جارٍ الحفظ وتوليد الـ Checklist...')
                        : (widget.archiveContext?.isClosed == true ? 'حفظ الإجراء في الأرشيف المنتهي' : 'اعتماد وحفظ المعاملة في المكتب مع خطوات التنفيذ التلقائية')),
                    onPressed: _isSaving ? null : _saveProcedure,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProcedure() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.proceduresCreate)) {
      await ref.read(auditServiceProvider).log(
        action: 'access_denied',
        category: 'procedures',
        entityType: 'procedure',
        description: 'محاولة إنشاء إجراء إداري دون صلاحية',
        severity: 'warning',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا تملك صلاحية إنشاء إجراء إداري'), backgroundColor: AppConstants.statusDanger));
      }
      return;
    }
    if (!_formKey.currentState!.validate() || _selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار الموكل وتعبئة الحقول المطلوبة!'), backgroundColor: AppConstants.statusDanger));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(adminProcedureRepositoryProvider);

      final companion = AdminProceduresCompanion.insert(
        internalNumber: 'TEMP-${DateTime.now().microsecondsSinceEpoch}',
        procedureType: _category,
        subType: drift.Value(_subType),
        clientId: _selectedClientId!,
        title: _titleController.text.trim(),
        status: drift.Value(widget.archiveContext?.isClosed == true ? 2 : 1),
        department: drift.Value(_deptController.text.trim()),
        transactionNumber: drift.Value(_transNumController.text.trim()),
        currentStep: drift.Value(widget.archiveContext == null ? null : 'سياق الأرشيف: ${widget.archiveContext!.summary}'),
        startDate: drift.Value(_startDate),
        nextDate: drift.Value(widget.archiveContext?.isClosed == true ? null : _nextDate),
      );

      final List<AdminStepsCompanion> initialSteps = widget.archiveContext?.isClosed == true
          ? const <AdminStepsCompanion>[]
          : [
              AdminStepsCompanion.insert(procedureId: 0, stepTitle: 'تقديم الطلب الأولي واستيفاء الشروط', stepDate: drift.Value(DateTime.now()), status: const drift.Value(1)),
              AdminStepsCompanion.insert(procedureId: 0, stepTitle: 'مراجعة الدائرة المختصة ودفع الرسوم المقررة', status: const drift.Value(0)),
              AdminStepsCompanion.insert(procedureId: 0, stepTitle: 'استلام البيان أو السند النهائي وتدقيقه', status: const drift.Value(0)),
            ];

      final procId = await repo.createProcedure(
        procedure: companion,
        initialSteps: initialSteps,
        userRef: ref.read(authControllerProvider).user?.fullName ?? AppConstants.defaultLawyerName,
      );
      await ref.read(auditServiceProvider).log(
        action: 'create',
        category: 'procedures',
        entityType: 'procedure',
        entityId: '$procId',
        entityTitle: _titleController.text.trim(),
        description: 'إنشاء إجراء إداري',
        after: {'title': _titleController.text.trim(), 'category': _category, 'subType': _subType, if (widget.archiveContext != null) 'archive': widget.archiveContext!.summary, if (widget.archiveContext != null) 'archiveStatus': widget.archiveContext!.status},
        severity: 'info',
      );

      if (mounted) {
        ref.invalidate(allProceduresProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.archiveContext?.isClosed == true ? 'تم حفظ الإجراء في الأرشيف المنتهي بنجاح!' : 'تم تسجيل المعاملة وتوليد خطوات الـ Checklist بنجاح!'), backgroundColor: AppConstants.statusSuccess));
        GoRouter.of(context).pushReplacement('/procedures/$procId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في حفظ المعاملة: $e'), backgroundColor: AppConstants.statusDanger));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
