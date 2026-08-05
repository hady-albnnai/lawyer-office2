import 'dart:io';

import 'package:file_picker/file_picker.dart' as file_picker;
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
import '../../widgets/common/searchable_picker.dart';

/// شاشة تسجيل معاملة وإجراء إداري جديد مع توليد الـ Checklist التلقائي (CreateProcedureScreen V6.2)
class CreateProcedureScreen extends ConsumerStatefulWidget {
  final ArchiveEntryContext? archiveContext;
  const CreateProcedureScreen({super.key, this.archiveContext});

  @override
  ConsumerState<CreateProcedureScreen> createState() => _CreateProcedureScreenState();
}

class _CreateProcedureScreenState extends ConsumerState<CreateProcedureScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  String _category = 'أحوال شخصية';
  String _subType = 'حصر إرث شرعي / مدني';
  int? _selectedClientId;

  final _titleController = TextEditingController();
  final _transNumController = TextEditingController();
  final _deptController = TextEditingController(text: 'محكمة الصلح / السجل المدني');
  final DateTime _startDate = DateTime.now();
  DateTime? _nextDate = DateTime.now().add(const Duration(days: 3));

  // ===========================================================================
  // المرفقات
  // ===========================================================================
  final List<String> _attachmentPaths = [];
  final List<TextEditingController> _attachmentControllers = [];

  bool _isSaving = false;

  final Map<String, List<String>> _subTypesMap = {
    'أحوال شخصية': ['حصر إرث شرعي / مدني', 'تصحيح قيد مدني', 'تغيير اسم أو كنية', 'وصاية / ولاية قاصر', 'إذن سفر قاصر', 'بيان قيد عائلي / فردي'],
    'إجراءات عقارية': ['نقل ملكية وفراغ عقاري', 'رهن عقاري / فك رهن', 'إفراز وضم عقاري', 'تسجيل عقار في السجل المؤقت', 'بيان قيد عقاري / مساحة', 'تسوية عقارية'],
    'إجراءات تجارية': ['تسجيل في السجل التجاري', 'تعديل أو شطب سجل تجاري', 'تسجيل علامة تجارية / براءة اختراع', 'تجديد علامة تجارية', 'ترخيص وكالة تجارية', 'ترخيص استيراد وتصدير'],
    'إجراءات تنفيذية': ['فتح ملف تنفيذي', 'إعلان خصم', 'حجز احتياطي / تنفيذي', 'طلب إخلاء عقار', 'بيع بالمزاد العلني', 'إغلاق ملف تنفيذي'],
    'إجراءات إدارية عامة': ['تصديق وثائق', 'ترجمة محلفة', 'طلب بيان أو شهادة', 'تقديم شكوى إدارية', 'معاملة تأمينات اجتماعية', 'أخرى'],
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

  /// إرجاع فهرس آخر خطوة في الويزارد
  /// الأرشيف المنتهي: 3 خطوات (بدون موعد قادم)
  /// الأرشيف الجاري أو الإجراء الجديد: 4 خطوات (مع موعد قادم)
  int _getLastStepIndex() {
    return widget.archiveContext?.isClosed == true ? 2 : 3;
  }

  void _nextStep() {
    if (!_validateCurrentStep()) {
      return;
    }
    
    if (_currentStep < _getLastStepIndex()) {
      setState(() => _currentStep++);
    }
  }
  
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }
  
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // التصنيف
        // التصنيف له قيم افتراضية، لا يحتاج تحقق
        break;
      case 1: // الموكل والبيانات
        if (_selectedClientId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى اختيار الموكل'),
              backgroundColor: AppConstants.statusDanger,
            ),
          );
          return false;
        }
        if (_titleController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى إدخال عنوان المعاملة'),
              backgroundColor: AppConstants.statusDanger,
            ),
          );
          return false;
        }
        break;
      case 2: // المرفقات
        // المرفقات اختيارية
        break;
      case 3: // الموعد القادم
        if (widget.archiveContext?.isClosed == true) {
          return true;
        }
        if (_nextDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى تحديد موعد المراجعة القادم'),
              backgroundColor: AppConstants.statusDanger,
            ),
          );
          return false;
        }
        break;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final lastStep = _getLastStepIndex();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.archiveContext == null ? 'تسجيل معاملة وإجراء إداري جديد' : (widget.archiveContext!.isRunning ? 'إدخال إجراء أرشيفي جارٍ' : 'أرشفة إجراء منتهٍ')),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // شريط التقدم
            _buildProgressBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ArchiveContextBanner(contextInfo: widget.archiveContext),
            ),
            
            // المحتوى
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildCurrentStepContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          border: Border.all(color: AppConstants.cardBorder, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // زر الرجوع (السابق)
            if (_currentStep > 0)
              TextButton.icon(
                onPressed: _isSaving ? null : _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('السابق'),
              )
            else
              const SizedBox.shrink(),
            
            // زر التالي أو حفظ
            if (_currentStep < lastStep)
              TextButton.icon(
                onPressed: _isSaving ? null : _nextStep,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('التالي'),
              ),
            if (_currentStep == lastStep)
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProcedure,
                icon: _isSaving 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(widget.archiveContext?.isClosed == true 
                    ? 'حفظ الإجراء في الأرشيف المنتهي' 
                    : 'اعتماد وحفظ المعاملة'),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // شريط التقدم
  // ===========================================================================
  
  Widget _buildProgressBar() {
    final lastStep = _getLastStepIndex();
    final totalSteps = lastStep + 1;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppConstants.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الخطوات
          Row(
            children: List.generate(totalSteps, (index) => _buildStepIndicator(index)),
          ),
          const SizedBox(height: 8),
          
          // أسماء الخطوات
          Row(
            children: List.generate(totalSteps, (index) => _buildStepLabel(index)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStepIndicator(int index) {
    final isCompleted = index < _currentStep;
    final isCurrent = index == _currentStep;
    
    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isCompleted 
              ? AppConstants.statusSuccess 
              : isCurrent 
                  ? AppConstants.primaryNavy 
                  : AppConstants.cardBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
  
  Widget _buildStepLabel(int index) {
    final isCompleted = index < _currentStep;
    final isCurrent = index == _currentStep;
    
    String label;
    switch (index) {
      case 0: label = 'التصنيف'; break;
      case 1: label = 'الموكل والبيانات'; break;
      case 2: label = 'المرفقات'; break;
      case 3: label = 'الموعد'; break;
      default: label = '';
    }
    
    return Expanded(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isCompleted 
              ? AppConstants.statusSuccess 
              : isCurrent 
                  ? AppConstants.primaryNavy 
                  : AppConstants.textMuted,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ===========================================================================
  // محتوى كل خطوة
  // ===========================================================================
  
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildClassificationStep();
      case 1:
        return _buildClientAndDataStep();
      case 2:
        return _buildAttachmentsStep();
      case 3:
        return _buildNextDateStep();
      default:
        return const SizedBox();
    }
  }
  
  Widget _buildStepHeader({
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 14, color: AppConstants.textMuted),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // الخطوة 1: التصنيف
  // ===========================================================================
  
  Widget _buildClassificationStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(
            title: 'تصنيف الإجراء',
            description: 'حدد التصنيف الرئيسي والنوع الفرعي للإجراء',
          ),
          const SizedBox(height: 24),
          
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
        ],
      ),
    );
  }

  // ===========================================================================
  // الخطوة 2: الموكل والبيانات
  // ===========================================================================
  
  Widget _buildClientAndDataStep() {
    final personsAsync = ref.watch(allPersonsProvider(null));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'الموكل والبيانات',
          description: 'حدد الموكل وأدخل بيانات المعاملة',
        ),
        const SizedBox(height: 24),
        
        personsAsync.when(
          data: (persons) {
            final selectedPerson = _selectedClientId == null
                ? null
                : persons.where((p) => p.id == _selectedClientId).firstOrNull;
            
            // التحقق إذا كان الشخص أيضاً خصم في دعاوى أخرى
            final isAlsoOpponentAsync = _selectedClientId != null
                ? ref.watch(personIsClientInOtherCasesProvider(_selectedClientId!))
                : null;
            final isAlsoOpponent = isAlsoOpponentAsync?.value ?? false;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchablePicker<PersonEntity>(
                  label: 'الموكل صاحب المعاملة *',
                  hintText: 'ابحث بالاسم أو الهاتف',
                  prefixIcon: const Icon(Icons.person_search),
                  items: persons,
                  labelOf: (p) => p.fullName,
                  searchTermsOf: (p) => [p.phone1 ?? '', p.nationalId ?? ''],
                  subtitleOf: (p) => p.phone1,
                  value: selectedPerson,
                  onSelected: (p) => setState(() => _selectedClientId = p.id),
                ),
                if (isAlsoOpponent)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.statusWarning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppConstants.statusWarning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: AppConstants.statusWarning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ هذا الشخص هو أيضاً خصم في دعاوى أخرى. تأكد من عدم وجود تعارض في المصالح.',
                            style: TextStyle(fontSize: 12, color: AppConstants.statusWarning),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('خطأ في تحميل أسماء الموكلين'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'عنوان المعاملة *', prefixIcon: Icon(Icons.title)),
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
      ],
    );
  }

  // ===========================================================================
  // الخطوة 3: المرفقات
  // ===========================================================================
  
  Widget _buildAttachmentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'المرفقات',
          description: 'أرفق المستندات المتعلقة بالإجراء (اختياري)',
        ),
        const SizedBox(height: 24),
        
        // قائمة المرفقات
        if (_attachmentPaths.isNotEmpty) ...[
          Text(
            'المرفقات المرفوعة:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppConstants.cardBorder, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attachmentPaths.length,
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppConstants.cardBorder, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, color: AppConstants.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _attachmentControllers[index].text.isNotEmpty
                              ? _attachmentControllers[index].text
                              : _attachmentPaths[index].split(Platform.pathSeparator).last,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete, color: AppConstants.statusDanger),
                        onPressed: () => _removeAttachment(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // زر إضافة مرفق
        ElevatedButton.icon(
          onPressed: _addAttachment,
          icon: const Icon(Icons.attach_file),
          label: const Text('إضافة مرفق'),
        ),
        const SizedBox(height: 8),
        Text(
          'يمكنك إضافة المرفقات لاحقاً من شاشة تفاصيل الإجراء',
          style: TextStyle(fontSize: 12, color: AppConstants.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Future<void> _addAttachment() async {
    final result = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: file_picker.FileType.custom,
      allowedExtensions: AppConstants.allowedAttachmentExtensions,
    );
    if (result == null) return;
    final picked = result.files.where((f) => (f.path ?? '').isNotEmpty).toList();
    if (picked.isEmpty) return;
    setState(() {
      for (final file in picked) {
        _attachmentPaths.add(file.path!);
        _attachmentControllers.add(TextEditingController(text: file.name));
      }
    });
  }
  
  void _removeAttachment(int index) {
    setState(() {
      _attachmentPaths.removeAt(index);
      _attachmentControllers[index].dispose();
      _attachmentControllers.removeAt(index);
    });
  }

  // ===========================================================================
  // الخطوة 4: الموعد القادم
  // ===========================================================================
  
  Widget _buildNextDateStep() {
    if (widget.archiveContext?.isClosed == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(
            title: 'أثر الأرشيف المنتهي',
            description: 'هذا الإجراء محفوظ للأرشيف والبحث فقط',
          ),
          const SizedBox(height: 24),
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
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'الموعد القادم للمراجعة',
          description: '⚠️ يجب تحديد موعد المراجعة القادم',
        ),
        const SizedBox(height: 24),
        
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
                  _nextDate != null ? 'موعد المراجعة القادم: ${_nextDate!.toString().substring(0, 10)}' : 'لم يتم تحديد موعد (سيولد إشعار نقص)',
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
      ],
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
