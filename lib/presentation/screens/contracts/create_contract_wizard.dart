import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart' as file_picker;
import 'contract_detail_screen.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../../data/services/file_storage_service.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';

/// ويزارد إنشاء عقد جديد - نسخة مبسطة (خطوتين فقط)
///
/// الخطوة 1: المعلومات الأساسية (تصنيف + أطراف + تاريخ + قيمة + دفع + أقساط + تذكيرات + مستندات + أتعاب)
/// الخطوة 2: اختيار النموذج + فتحه في Word مباشرة
class CreateContractWizard extends ConsumerStatefulWidget {
  const CreateContractWizard({super.key});

  @override
  ConsumerState<CreateContractWizard> createState() => _CreateContractWizardState();
}

class _CreateContractWizardState extends ConsumerState<CreateContractWizard> {
  int _currentStep = 0;
  bool _isSaving = false;

  // =========================================================================
  // الخطوة 1: المعلومات الأساسية
  // =========================================================================
  
  // --- التصنيفات المخصصة ---
  final List<String> _customSubcategories = [];
  final List<String> _customMainCategories = [];
  
  // =========================================================================
  
  // --- التصنيف القانوني ---
  String? _legalCategory;
  String? _legalSubcategory;

  // --- الأطراف ---
  final List<_PartyEntry> _parties = [
    _PartyEntry(role: 'الطرف الأول'),
    _PartyEntry(role: 'الطرف الثاني'),
  ];

  // --- بيانات العقد ---
  final _titleController = TextEditingController();
  final _valueController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _notarizationNumberController = TextEditingController();
  
  String _currency = 'ل.س';
  DateTime? _dateSigned;
  DateTime? _dateStart;
  DateTime? _dateEnd;
  bool _isRenewable = false;
  String _renewalType = 'تلقائي';
  String _contractStatus = 'active';
  String _notarizationType = 'عرفي';

  // --- طريقة الدفع ---
  String _paymentMethod = 'نقدي';
  File? _paymentProofFile;
  
  // --- الأقساط (عند اختيار تقسيط) ---
  final List<_InstallmentEntry> _installments = [];
  int _installmentCount = 0;
  final _installmentValueController = TextEditingController();
  String _installmentPeriod = 'شهري'; // شهري، كل شهرين، كل 3 أشهر، كل 6 أشهر، سنوي، مخصص
  int _customDays = 30; // عدد الأيام المخصص
  final _customDaysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customDaysController.text = _customDays.toString();
  }

  // --- التذكيرات الزمنية ---
  final List<_ReminderEntry> _reminders = [];
  bool _autoGenerateInstallmentReminders = true;
  int _reminderDaysBefore = 3;

  // --- المستندات المرفقة ---
  final List<_DocumentEntry> _attachedDocuments = [];

  // --- أتعاب المكتب ---
  String _feeAgreementType = 'fixed';
  final _feeAmountController = TextEditingController();
  int? _feePartyId;

  // =========================================================================
  // الخطوة 2: اختيار النموذج
  // =========================================================================
  String _creationMethod = 'from_template';
  ContractTemplate? _selectedTemplate;
  File? _uploadedFile;
  final _templateNameController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _notarizationNumberController.dispose();
    _installmentValueController.dispose();
    _feeAmountController.dispose();
    _templateNameController.dispose();
    _customDaysController.dispose();
    for (final doc in _attachedDocuments) {
      doc.nameController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy.withOpacity(0.05),
      appBar: AppBar(
        title: Text(_currentStep == 0 ? 'إنشاء عقد جديد - المعلومات الأساسية' : 'اختيار النموذج'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey<int>(_currentStep),
                padding: const EdgeInsets.all(24),
                child: _currentStep == 0 ? _buildBasicInfoStep() : _buildTemplateStep(),
              ),
            ),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  // =========================================================================
  // Stepper & Navigation
  // =========================================================================
  
  Widget _buildStepper() {
    return Container(
      color: AppColors.primaryNavy.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: GlassmorphicStepper(
        currentStep: _currentStep,
        totalSteps: 2,
        stepLabels: const ['المعلومات الأساسية', 'اختيار النموذج'],
        stepIcons: const [Icons.info_outline, Icons.description],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back),
              label: const Text('السابق'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardBackground,
                foregroundColor: AppColors.textPrimary,
              ),
            )
          else
            const SizedBox(),
          
          if (_currentStep == 0)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _goToNextStep,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('التالي'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _createAndOpenInWord,
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.open_in_new),
              label: Text(_isSaving ? 'جاري الإنشاء...' : 'إنشاء العقد وفتحه في Word 📝'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
        ],
      ),
    );
  }

  void _goToNextStep() {
    if (!_validateBasicInfo()) return;
    setState(() => _currentStep++);
  }

  bool _validateBasicInfo() {
    if (_legalCategory == null || _legalSubcategory == null) {
      _showError('يرجى اختيار التصنيف القانوني والفرعي');
      return false;
    }
    if (_parties.length < 2) {
      _showError('العقد يحتاج طرفين على الأقل');
      return false;
    }
    for (final party in _parties) {
      for (final person in party.persons) {
        if (person.personId == null) {
          _showError('يرجى اختيار شخص لكل شخص في الطرف "${party.role}"');
          return false;
        }
      }
    }
    
    // Check for duplicate persons across parties
    final allPersonIds = <int>[];
    for (final party in _parties) {
      for (final person in party.persons) {
        if (person.personId != null) {
          if (allPersonIds.contains(person.personId)) {
            _showError('لا يمكن اختيار نفس الشخص في أكثر من طرف');
            return false;
          }
          allPersonIds.add(person.personId!);
        }
      }
    }
    
    if (_titleController.text.trim().isEmpty) {
      _showError('يرجى إدخال عنوان للعقد');
      return false;
    }
    if (_paymentMethod == 'تقسيط' && _installments.isEmpty) {
      _showError('يرجى إضافة الأقساط عند اختيار التقسيط');
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // =========================================================================
  // الخطوة 1: المعلومات الأساسية (صفحة واحدة شاملة)
  // =========================================================================
  
  Widget _buildBasicInfoStep() {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ═══════════════════════════════════════════════════════════════
          // القسم 1: التصنيف القانوني
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('التصنيف القانوني', Icons.category, 'حدد التصنيف الرئيسي والفرعي للعقد'),
          const SizedBox(height: 12),
          _buildClassificationFields(inputDecoration),
          const SizedBox(height: 32),

          // ═══════════════════════════════════════════════════════════════
          // القسم 2: أطراف العقد
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('أطراف العقد', Icons.people, 'أضف أطراف العقد مع الصفة والدور'),
          const SizedBox(height: 12),
          _buildPartiesSection(inputDecoration),
          const SizedBox(height: 32),

          // ═══════════════════════════════════════════════════════════════
          // القسم 3: بيانات العقد
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('بيانات العقد', Icons.subject, 'العنوان، التواريخ، القيمة، والملاحظات'),
          const SizedBox(height: 12),
          _buildContractDataFields(inputDecoration),
          const SizedBox(height: 32),

          // ═══════════════════════════════════════════════════════════════
          // القسم 4: طريقة الدفع والأقساط
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('طريقة الدفع', Icons.payment, 'اختر طريقة الدفع المناسبة'),
          const SizedBox(height: 12),
          _buildPaymentSection(inputDecoration),
          const SizedBox(height: 32),

          // ═══════════════════════════════════════════════════════════════
          // القسم 5: التذكيرات الزمنية (اختياري)
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('التذكيرات الزمنية', Icons.alarm, 'أضف تذكيرات للمواعيد المهمة (اختياري)'),
          const SizedBox(height: 12),
          _buildRemindersSection(inputDecoration),
          const SizedBox(height: 32),

          // ═══════════════════════════════════════════════════════════════
          // القسم 6: المستندات المرفقة (اختياري)
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('المستندات المرفقة', Icons.attach_file, 'أرفق مستندات مرتبطة بالعقد (اختياري)'),
          const SizedBox(height: 12),
          _buildDocumentsSection(inputDecoration),
          const SizedBox(height: 32),

          // ═══════════════════════════════════════════════════════════════
          // القسم 7: أتعاب المكتب
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('أتعاب المكتب', Icons.account_balance, 'حدد أتعاب المكتب لتنظيم هذا العقد'),
          const SizedBox(height: 12),
          _buildFeeSection(inputDecoration),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryNavy.withOpacity(0.1), AppColors.primaryNavy.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryNavy.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryNavy, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 18, color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // التصنيف القانوني
  // -------------------------------------------------------------------------
  Widget _buildClassificationFields(InputDecoration baseDecoration) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _legalCategory,
            decoration: baseDecoration.copyWith(labelText: 'التصنيف الرئيسي *'),
            items: const [
              DropdownMenuItem(value: 'عقود واردة على الملكية', child: Text('عقود واردة على الملكية')),
              DropdownMenuItem(value: 'عقود الاستثمار', child: Text('عقود الاستثمار')),
              DropdownMenuItem(value: 'عقود العمل والمقاولة', child: Text('عقود العمل والمقاولة')),
              DropdownMenuItem(value: 'عقود الشركات', child: Text('عقود الشركات')),
              DropdownMenuItem(value: 'عقود الصلح', child: Text('عقود الصلح')),
              DropdownMenuItem(value: 'عقود أخرى', child: Text('عقود أخرى')),
            ],
            onChanged: (v) => setState(() {
              _legalCategory = v;
              _legalSubcategory = null;
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FutureBuilder<List<DropdownMenuItem<String>>>(
            future: _getSubcategories(),
            builder: (context, snapshot) {
              final subItems = snapshot.data ?? [
                const DropdownMenuItem(value: null, enabled: false, child: Text('جارٍ التحميل...')),
              ];
              return DropdownButtonFormField<String>(
                value: _legalSubcategory,
                decoration: baseDecoration.copyWith(labelText: 'التصنيف الفرعي *'),
                items: subItems,
                onChanged: (v) => setState(() => _legalSubcategory = v),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryNavy),
          onPressed: () => _showAddCategoryDialog(isMainCategory: true),
          tooltip: 'إضافة تصنيف رئيسي جديد',
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.add_circle, color: AppColors.primaryNavy),
          onPressed: () => _showAddCategoryDialog(isMainCategory: false),
          tooltip: 'إضافة تصنيف فرعي جديد',
        ),
      ],
    );
  }

  Future<List<DropdownMenuItem<String>>> _getSubcategories() async {
    final db = ref.read(databaseProvider);
    final query = db.select(db.contractTypesLookup)
      ..where((t) => t.isActive.equals(true));
    if (_legalCategory != null && _legalCategory!.isNotEmpty) {
      query.where((t) => t.category.equals(_legalCategory!));
    } else {
      query.where((t) => t.category.isNull());
    }
    final rows = await query.get();

    final defaultSubcats = {
      'عقود واردة على الملكية': ['بيع عقار', 'إيجار سكني', 'إيجار تجاري', 'هبة', 'مبادلة'],
      'عقود الاستثمار': ['استثمار عقاري', 'استثمار تجاري', 'مشاركة'],
      'عقود العمل والمقاولة': ['عقد عمل', 'مقاولة', 'خدمات'],
      'عقود الشركات': ['تأسيس شركة', 'شراكة', 'تعديل عقد شركة'],
      'عقود الصلح': ['صلح إسقاط', 'صلح إقرار', 'صلح معاوضة'],
      'عقود أخرى': ['عقد وكالة', 'عقد كفالة', 'عقد ضمان'],
    };
    final defaultList = defaultSubcats[_legalCategory] ?? [];
    final defaultItems = defaultList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList();

    final dbNames = rows.map((r) => r.name).toList();
    final extraNames = dbNames.where((n) => !defaultList.contains(n)).toList();

    return [...defaultItems, ...extraNames.map((s) => DropdownMenuItem(value: s, child: Text(s)))];
  }

  // -------------------------------------------------------------------------
  // أطراف العقد
  // -------------------------------------------------------------------------
  Widget _buildPartiesSection(InputDecoration baseDecoration) {
    final personsAsync = ref.watch(allPersonsProvider(null));
    return Column(
      children: [
        ...List.generate(_parties.length, (i) => _buildPartyCard(i, _parties[i], personsAsync, baseDecoration)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _parties.add(_PartyEntry(role: 'طرف ${_parties.length + 1}'))),
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة طرف'),
        ),
      ],
    );
  }

  Widget _buildPartyCard(int index, _PartyEntry party, AsyncValue<List<PersonEntity>> personsAsync, InputDecoration baseDecoration) {
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: party.role,
                  decoration: baseDecoration.copyWith(labelText: 'صفة الطرف'),
                  onChanged: (v) => party.role = v,
                ),
              ),
              if (_parties.length > 2)
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => setState(() => _parties.removeAt(index)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(party.persons.length, (j) => _buildPersonInPartyRow(party.persons[j], personsAsync, baseDecoration)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => party.persons.add(_PersonInParty())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة شخص لهذا الطرف'),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonInPartyRow(_PersonInParty person, AsyncValue<List<PersonEntity>> personsAsync, InputDecoration baseDecoration) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: personsAsync.when(
              data: (persons) {
                // Get all selected person IDs from other parties
                final selectedIds = <int>{};
                for (final party in _parties) {
                  for (final p in party.persons) {
                    if (p.personId != null && p != person) {
                      selectedIds.add(p.personId!);
                    }
                  }
                }
                
                return DropdownButtonFormField<int>(
                  value: (personsAsync.hasValue && personsAsync.valueOrNull != null && personsAsync.valueOrNull!.any((p) => p.id == person.personId)) ? person.personId : null,
                  decoration: baseDecoration.copyWith(labelText: 'اختر الشخص *'),
                  isExpanded: true,
                  items: persons.map((p) {
                    final isDisabled = selectedIds.contains(p.id);
                    return DropdownMenuItem(
                      value: p.id,
                      enabled: !isDisabled,
                      child: Text(
                        p.fullName + (isDisabled ? ' (مختار في طرف آخر)' : ''),
                        style: TextStyle(
                          color: isDisabled ? Colors.grey : null,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => person.personId = v),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('خطأ: $e'),
            ),
          ),
          // زر إضافة شخص جديد بجانب اختيار الشخص
          IconButton(
            icon: const Icon(Icons.person_add, color: AppColors.primaryNavy, size: 22),
            tooltip: 'إضافة شخص جديد',
            onPressed: () => _showAddPersonDialog(person),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: person.capacity,
              decoration: baseDecoration.copyWith(labelText: 'الصفة'),
              items: const [
                DropdownMenuItem(value: 'أصيل', child: Text('أصيل')),
                DropdownMenuItem(value: 'وكيل', child: Text('وكيل')),
                DropdownMenuItem(value: 'ولي', child: Text('ولي')),
                DropdownMenuItem(value: 'وصي', child: Text('وصي')),
                DropdownMenuItem(value: 'ممثل شركة', child: Text('ممثل شركة')),
              ],
              onChanged: (v) => setState(() => person.capacity = v ?? 'أصيل'),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // بيانات العقد
  // -------------------------------------------------------------------------
  Widget _buildContractDataFields(InputDecoration baseDecoration) {
    return Column(
      children: [
        TextFormField(
          controller: _titleController,
          decoration: baseDecoration.copyWith(
            labelText: 'عنوان العقد *',
            hintText: 'مثال: عقد بيع شقة في المزة',
            prefixIcon: const Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 16),
        Text('تواريخ العقد', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildDateField('تاريخ الإبرام', _dateSigned, (d) => setState(() => _dateSigned = d), baseDecoration)),
          const SizedBox(width: 12),
          Expanded(child: _buildDateField('تاريخ البدء', _dateStart, (d) => setState(() => _dateStart = d), baseDecoration)),
          const SizedBox(width: 12),
          Expanded(child: _buildDateField('تاريخ الانتهاء', _dateEnd, (d) => setState(() => _dateEnd = d), baseDecoration)),
        ]),
        const SizedBox(height: 16),
        Text('القيمة المالية', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: baseDecoration.copyWith(
                labelText: 'القيمة المالية (اختياري)',
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _currency,
              decoration: baseDecoration.copyWith(labelText: 'العملة'),
              items: const [
                DropdownMenuItem(value: 'ل.س', child: Text('ل.س')),
                DropdownMenuItem(value: 'دولار', child: Text('دولار')),
                DropdownMenuItem(value: 'يورو', child: Text('يورو')),
              ],
              onChanged: (v) => setState(() => _currency = v ?? 'ل.س'),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        TextFormField(
          controller: _locationController,
          decoration: baseDecoration.copyWith(
            labelText: 'مكان الإبرام (اختياري)',
            prefixIcon: const Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _contractStatus,
              decoration: baseDecoration.copyWith(labelText: 'حالة العقد'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('ساري المفعول')),
                DropdownMenuItem(value: 'expired', child: Text('منتهٍ')),
                DropdownMenuItem(value: 'cancelled', child: Text('ملغى')),
              ],
              onChanged: (v) => setState(() => _contractStatus = v ?? 'active'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _notarizationType,
              decoration: baseDecoration.copyWith(labelText: 'نوع التوثيق'),
              items: const [
                DropdownMenuItem(value: 'عرفي', child: Text('عرفي')),
                DropdownMenuItem(value: 'notary', child: Text('كاتب العدل')),
                DropdownMenuItem(value: 'court', child: Text('المحكمة')),
              ],
              onChanged: (v) => setState(() => _notarizationType = v ?? 'عرفي'),
            ),
          ),
        ]),
        if (_notarizationType != 'عرفي') ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _notarizationNumberController,
            decoration: baseDecoration.copyWith(labelText: 'رقم التوثيق'),
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: baseDecoration.copyWith(
            labelText: 'ملاحظات حرة (اختياري)',
            prefixIcon: const Icon(Icons.notes),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? value, ValueChanged<DateTime> onChanged, InputDecoration baseDecoration) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: baseDecoration.copyWith(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          value != null ? DateFormat('yyyy-MM-dd').format(value) : 'اختر التاريخ',
          style: TextStyle(color: value != null ? AppColors.textPrimary : AppColors.textSecondary),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // طريقة الدفع والأقساط
  // -------------------------------------------------------------------------
  Widget _buildPaymentSection(InputDecoration baseDecoration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _paymentChip('نقدي', Icons.money),
            _paymentChip('تقسيط', Icons.calendar_month),
            _paymentChip('تحويل بنكي', Icons.account_balance),
            _paymentChip('شيك', Icons.payments),
          ],
        ),
        if (_paymentMethod == 'تقسيط') ...[
          const SizedBox(height: 16),
          _buildInstallmentsSection(baseDecoration),
        ],
        if (_paymentMethod == 'تحويل بنكي' || _paymentMethod == 'شيك') ...[
          const SizedBox(height: 16),
          _buildPaymentProofUpload(baseDecoration),
        ],
      ],
    );
  }

  Widget _buildPaymentProofUpload(InputDecoration baseDecoration) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _paymentMethod == 'شيك' ? 'صورة الشيك' : 'إيصال التحويل البنكي',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await file_picker.FilePicker.pickFiles(
                type: file_picker.FileType.image,
              );
              if (result != null) {
                setState(() {
                  _paymentProofFile = File(result.files.single.path!);
                });
              }
            },
            icon: Icon(_paymentProofFile != null ? Icons.check_circle : Icons.upload_file),
            label: Text(_paymentProofFile != null 
                ? path.basename(_paymentProofFile!.path) 
                : 'اختيار صورة'),
          ),
        ],
      ),
    );
  }

  Widget _paymentChip(String method, IconData icon) {
    final isSelected = _paymentMethod == method;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(method, style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryNavy,
      backgroundColor: AppColors.cardBackground,
      side: BorderSide(color: isSelected ? AppColors.primaryNavy : AppColors.cardBorder),
          onSelected: (_) {
            setState(() {
              _paymentMethod = method;
              _installments.clear();
            });
          },
    );
  }

  Widget _buildInstallmentsSection(InputDecoration baseDecoration) {
    return GlassmorphicCard(
      color: AppColors.primaryNavy.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الأقساط', style: TextStyle(fontSize: 18, color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _installmentPeriod,
            decoration: baseDecoration.copyWith(labelText: 'الفترة بين الأقساط'),
            items: const [
              DropdownMenuItem(value: 'شهري', child: Text('شهري (30 يوم)')),
              DropdownMenuItem(value: 'كل شهرين', child: Text('كل شهرين (60 يوم)')),
              DropdownMenuItem(value: 'كل 3 أشهر', child: Text('كل 3 أشهر (90 يوم)')),
              DropdownMenuItem(value: 'كل 6 أشهر', child: Text('كل 6 أشهر (180 يوم)')),
              DropdownMenuItem(value: 'سنوي', child: Text('سنوي (365 يوم)')),
              DropdownMenuItem(value: 'مخصص', child: Text('مخصص (بالأيام)')),
            ],
            onChanged: (v) => setState(() => _installmentPeriod = v ?? 'شهري'),
          ),
          Visibility(
            visible: _installmentPeriod == 'مخصص',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customDaysController,
                  keyboardType: TextInputType.number,
                  decoration: baseDecoration.copyWith(
                    labelText: 'عدد الأيام بين الأقساط',
                    hintText: 'مثال: 45',
                  ),
                  onChanged: (v) {
                    _customDays = int.tryParse(v) ?? 30;
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                keyboardType: TextInputType.number,
                decoration: baseDecoration.copyWith(labelText: 'عدد الأقساط'),
                onChanged: (v) => setState(() => _installmentCount = int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _installmentValueController,
                keyboardType: TextInputType.number,
                decoration: baseDecoration.copyWith(labelText: 'قيمة القسط'),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _generateInstallments,
              icon: const Icon(Icons.add),
              label: const Text('توليد'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _autoGenerateInstallmentReminders,
                onChanged: (v) => setState(() => _autoGenerateInstallmentReminders = v ?? false),
                activeColor: AppColors.primaryNavy,
              ),
              const Text('إنشاء تذكيرات تلقائية للأقساط'),
              const SizedBox(width: 12),
              if (_autoGenerateInstallmentReminders)
                DropdownButtonFormField<int>(
                  value: _reminderDaysBefore,
                  decoration: baseDecoration.copyWith(labelText: 'قبل'),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('يوم')),
                    DropdownMenuItem(value: 3, child: Text('3 أيام')),
                    DropdownMenuItem(value: 7, child: Text('أسبوع')),
                  ],
                  onChanged: (v) => setState(() => _reminderDaysBefore = v ?? 3),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_installments.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            ..._installments.asMap().entries.map((entry) => _buildInstallmentRow(entry.key, entry.value, baseDecoration)),
          ],
        ],
      ),
    );
  }

  Widget _buildInstallmentRow(int index, _InstallmentEntry installment, InputDecoration baseDecoration) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryNavy,
            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('${installment.amount} $_currency', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: installment.dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => installment.dueDate = picked);
              },
              child: Text(
                DateFormat('yyyy-MM-dd').format(installment.dueDate),
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
            onPressed: () => setState(() => _installments.removeAt(index)),
          ),
        ],
      ),
    );
  }

  void _generateInstallments() {
    final amount = double.tryParse(_installmentValueController.text);
    if (_installmentCount <= 0 || amount == null) {
      _showError('يرجى إدخال عدد الأقساط وقيمة القسط');
      return;
    }
    setState(() {
      _installments.clear();
      final startDate = _dateStart ?? DateTime.now();
      
      // Calculate days to add based on period
      int daysToAdd = 30;
      switch (_installmentPeriod) {
        case 'شهري':
          daysToAdd = 30;
          break;
        case 'كل شهرين':
          daysToAdd = 60;
          break;
        case 'كل 3 أشهر':
          daysToAdd = 90;
          break;
        case 'كل 6 أشهر':
          daysToAdd = 180;
          break;
        case 'سنوي':
          daysToAdd = 365;
          break;
        case 'مخصص':
          daysToAdd = _customDays;
          break;
      }
      
      for (int i = 0; i < _installmentCount; i++) {
        final dueDate = startDate.add(Duration(days: (i + 1) * daysToAdd));
        _installments.add(_InstallmentEntry(
          amount: amount,
          dueDate: dueDate,
        ));
        
        // Auto-generate reminder for this installment
        if (_autoGenerateInstallmentReminders) {
          _reminders.add(_ReminderEntry(
            type: 'manual',
            date: dueDate.subtract(Duration(days: _reminderDaysBefore)),
            note: 'تذكير: القسط ${i + 1} بقيمة $amount $_currency يستحق في ${dueDate.day}/${dueDate.month}/${dueDate.year}',
          ));
        }
      }
    });
  }

  // -------------------------------------------------------------------------
  // التذكيرات الزمنية
  // -------------------------------------------------------------------------
  Widget _buildRemindersSection(InputDecoration baseDecoration) {
    return Column(
      children: [
        ..._reminders.asMap().entries.map((entry) => _buildReminderCard(entry.key, entry.value, baseDecoration)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showAddReminderDialog(baseDecoration),
          icon: const Icon(Icons.add_alarm),
          label: const Text('إضافة تذكير'),
        ),
      ],
    );
  }

  Widget _buildReminderCard(int index, _ReminderEntry reminder, InputDecoration baseDecoration) {
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.alarm, color: AppColors.primaryNavy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.type == 'expiry' ? 'تذكير انتهاء' : reminder.type == 'renewal' ? 'تذكير تجديد' : 'تذكير يدوي',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(reminder.date)}'),
                if (reminder.note.isNotEmpty) Text('ملاحظة: ${reminder.note}', style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error),
            onPressed: () => setState(() => _reminders.removeAt(index)),
          ),
        ],
      ),
    );
  }

  void _showAddReminderDialog(InputDecoration baseDecoration) {
    String type = 'expiry';
    DateTime? date;
    final noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة تذكير جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: baseDecoration.copyWith(labelText: 'نوع التذكير'),
              items: const [
                DropdownMenuItem(value: 'expiry', child: Text('تذكير انتهاء')),
                DropdownMenuItem(value: 'renewal', child: Text('تذكير تجديد')),
                DropdownMenuItem(value: 'manual', child: Text('تذكير يدوي')),
              ],
              onChanged: (v) => type = v ?? 'expiry',
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) date = picked;
              },
              child: InputDecorator(
                decoration: baseDecoration.copyWith(labelText: 'تاريخ التذكير'),
                child: Text(date != null ? DateFormat('yyyy-MM-dd').format(date!) : 'اختر التاريخ'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteController,
              decoration: baseDecoration.copyWith(labelText: 'ملاحظة (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (date == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى اختيار تاريخ التذكير'), backgroundColor: AppColors.error),
                );
                return;
              }
              setState(() {
                _reminders.add(_ReminderEntry(type: type, date: date!, note: noteController.text.trim()));
              });
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // المستندات المرفقة
  // -------------------------------------------------------------------------
  Widget _buildDocumentsSection(InputDecoration baseDecoration) {
    return Column(
      children: [
        ..._attachedDocuments.asMap().entries.map((entry) => _buildDocumentCard(entry.key, entry.value, baseDecoration)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showAttachDocumentDialog(baseDecoration),
          icon: const Icon(Icons.attach_file),
          label: const Text('إرفاق مستند'),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(int index, _DocumentEntry doc, InputDecoration baseDecoration) {
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.description, color: AppColors.primaryNavy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.nameController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(doc.type, style: AppTextStyles.bodySmallSecondary),
                if (doc.file != null) Text(path.basename(doc.file!.path), style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error),
            onPressed: () => setState(() {
              doc.nameController.dispose();
              _attachedDocuments.removeAt(index);
            }),
          ),
        ],
      ),
    );
  }

  void _showAttachDocumentDialog(InputDecoration baseDecoration) {
    final nameController = TextEditingController();
    String docType = 'مستند عقد';
    File? selectedFile;
    // التقاط setState الخاص بالويزارد: لأن StatefulBuilder يعرّف setState
    // محلياً يظلّل setState الخاص بالشاشة، وبدون ذلك لا تُعاد بناء الواجهة
    // بعد إغلاق الحوار فلا تظهر بطاقة المرفق الجديد.
    final wizardSetState = setState;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إرفاق مستند جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: baseDecoration.copyWith(labelText: 'اسم المستند *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: docType,
                decoration: baseDecoration.copyWith(labelText: 'نوع المستند'),
                items: const [
                  DropdownMenuItem(value: 'مستند عقد', child: Text('مستند عقد')),
                  DropdownMenuItem(value: 'هوية', child: Text('هوية')),
                  DropdownMenuItem(value: 'سند توكيل', child: Text('سند توكيل')),
                  DropdownMenuItem(value: 'إخراج قيد', child: Text('إخراج قيد')),
                  DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                ],
                onChanged: (v) => docType = v ?? 'مستند عقد',
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await file_picker.FilePicker.pickFiles(
                type: file_picker.FileType.custom,
                allowedExtensions: const ['pdf', 'doc', 'docx', 'rtf', 'txt', 'jpg', 'png', 'jpeg'],
              );
                  if (result != null) {
                    selectedFile = File(result.files.single.path!);
                    setState(() {});  // Update dialog without closing
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: Text(selectedFile != null ? path.basename(selectedFile!.path) : 'اختيار ملف'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم المستند'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                wizardSetState(() {
                  _attachedDocuments.add(_DocumentEntry(
                    nameController: nameController,
                    type: docType,
                    file: selectedFile,
                  ));
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // أتعاب المكتب
  // -------------------------------------------------------------------------
  Widget _buildFeeSection(InputDecoration baseDecoration) {
    return GlassmorphicCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _feeAgreementType,
            decoration: baseDecoration.copyWith(labelText: 'نوع الأتعاب'),
            items: const [
              DropdownMenuItem(value: 'fixed', child: Text('مبلغ مقطوع')),
              DropdownMenuItem(value: 'percentage', child: Text('نسبة مئوية')),
              DropdownMenuItem(value: 'free', child: Text('مجاني / بدون أتعاب')),
            ],
            onChanged: (v) => setState(() => _feeAgreementType = v ?? 'fixed'),
          ),
          if (_feeAgreementType != 'free') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _feeAmountController,
              keyboardType: TextInputType.number,
              decoration: baseDecoration.copyWith(
                labelText: _feeAgreementType == 'percentage' ? 'النسبة المئوية' : 'المبلغ',
                suffixText: _feeAgreementType == 'percentage' ? '%' : _currency,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeePartyPicker(baseDecoration),
          ],
        ],
      ),
    );
  }

  Widget _buildFeePartyPicker(InputDecoration baseDecoration) {
    final uniquePartyIds = <int>{};
    final clientParties = <DropdownMenuItem<int>>[];
    
    for (final party in _parties) {
      for (final person in party.persons) {
        if (person.personId != null && uniquePartyIds.add(person.personId!)) {
          // Get person name from the persons list
          final personsAsync = ref.read(allPersonsProvider(null));
          final persons = personsAsync.valueOrNull ?? [];
          final personEntity = persons.where((p) => p.id == person.personId).firstOrNull;
          final personName = personEntity?.fullName ?? 'شخص #${person.personId}';
          
          clientParties.add(DropdownMenuItem(
            value: person.personId,
            child: Text('$personName (${party.role})'),
          ));
        }
      }
    }
    
    // Validate that _feePartyId exists in the list
    final isValidValue = clientParties.any((item) => item.value == _feePartyId);
    
    return DropdownButtonFormField<int>(
      value: isValidValue ? _feePartyId : null,
      decoration: baseDecoration.copyWith(labelText: 'الموكل (دافع الأتعاب)'),
      items: clientParties,
      onChanged: (v) => setState(() => _feePartyId = v),
    );
  }

  // =========================================================================
  // الخطوة 2: اختيار النموذج
  // =========================================================================
  
  Widget _buildTemplateStep() {
    final templatesAsync = ref.watch(contractRepositoryProvider)
        .watchContractTemplates(type: 'عقد');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('اختيار نموذج العقد', Icons.description, 'اختر نموذجاً جاهزاً، أو استورد نموذجك الخاص، أو ابدأ من ورقة فارغة'),
        const SizedBox(height: 24),
        Row(
          children: [
            _methodChip('📚 من المكتبة', 'from_template', Icons.library_books),
            const SizedBox(width: 8),
            _methodChip('📁 استيراد نموذج', 'uploaded', Icons.upload_file),
            const SizedBox(width: 8),
            _methodChip('📝 ورقة فارغة', 'blank', Icons.note_add),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_creationMethod == 'from_template') _buildTemplateLibrary(templatesAsync),
                if (_creationMethod == 'uploaded') _buildUploadSection(),
                if (_creationMethod == 'blank') _buildBlankInfo(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _methodChip(String label, String method, IconData icon) {
    final isSelected = _creationMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _creationMethod = method;
          _selectedTemplate = null;
          _uploadedFile = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryNavy.withOpacity(0.1) : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primaryNavy : AppColors.cardBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary, size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
              ), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateLibrary(Stream<List<ContractTemplate>> stream) {
    return StreamBuilder<List<ContractTemplate>>(
      stream: stream,
      builder: (context, snapshot) {
        final templates = snapshot.data ?? [];
        if (templates.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.library_books_outlined, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text('لا توجد قوالب عقود متاحة حالياً', style: AppTextStyles.bodyMediumSecondary, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('يمكنك استيراد نموذج من جهازك أو البدء من ورقة فارغة', style: AppTextStyles.bodySmallSecondary, textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return Column(
          children: templates.map((t) {
            final isSelected = _selectedTemplate?.id == t.id;
            return InkWell(
              onTap: () => setState(() => _selectedTemplate = t),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryNavy.withOpacity(0.08) : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryNavy : AppColors.cardBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description, color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.templateName, style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.primaryNavy : AppColors.textPrimary,
                          )),
                          Text(t.contractType, style: AppTextStyles.bodySmallSecondary),
                        ],
                      ),
                    ),
                    if (isSelected) const Icon(Icons.check_circle, color: AppColors.success),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildUploadSection() {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _uploadedFile != null ? AppColors.success : AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(
            _uploadedFile != null ? Icons.check_circle : Icons.cloud_upload,
            size: 48,
            color: _uploadedFile != null ? AppColors.success : AppColors.primaryNavy,
          ),
          const SizedBox(height: 12),
          Text(
            _uploadedFile != null ? 'تم اختيار: ${path.basename(_uploadedFile!.path)}' : 'استورد نموذجك الخاص (Word/PDF)',
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickUploadFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('اختيار ملف من جهازي'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _templateNameController,
            decoration: inputDecoration.copyWith(
              labelText: 'اسم النموذج (للاستخدام المستقبلي) *',
              hintText: 'مثال: عقد بيع شقة سكنية',
              prefixIcon: const Icon(Icons.label),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'سيُحفظ النموذج المستورد في مكتبة القوالب للاستخدام المستقبلي',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBlankInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.note_add, size: 48, color: AppColors.primaryNavy),
          const SizedBox(height: 12),
          Text('سيُنشأ ملف عقد فارغ يمكنك تحريره في Microsoft Word', style: AppTextStyles.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('اكتب العقد بنفسك خارج التطبيق ثم اربطه بملف العقد', style: AppTextStyles.bodySmallSecondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _pickUploadFile() async {
    final result = await file_picker.FilePicker.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: const ['docx', 'doc', 'pdf', 'rtf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _uploadedFile = File(result.files.single.path!));
    }
  }

  // =========================================================================
  // الحفظ النهائي وفتح Word
  // =========================================================================
  
  Future<void> _createAndOpenInWord() async {
    // TODO: Add permission check

    if (_creationMethod == 'from_template' && _selectedTemplate == null) {
      _showError('يرجى اختيار نموذج أو تغيير طريقة الإنشاء');
      return;
    }
    if (_creationMethod == 'uploaded' && _uploadedFile == null) {
      _showError('يرجى اختيار ملف للاستيراد');
      return;
    }
    if (_creationMethod == 'uploaded' && _templateNameController.text.trim().isEmpty) {
      _showError('يرجى إدخال اسم النموذج');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(contractRepositoryProvider);
      final userRef = AppConstants.defaultLawyerName;

      // 1. إعداد بيانات العقد
      final contractCompanion = ContractsCompanion.insert(
        internalNumber: 'TEMP-${DateTime.now().microsecondsSinceEpoch}',
        title: _titleController.text.trim(),
        contractType: _legalSubcategory ?? _legalCategory ?? 'عقد',
        legalCategory: Value(_legalCategory),
        legalSubcategory: Value(_legalSubcategory),
        sourceTemplateId: Value(_selectedTemplate?.id),
        creationMethod: Value(_creationMethod),
        status: Value(false ? 'archived' : _contractStatus),
        notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
        dateSigned: Value(_dateSigned),
        dateStart: Value(_dateStart),
        dateEnd: Value(_dateEnd),
        financialValue: Value(double.tryParse(_valueController.text.trim())),
        currency: Value(_currency),
        location: Value(_locationController.text.trim().isEmpty ? null : _locationController.text.trim()),
        isRenewable: Value(_isRenewable),
        renewalType: Value(_isRenewable ? _renewalType : null),
        notarizationType: Value(_notarizationType == 'عرفي' ? null : _notarizationType),
        notarizationNumber: Value(_notarizationNumberController.text.trim().isEmpty ? null : _notarizationNumberController.text.trim()),
        paymentMethod: Value(_paymentMethod),
      );

      // 2. إعداد الأطراف
      final parties = <ContractPartiesCompanion>[];
      for (var i = 0; i < _parties.length; i++) {
        final party = _parties[i];
        for (final person in party.persons) {
          parties.add(ContractPartiesCompanion.insert(
            contractId: 0,
            personId: person.personId!,
            partyRole: Value(party.role),
            partyCapacity: Value(person.capacity),
            partyOrder: Value(i + 1),
          ));
        }
      }

      // 3. إعداد التذكيرات
      final reminders = _reminders.map((r) => ContractRemindersCompanion.insert(
        contractId: 0,
        reminderType: r.type,
        reminderDate: r.date,
        reminderNote: Value(r.note.isEmpty ? null : r.note),
      )).toList();

      // 4. إعداد الأقساط
      final installments = _installments.asMap().entries.map((entry) => ContractInstallmentsCompanion.insert(
        contractId: 0,
        installmentNumber: entry.key + 1,
        amount: entry.value.amount,
        dueDate: entry.value.dueDate,
      )).toList();

      // 5. إعداد اتفاقية الأتعاب
      FeeAgreementsCompanion? feeAgreement;
      if (_feeAgreementType != 'free') {
        // إذا لم يحدّد المستخدم دافع الأتعاب صراحةً، نعتمد أول طرف في العقد
        // كي لا تضيع الأتعاب (كان الشرط _feePartyId != null يمنع الحفظ تماماً).
        var feePartyId = _feePartyId;
        if (feePartyId == null) {
          outer:
          for (final party in _parties) {
            for (final person in party.persons) {
              if (person.personId != null) {
                feePartyId = person.personId;
                break outer;
              }
            }
          }
        }
        final amount = double.tryParse(_feeAmountController.text.trim()) ?? 0;
        if (feePartyId != null) {
          feeAgreement = FeeAgreementsCompanion.insert(
            entityType: EntityType.contract.index,
            entityId: 0,
            partyId: feePartyId!,
            agreementType: Value(_feeAgreementType),
            totalAmount: Value(amount),
            currency: Value(_currency),
          );
        }
      }

      // 6. إعداد ملف Word
      // ملاحظة: filePath المخزّن للقالب مسار نسبي (templates/...)، لذا
      // يحوَّل إلى المسار المطلق قبل فتحه، وإلا فشل فتح الملف بخطأ
      // «ملف غير موجود» لأن File(path نسبي) لا يجد الملف في القرص.
      File? wordFile;
      if (_creationMethod == 'from_template' && _selectedTemplate != null) {
        final storageService = ref.read(fileStorageServiceProvider);
        final absPath = await storageService.getAbsolutePath(_selectedTemplate!.filePath);
        final f = File(absPath);
        if (await f.exists()) {
          wordFile = f;
        } else {
          wordFile = File(_selectedTemplate!.filePath);
        }
      } else if (_creationMethod == 'uploaded' && _uploadedFile != null) {
        wordFile = _uploadedFile;
      }

      // 7. حفظ العقد
      final contractId = await repo.createContract(
        contract: contractCompanion,
        parties: parties,
        reminders: reminders,
        installments: installments,
        feeAgreement: feeAgreement,
        wordFile: wordFile,
        userRef: userRef,
      );

      // 8. حفظ المستندات المرفقة + حفظ مستند الدفع (شيك / تحويل)
      if (_attachedDocuments.isNotEmpty || _paymentProofFile != null) {
        final db = ref.read(databaseProvider);
        final storageService = ref.read(fileStorageServiceProvider);
        
        for (final doc in _attachedDocuments) {
          String? filePath;
          if (doc.file != null) {
            filePath = await storageService.saveAttachment(
              sourceFile: doc.file!,
              folderType: 'documents',
              entityId: contractId,
            );
          }
          
          final docId = await db.into(db.documents).insert(
            DocumentsCompanion.insert(
              docName: doc.nameController.text.trim(),
              docType: Value(doc.type),
              filePath: Value(filePath),
              fileType: Value(doc.file != null ? path.extension(doc.file!.path).substring(1) : null),
            ),
          );
          
          await db.into(db.documentLinks).insert(
            DocumentLinksCompanion.insert(
              documentId: docId,
              entityType: EntityType.contract.index,
              entityId: contractId,
              linkType: const Value('general'),
            ),
          );

          // تسجيل المرفق أيضاً كقالب في مكتبة قوالب العقود (فئة 'عقد') ليكون
          // قابلاً لإعادة الاستخدام ويظهر ضمن "النماذج القانونية > قوالب العقود".
          if (doc.file != null) {
            final templatePath = await storageService.saveTemplate(
              doc.file!,
              doc.nameController.text.trim(),
            );
            await db.contractDao.insertContractTemplate(
              ContractTemplatesCompanion.insert(
                contractType: 'عقد',
                templateName: doc.nameController.text.trim(),
                filePath: templatePath,
                isDefault: const Value(false),
                templateSource: const Value('imported'),
              ),
            );
          }
        }

        // حفظ مستند الدفع (شيك أو تحويل بنكي) إن وُجد
        if (_paymentProofFile != null) {
          final proofPath = await storageService.saveAttachment(
            sourceFile: _paymentProofFile!,
            folderType: 'documents',
            entityId: contractId,
          );
          final proofDocName = _paymentMethod == 'شيك' ? 'صورة الشيك' : 'إيصال التحويل البنكي';
          final proofDocId = await db.into(db.documents).insert(
            DocumentsCompanion.insert(
              docName: proofDocName,
              docType: const Value('إثبات دفع'),
              filePath: Value(proofPath),
              fileType: Value(path.extension(_paymentProofFile!.path).substring(1)),
            ),
          );
          await db.into(db.documentLinks).insert(
            DocumentLinksCompanion.insert(
              documentId: proofDocId,
              entityType: EntityType.contract.index,
              entityId: contractId,
              linkType: const Value('payment_proof'),
            ),
          );
        }
      }

      // 9. حفظ النموذج المستورد في المكتبة
      if (_creationMethod == 'uploaded' && _uploadedFile != null) {
        final db = ref.read(databaseProvider);
        final storageService = ref.read(fileStorageServiceProvider);
        
        final templatePath = await storageService.saveTemplate(
          _uploadedFile!,
          _templateNameController.text.trim(),
        );

        await db.contractDao.insertContractTemplate(
          ContractTemplatesCompanion.insert(
            // يُصنَّف النموذج المستورد ضمن فئة "عقد" ليظهر في "قوالب العقود"
            // (كان يُحفظ بالتصنيف الفرعي فلا يظهر تحت فلتر قوالب العقود).
            contractType: 'عقد',
            templateName: _templateNameController.text.trim(),
            filePath: templatePath,
            isDefault: const Value(false),
            templateSource: const Value('imported'),
          ),
        );
      }

      // 10. فتح Word مباشرة!
      if (wordFile != null && await wordFile.exists()) {
        // Open in Word using Process.start
        if (Platform.isWindows) {
          await Process.start('explorer', [wordFile.path], runInShell: true);
        } else if (Platform.isMacOS) {
          await Process.start('open', [wordFile.path]);
        } else {
          await Process.start('xdg-open', [wordFile.path]);
        }

        // الانتقال لتفاصيل العقد بعد فتح Word
        if (mounted && contractId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ContractDetailScreen(contractId: contractId),
            ),
          );
        }
      }

      // 11. Audit log - TODO: Implement later
      // await auditService.log(...)

      if (mounted) {
        ref.invalidate(allContractsProvider);
        ref.invalidate(allPersonsProvider(null));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء العقد بنجاح! وفُتح في Word. يمكنك الوصول إليه لاحقاً من قائمة العقود.'),
            backgroundColor: AppColors.success,
          ),
        );
        if (mounted && contractId != null) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ContractDetailScreen(contractId: contractId))); }
      }
    } catch (e) {
      if (mounted) {
        _showError('خطأ أثناء حفظ العقد: $e');
        // TODO: Audit log for error
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }




  Future<void> _showAddPersonDialog(_PersonInParty person) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final idController = TextEditingController();
    final residenceController = TextEditingController(); // الموطن

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('إضافة شخص جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'رقم الهوية'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: residenceController,
                decoration: const InputDecoration(labelText: 'الموطن / الدائرة المختارة'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال الاسم'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      );

      if (result == true) {
        final db = ref.read(databaseProvider);
        final name = nameController.text.trim();

        // ===== منع التكرار =====
        final query = db.select(db.persons)..where((p) => p.fullName.equals(name));
        final existing = await query.getSingleOrNull();
        if (existing != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هذا الاسم موجود مسبقاً')),
          );
          return;
        }

        final personId = await db.into(db.persons).insert(
          PersonsCompanion.insert(
            fullName: name,
            phone1: Value(phoneController.text.trim().isEmpty ? null : phoneController.text.trim()),
            nationalId: Value(idController.text.trim().isEmpty ? null : idController.text.trim()),
            residence: Value(residenceController.text.trim().isEmpty ? null : residenceController.text.trim()),
            type: const Value(0),
          ),
        );

        ref.invalidate(allPersonsProvider(null));
        setState(() {
          person.personId = personId;
        });
      }
    } catch (e, st) {
      debugPrint('AddPersonDialogError: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الحفظ: $e'), duration: const Duration(seconds: 5)),
      );
    }
  }


  Future<void> _showAddSubcategoryDialog() async {
    final nameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة تصنيف فرعي جديد'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم التصنيف الفرعي *'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال اسم التصنيف'), backgroundColor: AppColors.error),
                );
                return;
              }
              Navigator.pop(ctx, nameController.text.trim());
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      // For now, just set it as the selected subcategory
      // In a full implementation, you would save it to the database
      setState(() {
        _legalSubcategory = result;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إضافة التصنيف: $result'), backgroundColor: AppColors.success),
      );
    }
  }




  Future<void> _showAddCategoryDialog({required bool isMainCategory}) async {
    final nameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMainCategory ? 'إضافة تصنيف رئيسي جديد' : 'إضافة تصنيف فرعي جديد'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: isMainCategory ? 'اسم التصنيف الرئيسي *' : 'اسم التصنيف الفرعي *',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال اسم التصنيف'), backgroundColor: AppColors.error),
                );
                return;
              }
              Navigator.pop(ctx, nameController.text.trim());
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      // Save to database
      final db = ref.read(databaseProvider);
      await db.into(db.contractTypesLookup).insert(
        ContractTypesLookupCompanion.insert(
          name: result,
          category: Value(isMainCategory ? null : _legalCategory),
        ),
      );
      
      setState(() {
        if (isMainCategory) {
          _customMainCategories.add(result);
          _legalCategory = result;
          _legalSubcategory = null;
        } else {
          _customSubcategories.add(result);
          _legalSubcategory = result;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة التصنيف: $result'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

}

// =============================================================================
// Helper Classes
// =============================================================================

class _PersonInParty {
  int? personId;
  String capacity;

  _PersonInParty({this.personId, this.capacity = 'أصيل'});
}

class _PartyEntry {
  String role;
  final List<_PersonInParty> persons;

  _PartyEntry({required this.role, List<_PersonInParty>? persons})
      : persons = persons ?? [_PersonInParty()];
}

class _InstallmentEntry {
  double amount;
  DateTime dueDate;

  _InstallmentEntry({required this.amount, required this.dueDate});
}

class _ReminderEntry {
  String type;
  DateTime date;
  String note;

  _ReminderEntry({required this.type, required this.date, this.note = ''});
}

class _DocumentEntry {
  TextEditingController nameController;
  String type;
  File? file;

  _DocumentEntry({required this.nameController, required this.type, this.file});
}
