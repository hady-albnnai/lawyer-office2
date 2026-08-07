/// معالج إنشاء عقد جديد — مبني على فلسفة "غلاف + نموذج + نسخة"
///
/// الهيكلية جاهزة للذكاء الاصطناعي:
/// - كل خطوة تسجل بيانات منظمة
/// - القالب يرتبط بالنسخة (template → instance)
/// - المتغيرات تُكتشف وتُملأ وتُحفظ للتعلم
/// - كل تفاعل يُسجل في ContractTemplateUsageLog
///
/// الخطوات الخمس:
/// 1. التصنيف (قانوني + فرعي)
/// 2. الأطراف (ديناميكية + صفة)
/// 3. موضوع العقد (عنوان + ملاحظات)
/// 4. اختيار النموذج (مكتبة / استيراد / فارغ)
/// 5. التحرير (متغيرات داخلية + Word خارجي)
///
/// آخر تحديث: 2026-08-06
library;

import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;

import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart';
import '../../../data/services/template_variable_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';
import '../../widgets/archive_context_banner.dart';
import '../../widgets/common/searchable_picker.dart';

class CreateContractWizard extends ConsumerStatefulWidget {
  final ArchiveEntryContext? archiveContext;
  const CreateContractWizard({super.key, this.archiveContext});

  @override
  ConsumerState<CreateContractWizard> createState() => _CreateContractWizardState();
}

class _CreateContractWizardState extends ConsumerState<CreateContractWizard> {
  int _currentStep = 0;
  bool _isSaving = false;

  // =========================================================================
  // الخطوة 0: نوع ملف العقد
  // =========================================================================
  String _contractFileType = 'new'; // new, review, followup

  // =========================================================================
  // الخطوة 1: التصنيف القانوني
  // =========================================================================
  String? _legalCategory;
  String? _legalSubcategory;

  static const Map<String, List<String>> _categorySubcategories = {
    'عقود واردة على الملكية': [
      'بيع عقار', 'بيع منقول', 'بيع مركبة', 'بيع حصة/أسهم',
      'مقايضة', 'هبة', 'قرض/دين',
    ],
    'عقود واردة على الانتفاع': [
      'إيجار سكني', 'إيجار تجاري', 'إيجار مكتب/مهنة',
      'إيجار أرض', 'عارية استعمال',
    ],
    'عقود واردة على العمل/الخدمة': [
      'مقاولة', 'عقد عمل', 'عقد خدمات',
      'عقد استشارة', 'توريد مع تنفيذ',
    ],
    'عقود صلح/تسوية': [
      'صلح قضائي', 'صلح غير قضائي', 'تسوية نزاع',
      'مخالصة/إبراء', 'إنهاء علاقة تعاقدية',
    ],
    'عقود شركات/شراكات': [
      'اتفاق شركاء', 'عقد محاصة', 'عقد تأسيس شركة',
      'ملحق عقد تأسيس', 'تنازل عن حصص',
    ],
    'عقود ضمان/كفالة/رهن': [
      'كفالة شخصية', 'رهن عقاري', 'رهن منقول',
      'ضمان بنكي', 'تعهد تضامني',
    ],
    'وكالات/تفويضات': [
      'تفويض خاص', 'عقد وكالة مدنية', 'وكالة بيع',
      'وكالة إدارة', 'وكالة غير قابلة للعزل مرتبطة بحق',
    ],
    'عقود تجارية': [
      'توريد', 'توزيع', 'وكالة تجارية',
      'استثمار', 'تعاون تجاري', 'سمسرة/وساطة',
    ],
    'عقود أخرى': ['عقد آخر', 'تصنيف مخصص'],
  };

  // =========================================================================
  // الخطوة 2: الأطراف
  // =========================================================================
  final List<_PartyEntry> _parties = [];
  // أسماء الأطراف النموذجية حسب التصنيف الفرعي
  List<String> get _defaultPartyRoles {
    final sub = _legalSubcategory ?? '';
    if (sub.contains('بيع')) return ['البائع', 'المشتري'];
    if (sub.contains('إيجار')) return ['المؤجر', 'المستأجر'];
    if (sub.contains('مقاولة') || sub.contains('توريد')) return ['صاحب العمل', 'المقاول'];
    if (sub.contains('عمل')) return ['صاحب العمل', 'العامل'];
    if (sub.contains('شراكة') || sub.contains('محاصة') || sub.contains('تأسيس')) return ['الشريك الأول', 'الشريك الثاني'];
    if (sub.contains('وكالة') || sub.contains('تفويض')) return ['الموكل', 'الوكيل'];
    if (sub.contains('صلح') || sub.contains('تسوية') || sub.contains('مخالصة')) return ['الطرف الأول', 'الطرف الثاني'];
    if (sub.contains('كفالة') || sub.contains('ضمان')) return ['المكفول له', 'الكفيل', 'الدائن'];
    if (sub.contains('رهن')) return ['الراهن', 'المرتهن'];
    if (sub.contains('هبة')) return ['الواهب', 'الموهوب له'];
    if (sub.contains('قرض')) return ['المقرض', 'المقترض'];
    return ['الطرف الأول', 'الطرف الثاني'];
  }

  // =========================================================================
  // الخطوة 3: موضوع العقد
  // =========================================================================
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _valueController = TextEditingController();
  final _locationController = TextEditingController();
  final _notarizationNumberController = TextEditingController();
  String _currency = 'ل.س';
  DateTime? _dateSigned;
  DateTime? _dateStart;
  DateTime? _dateEnd;
  bool _isRenewable = false;
  String _renewalType = 'تلقائي';
  String _contractStatus = 'active';
  String _notarizationType = 'عرفي';
  String _paymentMethod = 'نقدي';

  // =========================================================================
  // الخطوة 4: النموذج
  // =========================================================================
  /// من أين جاء العقد: from_template / uploaded / blank
  String _creationMethod = 'from_template';
  ContractTemplate? _selectedTemplate;
  File? _uploadedFile;

  // =========================================================================
  // الخطوة 5: التحرير والمتغيرات
  // =========================================================================
  List<TemplateVariable> _detectedVariables = [];
  final Map<String, TextEditingController> _variableControllers = {};
  final Map<String, String> _variableFillMethods = {};
  bool _variablesDetected = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _valueController.dispose();
    _locationController.dispose();
    _notarizationNumberController.dispose();
    for (final controller in _variableControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.archiveContext == null
            ? 'إنشاء عقد جديد'
            : 'إدخال عقد من الأرشيف'),
      ),
      body: Column(
        children: [
          _buildStepper(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ArchiveContextBanner(contextInfo: widget.archiveContext),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: SingleChildScrollView(
                key: ValueKey<int>(_currentStep),
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // =========================================================================
  // شريط التقدم
  // =========================================================================
  Widget _buildStepper() {
    return GlassmorphicStepper(
      currentStep: _currentStep,
      totalSteps: 6,
      stepLabels: const ['النوع', 'التصنيف', 'الأطراف', 'التفاصيل', 'النموذج', 'التحرير'],
      stepIcons: const [
        Icons.folder_open,
        Icons.category,
        Icons.people,
        Icons.subject,
        Icons.description,
        Icons.edit_note,
      ],
    );
  }

  // =========================================================================
  // شريط التنقل السفلي
  // =========================================================================
  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withOpacity(0.85),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                GlassmorphicButton(
                  onPressed: _isSaving ? null : () => setState(() => _currentStep--),
                  isPrimary: false,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: AppColors.textOnLight),
                      SizedBox(width: 8),
                      Text('السابق', style: TextStyle(color: AppColors.textOnLight)),
                    ],
                  ),
                )
              else
                const SizedBox(width: 120),
              if (_currentStep < 4)
                GlassmorphicButton(
                  onPressed: _isSaving ? null : _nextStep,
                  isPrimary: true,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('التالي', style: TextStyle(color: AppColors.textOnLight)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: AppColors.textOnLight),
                    ],
                  ),
                ),
              if (_currentStep == 4)
                GlassmorphicButton(
                  onPressed: _isSaving ? null : _saveContract,
                  isPrimary: true,
                  backgroundColor: AppColors.success.withOpacity(0.85),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.save, color: AppColors.textOnLight),
                            SizedBox(width: 8),
                            Text('حفظ العقد', style: TextStyle(color: AppColors.textOnLight)),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // محتوى الخطوات
  // =========================================================================
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _buildFileTypeStep();
      case 1: return _buildClassificationStep();
      case 2: return _buildPartiesStep();
      case 3: return _buildSubjectStep();
      case 4: return _buildTemplateStep();
      case 5: return _buildEditStep();
      default: return const SizedBox();
    }
  }

  Widget _buildStepHeader(String title, String description, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryNavy.withOpacity(0.1), AppColors.cardBackground],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryNavy.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryNavy, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy)),
                const SizedBox(height: 4),
                Text(description, style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // الخطوة 0: نوع ملف العقد
  // =========================================================================
  Widget _buildFileTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader('نوع ملف العقد', 'ماذا تريد أن تفعل؟', Icons.folder_open),
        const SizedBox(height: 16),
        _fileTypeCard('new', 'إنشاء عقد جديد',
            'المكتب سيبدأ بصياغة عقد جديد من الصفر أو من نموذج جاهز',
            Icons.add_circle_outline),
        const SizedBox(height: 12),
        _fileTypeCard('review', 'مراجعة / تعديل عقد جاهز',
            'لديك عقد أو مسودة موجودة وتريد مراجعتها أو تعديلها',
            Icons.edit_note),
        const SizedBox(height: 12),
        _fileTypeCard('followup', 'متابعة عقد موقع',
            'العقد موقع بالفعل والمكتب سيتابع التزاماته أو إجراءاته',
            Icons.follow_the_signs),
      ],
    );
  }

  Widget _fileTypeCard(String value, String title, String description, IconData icon) {
    final isSelected = _contractFileType == value;
    return InkWell(
      onTap: () => setState(() => _contractFileType = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy.withOpacity(0.08) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryNavy.withOpacity(0.15) : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.primaryNavy : AppColors.textPrimary,
                  )),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.bodySmallSecondary),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primaryNavy, size: 24),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // الخطوة 1: التصنيف القانوني
  // =========================================================================
  Widget _buildClassificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader('التصنيف القانوني', 'حدد التصنيف الرئيسي والفرعي للعقد', Icons.category),

        // التصنيف الرئيسي
        Text('التصنيف القانوني الرئيسي *', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categorySubcategories.keys.map((cat) {
            final isSelected = _legalCategory == cat;
            return ChoiceChip(
              label: Text(cat, style: TextStyle(
                color: isSelected ? AppColors.textOnLight : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              )),
              selected: isSelected,
              selectedColor: AppColors.primaryNavy,
              backgroundColor: AppColors.cardBackground,
              side: BorderSide(
                color: isSelected ? AppColors.primaryNavy : AppColors.cardBorder,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              onSelected: (_) => setState(() {
                _legalCategory = cat;
                _legalSubcategory = null;
              }),
            );
          }).toList(),
        ),

        // التصنيف الفرعي
        if (_legalCategory != null) ...[
          const SizedBox(height: 24),
          Text('التصنيف الفرعي *', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_categorySubcategories[_legalCategory!] ?? []).map((sub) {
              final isSelected = _legalSubcategory == sub;
              return ChoiceChip(
                label: Text(sub, style: TextStyle(
                  color: isSelected ? AppColors.textOnLight : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
                selected: isSelected,
                selectedColor: AppColors.secondaryGold,
                backgroundColor: AppColors.cardBackground,
                side: BorderSide(
                  color: isSelected ? AppColors.secondaryGold : AppColors.cardBorder,
                ),
                onSelected: (_) => setState(() => _legalSubcategory = sub),
              );
            }).toList(),
          ),
        ],

        // عرض أطراف افتراضية متوقعة
        if (_legalSubcategory != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الأطراف المتوقعة لهذا النوع: ${_defaultPartyRoles.join(' + ')}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================================
  // الخطوة 2: الأطراف
  // =========================================================================
  Widget _buildPartiesStep() {
    final personsAsync = ref.watch(allPersonsProvider(null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          'الأطراف المتعاقدة',
          'أضف أطراف العقد مع تحديد دور كل طرف وصفته',
          Icons.people,
        ),

        // الأطراف المضافة
        ..._parties.asMap().entries.map((entry) {
          final index = entry.key;
          final party = entry.value;
          return _buildPartyCard(index, party, personsAsync);
        }),

        const SizedBox(height: 16),

        // زر إضافة طرف
        OutlinedButton.icon(
          onPressed: () => _addParty(),
          icon: const Icon(Icons.person_add),
          label: Text(_parties.isEmpty
              ? 'إضافة الأطراف'
              : 'إضافة طرف آخر (كفيل/ضامن/شاهد)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryNavy,
            side: BorderSide(color: AppColors.primaryNavy.withOpacity(0.3)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPartyCard(int index, _PartyEntry party, AsyncValue<List<PersonEntity>> personsAsync) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryNavy.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان الطرف
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text('${index + 1}', style: const TextStyle(
                    color: AppColors.secondaryGold, fontWeight: FontWeight.bold,
                  )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: party.role,
                  decoration: InputDecoration(
                    labelText: 'اسم الطرف',
                    hintText: 'مثال: البائعون، المشتري، الكفيل',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => party.role = v),
                ),
              ),
              if (_parties.length > 2)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => setState(() => _parties.removeAt(index)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // الأشخاص داخل الطرف
          ...party.persons.asMap().entries.map((entry) {
            final pIndex = entry.key;
            final person = entry.value;
            return _buildPersonInPartyRow(personsAsync, party, person, pIndex);
          }),

          // زر إضافة شخص للطرف
          if (party.persons.length >= 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () => setState(() => party.persons.add(_PersonInParty())),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('إضافة شخص لهذا الطرف'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonInPartyRow(
    AsyncValue<List<PersonEntity>> personsAsync,
    _PartyEntry party,
    _PersonInParty person,
    int pIndex,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(children: [
              Expanded(child: personsAsync.when(
                data: (persons) => SearchablePicker<PersonEntity>(
                  label: 'اختر الشخص/الجهة *',
                  hintText: 'ابحث بالاسم أو الهاتف',
                  prefixIcon: const Icon(Icons.person_search),
                  items: persons,
                  labelOf: (p) => p.fullName,
                  searchTermsOf: (p) => [p.phone1 ?? '', p.nationalId ?? ''],
                  subtitleOf: (p) => p.phone1,
                  value: person.personId == null ? null : persons.where((p) => p.id == person.personId).firstOrNull,
                  onSelected: (p) {
                    // التحقق من عدم تكرار نفس الشخص في أطراف أخرى
                    final isDuplicate = _parties.any((other) =>
                        other.persons.any((op) => op != person && op.personId == p.id));
                    if (isDuplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${p.fullName} مُضاف بالفعل في طرف آخر'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    setState(() => person.personId = p.id);
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('خطأ'),
              )),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.person_add, color: AppColors.primaryNavy, size: 20),
                tooltip: 'إضافة شخص جديد',
                onPressed: () => _showQuickAddPerson(context, person),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: person.capacity,
                  decoration: InputDecoration(
                    labelText: 'الصفة',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'أصيل', child: Text('أصيل')),
                    DropdownMenuItem(value: 'وكيل', child: Text('وكيل')),
                    DropdownMenuItem(value: 'ولي', child: Text('ولي')),
                    DropdownMenuItem(value: 'وصي', child: Text('وصي')),
                    DropdownMenuItem(value: 'ممثل شركة', child: Text('ممثل شركة')),
                  ],
                  onChanged: (v) => setState(() => person.capacity = v ?? 'أصيل'),
                ),
                // إظهار اختيار الوكالة إذا كانت الصفة "وكيل"
                if (person.capacity == 'وكيل' && person.personId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildPoaPicker(person),
                  ),
              ],
            ),
          ),
          if (party.persons.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 18),
              tooltip: 'حذف هذا الشخص',
              onPressed: () => setState(() => party.persons.removeAt(pIndex)),
            ),
        ],
      ),
    );
  }

  /// اختيار الوكالة المرتبطة بالشخص (عند صفة "وكيل")
  Widget _buildPoaPicker(_PersonInParty person) {
    final poasAsync = ref.watch(allPoasProvider);
    return poasAsync.when(
      data: (allPoas) {
        if (allPoas.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لا توجد وكالات مسجلة. أضف وكالة من شاشة الوكالات.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          );
        }
        return DropdownButtonFormField<int>(
          value: person.poaId,
          isDense: true,
          decoration: InputDecoration(
            labelText: 'رقم الوكالة *',
            hintText: 'اختر الوكالة',
            prefixIcon: const Icon(Icons.verified_user, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: allPoas.map((poa) => DropdownMenuItem(
            value: poa.id,
            child: Text('${poa.poaNumber ?? poa.id.toString()} — ${poa.subType ?? 'عامة'}'),
          )).toList(),
          onChanged: (v) => setState(() => person.poaId = v),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('خطأ في تحميل الوكالات'),
    );
  }

  void _addParty() {
    setState(() {
      final roles = _defaultPartyRoles;
      final role = _parties.length < roles.length ? roles[_parties.length] : 'طرف ${_parties.length + 1}';
      _parties.add(_PartyEntry(role: role));
    });
  }

  /// حوار سريع لإضافة شخص جديد من داخل الويزارد
  void _showQuickAddPerson(BuildContext context, _PersonInParty person) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final idCtrl = TextEditingController();

    showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة شخص جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل *')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف')),
            const SizedBox(height: 8),
            TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'رقم الهوية')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final personId = await ref.read(personRepositoryProvider).createPerson(
                  person: PersonsCompanion.insert(
                    fullName: nameCtrl.text.trim(),
                    phone1: Value(phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim()),
                    nationalId: Value(idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim()),
                  ),
                );
                ref.invalidate(allPersonsProvider);
                if (ctx.mounted) Navigator.pop(ctx, personId);
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
    ).then((personId) {
      if (personId != null && mounted) {
        setState(() => person.personId = personId);
      }
    });
  }

  // =========================================================================
  // الخطوة 3: تفاصيل العقد
  // =========================================================================
  Widget _buildSubjectStep() {
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
          _buildStepHeader('تفاصيل العقد', 'البيانات الأساسية للعقد — تُحفظ للفهرسة والذكاء الاصطناعي', Icons.subject),

          // عنوان العقد
          TextFormField(
            controller: _titleController,
            decoration: inputDecoration.copyWith(
              labelText: 'عنوان العقد *',
              hintText: 'مثال: عقد بيع شقة في المزة - دمشق',
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),

          // تاريخ الإبرام
          Text('تواريخ العقد', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildDateField('تاريخ الإبرام', _dateSigned, (d) => setState(() => _dateSigned = d), inputDecoration)),
            const SizedBox(width: 12),
            Expanded(child: _buildDateField('تاريخ البدء', _dateStart, (d) => setState(() => _dateStart = d), inputDecoration)),
            const SizedBox(width: 12),
            Expanded(child: _buildDateField('تاريخ الانتهاء', _dateEnd, (d) => setState(() => _dateEnd = d), inputDecoration)),
          ]),
          const SizedBox(height: 16),

          // القيمة المالية
          Text('القيمة المالية', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                decoration: inputDecoration.copyWith(
                  labelText: 'القيمة المالية (اختياري)',
                  hintText: 'مثال: 50000000',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _currency,
                decoration: inputDecoration.copyWith(labelText: 'العملة'),
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

          // مكان الإبرام
          TextFormField(
            controller: _locationController,
            decoration: inputDecoration.copyWith(
              labelText: 'مكان الإبرام (اختياري)',
              hintText: 'مثال: دمشق - كاتب العدل الأول',
              prefixIcon: const Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 16),

          // قابلية التجديد
          Row(children: [
            Checkbox(
              value: _isRenewable,
              onChanged: (v) => setState(() => _isRenewable = v ?? false),
              activeColor: AppColors.primaryNavy,
            ),
            const Text('العقد قابل للتجديد'),
            if (_isRenewable) ...[
              const SizedBox(width: 16),
              DropdownButtonFormField<String>(
                value: _renewalType,
                isDense: true,
                decoration: inputDecoration.copyWith(labelText: 'نوع التجديد'),
                items: const [
                  DropdownMenuItem(value: 'تلقائي', child: Text('تلقائي')),
                  DropdownMenuItem(value: 'اتفاق', child: Text('باتفاق الأطراف')),
                  DropdownMenuItem(value: 'قرار', child: Text('بقرار')),
                ],
                onChanged: (v) => setState(() => _renewalType = v ?? 'تلقائي'),
              ),
            ],
          ]),
          const SizedBox(height: 16),

          // حالة العقد + التوثيق
          Text('الحالة والتوثيق', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _contractStatus,
                decoration: inputDecoration.copyWith(labelText: 'حالة العقد'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('ساري المفعول')),
                  DropdownMenuItem(value: 'expired', child: Text('منتهٍ')),
                  DropdownMenuItem(value: 'cancelled', child: Text('ملغى')),
                  DropdownMenuItem(value: 'disputed', child: Text('متنازع عليه')),
                ],
                onChanged: (v) => setState(() => _contractStatus = v ?? 'active'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _notarizationType,
                decoration: inputDecoration.copyWith(labelText: 'نوع التوثيق'),
                items: const [
                  DropdownMenuItem(value: 'عرفي', child: Text('عرفي')),
                  DropdownMenuItem(value: 'notary', child: Text('كاتب العدل')),
                  DropdownMenuItem(value: 'court', child: Text('المحكمة')),
                  DropdownMenuItem(value: 'chamber', child: Text('غرفة التجارة')),
                ],
                onChanged: (v) => setState(() => _notarizationType = v ?? 'عرفي'),
              ),
            ),
          ]),
          if (_notarizationType != 'عرفي') ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _notarizationNumberController,
              decoration: inputDecoration.copyWith(
                labelText: 'رقم التوثيق',
                hintText: _notarizationType == 'notary' ? 'رقم سند كاتب العدل' : 'رقم التوثيق',
                prefixIcon: const Icon(Icons.confirmation_number),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // طريقة الدفع
          Text('طريقة الدفع', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),

          // ملاحظات
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: inputDecoration.copyWith(
              labelText: 'ملاحظات حرة (اختياري)',
              hintText: 'أي ملاحظات تريد تسجيلها حول هذا العقد...',
              prefixIcon: const Icon(Icons.notes),
            ),
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
      side: BorderSide(
        color: isSelected ? AppColors.primaryNavy : AppColors.cardBorder,
      ),
      onSelected: (_) => setState(() => _paymentMethod = method),
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
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value == null ? 'اختر التاريخ' : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
          style: TextStyle(color: value == null ? AppColors.textSecondary : AppColors.textPrimary),
        ),
      ),
    );
  }

  // =========================================================================
  // الخطوة 4: اختيار النموذج
  // =========================================================================
  Widget _buildTemplateStep() {
    final templatesAsync = ref.watch(contractRepositoryProvider)
        .watchContractTemplates(type: _legalSubcategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          'اختيار نموذج العقد',
          'اختر نموذجاً جاهزاً، أو استورد نموذجك الخاص، أو ابدأ من ورقة فارغة',
          Icons.description,
        ),

        // الخيارات الثلاثة
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

        // حسب الخيار المختار
        if (_creationMethod == 'from_template') _buildTemplateLibrary(templatesAsync),
        if (_creationMethod == 'uploaded') _buildUploadSection(),
        if (_creationMethod == 'blank') _buildBlankInfo(),
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
                Text(
                  'لا توجد قوالب متاحة لتصنيف "${_legalSubcategory ?? ""}"',
                  style: AppTextStyles.bodyMediumSecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'يمكنك استيراد نموذج من جهازك أو البدء من ورقة فارغة',
                  style: AppTextStyles.bodySmallSecondary,
                  textAlign: TextAlign.center,
                ),
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
                    Icon(Icons.description,
                      color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary),
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
                    if (t.isDefault) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryGold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('افتراضي ⭐', style: TextStyle(fontSize: 10)),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: AppColors.success),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _uploadedFile != null ? AppColors.success : AppColors.cardBorder,
          style: _uploadedFile != null ? BorderStyle.solid : BorderStyle.solid,
        ),
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
            _uploadedFile != null
                ? 'تم اختيار: ${path.basename(_uploadedFile!.path)}'
                : 'استورد نموذجك الخاص (Word/PDF)',
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickUploadFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('اختيار ملف من جهازي'),
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
          Text(
            'سيُنشأ ملف عقد فارغ يمكنك تحريره في Microsoft Word',
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'اكتب العقد بنفسك خارج التطبيق ثم اربطه بملف العقد',
            style: AppTextStyles.bodySmallSecondary,
            textAlign: TextAlign.center,
          ),
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
  // الخطوة 5: التحرير والمتغيرات
  // =========================================================================
  Widget _buildEditStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          'تحرير العقد',
          'املأ المتغيرات داخلياً أو افتح الملف بـ Word للتحرير الكامل',
          Icons.edit_note,
        ),

        // ملخص ما تم
        _buildSummaryCard(),
        const SizedBox(height: 24),

        // المتغيرات (إذا وُجدت)
        if (_creationMethod == 'from_template' && _selectedTemplate != null) ...[
          if (!_variablesDetected)
            Center(
              child: ElevatedButton.icon(
                onPressed: _detectVariables,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('اكتشاف متغيرات النموذج'),
              ),
            ),
          if (_variablesDetected && _detectedVariables.isNotEmpty) ...[
            Text('المتغيرات المكتشفة في النموذج:', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🤖 هذه المتغيرات سيملؤها الذكاء الاصطناعي تلقائياً لاحقاً من بيانات الأطراف',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._detectedVariables.map(_buildVariableField),
          ],
          if (_variablesDetected && _detectedVariables.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(child: Text('لم يُعثر على متغيرات {{...}} في هذا القالب.\nيمكنك تحريره مباشرة بـ Word.')),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 24),

        // أزرار التحرير
        _buildEditButtons(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryNavy.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ملخص العقد', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 8),
          _summaryRow('التصنيف', '${_legalCategory ?? "---"} > ${_legalSubcategory ?? "---"}'),
          _summaryRow('الأطراف', _parties.map((p) => p.role).join(' + ')),
          _summaryRow('العنوان', _titleController.text.isEmpty ? '---' : _titleController.text),
          _summaryRow('النموذج', _creationMethod == 'from_template'
              ? (_selectedTemplate?.templateName ?? '---')
              : _creationMethod == 'uploaded'
                  ? (_uploadedFile != null ? path.basename(_uploadedFile!.path) : '---')
                  : 'ورقة فارغة'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary,
          ))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildVariableField(TemplateVariable variable) {
    final controller = _variableControllers[variable.name] ??= TextEditingController();

    // تلوين حسب النوع
    Color typeColor;
    String typeIcon;
    switch (variable.type) {
      case 'person': typeColor = AppColors.primaryNavy; typeIcon = '👤'; break;
      case 'money': typeColor = AppColors.success; typeIcon = '💰'; break;
      case 'date': typeColor = AppColors.info; typeIcon = '📅'; break;
      case 'property': typeColor = AppColors.secondaryGold; typeIcon = '🏠'; break;
      case 'number': typeColor = AppColors.warning; typeIcon = '🔢'; break;
      default: typeColor = AppColors.textSecondary; typeIcon = '📝'; break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: '$typeIcon ${variable.name}',
          hintText: variable.autoFillFromParty ? 'يُملأ تلقائياً من الأطراف' : 'أدخل القيمة',
          prefixIcon: Icon(
            variable.type == 'person' ? Icons.person :
            variable.type == 'money' ? Icons.attach_money :
            variable.type == 'date' ? Icons.calendar_today :
            variable.type == 'property' ? Icons.location_city :
            Icons.text_fields,
            color: typeColor,
          ),
          suffixIcon: variable.autoFillFromParty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('تلقائي', style: TextStyle(fontSize: 10, color: AppColors.success)),
                )
              : null,
          filled: true,
          fillColor: AppColors.cardBackground,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: typeColor.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: typeColor, width: 2),
          ),
        ),
        onChanged: (value) {
          _variableFillMethods[variable.name] = 'manual';
        },
      ),
    );
  }

  Widget _buildEditButtons() {
    return Column(
      children: [
        // فتح بـ Word
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openInWord,
            icon: const Icon(Icons.open_in_new),
            label: const Text('📄 فتح في Microsoft Word'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: AppColors.textOnLight,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '🔀 يمكنك ملء المتغيرات هنا ثم فتح Word لتعديل البنود — الاثنان يعملان معاً',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // =========================================================================
  // اكتشاف المتغيرات
  // =========================================================================
  Future<void> _detectVariables() async {
    if (_selectedTemplate == null) return;

    setState(() => _variablesDetected = true);

    try {
      final varService = TemplateVariableService(ref.read(databaseProvider));
      
      // محاولة قراءة المتغيرات من ملف .docx الحقيقي
      final templatePath = _selectedTemplate!.filePath;
      final templateFile = File(templatePath);
      
      if (await templateFile.exists()) {
        _detectedVariables = await varService.detectVariablesFromDocx(templateFile);
      }
      
      // إذا فشل القراءة أو لم يجد متغيرات — استخدام نص تجريبي للعرض
      if (_detectedVariables.isEmpty) {
        final fallbackText = '{{البائع}} يبيع {{المشتري}} العقار رقم {{رقم_العقار}} بثمن {{الثمن}} بتاريخ {{التاريخ}} في {{مكان_الإبرام}}';
        _detectedVariables = varService.detectVariables(fallbackText);
      }

      // ملء تلقائي من بيانات الأطراف (أول شخص في كل طرف)
      for (final variable in _detectedVariables) {
        if (variable.autoFillFromParty && variable.partyOrder != null) {
          final targetIndex = variable.partyOrder! - 1;
          final party = targetIndex >= 0 && targetIndex < _parties.length ? _parties[targetIndex] : null;
          final firstPerson = party?.persons.isNotEmpty == true ? party!.persons.first : null;
          if (firstPerson?.personId != null) {
            final persons = ref.read(allPersonsProvider(null)).valueOrNull ?? [];
            final person = persons.where((p) => p.id == firstPerson!.personId).firstOrNull;
            if (person != null) {
              _variableControllers[variable.name] ??= TextEditingController();
              _variableControllers[variable.name]!.text = person.fullName;
              _variableFillMethods[variable.name] = 'auto';
            }
          }
        } else if (variable.type == 'date') {
          _variableControllers[variable.name] ??= TextEditingController();
          _variableControllers[variable.name]!.text = DateTime.now().toString().substring(0, 10);
          _variableFillMethods[variable.name] = 'auto';
        }
      }

      // تسجيل الاكتشاف (AI Learning)
      await varService.logTemplateUsage(
        templateId: _selectedTemplate!.id,
        contractId: null,
        eventType: 'variables_detected',
        eventData: {
          'variables': _detectedVariables.map((v) => v.toJson()).toList(),
          'count': _detectedVariables.length,
        },
      );

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اكتشاف المتغيرات: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _openInWord() async {
    String? filePath;

    if (_creationMethod == 'from_template' && _selectedTemplate != null) {
      filePath = _selectedTemplate!.filePath;
    } else if (_creationMethod == 'uploaded' && _uploadedFile != null) {
      filePath = _uploadedFile!.path;
    } else if (_creationMethod == 'blank') {
      _showError('الورقة الفارغة — اكتب العقد مباشرة في Word واحفظه ثم استورده');
      return;
    } else {
      _showError('يرجى اختيار نموذج أو استيراد ملف أولاً');
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      _showError('الملف غير موجود: $filePath');
      return;
    }

    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        _showError('تعذّر فتح الملف: ${result.message}');
      }
    } catch (e) {
      _showError('خطأ في فتح الملف: $e');
    }
  }

  // =========================================================================
  // التنقل والتحقق
  // =========================================================================
  void _nextStep() {
    if (!_validateCurrentStep()) return;
    setState(() => _currentStep++);
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        // نوع ملف العقد — لا يحتاج تحقق (قيمة افتراضية موجودة)
        break;
      case 1:
        if (_legalCategory == null || _legalSubcategory == null) {
          _showError('يرجى اختيار التصنيف القانوني والفرعي');
          return false;
        }
        break;
      case 2:
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
        break;
      case 3:
        if (_titleController.text.trim().isEmpty) {
          _showError('يرجى إدخال عنوان للعقد');
          return false;
        }
        break;
      case 4:
        if (_creationMethod == 'from_template' && _selectedTemplate == null) {
          _showError('يرجى اختيار نموذج أو تغيير طريقة الإنشاء');
          return false;
        }
        if (_creationMethod == 'uploaded' && _uploadedFile == null) {
          _showError('يرجى اختيار ملف للاستيراد');
          return false;
        }
        break;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // =========================================================================
  // الحفظ النهائي
  // =========================================================================
  Future<void> _saveContract() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.contractsCreate)) {
      _showError('لا تملك صلاحية إنشاء عقد');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(contractRepositoryProvider);
      final varService = TemplateVariableService(ref.read(databaseProvider));
      final userRef = ref.read(authControllerProvider).user?.fullName ?? AppConstants.defaultLawyerName;

      // 1. إنشاء العقد
      final contractCompanion = ContractsCompanion.insert(
        internalNumber: 'TEMP-${DateTime.now().microsecondsSinceEpoch}',
        title: _titleController.text.trim(),
        contractType: _legalSubcategory ?? _legalCategory ?? 'عقد',
        legalCategory: Value(_legalCategory),
        legalSubcategory: Value(_legalSubcategory),
        sourceTemplateId: Value(_selectedTemplate?.id),
        creationMethod: Value(_creationMethod),
        status: Value(widget.archiveContext?.isClosed == true ? 'archived' : _contractStatus),
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

      // 2. إعداد الأطراف (عدة أشخاص لكل طرف)
      final parties = <ContractPartiesCompanion>[];
      for (var i = 0; i < _parties.length; i++) {
        final party = _parties[i];
        for (final person in party.persons) {
          parties.add(ContractPartiesCompanion.insert(
            contractId: 0,
            personId: person.personId!,
            partyRole: Value(party.role),
            partyCapacity: Value(person.capacity),
            poaId: Value(person.poaId),
            partyOrder: Value(i + 1),
          ));
        }
      }

      // 3. حفظ العقد
      final contractId = await repo.createContract(
        contract: contractCompanion,
        parties: parties,
        reminders: [],
        wordFile: _uploadedFile,
        userRef: userRef,
      );

      // 4. حفظ قيم المتغيرات (AI Learning Data)
      if (_detectedVariables.isNotEmpty) {
        final varValues = <String, String>{};
        for (final variable in _detectedVariables) {
          final controller = _variableControllers[variable.name];
          if (controller != null && controller.text.trim().isNotEmpty) {
            varValues[variable.name] = controller.text.trim();
          }
        }
        await varService.saveInstanceVariables(contractId, varValues, _variableFillMethods);

        // حفظ متغيرات القالب
        if (_selectedTemplate != null) {
          await varService.saveTemplateVariables(_selectedTemplate!.id, _detectedVariables);
        }
      }

      // 5. تسجيل الحفظ (AI Learning)
      await varService.logTemplateUsage(
        templateId: _selectedTemplate?.id,
        contractId: contractId,
        eventType: 'contract_created',
        eventData: {
          'creationMethod': _creationMethod,
          'legalCategory': _legalCategory,
          'legalSubcategory': _legalSubcategory,
          'partiesCount': _parties.length,
          'variablesCount': _detectedVariables.length,
          'autoFillCount': _variableFillMethods.values.where((m) => m == 'auto').length,
          'manualFillCount': _variableFillMethods.values.where((m) => m == 'manual').length,
        },
      );

      // 6. Audit log
      await ref.read(auditServiceProvider).log(
        action: 'create',
        category: 'contracts',
        entityType: 'contract',
        entityId: '$contractId',
        entityTitle: _titleController.text.trim(),
        description: 'إنشاء عقد جديد عبر الويزارد',
        after: {
          'title': _titleController.text.trim(),
          'category': _legalCategory,
          'subcategory': _legalSubcategory,
          'creationMethod': _creationMethod,
          'templateId': _selectedTemplate?.id,
          'partiesCount': _parties.length,
        },
        severity: 'info',
      );

      if (mounted) {
        ref.invalidate(allContractsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء العقد بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/contracts/$contractId');
      }
    } catch (e) {
      if (mounted) {
        _showError('خطأ أثناء حفظ العقد: $e');
        await ref.read(auditServiceProvider).log(
          action: 'error', category: 'contracts', entityType: 'contract',
          description: 'فشل إنشاء العقد: $e', severity: 'error',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

/// بيانات طرف واحد في العقد
class _PersonInParty {
  int? personId;
  String capacity;
  int? poaId;

  _PersonInParty({this.personId, this.capacity = 'أصيل', this.poaId});
}

class _PartyEntry {
  String role;
  final List<_PersonInParty> persons;

  _PartyEntry({required this.role, List<_PersonInParty>? persons})
      : persons = persons ?? [_PersonInParty()];
}
