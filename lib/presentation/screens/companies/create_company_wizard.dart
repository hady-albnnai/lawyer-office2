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
import 'company_detail_screen.dart';

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
            title: const Text('الشركاء وحصص رأس المال'),
            subtitle: Text('عدد الشركاء: ${_selectedPartners.length}'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.editing,
            content: _buildPartnersStep(),
          ),
          Step(
            title: const Text('الإدارة والتفويض بالتوقيع'),
            subtitle: Text('عدد المديرين/المفوضين: ${_selectedDirectors.length}'),
            isActive: _currentStep >= 4,
            state: _currentStep == 4 ? StepState.editing : StepState.indexed,
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
    return Row(
      children: [
        ChoiceChip(
          label: const Text('تأسيس جديد (من الصفر)'),
          selected: _isNewEstablishment,
          onSelected: (_) => setState(() => _isNewEstablishment = true),
        ),
        const SizedBox(width: 16),
        ChoiceChip(
          label: const Text('أرشفة شركة قائمة ومسجلة'),
          selected: !_isNewEstablishment,
          onSelected: (_) => setState(() => _isNewEstablishment = false),
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
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'القيمة الجديدة')),
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
        const Text('اختر الشكل القانوني للشركة السورية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _companyType,
          items: _companyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => _companyType = val!),
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
          decoration: const InputDecoration(labelText: 'الاسم التجاري للشركة *', prefixIcon: Icon(Icons.business)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _activityController,
          decoration: const InputDecoration(labelText: 'الغاية / نشاط الشركة *', prefixIcon: Icon(Icons.work)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _capitalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'رأس المال المكتتب به (ل.س) *'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _paidCapitalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'رأس المال المدفوع (ل.س) *'),
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
                decoration: const InputDecoration(labelText: 'مدة الشركة (بالسنوات)'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'المقر الرئيسي / المحافظة *'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _propertyDetailsController,
          decoration: const InputDecoration(labelText: 'بيانات وصفة المقر (عقد إيجار / ملك / رقم قيد)', prefixIcon: Icon(Icons.location_city)),
        ),
      ],
    );
  }

  Widget _buildPartnersStep() {
    final personsAsync = ref.watch(allPersonsProvider(null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إضافة الشركاء وتوزيع الحصص:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (widget.archiveContext?.isClosed == true) ...[
          const SizedBox(height: 8),
          const Text('هذه شركة مؤرشفة كمنتهية؛ إدخال الشركاء هنا للتوثيق التاريخي فقط ولا يولد نواقص أو عمل قادم.', style: TextStyle(color: AppConstants.textMuted)),
        ],
        const SizedBox(height: 12),
        personsAsync.when(
          data: (persons) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _tempPartnerPersonId,
                  decoration: const InputDecoration(labelText: 'اختر الشريك من سجل الأشخاص'),
                  items: persons.map((p) => DropdownMenuItem(value: p.id, child: Text(p.fullName))).toList(),
                  onChanged: (val) => setState(() => _tempPartnerPersonId = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _tempShareType,
                        decoration: const InputDecoration(labelText: 'نوع الحصة'),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقدية')),
                          DropdownMenuItem(value: 'in_kind', child: Text('عينية')),
                          DropdownMenuItem(value: 'effort', child: Text('جهد')),
                        ],
                        onChanged: (val) => setState(() => _tempShareType = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _tempShareValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'قيمة الحصة (ل.س)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _tempSharePercentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'النسبة %'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة الشريك للقائمة'),
                  onPressed: () {
                    if (_tempPartnerPersonId != null) {
                      setState(() {
                        _selectedPartners.add(CompanyPartnersCompanion.insert(
                          companyId: 0,
                          personId: _tempPartnerPersonId!,
                          partnerType: const drift.Value('شريك مؤسس'),
                          shareType: drift.Value(_tempShareType),
                          shareValue: drift.Value(double.tryParse(_tempShareValueController.text.trim()) ?? 0),
                          sharePercentage: drift.Value(double.tryParse(_tempSharePercentController.text.trim()) ?? 0),
                        ));
                        _tempPartnerPersonId = null;
                        _tempShareValueController.clear();
                        _tempSharePercentController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('خطأ في تحميل أسماء الأشخاص'),
        ),
        const SizedBox(height: 16),
        const Text('قائمة الشركاء المضافين:', style: TextStyle(fontWeight: FontWeight.bold)),
        ..._selectedPartners.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.person, color: AppConstants.primaryNavy),
              title: Text('شريك رقم ID: ${p.personId.value} • النسبة: ${p.sharePercentage.value}%'),
              subtitle: Text('قيمة الحصة: ${p.shareValue.value} ل.س • النوع: ${p.shareType.value == "cash" ? "نقدية" : "عينية"}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppConstants.statusDanger),
                onPressed: () => setState(() => _selectedPartners.removeAt(idx)),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDirectorsStep() {
    final personsAsync = ref.watch(allPersonsProvider(null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تعيين المدير العام والمفوضين بالتوقيع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (widget.archiveContext?.isClosed == true) ...[
          const SizedBox(height: 8),
          const Text('إدخال المديرين والمفوضين هنا للتوثيق التاريخي فقط، ولن ينشئ متابعة تأسيس.', style: TextStyle(color: AppConstants.textMuted)),
        ],
        const SizedBox(height: 12),
        personsAsync.when(
          data: (persons) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _tempDirectorPersonId,
                  decoration: const InputDecoration(labelText: 'اختر الشخص من السجل'),
                  items: persons.map((p) => DropdownMenuItem(value: p.id, child: Text(p.fullName))).toList(),
                  onChanged: (val) => setState(() => _tempDirectorPersonId = val),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tempAuthorityController,
                  decoration: const InputDecoration(labelText: 'المنصب ونطاق الصلاحيات'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة المدير للقائمة'),
                  onPressed: () {
                    if (_tempDirectorPersonId != null) {
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
                  },
                ),
              ],
            ),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('خطأ في تحميل أسماء الأشخاص'),
        ),
        const SizedBox(height: 16),
        const Text('قائمة المديرين والمفوضين المضافين:', style: TextStyle(fontWeight: FontWeight.bold)),
        ..._selectedDirectors.asMap().entries.map((entry) {
          final idx = entry.key;
          final d = entry.value;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.gavel, color: AppConstants.accentGold),
              title: Text('مدير رقم ID: ${d.personId.value}'),
              subtitle: Text('الصلاحيات: ${d.authorityScope.value ?? ""}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppConstants.statusDanger),
                onPressed: () => setState(() => _selectedDirectors.removeAt(idx)),
              ),
            ),
          );
        }),
      ],
    );
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

    if (_currentStep < 4) {
      setState(() => _currentStep++);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء حفظ الشركة: $e'), backgroundColor: AppConstants.statusDanger),
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
