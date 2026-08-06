import 'dart:ui';
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

/// معالج تأسيس شركة جديدة أو أرشفة شركة قائمة (CreateCompanyWizard V6.2)
class CreateCompanyWizard extends ConsumerStatefulWidget {
  final ArchiveEntryContext? archiveContext;
  const CreateCompanyWizard({super.key, this.archiveContext});

  @override
  ConsumerState<CreateCompanyWizard> createState() => _CreateCompanyWizardState();
}

class _CreateCompanyWizardState extends ConsumerState<CreateCompanyWizard> {
  int _currentStep = 0;

  // الخطوة 1: نوع مسار التأسيس
  bool _isNewEstablishment = true;

  // الخطوة 2: الشكل القانوني للشركة
  String _companyType = 'شركة محدودة المسؤولية';

  // الخطوة 3: البيانات الأساسية والعقار
  final _nameController = TextEditingController();
  final _activityController = TextEditingController();
  final _capitalController = TextEditingController(text: '10000000');
  final _paidCapitalController = TextEditingController(text: '10000000');
  final _durationController = TextEditingController(text: '99');
  final _addressController = TextEditingController(text: 'سوريا - دمشق');
  final _propertyDetailsController = TextEditingController(text: 'ملك / إيجار - عقار رقم ...');

  // الخطوة 4: الشركاء وحصصهم
  final List<CompanyPartnersCompanion> _selectedPartners = [];
  int? _tempPartnerPersonId;
  String _tempShareType = 'cash';
  final _tempShareValueController = TextEditingController();
  final _tempSharePercentController = TextEditingController();
  /// أي حقل شريك ناقص: person | value | percent
  String? _partnerFieldError;

  // الخطوة 5: الإدارة والمدير العام
  final List<CompanyDirectorsCompanion> _selectedDirectors = [];
  int? _tempDirectorPersonId;
  final _tempAuthorityController = TextEditingController(text: 'مدير عام ومفوض بالتوقيع منفرداً');

  bool _isSaving = false;

  final List<String> _companyTypes = [
    'شركة تضامن (أشخاص)',
    'شركة توصية بسيطة (أشخاص)',
    'شركة محاصة (أشخاص)',
    'شركة محدودة المسؤولية (أموال)',
    'شركة الشخص الواحد محدودة المسؤولية',
    'شركة مساهمة مغفلة خاصة (أموال)',
    'شركة مساهمة مغفلة عامة (أموال)',
  ];

  @override
  void initState() {
    super.initState();
    final archive = widget.archiveContext;
    if (archive != null) {
      _isNewEstablishment = false;
      if ((archive.companyType ?? '').isNotEmpty) {
        _companyType = archive.companyType!;
        if (!_companyTypes.contains(_companyType)) _companyTypes.add(_companyType);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.archiveContext == null ? 'معالج تأسيس شركة تجارية أو أرشفة شركة قائمة (V6.2)' : (widget.archiveContext!.isRunning ? 'إدخال شركة أرشيفية جارية' : 'أرشفة شركة منتهية')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ArchiveContextBanner(contextInfo: widget.archiveContext),
          ),
          Expanded(
            child: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onContinue,
        onStepCancel: _onCancel,
        // الرجوع للخطوات السابقة بالنقر على عناوينها. التحقق يُطبَّق
        // عند التقدّم فقط، فالرجوع لمراجعة بيانات مُدخلة لا يُمنع.
        onStepTapped: (index) {
          if (index < _currentStep) setState(() => _currentStep = index);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(_currentStep == 4 ? Icons.check_circle : Icons.arrow_forward),
                  label: Text(_currentStep == 4
                      ? (_isSaving
                          ? (widget.archiveContext?.isClosed == true ? 'جارٍ أرشفة الشركة...' : 'جارٍ تأسيس الشركة...')
                          : (widget.archiveContext?.isClosed == true ? 'حفظ الشركة في الأرشيف المنتهي' : 'اعتماد وتوليد مراحل التأسيس الـ 10'))
                      : 'التالي'),
                  onPressed: _isSaving ? null : details.onStepContinue,
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('السابق'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('مسار التأسيس'),
            subtitle: Text(_isNewEstablishment ? 'تأسيس جديد من الصفر' : 'أرشفة شركة قائمة'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
            content: _buildPathStep(),
          ),
          Step(
            title: const Text('الشكل القانوني للشركة'),
            subtitle: Text(_companyType),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
            content: _buildTypeStep(),
          ),
          Step(
            title: const Text('البيانات الأساسية والمقر'),
            subtitle: Text(_nameController.text.isNotEmpty ? _nameController.text : 'إلزامي *'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.editing,
            content: _buildBasicDataStep(),
          ),
          Step(
            title: const Text('الشركاء'),
            subtitle: Text(_selectedPartners.isEmpty
                ? 'المطلوب: $_partnersRuleLabel'
                : '${_selectedPartners.length} شريك • مجموع النسب ${_totalSharePercent.toStringAsFixed(1)}%'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.editing,
            content: _buildPartnersStep(),
          ),
          Step(
            title: const Text('الإدارة والتفويض بالتوقيع'),
            subtitle: Text(_selectedDirectors.isEmpty
                ? 'لم يُضف مديرون بعد'
                : '${_selectedDirectors.length} مدير/مفوض'),
            isActive: _currentStep >= 4,
            state: _currentStep > 4
                ? StepState.complete
                : (_currentStep == 4 ? StepState.editing : StepState.indexed),
            content: _buildDirectorsStep(),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathStep() {
    // تحديد لون النص صراحةً: الاعتماد على الافتراضي كان يُنتج نصاً
    // أبيض على خلفية فاتحة فيختفي الخيار المحدد.
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? AppConstants.primaryNavy : AppConstants.textDark,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: selected,
        selectedColor: AppConstants.primaryNavy.withOpacity(0.15),
        backgroundColor: AppConstants.surfaceWhite,
        side: BorderSide(
          color: selected ? AppConstants.primaryNavy : AppConstants.textMuted,
        ),
        onSelected: (_) => onTap(),
      );
    }

    return Row(
      children: [
        chip(
          label: 'تأسيس جديد (من الصفر)',
          selected: _isNewEstablishment,
          onTap: () => setState(() => _isNewEstablishment = true),
        ),
        const SizedBox(width: 16),
        chip(
          label: 'أرشفة شركة قائمة ومسجلة',
          selected: !_isNewEstablishment,
          onTap: () => setState(() => _isNewEstablishment = false),
        ),
      ],
    );
  }

  Future<String?> _askCustomValue(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),
labelText: 'القيمة الجديدة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
  }

  Widget _buildTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اختر الشكل القانوني للشركة السورية:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        SearchablePicker<String>(
          label: 'الشكل القانوني',
          hintText: 'ابحث عن الشكل القانوني',
          prefixIcon: const Icon(Icons.business_center),
          items: _companyTypes,
          labelOf: (t) => t,
          value: _companyType,
          onSelected: (val) => setState(() => _companyType = val),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('إضافة شكل قانوني غير موجود'),
            onPressed: () async {
              final value = await _askCustomValue('إضافة نوع شركة');
              if (value == null || value.isEmpty) return;
              setState(() {
                if (!_companyTypes.contains(value)) _companyTypes.add(value);
                _companyType = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBasicDataStep() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'الاسم التجاري للشركة *',
            prefixIcon: Icon(Icons.business),
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),
          ),
          validator: (value) => (value?.trim().isEmpty ?? true) ? 'الاسم التجاري إلزامي' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _activityController,
          decoration: InputDecoration(
            labelText: 'الغاية / نشاط الشركة *',
            prefixIcon: Icon(Icons.work),
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),
          ),
          validator: (value) => (value?.trim().isEmpty ?? true) ? 'النشاط إلزامي' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _capitalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),
labelText: 'رأس المال المكتتب به (ل.س) *'),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'رأس المال إلزامي';
                  final capital = double.tryParse(value!.trim());
                  if (capital == null || capital <= 0) return 'يرجى إدخال رقم صالح أكبر من صفر';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _paidCapitalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),
labelText: 'رأس المال المدفوع (ل.س) *'),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'رأس المال المدفوع إلزامي';
                  final paidCapital = double.tryParse(value!.trim());
                  if (paidCapital == null || paidCapital < 0) return 'يرجى إدخال رقم صالح';
                  final declaredCapital = double.tryParse(_capitalController.text.trim()) ?? 0;
                  if (paidCapital > declaredCapital) return 'الرأس المال المدفوع لا يمكن أن يفوق المكتتب به';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),
labelText: 'مدة الشركة (بالسنوات)'),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'المدة إلزامية';
                  final duration = int.tryParse(value!.trim());
                  if (duration == null || duration <= 0) return 'يرجى إدخال مدة صالحة أكبر من صفر';
                  if (duration > 99) return 'المدة لا يمكن أن تتجاوز 99 سنة';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),
labelText: 'المقر الرئيسي / المحافظة *'),
                validator: (value) => (value?.trim().isEmpty ?? true) ? 'المقر الرئيسي إلزامي' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _propertyDetailsController,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),
labelText: 'بيانات وصفة المقر (عقد إيجار / ملك / رقم قيد)', prefixIcon: Icon(Icons.location_city)),
        ),
      ],
    );
  }

  /// هل الشكل المختار شركة شخص واحد؟
  ///
  /// النظام السوري يقصر هذه الشركة على شريك واحد، فالتحقق العام
  /// "شريك واحد على الأقل" لا يكفي: يجب منع إضافة شريك ثانٍ.
  bool get _isSinglePersonCompany =>
      _companyType.contains('الشخص الواحد');

  /// الحد الأدنى لعدد الشركاء حسب الشكل القانوني.
  int get _minPartners => _isSinglePersonCompany ? 1 : 2;

  /// الحد الأقصى لعدد الشركاء، أو null إن كان غير محدود.
  int? get _maxPartners => _isSinglePersonCompany ? 1 : null;

  /// وصف قيد الشركاء لعرضه في الواجهة.
  String get _partnersRuleLabel {
    if (_isSinglePersonCompany) return 'شريك واحد فقط (شركة شخص واحد)';
    return 'شريكان على الأقل';
  }

  /// مجموع نسب الشركاء المضافين — يُستخدم للتحقق والعرض.
  double get _totalSharePercent => _selectedPartners.fold<double>(
      0, (sum, p) => sum + (p.sharePercentage.value ?? 0));

  /// إنشاء شخص جديد دون مغادرة الويزارد.
  ///
  /// كان الشريك/المدير لا يُضاف إلا من سجل الأشخاص، وهو سجل قد لا
  /// يعرفه المستخدم ولا يملك بياناته مسبقاً.
  Future<PersonEntity?> _createPersonInline(String initialName, String title) async {
    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<PersonEntity>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),

                    labelText: 'الاسم الثلاثي *',
                    hintText: 'مثال: أحمد محمد العلي',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'الاسم إلزامي';
                    if (t.split(RegExp(r'\s+')).length < 3) {
                      return 'أدخل الاسم الثلاثي';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),

                    labelText: 'رقم الهاتف *',
                    hintText: 'مثال: 0999123456',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'رقم الهاتف إلزامي'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),

                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(t)
                        ? null
                        : 'بريد إلكتروني غير صالح';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),

                    labelText: 'عنوان الإقامة',
                    prefixIcon: Icon(Icons.home),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final id = await ref.read(personRepositoryProvider).createPerson(
                    person: PersonsCompanion.insert(
                      fullName: nameCtrl.text.trim(),
                      phone1: drift.Value(phoneCtrl.text.trim()),
                      email: drift.Value(emailCtrl.text.trim().isEmpty
                          ? null
                          : emailCtrl.text.trim()),
                      permanentAddress: drift.Value(
                          addressCtrl.text.trim().isEmpty
                              ? null
                              : addressCtrl.text.trim()),
                    ),
                  );
              final person =
                  await ref.read(personRepositoryProvider).getPersonById(id);
              if (ctx.mounted) Navigator.pop(ctx, person);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();

    if (created != null) ref.invalidate(allPersonsProvider);
    return created;
  }

  Widget _buildPartnersStep() {
    final personsAsync = ref.watch(allPersonsProvider(null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إضافة الشركاء وتوزيع الحصص:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppConstants.statusInfo),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'الشكل المختار: $_companyType — المطلوب: $_partnersRuleLabel',
                style: const TextStyle(
                    fontSize: 12, color: AppConstants.textMuted),
              ),
            ),
          ],
        ),
        if (widget.archiveContext?.isClosed == true) ...[
          const SizedBox(height: 8),
          const Text(
              'هذه شركة مؤرشفة كمنتهية؛ إدخال الشركاء هنا للتوثيق التاريخي فقط ولا يولد نواقص أو عمل قادم.',
              style: TextStyle(color: AppConstants.textMuted)),
        ],
        const SizedBox(height: 12),
        personsAsync.when(
          data: (persons) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SearchablePicker<PersonEntity>(
                  label: 'الشريك',
                  hintText: 'ابحث بالاسم أو الهاتف',
                  prefixIcon: const Icon(Icons.person_search),
                  items: persons,
                  labelOf: (p) => p.fullName,
                  searchTermsOf: (p) =>
                      [p.phone1 ?? '', p.nationalId ?? ''],
                  subtitleOf: (p) => p.phone1,
                  value: _tempPartnerPersonId == null
                      ? null
                      : persons
                          .where((p) => p.id == _tempPartnerPersonId)
                          .firstOrNull,
                  onSelected: (p) =>
                      setState(() => _tempPartnerPersonId = p.id),
                  createNewLabel: 'إضافة شريك جديد',
                  onCreateNew: (typed) =>
                      _createPersonInline(typed, 'إضافة شريك جديد'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _tempShareType,
                        decoration:
                            InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),
labelText: 'نوع الحصة'),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقدية')),
                          DropdownMenuItem(
                              value: 'in_kind', child: Text('عينية')),
                          DropdownMenuItem(
                              value: 'effort', child: Text('جهد')),
                        ],
                        onChanged: (val) =>
                            setState(() => _tempShareType = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _tempShareValueController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'قيمة الحصة (ل.س) *',
                          errorText: _partnerFieldError == 'value'
                              ? 'مطلوبة'
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _tempSharePercentController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'النسبة % *',
                          errorText: _partnerFieldError == 'percent'
                              ? 'مطلوبة'
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة الشريك للقائمة'),
                  onPressed: _addPartnerToList,
                ),
              ],
            ),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('خطأ في تحميل أسماء الأشخاص'),
        ),
        const SizedBox(height: 16),
        if (_selectedPartners.isNotEmpty) ...[
          Row(
            children: [
              const Text('قائمة الشركاء المضافين:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                'المجموع: ${_totalSharePercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (_totalSharePercent - 100).abs() < 0.01
                      ? AppConstants.statusSuccess
                      : AppConstants.statusWarning,
                ),
              ),
            ],
          ),
          if ((_totalSharePercent - 100).abs() >= 0.01)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'تنبيه: مجموع النسب لا يساوي 100%.',
                style: const TextStyle(
                    color: AppConstants.statusWarning, fontSize: 12),
              ),
            ),
        ],
        ..._selectedPartners.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          final name = personsAsync.valueOrNull
                  ?.where((x) => x.id == p.personId.value)
                  .firstOrNull
                  ?.fullName ??
              'شريك #${p.personId.value}';
          return Card(
            child: ListTile(
              leading:
                  const Icon(Icons.person, color: AppConstants.primaryNavy),
              title: Text('$name • النسبة: ${p.sharePercentage.value}%'),
              subtitle: Text(
                  'قيمة الحصة: ${p.shareValue.value} ل.س • النوع: ${_shareTypeLabel(p.shareType.value)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete,
                    color: AppConstants.statusDanger),
                onPressed: () =>
                    setState(() => _selectedPartners.removeAt(idx)),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _shareTypeLabel(String? type) {
    switch (type) {
      case 'cash':
        return 'نقدية';
      case 'in_kind':
        return 'عينية';
      case 'effort':
        return 'جهد';
      default:
        return 'غير محدد';
    }
  }

  /// إضافة الشريك بعد التحقق الكامل.
  ///
  /// كان الزر يضيف الشريك حتى مع ترك قيمة الحصة والنسبة فارغتين
  /// لأن `double.tryParse(...) ?? 0` يبتلع الفراغ ويحوّله صفراً.
  void _addPartnerToList() {
    if (_tempPartnerPersonId == null) {
      setState(() => _partnerFieldError = 'person');
      _showError('يرجى اختيار الشريك أولاً');
      return;
    }

    final valueText = _tempShareValueController.text.trim();
    final percentText = _tempSharePercentController.text.trim();

    final value = double.tryParse(valueText);
    if (valueText.isEmpty || value == null || value <= 0) {
      setState(() => _partnerFieldError = 'value');
      _showError('يرجى إدخال قيمة حصة صحيحة أكبر من صفر');
      return;
    }

    final percent = double.tryParse(percentText);
    if (percentText.isEmpty || percent == null || percent <= 0) {
      setState(() => _partnerFieldError = 'percent');
      _showError('يرجى إدخال نسبة صحيحة أكبر من صفر');
      return;
    }

    if (percent > 100) {
      setState(() => _partnerFieldError = 'percent');
      _showError('النسبة لا يمكن أن تتجاوز 100%');
      return;
    }

    if (_selectedPartners
        .any((p) => p.personId.value == _tempPartnerPersonId)) {
      _showError('هذا الشريك مضاف بالفعل');
      return;
    }

    final max = _maxPartners;
    if (max != null && _selectedPartners.length >= max) {
      _showError('$_companyType لا تقبل أكثر من $max شريك.');
      return;
    }

    if (_totalSharePercent + percent > 100.01) {
      _showError(
          'المجموع سيتجاوز 100% (الحالي ${_totalSharePercent.toStringAsFixed(1)}%)');
      return;
    }

    setState(() {
      _partnerFieldError = null;
      _selectedPartners.add(CompanyPartnersCompanion.insert(
        companyId: 0,
        personId: _tempPartnerPersonId!,
        partnerType: const drift.Value('شريك مؤسس'),
        shareType: drift.Value(_tempShareType),
        shareValue: drift.Value(value),
        sharePercentage: drift.Value(percent),
      ));
      _tempPartnerPersonId = null;
      _tempShareValueController.clear();
      _tempSharePercentController.clear();
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppConstants.statusDanger),
    );
  }

  Widget _buildDirectorsStep() {
    final personsAsync = ref.watch(allPersonsProvider(null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تعيين المدير العام والمفوضين بالتوقيع:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (widget.archiveContext?.isClosed == true) ...[
          const SizedBox(height: 8),
          const Text(
              'إدخال المديرين والمفوضين هنا للتوثيق التاريخي فقط، ولن ينشئ متابعة تأسيس.',
              style: TextStyle(color: AppConstants.textMuted)),
        ],
        const SizedBox(height: 12),
        personsAsync.when(
          data: (persons) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SearchablePicker<PersonEntity>(
                  label: 'المدير / المفوض',
                  hintText: 'ابحث بالاسم أو الهاتف',
                  prefixIcon: const Icon(Icons.person_search),
                  items: persons,
                  labelOf: (p) => p.fullName,
                  searchTermsOf: (p) => [p.phone1 ?? '', p.nationalId ?? ''],
                  subtitleOf: (p) => p.phone1,
                  value: _tempDirectorPersonId == null
                      ? null
                      : persons
                          .where((p) => p.id == _tempDirectorPersonId)
                          .firstOrNull,
                  onSelected: (p) =>
                      setState(() => _tempDirectorPersonId = p.id),
                  createNewLabel: 'إضافة مدير جديد',
                  onCreateNew: (typed) =>
                      _createPersonInline(typed, 'إضافة مدير جديد'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tempAuthorityController,
                  decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.surfaceWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.backgroundLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryNavy, width: 2),
            ),

                      labelText: 'المنصب ونطاق الصلاحيات *'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة المدير للقائمة'),
                  onPressed: _addDirectorToList,
                ),
              ],
            ),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('خطأ في تحميل أسماء الأشخاص'),
        ),
        const SizedBox(height: 16),
        if (_selectedDirectors.isNotEmpty)
          const Text('قائمة المديرين والمفوضين المضافين:',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ..._selectedDirectors.asMap().entries.map((entry) {
          final idx = entry.key;
          final d = entry.value;
          final name = personsAsync.valueOrNull
                  ?.where((x) => x.id == d.personId.value)
                  .firstOrNull
                  ?.fullName ??
              'مدير #${d.personId.value}';
          return Card(
            child: ListTile(
              leading: const Icon(Icons.gavel, color: AppConstants.accentGold),
              title: Text(name),
              subtitle: Text('الصلاحيات: ${d.authorityScope.value ?? ""}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete,
                    color: AppConstants.statusDanger),
                onPressed: () =>
                    setState(() => _selectedDirectors.removeAt(idx)),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// إضافة المدير بعد التحقق.
  ///
  /// كان الزر يضيف مديراً بلا بيانات ويُفرغ الاختيار، فيبدو كأن
  /// المدير "اختفى" بينما أُضيف سجل فارغ.
  void _addDirectorToList() {
    if (_tempDirectorPersonId == null) {
      _showError('يرجى اختيار المدير أولاً');
      return;
    }
    if (_tempAuthorityController.text.trim().isEmpty) {
      _showError('يرجى إدخال المنصب ونطاق الصلاحيات');
      return;
    }
    if (_selectedDirectors
        .any((d) => d.personId.value == _tempDirectorPersonId)) {
      _showError('هذا المدير مضاف بالفعل');
      return;
    }

    setState(() {
      _selectedDirectors.add(CompanyDirectorsCompanion.insert(
        companyId: 0,
        personId: _tempDirectorPersonId!,
        roleType: const drift.Value('مدير عام'),
        authorityScope: drift.Value(_tempAuthorityController.text.trim()),
        appointmentDate: drift.Value(DateTime.now()),
      ));
      _tempDirectorPersonId = null;
    });
  }

  void _onContinue() {
    if (_currentStep == 2 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال الاسم التجاري للشركة!'),
          backgroundColor: AppConstants.statusDanger,
        ),
      );
      return;
    }

    if (_currentStep == 3 && _selectedPartners.length < _minPartners) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_companyType تتطلب $_partnersRuleLabel.'),
          backgroundColor: AppConstants.statusDanger,
        ),
      );
      return;
    }

    if (_currentStep == 4 && _selectedDirectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تعيين مدير عام واحد على الأقل!'),
          backgroundColor: AppConstants.statusDanger,
        ),
      );
      return;
    }

    if (_currentStep < 4) {
      setState(() => _currentStep++);
      return;
    }

    _validateAndSaveCompany();
  }

  Future<void> _validateAndSaveCompany() async {
    // المطابقة بعد تطبيع الهمزات والمسافات، وإلا اعتُبر
    // "شركة الأمل" و"شركة الامل" مختلفين، أو تكرّر خطأ مطابقة زائفة.
    final companiesAsync = ref.read(allCompaniesProvider);
    final companies = companiesAsync.value ?? [];
    final target = normalizeArabic(_nameController.text);

    final duplicate = companies
        .where((c) => normalizeArabic(c.name) == target)
        .firstOrNull;

    if (duplicate != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'يوجد شركة مسجّلة بهذا الاسم: «${duplicate.name}». غيّر الاسم أو افتح الشركة القائمة.'),
          backgroundColor: AppConstants.statusDanger,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    _saveCompany();
  }

  void _onCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _saveCompany() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.companiesCreate)) {
      await ref.read(auditServiceProvider).log(
        action: 'access_denied',
        category: 'companies',
        entityType: 'company',
        description: 'محاولة إنشاء شركة دون صلاحية',
        severity: 'warning',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا تملك صلاحية تأسيس/أرشفة شركة'), backgroundColor: AppConstants.statusDanger));
      }
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال الاسم التجاري للشركة!'),
          backgroundColor: AppConstants.statusDanger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(companyRepositoryProvider);
      final company = CompaniesCompanion.insert(
        internalNumber: 'TEMP-${DateTime.now().microsecondsSinceEpoch}',
        companyType: _companyType,
        legalStatus: drift.Value(widget.archiveContext?.isClosed == true ? 'archived' : (_isNewEstablishment ? 'under_establishment' : 'active')),
        name: _nameController.text.trim(),
        activity: drift.Value(_activityController.text.trim()),
        capitalDeclared: drift.Value(double.tryParse(_capitalController.text.trim()) ?? 0),
        capitalPaid: drift.Value(double.tryParse(_paidCapitalController.text.trim()) ?? 0),
        durationType: const drift.Value('fixed'),
        durationYears: drift.Value(int.tryParse(_durationController.text.trim()) ?? 99),
        mainAddress: drift.Value(_addressController.text.trim()),
        propertyDetails: drift.Value([
          _propertyDetailsController.text.trim(),
          if (widget.archiveContext != null) 'سياق الأرشيف: ${widget.archiveContext!.summary}',
        ].where((v) => v.isNotEmpty).join('\n')),
        currentPhase: drift.Value(widget.archiveContext == null ? (_isNewEstablishment ? 'صياغة عقد التأسيس وتصديق النقابة' : 'أرشفة شركة قائمة') : widget.archiveContext!.summary),
        isArchived: drift.Value(widget.archiveContext?.isClosed == true),
      );

      final companyId = await repo.createCompany(
        company: company,
        partners: _selectedPartners,
        directors: _selectedDirectors,
        userRef: ref.read(authControllerProvider).user?.fullName ?? AppConstants.defaultLawyerName,
      );
      await ref.read(auditServiceProvider).log(
        action: 'create',
        category: 'companies',
        entityType: 'company',
        entityId: '$companyId',
        entityTitle: _nameController.text.trim(),
        description: _isNewEstablishment ? 'تأسيس شركة جديدة' : 'أرشفة شركة قائمة',
        after: {'name': _nameController.text.trim(), 'type': _companyType, 'status': _isNewEstablishment ? 'new' : 'archive', if (widget.archiveContext != null) 'archive': widget.archiveContext!.summary, if (widget.archiveContext != null) 'archiveStatus': widget.archiveContext!.status},
        severity: 'info',
      );

      if (mounted) {
        ref.invalidate(allCompaniesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.archiveContext?.isClosed == true ? 'تم حفظ الشركة في الأرشيف المنتهي بنجاح!' : 'تم تأسيس الشركة بنجاح!'),
            backgroundColor: AppConstants.statusSuccess,
          ),
        );
        GoRouter.of(context).pushReplacement('/companies/$companyId');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e.toString().contains('UNIQUE constraint')) {
          errorMessage = 'اسم الشركة موجود مسبقاً';
        } else if (e.toString().contains('FOREIGN KEY')) {
          errorMessage = 'مرجع غير صالح (الشركاء أو المديرين)';
        } else if (e.toString().contains('NOT NULL')) {
          errorMessage = 'حقل إلزامي فارغ';
        } else {
          errorMessage = 'خطأ أثناء حفظ الشركة';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: AppConstants.statusDanger),
        );
        
        // تسجيل الخطأ التفصيلي
        await ref.read(auditServiceProvider).log(
          action: 'error',
          category: 'companies',
          entityType: 'company',
          description: 'فشل حفظ الشركة: $e',
          severity: 'error',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _activityController.dispose();
    _capitalController.dispose();
    _paidCapitalController.dispose();
    _durationController.dispose();
    _addressController.dispose();
    _propertyDetailsController.dispose();
    _tempShareValueController.dispose();
    _tempSharePercentController.dispose();
    _tempAuthorityController.dispose();
    super.dispose();
  }
}
