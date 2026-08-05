/// معالج إنشاء دعوى قضائية جديدة
/// 
/// حسب مواصفات PRODUCT_REDESIGN_MASTER_PLAN.md - القسم 5
/// معالج من 8 خطوات إلزامية
/// 
/// آخر تحديث: 2026-07-09
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/court_catalog.dart';
import '../../../core/enums/app_enums.dart';

import '../../../data/database/database.dart' as db;
import '../../../data/services/conflict_of_interest_service.dart';
import '../../../data/services/poa_filter_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/archive_context_banner.dart';
import '../../widgets/common/court_selector.dart';
import '../../widgets/common/searchable_picker.dart';
import 'case_models.dart';

/// معالج إنشاء دعوى جديدة
class CreateCaseWizard extends ConsumerStatefulWidget {
  final ArchiveEntryContext? archiveContext;
  const CreateCaseWizard({super.key, this.archiveContext});

  @override
  ConsumerState<CreateCaseWizard> createState() => _CreateCaseWizardState();
}

class _CreateCaseWizardState extends ConsumerState<CreateCaseWizard> {
  int _currentStep = 0;
  
  // ===========================================================================
  // الخطوة 1: الموكل
  // ===========================================================================
  int? _selectedClientId;
  String _clientSearchQuery = '';
  final TextEditingController _clientSearchController = TextEditingController();
  
  // ===========================================================================
  // الخطوة 2: الوكالة
  // ===========================================================================
  int? _selectedPoaId;
  String _poaSearchQuery = '';
  final TextEditingController _poaSearchController = TextEditingController();
  
  // ===========================================================================
  // الخطوة 3: التصنيف
  // ===========================================================================
  CaseType _caseType = CaseType.civil;

  /// المحكمة المختارة كاملة: النوع والمحافظة والسجل والغرفة.
  ///
  /// كان الاختيار محافظةً وحدها، فتُحفظ الدعوى بلا درجة تقاضٍ
  /// ويستحيل معرفة مسار الطعن التالي.
  CourtSelection _court = const CourtSelection();

  /// معرّف سجل المحكمة، مشتق من الاختيار المركّب.
  int? get _selectedCourtId => _court.courtId;
  final TextEditingController _baseNumberController = TextEditingController();
  final TextEditingController _baseYearController = TextEditingController(
    text: DateTime.now().year.toString(),
  );
  bool _isUrgent = false;
  
  // ===========================================================================
  // الخطوة 4: البيانات الأساسية
  // ===========================================================================
  final TextEditingController _caseNumberController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  
  // ===========================================================================
  // الخطوة 5: الموضوع والطلبات
  // ===========================================================================
  final TextEditingController _claimController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  
  // ===========================================================================
  // الخطوة 6: الخصم
  // ===========================================================================
  int? _selectedOpponentId;
  String _opponentSearchQuery = '';
  final TextEditingController _opponentSearchController = TextEditingController();
  
  // ===========================================================================
  // الخطوة 7: المرفقات
  // ===========================================================================
  final List<String> _attachmentPaths = [];
  final List<TextEditingController> _attachmentControllers = [];
  
  // ===========================================================================
  // الخطوة 8: الموعد القادم (إلزامي - تولد نقصاً إذا ترك فارغاً)
  // ===========================================================================
  DateTime? _nextSessionDate;
  final TextEditingController _nextActionController = TextEditingController(
    text: 'مرافعة أولى / تقديم لائحة دعوى',
  );
  
  bool _isSaving = false;
  
  /// الدرجة القادمة من شاشة الأرشيف (صلح/بداية/استئناف/نقض).
  /// تُعرض للقراءة ولا يُعاد سؤال المستخدم عنها.
  String? _archiveCourtLevel;

  /// محافظة مستخرجة من الأرشيف بانتظار مطابقتها بمعرّف محكمة حقيقي.
  String? _pendingGovernorate;

  /// طلب المستخدم تعديل النوع رغم قدومه من الأرشيف.
  bool _overrideArchiveType = false;

  /// هل النوع والدرجة محدَّدان مسبقاً من شاشة الأرشيف؟
  bool get _cameFromArchive =>
      widget.archiveContext != null &&
      (widget.archiveContext!.caseType ?? '').isNotEmpty &&
      !_overrideArchiveType;

  /// معاينة الرقم الذي سيأخذه الملف عند الحفظ. الرقم النهائي يُولَّد
  /// داخل معاملة الحفظ عبر OfficeFileRepository لضمان عدم التكرار،
  /// وهذه معاينة للعرض فقط.
  bool _isGeneratingNumber = false;


  /// عرض الرقم المتوقع للدعوى اعتماداً على عدّاد ملفات المكتب.
  ///
  /// لا يستهلك رقماً من العدّاد؛ يقرأ آخر رقم ويضيف واحداً للعرض فقط،
  /// بينما يُحجز الرقم فعلياً داخل معاملة الحفظ.
  Future<void> _previewCaseNumber() async {
    setState(() => _isGeneratingNumber = true);
    try {
      final year = int.tryParse(_baseYearController.text.trim()) ??
          DateTime.now().year;
      final preview = await ref
          .read(officeFileRepositoryProvider)
          .peekNextFileNumber(OfficeFileType.caseFile, year);
      if (!mounted) return;
      _caseNumberController.text = preview;
    } catch (_) {
      if (!mounted) return;
      _caseNumberController.text = 'يُولَّد عند الحفظ';
    } finally {
      if (mounted) setState(() => _isGeneratingNumber = false);
    }
  }

  /// استخراج المحافظة من تسمية محكمة قديمة قد تحمل درجة وترتيباً.
  String? _governorateFrom(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    String norm(String x) => x
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final hay = norm(raw);
    if (RegExp(r'\bحما\b').hasMatch(hay) || hay.contains('حماه')) {
      return 'حماة';
    }
    if (hay.contains('ريف دمشق')) return 'ريف دمشق';
    for (final gov in AppConstants.syrianGovernorates) {
      if (hay.contains(norm(gov))) return gov;
    }
    return null;
  }

  /// حقل اختيار المحكمة الكامل: الدرجة ← النوع ← المحافظة ← الغرفة.
  ///
  /// كان الحقل يعرض المحافظات وحدها فتُحفظ الدعوى بلا درجة تقاضٍ.
  /// الاختيار الآن مركّب، ويُقصر على المحاكم التي تنظر نوع الدعوى
  /// المحدد في الخطوة نفسها.
  Widget _buildCourtAndChamberFields() {
    return CourtSelector(
      caseType: _caseType,
      value: _court,
      preferredGovernorate: _pendingGovernorate,
      onChanged: (selection) => setState(() => _court = selection),
    );
  }

  // دوال مساعدة للتحقق من صحة البيانات
  bool _isValidYear(String yearStr) {
    final year = int.tryParse(yearStr);
    if (year == null) return false;
    final currentYear = DateTime.now().year;
    return year >= 1900 && year <= currentYear + 5;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _previewCaseNumber());
    final archive = widget.archiveContext;
    if (archive != null) {
      final caseType = archive.caseType ?? '';
      if (caseType.contains('جزائ')) _caseType = CaseType.criminal;
      if (caseType.contains('تجار')) _caseType = CaseType.commercial;
      if (caseType.contains('شرع') || caseType.contains('احوال') || caseType.contains('شخصية')) _caseType = CaseType.personalStatus;
      if (caseType.contains('إدار') || caseType.contains('ادار')) _caseType = CaseType.administrative;
      if (caseType.contains('عقار')) _caseType = CaseType.realEstate;
      if (caseType.contains('عمال')) _caseType = CaseType.labor;
      // الدرجة اختارها المستخدم قبل فتح الويزارد، فتُحفظ ولا يُعاد سؤاله.
      _archiveCourtLevel = archive.courtLevel;
      // المحافظة تُطابَق بمعرّف المحكمة الحقيقي بعد تحميل القائمة.
      _pendingGovernorate = _governorateFrom(archive.courtLevel);
      // نوع المحكمة يُستنتج من الدرجة المختارة في شاشة الأرشيف،
      // فيبدأ الحقل المركّب من درجة صحيحة بدل أن يبدأ فارغاً.
      final inferredKind = CourtCatalog.inferKindFromText(
        degreeText: archive.courtLevel,
        caseTypeText: archive.caseType,
      );
      if (inferredKind != null) {
        _court = CourtSelection(kindId: inferredKind);
      }
      if (archive.isClosed) {
        _nextSessionDate = null;
        _nextActionController.text = 'ملف أرشيف منتهٍ - لا يوجد موعد قادم';
      }
    }
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    _poaSearchController.dispose();
    _baseNumberController.dispose();
    _baseYearController.dispose();
    _caseNumberController.dispose();
    _titleController.dispose();
    _subjectController.dispose();
    _claimController.dispose();
    _detailsController.dispose();
    _opponentSearchController.dispose();
    _nextActionController.dispose();
    for (final controller in _attachmentControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// إرجاع فهرس آخر خطوة في الويزارد
  /// الأرشيف المنتهي: 7 خطوات (بدون موعد قادم)
  /// الأرشيف الجاري أو الدعوى الجديدة: 8 خطوات (مع موعد قادم)
  int _getLastStepIndex() {
    return widget.archiveContext?.isClosed == true ? 6 : 7;
  }

  @override
  Widget build(BuildContext context) {
    final lastStep = _getLastStepIndex();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.archiveContext == null ? 'إنشاء دعوى جديدة' : (widget.archiveContext!.isRunning ? 'إدخال دعوى أرشيفية جارية' : 'أرشفة دعوى منتهية')),
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
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
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
            if (_currentStep < _getLastStepIndex())
              TextButton.icon(
                onPressed: _isSaving ? null : _nextStep,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('التالي'),
              ),
            if (_currentStep == _getLastStepIndex())
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitCase,
                icon: _isSaving 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnLight,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(widget.archiveContext == null ? 'إنشاء الدعوى' : (widget.archiveContext!.isRunning ? 'حفظ الدعوى الجارية' : 'حفظ الدعوى المنتهية')),
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
      color: AppColors.cardBackground,
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
              ? AppColors.success 
              : isCurrent 
                  ? AppColors.primaryNavy 
                  : AppColors.cardBorder,
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
      case 0: label = 'الموكل'; break;
      case 1: label = 'التصنيف'; break; // نقلت من الخطوة 3
      case 2: label = 'الوكالة'; break; // نقلت من الخطوة 2
      case 3: label = 'البيانات'; break;
      case 4: label = 'الطلبات'; break;
      case 5: label = 'الخصم'; break;
      case 6: label = 'المرفقات'; break;
      case 7: label = 'الموعد'; break;
      default: label = '';
    }
    
    return Expanded(
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: isCompleted 
              ? AppColors.success 
              : isCurrent 
                  ? AppColors.primaryNavy 
                  : AppColors.textSecondary,
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
        return _buildClientStep();
      case 1:
        return _buildClassificationStep(); // نقلت من الخطوة 3
      case 2:
        return _buildPoaStep(); // نقلت من الخطوة 2
      case 3:
        return _buildBasicDataStep();
      case 4:
        return _buildSubjectAndClaimsStep();
      case 5:
        return _buildOpponentStep();
      case 6:
        return _buildAttachmentsStep();
      case 7:
        return _buildNextSessionStep();
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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTextStyles.bodySmallSecondary,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // الخطوة 1: الموكل
  // ===========================================================================
  
  Widget _buildClientStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'اختر الموكل',
          description: 'يجب تحديد الموكل قبل المتابعة',
        ),
        const SizedBox(height: 24),
        
        // بحث عن موكل + إضافة موكل جديد في نفس موضع العمل
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _clientSearchController,
                decoration: InputDecoration(
                  labelText: 'بحث عن موكل',
                  hintText: 'ادخل اسم الموكل أو رقم هويته',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: _searchClients,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _showAddClientDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('إضافة موكل'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // قائمة الموكلين من قاعدة البيانات الحقيقية
        _buildClientList(),
        _buildConflictBanner(_selectedClientId, asClient: true),
      ],
    );
  }
  
  Widget _buildClientList() {
    final personsAsync = ref.watch(allPersonsProvider(null));

    return personsAsync.when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) => Text('تعذر تحميل الموكلين: $e', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
      data: (persons) {
        final query = _clientSearchQuery.trim().toLowerCase();
        final clients = persons.where((p) {
          if (query.isEmpty) return true;
          return p.fullName.toLowerCase().contains(query) ||
              (p.nationalId ?? '').toLowerCase().contains(query) ||
              (p.phone1 ?? '').toLowerCase().contains(query);
        }).toList();

        if (clients.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.cardBackground,
            ),
            child: Text(
              query.isEmpty
                  ? 'لا يوجد موكلون بعد — أضف أول موكل من الزر بجانب البحث.'
                  : 'لا يوجد موكل مطابق للبحث — يمكنك إضافته مباشرة من الزر بجانب البحث.',
              style: AppTextStyles.bodyMediumSecondary,
              textAlign: TextAlign.center,
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];
                final isSelected = _selectedClientId == client.id;
                final clientType = client.type == PersonType.legal.index ? 'جهة اعتبارية / شركة' : 'شخص طبيعي';

                return InkWell(
                  onTap: () => setState(() => _selectedClientId = client.id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryNavy.withOpacity(0.1) : AppColors.cardBackground,
                      border: Border.all(color: AppColors.cardBorder, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          client.type == PersonType.legal.index ? Icons.business : Icons.person,
                          color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client.fullName,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if ((client.phone1 ?? '').isNotEmpty || (client.nationalId ?? '').isNotEmpty)
                                Text(
                                  [client.phone1, client.nationalId].where((v) => (v ?? '').isNotEmpty).join(' • '),
                                  style: AppTextStyles.bodySmallSecondary,
                                ),
                            ],
                          ),
                        ),
                        Text(clientType, style: AppTextStyles.bodySmallSecondary),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
  
  void _searchClients(String query) {
    setState(() => _clientSearchQuery = query);
  }
  
  Future<void> _showAddClientDialog(BuildContext context) async {
    final id = await showDialog<int>(
      context: context,
      builder: (context) => const AddClientDialog(),
    );
    if (id != null && mounted) {
      ref.invalidate(allPersonsProvider(null));
      ref.invalidate(uiPersonsDirectoryProvider);
      setState(() => _selectedClientId = id);
    }
  }

  // ===========================================================================
  // الخطوة 2: الوكالة
  // ===========================================================================
  
  Widget _buildPoaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'اختر الوكالة',
          description: 'يجب ربط الدعوى بوكالة صالحة',
        ),
        const SizedBox(height: 24),
        
        // بحث عن وكالة
        TextField(
          controller: _poaSearchController,
          decoration: InputDecoration(
            labelText: 'بحث عن وكالة',
            hintText: 'ادخل رقم الوكالة أو اسم الموكل',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) => _searchPoas(value),
        ),
        const SizedBox(height: 16),
        
        // قائمة الوكالات
        _buildPoaList(),
        
        // أو إضافة وكالة جديدة
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _showAddPoaDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('إضافة وكالة جديدة'),
        ),
        
        // أو تأجيل اختيار الوكالة
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showPostponePoaDialog(context),
          icon: const Icon(Icons.warning),
          label: const Text('تأجيل اختيار الوكالة'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.warning,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPoaList() {
    // الوكالات المفلترة حسب الموكل ونوع الدعوى
    if (_selectedClientId == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.cardBackground,
        ),
        child: Text(
          'يرجى اختيار الموكل أولاً من الخطوة السابقة.',
          style: AppTextStyles.bodyMediumSecondary,
          textAlign: TextAlign.center,
        ),
      );
    }

    final filteredPoasAsync = ref.watch(filteredPoasProvider((
      principalId: _selectedClientId,
      caseType: _caseType.index,
    )));

    return filteredPoasAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'تعذر تحميل الوكالات: $e',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
      ),
      data: (results) {
        // تصفية الوكالات حسب البحث
        final query = _poaSearchQuery.trim().toLowerCase();
        final filteredResults = results.where((result) {
          if (query.isEmpty) return true;
          final poa = result.poa;
          return (poa.poaNumber ?? '').toLowerCase().contains(query) ||
              (poa.subType ?? '').toLowerCase().contains(query);
        }).toList();

        if (filteredResults.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.cardBackground,
            ),
            child: Text(
              query.isEmpty
                  ? 'لا توجد وكالات مسجلة لهذا الموكل — أضف وكالة جديدة.'
                  : 'لا توجد وكالات مطابقة للبحث — أضف وكالة جديدة.',
              style: AppTextStyles.bodyMediumSecondary,
              textAlign: TextAlign.center,
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredResults.length,
            itemBuilder: (context, index) {
              final result = filteredResults[index];
              final poa = result.poa;
              final isSelected = _selectedPoaId == poa.id;
              final isGeneral = poa.poaType == 0; // عامة
              final isValid = result.isValid;

              return InkWell(
                onTap: isValid || result.canOverride
                    ? () => setState(() => _selectedPoaId = poa.id)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryNavy.withOpacity(0.1)
                        : AppColors.cardBackground,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryNavy
                          : (isValid
                              ? AppColors.cardBorder
                              : AppColors.warning),
                      width: isSelected ? 2 : 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user,
                            color: isSelected
                                ? AppColors.primaryNavy
                                : (isValid
                                    ? AppColors.success
                                    : AppColors.warning),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  poa.poaNumber ?? 'وكالة #${poa.id}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // شارة نوع الوكالة
                                _buildPoaTypeBadge(poa, isGeneral),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                poa.poaDate != null
                                    ? '${poa.poaDate!.year}-${poa.poaDate!.month.toString().padLeft(2, '0')}-${poa.poaDate!.day.toString().padLeft(2, '0')}'
                                    : 'غير محدد',
                                style: AppTextStyles.bodySmallSecondary,
                              ),
                              const SizedBox(height: 4),
                              // زر فتح تفاصيل الوكالة
                              InkWell(
                                onTap: () => _openPoaDetails(poa.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.info.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.open_in_new, size: 14, color: AppColors.info),
                                      const SizedBox(width: 4),
                                      Text(
                                        'فتح',
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 4),
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      // تحذير إذا كانت الوكالة غير صالحة
                      if (!isValid && result.reason != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: AppColors.warning,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  result.reason!,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (result.canOverride) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => setState(() => _selectedPoaId = poa.id),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.warning,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('تجاوز التحذير'),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// شارة نوع الوكالة (عامة/خاصة)
  Widget _buildPoaTypeBadge(db.PowersOfAttorneyData poa, bool isGeneral) {
    if (isGeneral) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'عامة - صالحة لكل الدعاوى',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'خاصة - ${poa.subType ?? 'غير محدد'}',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
        ),
      );
    }
  }
  
  void _searchPoas(String query) {
    setState(() => _poaSearchQuery = query);
  }

  /// فتح شاشة تفاصيل الوكالة للمراجعة
  void _openPoaDetails(int poaId) {
    context.push('/poa/$poaId');
  }

  void _searchOpponents(String query) {
    setState(() => _opponentSearchQuery = query);
  }
  
  void _showAddPoaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddPoaDialog(),
    );
  }
  
  void _showPostponePoaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأجيل اختيار الوكالة'),
        content: const Text('سيتم إنشاء الدعوى بدون وكالة، ويمكن إضافة الوكالة لاحقاً. سيتم إنشاء نقص تلقائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _selectedPoaId = null);
            },
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // الخطوة 3: التصنيف
  // ===========================================================================
  
  Widget _buildClassificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'تصنيف الدعوى',
          description: _cameFromArchive
              ? 'النوع والدرجة محدَّدان مسبقاً — حدد المحافظة والغرفة'
              : 'حدد نوع الدعوى والمحكمة',
        ),
        const SizedBox(height: 24),

        // النوع والدرجة: إن جاءا من شاشة الأرشيف فلا يُعاد سؤال
        // المستخدم عنهما، إنما يُعرضان للقراءة مع إمكانية التعديل.
        if (_cameFromArchive) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 18, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نوع الدعوى: ${_caseType.displayName}',
                          style: AppTextStyles.labelMedium),
                      if ((_archiveCourtLevel ?? '').isNotEmpty)
                        Text('الدرجة: $_archiveCourtLevel',
                            style: AppTextStyles.bodySmallSecondary),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _overrideArchiveType = true),
                  child: const Text('تغيير'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // يظهر عند الإنشاء العادي أو عند طلب التغيير صراحةً.
        if (!_cameFromArchive) ...[
          DropdownButtonFormField<CaseType>(
            value: _caseType,
            items: CaseType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.displayName),
              );
            }).toList(),
            onChanged: (value) => setState(() => _caseType = value!),
            decoration: InputDecoration(
              labelText: 'نوع الدعوى',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        

        // المحكمة والغرفة
        _buildCourtAndChamberFields(),
        const SizedBox(height: 16),
        
        // رقم الأساس وسنة الأساس
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _baseNumberController,
                decoration: InputDecoration(
                  labelText: 'رقم الأساس',
                  hintText: 'مثال: 12345',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: _baseNumberController.text.isNotEmpty && int.tryParse(_baseNumberController.text.trim()) == null ? 'يرجى إدخال رقم صالح' : null,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _baseYearController,
                decoration: InputDecoration(
                  labelText: 'سنة الأساس',
                  hintText: 'مثال: 2026',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: _baseYearController.text.isNotEmpty && !_isValidYear(_baseYearController.text.trim()) ? 'يرجى إدخال سنة صالحة (1900-2030)' : null,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // مستعجلة
        CheckboxListTile(
          title: const Text('دعوى مستعجلة'),
          value: _isUrgent,
          onChanged: (value) => setState(() => _isUrgent = value!),
          contentPadding: EdgeInsets.zero,
          dense: true,
          secondary: const Icon(Icons.priority_high, color: AppColors.error),
        ),
      ],
    );
  }

  // ===========================================================================
  // الخطوة 4: البيانات الأساسية
  // ===========================================================================
  
  Widget _buildBasicDataStep() {
    final activeCount = ref.watch(activeCasesCountProvider);
    final closedCount = ref.watch(closedCasesCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'البيانات الأساسية',
          description: 'رقم الدعوى يُولَّد تلقائياً، وأدخل موضوع الدعوى',
        ),
        const SizedBox(height: 24),

        // رقم الدعوى: يُولَّد من عدّاد المكتب ولا يُحرَّر يدوياً
        TextField(
          controller: _caseNumberController,
          readOnly: true,
          enabled: false,
          style: AppTextStyles.numberText,
          decoration: InputDecoration(
            labelText: 'رقم الدعوى (تلقائي)',
            prefixIcon: const Icon(Icons.tag),
            suffixIcon: _isGeneratingNumber
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            filled: true,
            fillColor: AppColors.cardBorder.withValues(alpha: 0.15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.info.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'هذا الرقم هو تسلسل الدعوى ضمن دعاوى المكتب، ويشمل ما '
                  'أُدخل من الأرشيف الجاري وما يُضاف لاحقاً. '
                  'حالياً: ${activeCount.valueOrNull ?? 0} جارية • '
                  '${closedCount.valueOrNull ?? 0} منتهية.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // موضوع الدعوى: حقل واحد بدل العنوان والموضوع المكرّرين
        TextField(
          controller: _subjectController,
          decoration: InputDecoration(
            labelText: 'موضوع الدعوى',
            hintText: 'مثال: تعويض عن ضرر مادي',
            prefixIcon: const Icon(Icons.gavel),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 2,
          onChanged: (v) {
            // العنوان مشتق من الموضوع للحفاظ على توافق السجلات القديمة.
            _titleController.text = v;
            setState(() {});
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // الخطوة 5: الموضوع والطلبات
  // ===========================================================================
  
  Widget _buildSubjectAndClaimsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'الموضوع والطلبات',
          description: 'ادخل تفاصيل الدعوى وطلباتك',
        ),
        const SizedBox(height: 24),
        
        // الطلب
        TextField(
          controller: _claimController,
          decoration: InputDecoration(
            labelText: 'الطلب',
            hintText: 'مثال: مبلغ 10,000,000 ل.س كتعويض عن الأضرار',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        
        // التفاصيل
        TextField(
          controller: _detailsController,
          decoration: InputDecoration(
            labelText: 'التفاصيل',
            hintText: 'ادخل تفاصيل إضافية عن الدعوى',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 5,
        ),
      ],
    );
  }

  // ===========================================================================
  // الخطوة 6: الخصم
  // ===========================================================================
  
  Widget _buildOpponentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'اختر الخصم',
          description: 'يجب تحديد الخصم أو الخصوم',
        ),
        const SizedBox(height: 24),
        
        // البحث وزر الإضافة جنباً إلى جنب: إن لم يجد المستخدم الخصم
        // فالإجراء التالي الطبيعي هو إضافته فوراً لا البحث عن الزر.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _opponentSearchController,
                decoration: InputDecoration(
                  labelText: 'بحث عن خصم',
                  hintText: 'ادخل اسم الخصم أو رقم هويته',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) => _searchOpponents(value),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _showAddOpponentDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('إضافة خصم'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // قائمة الخصوم
        _buildOpponentList(),
        _buildConflictBanner(_selectedOpponentId, asClient: false),
      ],
    );
  }
  
  /// بانر تعارض المصالح — تنبيه لا منع، حسب المرحلة العاشرة من الخارطة.
  Widget _buildConflictBanner(int? personId, {required bool asClient}) {
    if (personId == null || personId <= 0) return const SizedBox.shrink();
    final warnings = ref.watch(conflictWarningsProvider((personId: personId, asClient: asClient)));
    return warnings.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final hasHigh = items.any((w) => w.severity == ConflictSeverity.high);
        final color = hasHigh ? AppColors.error : AppColors.warning;
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.gpp_maybe, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('تنبيه تعارض مصالح',
                      style: AppTextStyles.labelLarge.copyWith(color: color, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 8),
              ...items.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ${w.title}', style: AppTextStyles.bodyMedium),
                        Text(w.detail, style: AppTextStyles.bodySmallSecondary),
                        if (w.relatedFiles.isNotEmpty)
                          Text('الملفات: ${w.relatedFiles.take(5).join('، ')}',
                              style: AppTextStyles.bodySmallSecondary),
                      ],
                    ),
                  )),
              Text('يمكنك المتابعة، لكن راجع الوضع القانوني أولاً.',
                  style: AppTextStyles.bodySmallSecondary.copyWith(fontStyle: FontStyle.italic)),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildOpponentList() {
    // الخصوم أشخاص حقيقيون من الدليل المركزي. القائمة الثابتة السابقة كانت
    // تحفظ معرّفات (1..4) قد تقابل أشخاصاً مختلفين تماماً في قاعدة البيانات.
    final personsAsync = ref.watch(allPersonsProvider(null));
    final opponents = personsAsync.maybeWhen(
      // استبعاد موكّل الدعوى نفسه: لا يصحّ أن يكون المرء خصم نفسه،
      // وظهوره في القائمة يفتح باب خطأ إدخال يصعب تداركه لاحقاً.
      data: (persons) => persons
          .where((p) => p.id != _selectedClientId)
          .map((p) => {
                'id': p.id,
                'name': p.fullName,
                'type': p.type == PersonType.legal.index ? 'شخص اعتباري' : 'شخص طبيعي',
              })
          .toList(),
      orElse: () => const <Map<String, Object?>>[],
    );

    if (personsAsync.isLoading) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    
    // تصفية الخصوم حسب البحث
    final query = _opponentSearchQuery.trim().toLowerCase();
    final filteredOpponents = opponents.where((opponent) {
      if (query.isEmpty) return true;
      return (opponent['name'] as String).toLowerCase().contains(query) ||
             (opponent['type'] as String).toLowerCase().contains(query);
    }).toList();
    
    if (filteredOpponents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.cardBackground,
        ),
        child: Text(
          query.isEmpty
              ? 'لا يوجد أشخاص في الدليل بعد — أضف الخصم من شاشة الأشخاص أولاً.'
              : 'لا يوجد أشخاص مطابقين للبحث — أضف الخصم من شاشة الأشخاص أولاً.',
          style: AppTextStyles.bodyMediumSecondary,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredOpponents.length,
        itemBuilder: (context, index) {
          final opponent = filteredOpponents[index];
          final isSelected = _selectedOpponentId == opponent['id'];
          
          return InkWell(
            onTap: () => setState(() => _selectedOpponentId = opponent['id'] as int?),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryNavy.withOpacity(0.1) : AppColors.cardBackground,
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_off,
                    color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                opponent['name'] as String,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            // TODO: إضافة إشارة "موكل أيضاً" بعد إنشاء provider لجلب أدوار الشخص
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    opponent['type'] as String,
                    style: AppTextStyles.bodySmallSecondary,
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// عرض تحذير تعارض الأدوار (شخص هو موكل وخصم في نفس الوقت)
  void _showClientConflictWarning(int personId, String personName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('تعارض أدوار'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الشخص "$personName" هو موكل في دعاوى أخرى.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'هل أنت متأكد من إضافته كخصم في هذه الدعوى؟',
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '⚠️ تحذير: قد يؤدي هذا إلى تعارض في المصالح أو مشاكل قانونية.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _selectedOpponentId = personId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('متابعة على أي حال'),
          ),
        ],
      ),
    );
  }
  
  void _showAddOpponentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddOpponentDialog(),
    );
  }

  // ===========================================================================
  // الخطوة 7: المرفقات
  // ===========================================================================
  
  Widget _buildAttachmentsStep() {
    final expectedDocs = _defaultDocumentsFor(widget.archiveContext?.status ?? 'running');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'المرفقات',
          description: 'اختر نوع الوثيقة ثم ارفع الملف المقابل',
        ),
        const SizedBox(height: 24),
        
        // الوثائق المتوقعة
        if (expectedDocs.isNotEmpty) ...[
          Text(
            'الوثائق المتوقعة لهذه الدعوى:',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: expectedDocs.map((doc) => Chip(
                label: Text(doc),
                avatar: const Icon(Icons.description, size: 16),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // قائمة المرفقات
        if (_attachmentPaths.isNotEmpty) ...[
          Text(
            'المرفقات المرفوعة:',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attachmentPaths.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => _openPickedAttachment(index),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AppColors.cardBorder, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _attachmentControllers[index].text.isNotEmpty
                                    ? _attachmentControllers[index].text
                                    : _attachmentPaths[index]
                                        .split(Platform.pathSeparator)
                                        .last,
                                style: AppTextStyles.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text('اضغط للفتح والتحقق',
                                  style: AppTextStyles.bodySmallSecondary),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'فتح',
                          icon: const Icon(Icons.open_in_new,
                              color: AppColors.primaryNavy),
                          onPressed: () => _openPickedAttachment(index),
                        ),
                        IconButton(
                          tooltip: 'حذف',
                          icon:
                              const Icon(Icons.delete, color: AppColors.error),
                          onPressed: () => _removeAttachment(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // زر إضافة مرفق مع اختيار النوع
        ElevatedButton.icon(
          onPressed: () => _addAttachmentWithDocType(expectedDocs),
          icon: const Icon(Icons.attach_file),
          label: const Text('إضافة مرفق'),
        ),
        const SizedBox(height: 8),
        Text(
          'يمكنك إضافة المرفقات لاحقاً من شاشة تفاصيل الدعوى',
          style: AppTextStyles.bodySmallSecondary,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Future<void> _addAttachment() async {
    // اختيار ملفات حقيقية من القرص. سابقاً كانت تُضاف أسماء وهمية
    // (مستند_1.pdf) بلا ملف فعلي، فتضيع المرفقات بصمت عند الحفظ.
    final result = await file_picker.FilePicker.pickFiles(
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
  
  /// الوثائق المتوقعة بناءً على نوع الدعوى وحالتها
  List<String> _defaultDocumentsFor(String status) {
    final docs = <String>[];
    
    // وثائق مشتركة لجميع الدعاوى
    docs.addAll([
      'استدعاء الدعوى',
      'الوكالة',
      'هوية الموكل',
      'إيصال رسوم قضائية',
    ]);
    
    // وثائق حسب نوع الدعوى
    switch (_caseType) {
      case CaseType.civil:
        docs.addAll(['عقد', 'فواتير', 'مراسلات']);
        break;
      case CaseType.criminal:
        docs.addAll(['محضر شرطة', 'تقرير طبي', 'شهادات شهود']);
        break;
      case CaseType.personalStatus:
        docs.addAll(['قيد عائلي', 'عقد زواج', 'شهادة ميلاد']);
        break;
      case CaseType.commercial:
        docs.addAll(['سجل تجاري', 'عقد شركة', 'فواتير تجارية']);
        break;
      case CaseType.labor:
        docs.addAll(['عقد عمل', 'كشف رواتب', 'إنذار']);
        break;
      case CaseType.realEstate:
        docs.addAll(['سند ملكية', 'مخطط عقاري', 'بيان مساحة']);
        break;
      case CaseType.administrative:
        docs.addAll(['قرار إداري', 'مراسلات رسمية', 'طلب خطي']);
        break;
      case CaseType.constitutional:
        docs.addAll(['طعن دستوري', 'نصوص قانونية', 'سوابق قضائية']);
        break;
      case CaseType.other:
        docs.addAll(['مستندات إضافية']);
        break;
    }
    
    return docs;
  }
  
  /// إضافة مرفق مع اختيار نوع الوثيقة أولاً
  Future<void> _addAttachmentWithDocType(List<String> expectedDocs) async {
    // اختيار نوع الوثيقة
    String? selectedDocType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر نوع الوثيقة'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الوثائق المتوقعة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expectedDocs.map((doc) => ActionChip(
                    label: Text(doc),
                    onPressed: () => Navigator.pop(context, doc),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'أو أدخل اسم وثيقة مخصص:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'اسم الوثيقة',
                    hintText: 'مثال: تقرير خبير',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      Navigator.pop(context, value.trim());
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    
    if (selectedDocType == null || selectedDocType.isEmpty) return;
    
    // اختيار الملف
    final result = await file_picker.FilePicker.pickFiles(
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
        // استخدام اسم الوثيقة المختار كـ label
        final label = picked.length == 1 
            ? selectedDocType 
            : '$selectedDocType (${file.name})';
        _attachmentControllers.add(TextEditingController(text: label));
      }
    });
  }
  
  /// فتح مرفق مختار قبل الحفظ.
  ///
  /// الملف ما يزال في مساره الأصلي على القرص ولم يُشفَّر بعد، فيُفتح
  /// مباشرة لا عبر مسار المخزن المشفّر.
  Future<void> _openPickedAttachment(int index) async {
    if (index < 0 || index >= _attachmentPaths.length) return;
    final result = await ref
        .read(attachmentServiceProvider)
        .openLocalFile(_attachmentPaths[index]);
    if (!mounted || result.success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'تعذّر فتح الملف'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachmentPaths.removeAt(index);
      _attachmentControllers[index].dispose();
      _attachmentControllers.removeAt(index);
    });
  }

  // ===========================================================================
  // الخطوة 8: الموعد القادم (إلزامي)
  // ===========================================================================
  
  Widget _buildNextSessionStep() {
    if (widget.archiveContext?.isClosed == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(
            title: 'أثر الأرشيف المنتهي',
            description: 'هذا الملف محفوظ للأرشيف والبحث فقط، لذلك لن يتم تسجيل موعد قادم أو توليد مهمة في مكتب العمل.',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryNavy.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, color: AppColors.primaryNavy),
                const SizedBox(width: 10),
                Expanded(child: Text('لن يظهر هذا الملف ضمن اليوم أو الغد أو التقويم إلا إذا حُوّل لاحقاً إلى ملف جارٍ.', style: AppTextStyles.bodyMediumSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nextActionController,
            decoration: InputDecoration(
              labelText: 'ملاحظة أرشيفية اختيارية',
              hintText: 'مثال: الملف منتهٍ بحكم مبرم / محفوظ ورقياً',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'الموعد القادم',
          description: '⚠️ يجب تحديد موعد الجلسة القادمة. إذا تركت هذا الحقل فارغاً، سيتم إنشاء نقص تلقائياً.',
        ),
        const SizedBox(height: 24),
        
        // تاريخ الجلسة
        Row(
          children: [
            Expanded(
              child: Text(
                _nextSessionDate == null
                    ? 'لم يتم تحديد تاريخ'
                    : '${_nextSessionDate!.year}-${_nextSessionDate!.month.toString().padLeft(2, '0')}-${_nextSessionDate!.day.toString().padLeft(2, '0')}',
                style: AppTextStyles.bodyLarge,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _selectDate(context),
              icon: const Icon(Icons.calendar_today),
              label: const Text('اختر التاريخ'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // الوقت
        Row(
          children: [
            Expanded(
              child: Text(
                _nextSessionDate == null
                    ? 'لم يتم تحديد وقت'
                    : '${_nextSessionDate!.hour.toString().padLeft(2, '0')}:${_nextSessionDate!.minute.toString().padLeft(2, '0')}',
                style: AppTextStyles.bodyLarge,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _selectTime(context),
              icon: const Icon(Icons.access_time),
              label: const Text('اختر الوقت'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // الإجراء المطلوب
        TextField(
          controller: _nextActionController,
          decoration: InputDecoration(
            labelText: 'الإجراء المطلوب',
            hintText: 'مثال: مرافعة أولى، تقديم لائحة دعوى، إثبات',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // تنبيه
        if (_nextSessionDate == null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              border: Border.all(color: AppColors.warning, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سيتم إنشاء نقص تلقائياً إذا لم يتم تحديد موعد الجلسة القادمة',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextSessionDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SY'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryNavy,
              onPrimary: AppColors.textOnLight,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _nextSessionDate = picked);
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    if (_nextSessionDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى تحديد التاريخ أولاً'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextSessionDate!),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryNavy,
              onPrimary: AppColors.textOnLight,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _nextSessionDate = DateTime(
          _nextSessionDate!.year,
          _nextSessionDate!.month,
          _nextSessionDate!.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  // ===========================================================================
  // التنقل بين الخطوات
  // ===========================================================================
  
  void _nextStep() {
    // التحقق من الخطوات الإلزامية
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
      case 0: // الموكل
        if (_selectedClientId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى اختيار الموكل'),
              backgroundColor: AppColors.error,
            ),
          );
          return false;
        }
        break;
      case 1: // التصنيف (نقلت من الخطوة 3)
        if (_selectedCourtId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى اختيار المحكمة'),
              backgroundColor: AppColors.error,
            ),
          );
          return false;
        }
        break;
      case 2: // الوكالة (نقلت من الخطوة 2)
        // الوكالة اختيارية - يمكن تأجيلها
        break;
      case 3: // البيانات الأساسية
        // العنوان والموضوع صارا حقلاً واحداً؛ التحقق على الموضوع.
        if (_subjectController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى إدخال موضوع الدعوى'),
              backgroundColor: AppColors.error,
            ),
          );
          return false;
        }
        break;
      case 5: // الخصم
        if (_selectedOpponentId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى اختيار الخصم'),
              backgroundColor: AppColors.error,
            ),
          );
          return false;
        }
        break;
      case 7: // الموعد القادم (فقط للأرشيف الجاري والدعاوى الجديدة)
        if (widget.archiveContext?.isClosed == true) {
          return true;
        }
        // الأرشيف الجاري: دعوى قديمة مستوردة قد لا يكون لها موعد محدد بعد،
        // فلا يُحبس الحفظ. يُسجَّل نقص «موعد الجلسة» تلقائياً لاحقاً.
        if (widget.archiveContext?.isRunning == true && _nextSessionDate == null) {
          return true;
        }
        if (_nextSessionDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى تحديد موعد الجلسة القادمة'),
              backgroundColor: AppColors.error,
            ),
          );
          return false;
        }
        break;
    }
    
    return true;
  }

  // ===========================================================================
  // تقديم الدعوى (مرتبط بـ CaseRepository حقيقي)
  // ===========================================================================
  
  Future<void> _submitCase() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.casesCreateNew)) {
      await ref.read(auditServiceProvider).log(
            action: 'access_denied',
            category: 'cases',
            entityType: 'case',
            description: 'محاولة إنشاء دعوى دون صلاحية',
            severity: 'warning',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('لا تملك صلاحية إنشاء دعوى'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    if (!_validateCurrentStep()) {
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      // التحقق من عدم تكرار الدعوى (رقم الأساس + السنة)
      final casesAsync = ref.read(allCasesProvider);
      final cases = casesAsync.value ?? [];
      final baseNumber = _baseNumberController.text.trim();
      final year = int.tryParse(_baseYearController.text.trim()) ?? DateTime.now().year;
      
      // منع التكرار فقط إذا كان رقم الأساس غير فارغ
      if (baseNumber.isNotEmpty) {
        final isDuplicate = cases.any((existingCase) => 
          (existingCase.baseNumber?.trim() ?? '') == baseNumber &&
          (existingCase.year ?? 0) == year
        );

        if (isDuplicate) {
          setState(() => _isSaving = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('دعوى برقم الأساس $baseNumber لسنة $year موجودة مسبقاً!'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }
      
      // التحقق من صحة الوكالة إذا تم اختيارها
      if (_selectedPoaId != null) {
        final poasAsync = ref.read(allPoasProvider);
        final poas = poasAsync.value ?? [];
        final poa = poas.where((p) => p.id == _selectedPoaId).firstOrNull;
        
        if (poa == null) {
          setState(() => _isSaving = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الوكالة المختارة غير موجودة'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
        
        // التحقق من حالة الوكالة
        if (poa.status != PoaStatus.active.dbValue) {
          setState(() => _isSaving = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الوكالة المختارة غير نشطة، يرجى اختيار وكالة نشطة'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
        
        // التحقق من صلاحية الوكالة
        if (poa.expiryDate != null && poa.expiryDate!.isBefore(DateTime.now())) {
          setState(() => _isSaving = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الوكالة المختارة منتهية الصلاحية'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
        
        // التحقق من أن الوكالة تخص الموكل المختار
        // ملاحظة: في نظام الوكالات الحالي، نتحقق من وجود الوكالة فقط
        // التحقق من الربط بالموكل يمكن إضافته لاحقاً
        // if (poa.notaryId != _selectedClientId) {
        //   setState(() => _isSaving = false);
        //   if (mounted) {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       const SnackBar(
        //         content: Text('الوكالة المختارة لا تخص الموكل المحدد'),
        //         backgroundColor: AppColors.error,
        //       ),
        //     );
        //   }
        //   return;
        // }
      }
      
      final caseRepo = ref.read(caseRepositoryProvider);
      
      // إعداد بيانات الدعوى
      final caseData = db.CasesCompanion.insert(
        internalNumber: 'TMP',
        year: int.tryParse(_baseYearController.text) ?? DateTime.now().year,
        caseType: _caseType.toString().split('.').last,
        // الدرجة تُشتق من المحكمة المختارة، فهي مصدرها الصحيح.
        // نص الأرشيف يُستعمل بديلاً حين لا تُختار محكمة.
        subType: Value(_court.kind?.label ??
            (_archiveCourtLevel?.trim().isNotEmpty == true
                ? _archiveCourtLevel!.trim()
                : _caseType.displayName)),
        status: Value(widget.archiveContext?.isClosed == true ? 'closed' : 'registered'),
        courtId: Value(_selectedCourtId),
        // نوع المحكمة والغرفة يُحفظان صراحةً: المحافظة وحدها في
        // courtId لا تكفي لمعرفة الدرجة ولا مسار الطعن التالي.
        courtKind: Value(_court.kindId),
        chamberNumber: Value(_court.chamberNumber),
        baseNumber: Value(_baseNumberController.text.isNotEmpty ? _baseNumberController.text : null),
        subject: Value(_subjectController.text.isNotEmpty ? _subjectController.text : _titleController.text),
        subjectDetails: Value(_detailsController.text),
        notes: Value(widget.archiveContext == null
            ? null
            : [
                'سياق الأرشيف: ${widget.archiveContext!.summary}',
                'الحالة: ${widget.archiveContext!.statusLabel}',
                if (widget.archiveContext!.isClosed && _nextActionController.text.trim().isNotEmpty) 'ملاحظة أرشيفية: ${_nextActionController.text.trim()}',
              ].join('\n')),
        nextSessionDate: const Value(null),
        isUrgent: Value(_isUrgent),
      );
      
      // استدعاء المستودع الحقيقي
      final caseId = await caseRepo.createCase(
        caseData: caseData,
        clientId: _selectedClientId!,
        opponentId: _selectedOpponentId,
        poaId: _selectedPoaId,
        userRef: ref.read(authControllerProvider).user?.fullName ?? 'المستخدم',
      );
      // حفظ المرفقات فعلياً وربطها بالدعوى بعد إنشائها.
      if (_attachmentPaths.isNotEmpty) {
        final docRepo = ref.read(documentRepositoryProvider);
        final userRef = ref.read(authControllerProvider).user?.fullName ?? 'المستخدم';
        for (var i = 0; i < _attachmentPaths.length; i++) {
          final path = _attachmentPaths[i];
          final file = File(path);
          if (!file.existsSync()) continue;
          final label = _attachmentControllers[i].text.trim();
          await docRepo.addDocument(
            docName: label.isEmpty ? path.split(Platform.pathSeparator).last : label,
            docType: 'case_document',
            fileType: path.contains('.') ? path.split('.').last.toLowerCase() : null,
            summary: 'مرفق مرفوع عند إنشاء الدعوى',
            sourceFile: file,
            entityType: EntityType.caseEntity.index,
            entityId: caseId,
            userRef: userRef,
          );
        }
      }

      await ref.read(auditServiceProvider).log(
        action: 'create',
        category: 'cases',
        entityType: 'case',
        entityId: '$caseId',
        entityTitle: _titleController.text.trim(),
        description: 'إنشاء دعوى جديدة',
        after: {
          'title': _titleController.text.trim(),
          'caseType': _caseType.displayName,
          'clientId': _selectedClientId,
          'opponentId': _selectedOpponentId,
          if (widget.archiveContext != null) 'archive': widget.archiveContext!.summary,
          if (widget.archiveContext != null) 'archiveStatus': widget.archiveContext!.status,
        },
        severity: 'info',
      );
      
      setState(() => _isSaving = false);
      
      if (mounted) {
        context.go('/cases/$caseId');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء الدعوى بنجاح برقم داخلي: $caseId'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      
      String errorMessage;
      if (e.toString().contains('UNIQUE constraint')) {
        errorMessage = 'رقم الملف موجود مسبقاً';
      } else if (e.toString().contains('FOREIGN KEY')) {
        errorMessage = 'مرجع غير صالح (الموكل أو الخصم)';
      } else if (e.toString().contains('NOT NULL')) {
        errorMessage = 'حقل إلزامي فارغ';
      } else {
        errorMessage = 'حدث خطأ أثناء إنشاء الدعوى';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
      
      // تسجيل الخطأ التفصيلي
      await ref.read(auditServiceProvider).log(
        action: 'error',
        category: 'cases',
        entityType: 'case',
        description: 'فشل إنشاء الدعوى: $e',
        severity: 'error',
      );
    }
  }
}

// ===========================================================================
// حوارات إضافة سريعة
// ===========================================================================

class AddClientDialog extends ConsumerStatefulWidget {
  const AddClientDialog({super.key});

  @override
  ConsumerState<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends ConsumerState<AddClientDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _clientType = 'شخص طبيعي';

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'إضافة موكل جديد',
              style: AppTextStyles.headline4.copyWith(
                color: AppColors.primaryNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'الاسم الكامل',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                labelText: 'رقم الهوية',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _clientType,
              items: const [
                DropdownMenuItem(value: 'شخص طبيعي', child: Text('شخص طبيعي')),
                DropdownMenuItem(value: 'شركة', child: Text('شركة')),
                DropdownMenuItem(value: 'مؤسسة', child: Text('مؤسسة')),
              ],
              onChanged: (value) => setState(() => _clientType = value!),
              decoration: InputDecoration(
                labelText: 'نوع الموكل',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saving ? null : _submitClient,
                  child: Text(_saving ? 'جارٍ الإضافة...' : 'إضافة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  bool _saving = false;
  Future<void> _submitClient() async {
    if (_nameController.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final personId = await ref.read(personRepositoryProvider).createPerson(
        person: db.PersonsCompanion.insert(
          fullName: _nameController.text.trim(),
          type: Value(_clientType == 'شخص طبيعي' ? PersonType.natural.index : PersonType.legal.index),
          nationalId: Value(_idController.text.trim().isEmpty ? null : _idController.text.trim()),
          phone1: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
          whatsapp: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
        ),
        initialRoles: [PersonRoleType.client],
      );
      ref.invalidate(allPersonsProvider(null));
      ref.invalidate(uiPersonsDirectoryProvider);
      if (mounted) {
        Navigator.of(context).pop(personId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إضافة الموكل: ${_nameController.text}'), backgroundColor: AppColors.success));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

}

class AddPoaDialog extends ConsumerStatefulWidget {
  const AddPoaDialog({super.key});

  @override
  ConsumerState<AddPoaDialog> createState() => _AddPoaDialogState();
}

/// حوار إضافة وكالة وفق البندين 3 و7 من خطة ملف الوكالة:
/// النوع الرئيسي ثم التصنيف الفرعي، ثم رقم السجل والرقم الأبيض،
/// ثم فرع النقابة والمندوب للوكالة القضائية، ثم تاريخ التنظيم.
class _AddPoaDialogState extends ConsumerState<AddPoaDialog> {
  final TextEditingController _registryNumberController = TextEditingController();
  final TextEditingController _whiteNumberController = TextEditingController();
  final TextEditingController _delegateNameController = TextEditingController();
  final TextEditingController _delegatePhoneController = TextEditingController();

  int? _selectedClientId;
  PoaCategory _category = PoaCategory.judicial;
  String? _subType;
  PoaUsage? _poaUsage;
  String? _barBranch;
  DateTime? _poaDate;
  final List<String> _customSubTypes = [];
  bool _saving = false;

  @override
  void dispose() {
    _registryNumberController.dispose();
    _whiteNumberController.dispose();
    _delegateNameController.dispose();
    _delegatePhoneController.dispose();
    super.dispose();
  }

  List<String> get _subTypeOptions => [..._category.subTypes, ..._customSubTypes];

  /// مطابقة التصنيف الفرعي مع PoaType للتوافق مع بقية النظام.
  PoaType get _mappedPoaType {
    switch (_subType) {
      case 'سند توكيل خاص':
      case 'وكالة خاصة':
        return PoaType.special;
      case 'سند توكيل خاص شرعي':
        return PoaType.specialSharia;
      default:
        return PoaType.general;
    }
  }

  Future<void> _selectPoaDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _poaDate ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _poaDate = picked);
  }

  Future<void> _addCustomSubType() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة نوع جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم النوع'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      setState(() {
        _customSubTypes.add(value);
        _subType = value;
      });
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إضافة وكالة جديدة',
                style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 1) الموكل
                      ref.watch(allPersonsProvider(null)).maybeWhen(
                            data: (persons) => SearchablePicker<db.PersonEntity>(
                              label: 'الموكل *',
                              hintText: 'ابحث بالاسم أو الهاتف',
                              prefixIcon: const Icon(Icons.person_search),
                              items: persons,
                              labelOf: (p) => p.fullName,
                              searchTermsOf: (p) =>
                                  [p.phone1 ?? '', p.nationalId ?? ''],
                              subtitleOf: (p) => p.phone1,
                              value: _selectedClientId == null
                                  ? null
                                  : persons
                                      .where((p) => p.id == _selectedClientId)
                                      .firstOrNull,
                              onSelected: (p) =>
                                  setState(() => _selectedClientId = p.id),
                            ),
                            orElse: () => const LinearProgressIndicator(),
                          ),
                      const SizedBox(height: 16),
                      // 2) نوع الوكالة
                      DropdownButtonFormField<PoaCategory>(
                        value: _category,
                        isExpanded: true,
                        decoration: _dec('نوع الوكالة *'),
                        items: PoaCategory.values
                            .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                            .toList(),
                        onChanged: (value) => setState(() {
                          _category = value ?? PoaCategory.judicial;
                          _subType = null;
                          _poaUsage = null;
                          _customSubTypes.clear();
                          if (!_category.requiresBarBranch) {
                            _barBranch = null;
                            _delegateNameController.clear();
                            _delegatePhoneController.clear();
                          }
                        }),
                      ),
                      // 3) التصنيف الفرعي
                      if (_subTypeOptions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _subType,
                          isExpanded: true,
                          decoration: _dec('تصنيف ${_category.label} *'),
                          items: [
                            ..._subTypeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                            const DropdownMenuItem(value: '__add__', child: Text('إضافة نوع جديد...')),
                          ],
                          onChanged: (value) {
                            if (value == '__add__') {
                              _addCustomSubType();
                              return;
                            }
                            setState(() => _subType = value);
                          },
                        ),
                      ],
                      // الاستعمال/التصديق للقضائية فقط
                      if (_category == PoaCategory.judicial) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<PoaUsage>(
                          value: _poaUsage,
                          isExpanded: true,
                          decoration: _dec('الاستعمال / التصديق'),
                          items: PoaUsage.values
                              .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                              .toList(),
                          onChanged: (value) => setState(() => _poaUsage = value),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // 4) رقم الوكالة: سجل / أبيض
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _registryNumberController,
                              decoration: _dec('رقم السجل'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _whiteNumberController,
                              decoration: _dec('الرقم الأبيض'),
                            ),
                          ),
                        ],
                      ),
                      // 5) فرع النقابة والمندوب
                      if (_category.requiresBarBranch) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _barBranch,
                          isExpanded: true,
                          decoration: _dec('مندوب فرع النقابة'),
                          items: SyrianProvinces.all
                              .map((p) => DropdownMenuItem(value: p, child: Text('فرع $p')))
                              .toList(),
                          onChanged: (value) => setState(() => _barBranch = value),
                        ),
                        if (_barBranch != null) ...[
                          const SizedBox(height: 16),
                          // بحث في المندوبين المدخلين سابقاً لنفس الفرع فقط
                          ref.watch(allPoasProvider).maybeWhen(
                            data: (poas) {
                              // جمع المندوبين الفريدين من الوكالات السابقة لنفس الفرع
                              final delegates = <String, String>{};
                              for (final poa in poas) {
                                // فلترة حسب فرع النقابة المختار
                                if (poa.delegateBranch != _barBranch) continue;
                                
                                final name = poa.delegateName;
                                final phone = poa.delegatePhone;
                                if (name != null && name.trim().isNotEmpty) {
                                  // حفظ أحدث رقم هاتف لكل مندوب
                                  if (!delegates.containsKey(name) || 
                                      (phone != null && phone.trim().isNotEmpty)) {
                                    delegates[name] = phone ?? '';
                                  }
                                }
                              }
                              
                              if (delegates.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'لا يوجد مندوبين مسجلين لفرع $_barBranch',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                                  ),
                                );
                              }
                              
                              return SearchablePicker<MapEntry<String, String>>(
                                label: 'اختر مندوب من فرع $_barBranch (اختياري)',
                                hintText: 'ابحث بالاسم',
                                prefixIcon: const Icon(Icons.person_search),
                                items: delegates.entries.toList(),
                                labelOf: (e) => e.key,
                                searchTermsOf: (e) => [e.key, e.value],
                                subtitleOf: (e) => e.value.isNotEmpty ? e.value : null,
                                value: null,
                                onSelected: (delegate) {
                                  setState(() {
                                    _delegateNameController.text = delegate.key;
                                    _delegatePhoneController.text = delegate.value;
                                  });
                                },
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _delegateNameController,
                            decoration: _dec('اسم المندوب'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _delegatePhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _dec('هاتف المندوب (قابل للتعديل)'),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      // 6) تاريخ التنظيم
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _poaDate == null
                                  ? 'لم يتم تحديد تاريخ التنظيم'
                                  : 'تاريخ التنظيم: ${_poaDate!.year}-${_poaDate!.month.toString().padLeft(2, '0')}-${_poaDate!.day.toString().padLeft(2, '0')}',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _selectPoaDate,
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('تاريخ التنظيم'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _submitPoa,
                    child: Text(_saving ? 'جارٍ الحفظ...' : 'إضافة'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitPoa() async {
    final registry = _registryNumberController.text.trim();
    final white = _whiteNumberController.text.trim();
    // يكفي أحد الرقمين: بعض الوكالات تُسجَّل بالرقم الأبيض فقط.
    final number = registry.isNotEmpty ? registry : white;

    if (number.isEmpty || _selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الموكل ورقم الوكالة (السجل أو الأبيض) إلزاميان'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_subTypeOptions.isNotEmpty && (_subType == null || _subType!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اختر تصنيف ${_category.label}'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final poaId = await ref.read(poaRepositoryProvider).createPoa(
            poa: db.PowersOfAttorneyCompanion.insert(
              poaNumber: Value(number),
              poaDate: Value(_poaDate),
              // القضائية عبر مندوب النقابة، والعدلية عبر كاتب العدل.
              sourceType: _category == PoaCategory.judicial ? 'delegate' : 'notary',
              poaType: _mappedPoaType.index,
              category: Value(_category.dbValue),
              subType: Value(_subType),
              registryNumber: Value(registry.isEmpty ? null : registry),
              whiteNumber: Value(white.isEmpty ? null : white),
              delegateBranch: Value(_barBranch),
              delegateName: Value(
                  _delegateNameController.text.trim().isEmpty ? null : _delegateNameController.text.trim()),
              delegatePhone: Value(
                  _delegatePhoneController.text.trim().isEmpty ? null : _delegatePhoneController.text.trim()),
              scopeText: Value(_poaUsage?.label),
              status: Value(PoaStatus.active.dbValue),
            ),
            principalId: _selectedClientId!,
          );
      ref.invalidate(allPoasProvider);
      ref.invalidate(uiPersonsDirectoryProvider);
      if (mounted) {
        Navigator.of(context).pop(poaId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ الوكالة: $number'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر حفظ الوكالة: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}


class AddOpponentDialog extends ConsumerStatefulWidget {
  const AddOpponentDialog({super.key});

  @override
  ConsumerState<AddOpponentDialog> createState() => _AddOpponentDialogState();
}

class _AddOpponentDialogState extends ConsumerState<AddOpponentDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  /// اسم ممثل الشركة أو المؤسسة — إلزامي للأشخاص الاعتباريين.
  final TextEditingController _representativeController =
      TextEditingController();
  String _opponentType = 'شخص طبيعي';

  /// الشركة والمؤسسة شخص اعتباري لا يحضر بنفسه، فلا بد من ممثل.
  bool get _isLegalEntity => _opponentType != 'شخص طبيعي';

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    _representativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'إضافة خصم جديد',
              style: AppTextStyles.headline4.copyWith(
                color: AppColors.primaryNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'الاسم الكامل',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                labelText: 'رقم الهوية',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _opponentType,
              items: const [
                DropdownMenuItem(value: 'شخص طبيعي', child: Text('شخص طبيعي')),
                DropdownMenuItem(value: 'شركة', child: Text('شركة')),
                DropdownMenuItem(value: 'مؤسسة', child: Text('مؤسسة')),
              ],
              onChanged: (value) => setState(() => _opponentType = value!),
              decoration: InputDecoration(
                labelText: 'نوع الخصم',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_isLegalEntity) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _representativeController,
                decoration: InputDecoration(
                  labelText: 'اسم ممثل $_opponentType *',
                  hintText: 'المدير العام أو المفوَّض بالتوقيع',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submitOpponent,
                  child: const Text('إضافة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  bool _saving = false;
  void _submitOpponent() async {
    if (_nameController.text.trim().isEmpty || _saving) return;
    // الشخص الاعتباري لا يحضر بنفسه، فاسم الممثل شرط لصحة المراسلات.
    if (_isLegalEntity && _representativeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('اسم ممثل $_opponentType إلزامي'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final personId = await ref.read(personRepositoryProvider).createPerson(
        person: db.PersonsCompanion.insert(
          fullName: _nameController.text.trim(),
          type: Value(_opponentType == 'شخص طبيعي' ? PersonType.natural.index : PersonType.legal.index),
          nationalId: Value(_idController.text.trim().isEmpty ? null : _idController.text.trim()),
          phone1: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
          whatsapp: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
        ),
        // بيانات الشخص الاعتباري تُحفظ في جدولها لا كنص حر، فتبقى
        // صفة الممثل متاحة عند الطباعة والمراسلات.
        legalEntity: _isLegalEntity
            ? db.LegalEntitiesCompanion.insert(
                personId: 0, // يُضبط داخل المستودع بعد إنشاء الشخص
                legalEntityName: _nameController.text.trim(),
                entityType: Value(_opponentType),
                representativeCapacity:
                    Value(_representativeController.text.trim()),
                registrationNumber: Value(
                    _idController.text.trim().isEmpty
                        ? null
                        : _idController.text.trim()),
              )
            : null,
        initialRoles: [PersonRoleType.opponent],
      );
      ref.invalidate(allPersonsProvider(null));
      ref.invalidate(uiPersonsDirectoryProvider);
      if (mounted) {
        Navigator.of(context).pop(personId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إضافة الخصم: ${_nameController.text}'), backgroundColor: AppColors.success));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

}
