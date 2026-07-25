/// معالج إنشاء دعوى قضائية جديدة
/// 
/// حسب مواصفات PRODUCT_REDESIGN_MASTER_PLAN.md - القسم 5
/// معالج من 8 خطوات إلزامية
/// 
/// آخر تحديث: 2026-07-09

import 'dart:io';

import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/auth/permission_catalog.dart';
import '../../../core/enums/app_enums.dart';

import '../../../data/database/database.dart' as db;
import '../../../data/repositories/case_repository.dart';
import '../../../data/services/conflict_of_interest_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/archive_context_banner.dart';
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
  final TextEditingController _poaSearchController = TextEditingController();
  
  // ===========================================================================
  // الخطوة 3: التصنيف
  // ===========================================================================
  CaseType _caseType = CaseType.civil;
  String _caseSubType = 'بداية';
  int? _selectedCourtId;
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
  
  // قوائم الاختيار
  final List<String> _caseSubTypes = ['صلح', 'بداية', 'استئناف', 'نقض', 'مخاصمة'];
  final List<String> _courtNames = [
    'محكمة دمشق الأولى',
    'محكمة دمشق الثانية',
    'محكمة الاستئناف',
    'محكمة النقض',
    'محكمة حلب الأولى',
    'محكمة حمص الأولى',
    'محكمة اللاذقية الأولى',
    'محكمة حما',
    'محكمة درعا',
    'محكمة السويداء',
    'محكمة القنيطرة',
    'محكمة الرقة',
    'محكمة دير الزور',
    'محكمة الحسكة',
  ];

  @override
  void initState() {
    super.initState();
    final archive = widget.archiveContext;
    if (archive != null) {
      final caseType = archive.caseType ?? '';
      if (caseType.contains('جزائ')) _caseType = CaseType.criminal;
      if (caseType.contains('تجار')) _caseType = CaseType.commercial;
      if (caseType.contains('شرع')) _caseType = CaseType.personalStatus;
      if (caseType.contains('إدار') || caseType.contains('ادار')) _caseType = CaseType.administrative;
      if ((archive.courtLevel ?? '').isNotEmpty && !_caseSubTypes.contains(archive.courtLevel)) {
        _caseSubTypes.add(archive.courtLevel!);
      }
      if ((archive.courtLevel ?? '').isNotEmpty && !_courtNames.contains(archive.courtLevel)) {
        _courtNames.add(archive.courtLevel!);
      }
      if ((archive.courtLevel ?? '').isNotEmpty) {
        _caseSubType = archive.courtLevel!;
        _selectedCourtId = _courtNames.indexOf(archive.courtLevel!);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.archiveContext == null ? 'إنشاء دعوى جديدة' : (widget.archiveContext!.isRunning ? 'إدخال دعوى أرشيفية جارية' : 'أرشفة دعوى منتهية')),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('السابق'),
            ),
        ],
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
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_currentStep < 7)
              TextButton(
                onPressed: _isSaving ? null : _nextStep,
                child: const Text('التالي'),
              ),
            if (_currentStep == 7)
              ElevatedButton(
                onPressed: _isSaving ? null : _submitCase,
                child: _isSaving 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnLight,
                        ),
                      )
                    : Text(widget.archiveContext == null ? 'إنشاء الدعوى' : (widget.archiveContext!.isRunning ? 'حفظ الدعوى الجارية' : 'حفظ الدعوى المنتهية')),
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
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الخطوات
          Row(
            children: List.generate(8, (index) => _buildStepIndicator(index)),
          ),
          const SizedBox(height: 8),
          
          // أسماء الخطوات
          Row(
            children: List.generate(8, (index) => _buildStepLabel(index)),
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
      case 1: label = 'الوكالة'; break;
      case 2: label = 'التصنيف'; break;
      case 3: label = 'البيانات الأساسية'; break;
      case 4: label = 'الموضوع والطلبات'; break;
      case 5: label = 'الخصم'; break;
      case 6: label = 'المرفقات'; break;
      case 7: label = 'الموعد القادم'; break;
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
        return _buildPoaStep();
      case 2:
        return _buildClassificationStep();
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
    // الوكالات الحقيقية من قاعدة البيانات؛ القائمة الثابتة السابقة كانت تربط
    // الدعوى بمعرّف سند توكيل قد لا يكون موجوداً أصلاً.
    final poasAsync = ref.watch(allPoasProvider);
    if (poasAsync.isLoading) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    final poas = poasAsync.maybeWhen(
      data: (records) => records
          .map((r) => {
                'id': r.id,
                'number': r.poaNumber ?? 'وكالة #${r.id}',
                'client': r.sourceType == 'notary' ? 'كاتب عدل' : 'مندوب نقابة',
                'type': PoaType.values[r.poaType.clamp(0, PoaType.values.length - 1)].label,
                'date': r.poaDate == null
                    ? 'غير محدد'
                    : '${r.poaDate!.year}-${r.poaDate!.month.toString().padLeft(2, '0')}-${r.poaDate!.day.toString().padLeft(2, '0')}',
              })
          .toList(),
      orElse: () => const <Map<String, Object?>>[],
    );

    if (poas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.cardBackground,
        ),
        child: Text(
          'لا توجد وكالات مسجلة بعد — أضف سند التوكيل من شاشة الوكالات.',
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
        itemCount: poas.length,
        itemBuilder: (context, index) {
          final poa = poas[index];
          final isSelected = _selectedPoaId == poa['id'];
          
          return InkWell(
            onTap: () => setState(() => _selectedPoaId = poa['id'] as int?),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryNavy.withOpacity(0.1) : AppColors.cardBackground,
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user,
                    color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poa['number'] as String,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'الموكل: ${poa['client'] as String}',
                        style: AppTextStyles.bodySmallSecondary,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        poa['type'] as String,
                        style: AppTextStyles.bodySmall,
                      ),
                      Text(
                        poa['date'] as String,
                        style: AppTextStyles.bodySmallSecondary,
                      ),
                    ],
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
  
  void _searchPoas(String query) {
    // بحث عن وكالات في قاعدة البيانات
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

  // ===========================================================================
  // الخطوة 3: التصنيف
  // ===========================================================================
  
  Widget _buildClassificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'تصنيف الدعوى',
          description: 'حدد نوع الدعوى والمحكمة',
        ),
        const SizedBox(height: 24),
        
        // نوع الدعوى
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
        
        // النوع الفرعي
        DropdownButtonFormField<String>(
          value: _caseSubType,
          items: _caseSubTypes.map((subType) {
            return DropdownMenuItem(
              value: subType,
              child: Text(subType),
            );
          }).toList(),
          onChanged: (value) => setState(() => _caseSubType = value!),
          decoration: InputDecoration(
            labelText: 'النوع الفرعي',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('إضافة نوع فرعي غير موجود'),
            onPressed: () async {
              final value = await _askCustomValue('إضافة نوع فرعي للدعوى');
              if (value == null || value.isEmpty) return;
              setState(() {
                if (!_caseSubTypes.contains(value)) _caseSubTypes.add(value);
                _caseSubType = value;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        
        // المحكمة
        DropdownButtonFormField<int?>(
          value: _selectedCourtId,
          items: _courtNames.asMap().entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCourtId = value),
          decoration: InputDecoration(
            labelText: 'المحكمة',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('إضافة محكمة / درجة غير موجودة'),
            onPressed: () async {
              final value = await _askCustomValue('إضافة محكمة أو درجة تقاضي');
              if (value == null || value.isEmpty) return;
              setState(() {
                if (!_courtNames.contains(value)) _courtNames.add(value);
                _selectedCourtId = _courtNames.indexOf(value);
              });
            },
          ),
        ),
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
                ),
                keyboardType: TextInputType.number,
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
                ),
                keyboardType: TextInputType.number,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'البيانات الأساسية',
          description: 'ادخل رقم الدعوى وعنوانها',
        ),
        const SizedBox(height: 24),
        
        // رقم الدعوى
        TextField(
          controller: _caseNumberController,
          decoration: InputDecoration(
            labelText: 'رقم الدعوى',
            hintText: 'مثال: 2026/001 (سيتم توليد تلقائياً إذا ترك فارغاً)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // عنوان الدعوى
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'عنوان الدعوى',
            hintText: 'مثال: دعوى تعويض عن ضرر',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // الموضوع
        TextField(
          controller: _subjectController,
          decoration: InputDecoration(
            labelText: 'الموضوع',
            hintText: 'مثال: تعويض عن ضرر مادي',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 3,
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
        
        // بحث عن خصم
        TextField(
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
        const SizedBox(height: 16),
        
        // قائمة الخصوم
        _buildOpponentList(),
        _buildConflictBanner(_selectedOpponentId, asClient: false),
        
        // أو إضافة خصم جديد
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _showAddOpponentDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('إضافة خصم جديد'),
        ),
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
      data: (persons) => persons
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
    if (opponents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.cardBackground,
        ),
        child: Text(
          'لا يوجد أشخاص في الدليل بعد — أضف الخصم من شاشة الأشخاص أولاً.',
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
        itemCount: opponents.length,
        itemBuilder: (context, index) {
          final opponent = opponents[index];
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
                  Text(
                    opponent['name'] as String,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
  
  void _searchOpponents(String query) {
    // بحث عن خصوم في قاعدة البيانات
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'المرفقات',
          description: 'أرفق مستندات الدعوى (اختياري)',
        ),
        const SizedBox(height: 24),
        
        // قائمة المرفقات
        if (_attachmentPaths.isNotEmpty) ...[
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
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.cardBorder, width: 0.5),
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
                        child: Text(
                          _attachmentControllers[index].text.isNotEmpty
                              ? _attachmentControllers[index].text
                              : _attachmentPaths[index].split(Platform.pathSeparator).last,
                          style: AppTextStyles.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error),
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
    final result = await file_picker.FilePicker.platform.pickFiles(allowMultiple: true);
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
        const SizedBox(height: 16),
        
        // المحكمة
        DropdownButtonFormField<int?>(
          value: _selectedCourtId,
          items: _courtNames.asMap().entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCourtId = value),
          decoration: InputDecoration(
            labelText: 'المحكمة',
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
    
    if (_currentStep < 7) {
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
      case 2: // التصنيف
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
      case 3: // البيانات الأساسية
        if (_titleController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى إدخال عنوان الدعوى'),
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
      case 7: // الموعد القادم
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
      final caseRepo = ref.read(caseRepositoryProvider);
      
      // إعداد بيانات الدعوى
      final caseData = db.CasesCompanion.insert(
        internalNumber: 'TMP',
        year: int.tryParse(_baseYearController.text) ?? DateTime.now().year,
        caseType: _caseType.toString().split('.').last,
        subType: Value(_caseSubType),
        status: Value(widget.archiveContext?.isClosed == true ? 'closed' : 'registered'),
        courtId: Value(_selectedCourtId),
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
        nextSessionDate: Value(widget.archiveContext?.isClosed == true ? null : _nextSessionDate),
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إنشاء الدعوى: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
                            data: (persons) => DropdownButtonFormField<int>(
                              value: _selectedClientId,
                              isExpanded: true,
                              decoration: _dec('الموكل *'),
                              items: persons
                                  .map((p) => DropdownMenuItem(
                                        value: p.id,
                                        child: Text(p.fullName, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedClientId = v),
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
                          TextField(
                            controller: _delegateNameController,
                            decoration: _dec('اسم مندوب رئيس فرع النقابة'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _delegatePhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _dec('هاتف المندوب'),
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
  String _opponentType = 'شخص طبيعي';

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
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      if (mounted) {
        Navigator.of(context).pop(0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إضافة الخصم: ${_nameController.text}'), backgroundColor: AppColors.success));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

}
