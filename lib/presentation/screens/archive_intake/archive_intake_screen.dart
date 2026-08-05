import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/court_catalog.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/repositories/archive_intake_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../documents/document_models.dart' show documentsFutureProvider;
import '../files/files_screen.dart' show FileItem, FileStatus, FileType, filesProvider;
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';

final _archiveIntakeRefreshProvider = StateProvider<int>((ref) => 0);
final _archiveWizardQuerySeedProvider = StateProvider<String?>((ref) => null);
final _archiveBatchSearchProvider = StateProvider<String>((ref) => '');
final _archiveBatchSourceFilterProvider = StateProvider<String>((ref) => 'all');
final _archiveBatchStatusFilterProvider = StateProvider<String>((ref) => 'all');

final _archiveWizardProvider = StateProvider<_ArchiveWizardSelection>((ref) => const _ArchiveWizardSelection());

final _archiveReferenceValuesProvider = FutureProvider.family<List<String>, ({String category, String? parent})>((ref, key) async {
  final records = await ref.watch(archiveIntakeRepositoryProvider).getReferenceValues(category: key.category, parentValue: key.parent);
  return records.map((record) => record.value).toList();
});

class _ArchiveWizardSelection {
  final String? archiveStatus; // running / closed
  final String? fileKind;
  final String? caseType;
  final String? courtLevel;
  final String? companyGroup;
  final String? companyType;
  final String? procedureType;
  final String? contractType;
  final String? poaType;
  final List<String> customFileKinds;
  final List<String> customCaseTypes;
  final Map<String, List<String>> customCourtsByCaseType;
  final List<String> customCompanyTypes;
  final List<String> customProcedureTypes;
  final List<String> customContractTypes;
  final List<String> customPoaTypes;
  final List<String> customDocumentTypes;

  const _ArchiveWizardSelection({
    this.archiveStatus,
    this.fileKind,
    this.caseType,
    this.courtLevel,
    this.companyGroup,
    this.companyType,
    this.procedureType,
    this.contractType,
    this.poaType,
    this.customFileKinds = const [],
    this.customCaseTypes = const [],
    this.customCourtsByCaseType = const {},
    this.customCompanyTypes = const [],
    this.customProcedureTypes = const [],
    this.customContractTypes = const [],
    this.customPoaTypes = const [],
    this.customDocumentTypes = const [],
  });

  _ArchiveWizardSelection copyWith({
    Object? archiveStatus = _sentinel,
    Object? fileKind = _sentinel,
    Object? caseType = _sentinel,
    Object? courtLevel = _sentinel,
    Object? companyGroup = _sentinel,
    Object? companyType = _sentinel,
    Object? procedureType = _sentinel,
    Object? contractType = _sentinel,
    Object? poaType = _sentinel,
    List<String>? customFileKinds,
    List<String>? customCaseTypes,
    Map<String, List<String>>? customCourtsByCaseType,
    List<String>? customCompanyTypes,
    List<String>? customProcedureTypes,
    List<String>? customContractTypes,
    List<String>? customPoaTypes,
    List<String>? customDocumentTypes,
  }) {
    return _ArchiveWizardSelection(
      archiveStatus: archiveStatus == _sentinel ? this.archiveStatus : archiveStatus as String?,
      fileKind: fileKind == _sentinel ? this.fileKind : fileKind as String?,
      caseType: caseType == _sentinel ? this.caseType : caseType as String?,
      courtLevel: courtLevel == _sentinel ? this.courtLevel : courtLevel as String?,
      companyGroup: companyGroup == _sentinel ? this.companyGroup : companyGroup as String?,
      companyType: companyType == _sentinel ? this.companyType : companyType as String?,
      procedureType: procedureType == _sentinel ? this.procedureType : procedureType as String?,
      contractType: contractType == _sentinel ? this.contractType : contractType as String?,
      poaType: poaType == _sentinel ? this.poaType : poaType as String?,
      customFileKinds: customFileKinds ?? this.customFileKinds,
      customCaseTypes: customCaseTypes ?? this.customCaseTypes,
      customCourtsByCaseType: customCourtsByCaseType ?? this.customCourtsByCaseType,
      customCompanyTypes: customCompanyTypes ?? this.customCompanyTypes,
      customProcedureTypes: customProcedureTypes ?? this.customProcedureTypes,
      customContractTypes: customContractTypes ?? this.customContractTypes,
      customPoaTypes: customPoaTypes ?? this.customPoaTypes,
      customDocumentTypes: customDocumentTypes ?? this.customDocumentTypes,
    );
  }

  bool get isClosed => archiveStatus == 'closed';
  bool get isRunning => archiveStatus == 'running';
}

class _UnsetValue {
  const _UnsetValue();
}

const _UnsetValue _sentinel = _UnsetValue();

const _archiveFileKindOptions = <String, String>{
  'case': 'دعوى',
  'company': 'شركة',
  'procedure': 'إجراء / معاملة',
  'contract': 'عقد',
  'poa': 'وكالة',
  'misc': 'أرشيف غير محدد',
};

/// خارطة نوع الدعوى ← محاكمها، مشتقّة من `CourtCatalog`.
///
/// كانت خارطة يدوية انحرفت عن الواقع: أدرجت «محكمة عمالية» تحت
/// الدعاوى الإدارية، وأغفلت محاكم الأحداث والتنفيذ، وخلطت «نقض»
/// المجرد بدوائر النقض الثلاث. اشتقاقها من الفهرس يجعل المصدر
/// واحداً فلا يتباعد الاثنان مجدداً.
final _caseCourtMap = CourtCatalog.archiveClassificationMap();

const _companyTypeMap = <String, List<String>>{
  'شركات أشخاص': ['شركة تضامنية', 'شركة توصية بسيطة'],
  'شركات أموال': ['شركة محدودة المسؤولية', 'مساهمة مغفلة خاصة', 'مساهمة مغفلة عامة'],
};

const _procedureTypeOptions = ['أحوال شخصية', 'إجراءات عقارية', 'إجراءات تجارية', 'إجراءات تنفيذية', 'إجراءات إدارية عامة'];
const _contractTypeOptions = ['عقد بيع', 'عقد إيجار', 'عقد شراكة', 'عقد عمل', 'عقد مقاولة', 'مخالصة / إبراء'];
const _poaTypeOptions = ['وكالة عامة', 'وكالة خاصة', 'وكالة قضائية', 'وكالة بيع عقار', 'وكالة شركة'];

enum _ArchiveLinkTarget {
  caseFile,
  procedure,
  company,
  contract,
  person,
  poa;

  String get label => const ['دعوى', 'إجراء إداري', 'شركة', 'عقد', 'موكل / جهة', 'وكالة'][index];

  int get entityType {
    switch (this) {
      case _ArchiveLinkTarget.caseFile:
        return EntityType.caseEntity.index;
      case _ArchiveLinkTarget.procedure:
        return EntityType.adminProcedure.index;
      case _ArchiveLinkTarget.company:
        return EntityType.company.index;
      case _ArchiveLinkTarget.contract:
        return EntityType.contract.index;
      case _ArchiveLinkTarget.person:
        return EntityType.person.index;
      case _ArchiveLinkTarget.poa:
        return EntityType.powerOfAttorney.index;
    }
  }
}

const _documentTypeOptions = <String, String>{
  'case_document': 'مستند دعوى',
  'power_of_attorney': 'وكالة',
  'contract': 'عقد',
  'decision': 'قرار / حكم',
  'court_record': 'ضبط جلسة',
  'receipt': 'إيصال',
  'memo': 'مذكرة',
  'archive_document': 'مستند أرشيف',
};

/// مركز إدخال الأرشيف القديم.
///
/// يدير دفعات إدخال الأرشيف الورقي والإلكتروني، يحفظ الملفات المستوردة، يكشف
/// المكررات، ويسمح بمراجعة العناصر وربطها بملفات المكتب دون تجاوز مسارات العمل الرسمية.
class ArchiveIntakeScreen extends ConsumerStatefulWidget {
  const ArchiveIntakeScreen({super.key});

  @override
  ConsumerState<ArchiveIntakeScreen> createState() => _ArchiveIntakeScreenState();
}

class _ArchiveIntakeScreenState extends ConsumerState<ArchiveIntakeScreen> {
  @override
  void initState() {
    super.initState();
    // إعادة تعيين المعالج عند فتح الشاشة أو الرجوع إليها
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(_archiveWizardProvider.notifier).state = const _ArchiveWizardSelection();
      }
    });
  }

  String _normalizeSearchText(Object? value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  bool _containsSearch(Object? source, String query) => _normalizeSearchText(source).contains(query);

  @override
  Widget build(BuildContext context) {
    ref.watch(_archiveIntakeRefreshProvider);
    final selection = ref.watch(_archiveWizardProvider);
    
    // إذا لم يتم اختيار الحالة بعد، اعرض شاشة الاختيار
    if (selection.archiveStatus == null) {
      return _buildStatusSelectionScreen(context);
    }
    
    // إذا تم اختيار الحالة، اعرض شاشة اختيار طريقة الإدخال
    if (selection.fileKind == null && !_showingInputMethod) {
      return _buildInputMethodSelectionScreen(context, ref);
    }
    
    // إذا تم اختيار طريقة الإدخال اليدوي، اعرض الويزارد
    return _buildWizardScreen(context, ref);
  }

  bool _showingInputMethod = false;

  /// شاشة اختيار الحالة (أرشيف / عمل جاري)
  Widget _buildStatusSelectionScreen(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مركز إدخال الأرشيف القديم'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'اختر نوع الإدخال',
                    style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatusCard(
                        icon: Icons.inventory_2,
                        title: 'أرشيف',
                        subtitle: 'ملفات منتهية للحفظ والبحث',
                        color: AppColors.primaryNavy,
                        onTap: () {
                          ref.read(_archiveWizardProvider.notifier).state = 
                              const _ArchiveWizardSelection(archiveStatus: 'closed');
                        },
                      ),
                      const SizedBox(width: 32),
                      _buildStatusCard(
                        icon: Icons.pending_actions,
                        title: 'عمل جاري',
                        subtitle: 'ملفات جارية تغذي مكتب العمل',
                        color: AppColors.success,
                        onTap: () {
                          ref.read(_archiveWizardProvider.notifier).state = 
                              const _ArchiveWizardSelection(archiveStatus: 'running');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.headline5.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// شاشة اختيار طريقة الإدخال (3 خيارات)
  Widget _buildInputMethodSelectionScreen(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(_archiveWizardProvider);
    final statusLabel = selection.isRunning ? 'عمل جاري' : 'أرشيف';
    
    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text('إدخال $statusLabel'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                ref.read(_archiveWizardProvider.notifier).state = const _ArchiveWizardSelection();
              },
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'اختر طريقة الإدخال',
                    style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 48),
                  Column(
                    children: [
                      _buildInputMethodCard(
                        icon: Icons.edit,
                        title: 'إدخال يدوي',
                        subtitle: 'إدخال الملفات يدوياً بدقة متناهية',
                        color: AppColors.primaryNavy,
                        onTap: () {
                          setState(() => _showingInputMethod = true);
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildInputMethodCard(
                        icon: Icons.auto_awesome,
                        title: 'ذكاء صناعي مدمج',
                        subtitle: 'تصنيف تلقائي باستخدام نموذج محلي (قريباً)',
                        color: AppColors.info,
                        enabled: false,
                        onTap: () {},
                      ),
                      const SizedBox(height: 16),
                      _buildInputMethodCard(
                        icon: Icons.cloud,
                        title: 'ذكاء صناعي متصل',
                        subtitle: 'تصنيف تلقائي باستخدام DeepSeek/Groq (قريباً)',
                        color: AppColors.secondaryGold,
                        enabled: false,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.08) : AppColors.textSecondary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? color.withOpacity(0.3) : AppColors.textSecondary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 48, color: enabled ? color : AppColors.textSecondary),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.headline6.copyWith(
                      color: enabled ? color : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: enabled ? AppColors.textSecondary : AppColors.textSecondary.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (!enabled)
              Chip(
                label: const Text('قريباً'),
                backgroundColor: AppColors.warning.withOpacity(0.2),
              ),
          ],
        ),
      ),
    );
  }

  /// شاشة الويزارد (الإدخال اليدوي)
  Widget _buildWizardScreen(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(_archiveWizardProvider);
    final statusLabel = selection.isRunning ? 'عمل جاري' : 'أرشيف';
    
    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text('إدخال $statusLabel - إدخال يدوي'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                // الرجوع لشاشة اختيار طريقة الإدخال
                ref.read(_archiveWizardProvider.notifier).state = 
                    _ArchiveWizardSelection(archiveStatus: selection.archiveStatus);
                setState(() => _showingInputMethod = false);
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _archiveGuidedEntryPanel(context, ref),
          ),
        ),
      ),
    );
  }

  Widget _introCard() {
    return Card(
      color: AppColors.primaryNavy,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.archive, color: AppColors.secondaryGold, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إدخال الأرشيف القديم بدون فوضى', style: AppTextStyles.headline5.copyWith(color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text(
                    'كل ملف مستورد يجب أن يصبح إما ملفاً جارياً يغذي مكتب العمل، أو ملفاً منتهياً للأرشفة والبحث، أو عنصراً يحتاج مراجعة.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.bold),
      );

  Widget _archiveOverviewPanel(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ArchiveBatchRecord>>(
      future: ref.watch(archiveIntakeRepositoryProvider).getBatches(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 64, child: Center(child: CircularProgressIndicator()));
        }
        final batches = snapshot.data!;
        final totalFiles = batches.fold<int>(0, (sum, b) => sum + b.totalFiles);
        final approved = batches.fold<int>(0, (sum, b) => sum + b.approvedFiles);
        final needsReview = batches.fold<int>(0, (sum, b) => sum + b.unclassifiedFiles);
        final duplicates = batches.fold<int>(0, (sum, b) => sum + b.duplicateFiles);
        final failed = batches.fold<int>(0, (sum, b) => sum + b.failedFiles);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _overviewMetric('الدفعات', batches.length, Icons.inventory_2, AppColors.primaryNavy),
            _overviewMetric('إجمالي الملفات', totalFiles, Icons.insert_drive_file, AppColors.info),
            _overviewMetric('معتمدة', approved, Icons.check_circle, AppColors.success),
            _overviewMetric('تحتاج مراجعة', needsReview, Icons.rate_review, AppColors.warning, onTap: needsReview > 0 ? () => _showUnclassifiedInbox(context, ref) : null),
            _overviewMetric('مكررة', duplicates, Icons.copy_all, AppColors.info, onTap: duplicates > 0 ? () => _showDuplicates(context, ref) : null),
            _overviewMetric('فاشلة', failed, Icons.error_outline, AppColors.error, onTap: failed > 0 ? () => _showQualityReport(context, ref) : null),
            _paperOverviewMetric(context, ref),
          ],
        );
      },
    );
  }

  Widget _paperOverviewMetric(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _loadPaperArchiveRows(ref),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, Object?>>[];
        final missing = rows.where((row) => ((row['paper_original_saved'] as int?) ?? 0) != 1).length;
        final unreviewed = rows.where((row) => ((row['reviewed_by'] as String?) ?? '').trim().isEmpty).length;
        return _overviewMetric(
          'أصول ورقية',
          rows.length,
          Icons.inventory,
          missing > 0 || unreviewed > 0 ? AppColors.warning : AppColors.secondaryGold,
          onTap: rows.isNotEmpty ? () => _showPaperArchiveReport(context, ref) : null,
        );
      },
    );
  }

  Widget _overviewMetric(String label, int value, IconData icon, Color color, {VoidCallback? onTap}) {
    return SizedBox(
      width: 178,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: color.withOpacity(0.10), child: Icon(icon, color: color, size: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.bodySmallSecondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('$value', style: AppTextStyles.numberText.copyWith(color: color)),
                    ],
                  ),
                ),
                if (onTap != null) Icon(Icons.arrow_forward_ios, size: 14, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionCard({required IconData icon, required String title, required String subtitle, required bool enabled, VoidCallback? onTap}) {
    return Card(
      elevation: enabled ? 2 : 0,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: (enabled ? AppColors.primaryNavy : AppColors.textSecondary).withOpacity(0.12),
                child: Icon(icon, color: enabled ? AppColors.primaryNavy : AppColors.textSecondary),
              ),
              const Spacer(),
              Text(title, style: AppTextStyles.headline6.copyWith(color: enabled ? AppColors.primaryNavy : AppColors.textSecondary)),
              const SizedBox(height: 6),
              Text(subtitle, style: AppTextStyles.bodySmallSecondary, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (!enabled) ...[
                const SizedBox(height: 6),
                Text('لا تملك الصلاحية', style: AppTextStyles.labelSmall.copyWith(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomReferences(BuildContext context, WidgetRef ref) async {
    final values = await ref.read(archiveIntakeRepositoryProvider).getAllReferenceValues();
    await ref.read(auditServiceProvider).log(action: 'view', category: 'archive', entityType: 'archive_references', description: 'عرض التصنيفات المخصصة للأرشيف', severity: 'info');
    if (!context.mounted) return;
    final grouped = <String, List<ArchiveReferenceValueRecord>>{};
    for (final value in values) {
      grouped.putIfAbsent(value.category, () => []).add(value);
    }
    final referenceSearch = TextEditingController();
    String query = '';
    String categoryFilter = 'all';
    String activeFilter = 'all';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final filteredGroups = <String, List<ArchiveReferenceValueRecord>>{};
          final q = _normalizeSearchText(query);
          grouped.forEach((category, records) {
            final filtered = records.where((record) {
              final queryOk = q.isEmpty ||
                  _containsSearch(_archiveReferenceCategoryLabel(record.category), q) ||
                  _containsSearch(record.value, q) ||
                  _containsSearch(record.parentValue, q);
              final categoryOk = categoryFilter == 'all' || record.category == categoryFilter;
              final activeOk = activeFilter == 'all' || (activeFilter == 'active' && record.isActive) || (activeFilter == 'inactive' && !record.isActive);
              return queryOk && categoryOk && activeOk;
            }).toList();
            if (filtered.isNotEmpty) filteredGroups[category] = filtered;
          });
          final visibleValues = filteredGroups.values.expand((list) => list).toList();
          return AlertDialog(
            title: const Text('التصنيفات المخصصة للأرشيف'),
            content: SizedBox(
              width: 780,
              height: 600,
              child: values.isEmpty
                  ? const Center(child: Text('لا توجد تصنيفات مخصصة بعد.'))
                  : Column(
                      children: [
                        TextField(
                          controller: referenceSearch,
                          decoration: const InputDecoration(labelText: 'بحث في التصنيفات المخصصة', prefixIcon: Icon(Icons.search)),
                          onChanged: (value) => setDialog(() => query = value),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: categoryFilter,
                                decoration: const InputDecoration(labelText: 'فئة التصنيف'),
                                items: [
                                  const DropdownMenuItem(value: 'all', child: Text('كل الفئات')),
                                  ...grouped.keys.map((category) => DropdownMenuItem(value: category, child: Text(_archiveReferenceCategoryLabel(category)))),
                                ],
                                onChanged: (value) => setDialog(() => categoryFilter = value ?? 'all'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: activeFilter,
                                decoration: const InputDecoration(labelText: 'الحالة'),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('كل الحالات')),
                                  DropdownMenuItem(value: 'active', child: Text('مفعّلة')),
                                  DropdownMenuItem(value: 'inactive', child: Text('معطّلة')),
                                ],
                                onChanged: (value) => setDialog(() => activeFilter = value ?? 'all'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _mini('المعروض', visibleValues.length),
                              _mini('مفعّلة', visibleValues.where((value) => value.isActive).length),
                              _mini('معطّلة', visibleValues.where((value) => !value.isActive).length),
                              if (query.isNotEmpty || categoryFilter != 'all' || activeFilter != 'all')
                                TextButton.icon(
                                  icon: const Icon(Icons.filter_alt_off, size: 16),
                                  label: const Text('مسح'),
                                  onPressed: () => setDialog(() {
                                    referenceSearch.clear();
                                    query = '';
                                    categoryFilter = 'all';
                                    activeFilter = 'all';
                                  }),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: filteredGroups.isEmpty
                              ? const Center(child: Text('لا توجد تصنيفات مطابقة.'))
                              : ListView(
                                  children: filteredGroups.entries.map((entry) {
                                    return Card(
                                      child: ExpansionTile(
                                        initiallyExpanded: true,
                                        title: Text(_archiveReferenceCategoryLabel(entry.key), style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
                                        children: entry.value
                                            .map((value) => ListTile(
                                                  dense: true,
                                                  leading: const Icon(Icons.label_outline, size: 18),
                                                  title: Row(
                                                    children: [
                                                      Expanded(child: Text(value.value)),
                                                      Chip(label: Text(value.isActive ? 'مفعّل' : 'معطّل'), visualDensity: VisualDensity.compact),
                                                    ],
                                                  ),
                                                  subtitle: value.parentValue == null ? null : Text('ضمن: ${value.parentValue}'),
                                                  trailing: Wrap(
                                                    spacing: 6,
                                                    children: [
                                                      if (value.isActive)
                                                        IconButton(
                                                          tooltip: 'تعديل',
                                                          icon: const Icon(Icons.edit, size: 18),
                                                          onPressed: () => _renameCustomReference(ctx, ref, value),
                                                        ),
                                                      if (value.isActive)
                                                        IconButton(
                                                          tooltip: 'تعطيل',
                                                          icon: const Icon(Icons.block, size: 18, color: AppColors.error),
                                                          onPressed: () => _disableCustomReference(ctx, ref, value),
                                                        )
                                                      else
                                                        IconButton(
                                                          tooltip: 'إعادة تفعيل',
                                                          icon: const Icon(Icons.restore, size: 18, color: AppColors.success),
                                                          onPressed: () => _enableCustomReference(ctx, ref, value),
                                                        ),
                                                    ],
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
            ),
            actions: [
              if (ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport))
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('تصدير التصنيفات CSV'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _exportCustomReferences(context, ref, visibleValues);
                  },
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportCustomReferences(BuildContext context, WidgetRef ref, List<ArchiveReferenceValueRecord> values) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_references', description: 'محاولة تصدير التصنيفات المخصصة دون صلاحية', severity: 'warning');
      return;
    }
    final buffer = StringBuffer('id,category,categoryLabel,parent,value,isActive\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final value in values) {
      buffer.writeln([
        value.id,
        esc(value.category),
        esc(_archiveReferenceCategoryLabel(value.category)),
        esc(value.parentValue),
        esc(value.value),
        value.isActive,
      ].join(','));
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, AppConstants.appDataDirectoryName, 'archive_reference_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(path.join(dir.path, 'archive_custom_references_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await _writeArabicCsv(file, buffer.toString());
    await ref.read(auditServiceProvider).log(action: 'export', category: 'archive', entityType: 'archive_references', entityTitle: file.path, description: 'تصدير التصنيفات المخصصة للأرشيف CSV', after: {'count': values.length}, severity: 'info');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تصدير التصنيفات المخصصة: ${file.path}'), backgroundColor: AppColors.success));
    }
  }

  Future<void> _renameCustomReference(BuildContext context, WidgetRef ref, ArchiveReferenceValueRecord value) async {
    final controller = TextEditingController(text: value.value);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل تصنيف مخصص'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'الاسم الجديد')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    if (next == null || next.isEmpty || next == value.value) return;
    await ref.read(archiveIntakeRepositoryProvider).renameReferenceValue(id: value.id, value: next);
    ref.invalidate(_archiveReferenceValuesProvider((category: value.category, parent: value.parentValue)));
    await ref.read(auditServiceProvider).log(action: 'edit', category: 'archive', entityType: 'archive_reference', entityId: '${value.id}', entityTitle: next, description: 'تعديل تصنيف مخصص للأرشيف', before: {'value': value.value}, after: {'value': next}, severity: 'info');
    if (context.mounted) {
      Navigator.pop(context);
      await _showCustomReferences(context, ref);
    }
  }

  Future<void> _disableCustomReference(BuildContext context, WidgetRef ref, ArchiveReferenceValueRecord value) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تعطيل تصنيف مخصص'),
            content: Text('سيتم إخفاء "${value.value}" من قوائم معالج الأرشيف الجديدة دون حذف السجلات التي استخدمته سابقاً. هل تريد المتابعة؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تعطيل')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await ref.read(archiveIntakeRepositoryProvider).disableReferenceValue(value.id);
    ref.invalidate(_archiveReferenceValuesProvider((category: value.category, parent: value.parentValue)));
    await ref.read(auditServiceProvider).log(action: 'disable', category: 'archive', entityType: 'archive_reference', entityId: '${value.id}', entityTitle: value.value, description: 'تعطيل تصنيف مخصص للأرشيف', severity: 'warning');
    if (context.mounted) {
      Navigator.pop(context);
      await _showCustomReferences(context, ref);
    }
  }

  Future<void> _enableCustomReference(BuildContext context, WidgetRef ref, ArchiveReferenceValueRecord value) async {
    await ref.read(archiveIntakeRepositoryProvider).enableReferenceValue(value.id);
    ref.invalidate(_archiveReferenceValuesProvider((category: value.category, parent: value.parentValue)));
    await ref.read(auditServiceProvider).log(action: 'enable', category: 'archive', entityType: 'archive_reference', entityId: '${value.id}', entityTitle: value.value, description: 'إعادة تفعيل تصنيف مخصص للأرشيف', severity: 'info');
    if (context.mounted) {
      Navigator.pop(context);
      await _showCustomReferences(context, ref);
    }
  }

  String _archiveReferenceCategoryLabel(String category) {
    switch (category) {
      case 'file_kind': return 'أنواع ملفات الأرشيف';
      case 'case_type': return 'أنواع الدعاوى';
      case 'court_level': return 'المحاكم ودرجات التقاضي';
      case 'company_type': return 'أنواع الشركات';
      case 'procedure_type': return 'أنواع الإجراءات';
      case 'contract_type': return 'أنواع العقود';
      case 'poa_type': return 'أنواع الوكالات';
      case 'document_type': return 'أسماء الوثائق';
      default: return category;
    }
  }

  Widget _statusTile(String title, String subtitle, IconData icon, Color color, {VoidCallback? onTap}) {
    return SizedBox(
      width: 300,
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
          title: Text(title, style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
          subtitle: Text(subtitle, style: AppTextStyles.bodySmallSecondary),
          trailing: onTap == null ? null : const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }

  Widget _archiveGuidedEntryPanel(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(_archiveWizardProvider);
    final notifier = ref.read(_archiveWizardProvider.notifier);
    final persistedFileKinds = ref.watch(_archiveReferenceValuesProvider((category: 'file_kind', parent: null))).maybeWhen(data: (values) => values, orElse: () => const <String>[]);
    final kindDone = selection.fileKind != null;
    final canStart = _archiveSelectionReady(selection);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: AppColors.primaryNavy.withOpacity(0.1), child: const Icon(Icons.account_tree, color: AppColors.primaryNavy)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('معالج إدخال الأرشيف', style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('اختر نوع الملف وتصنيفه. الجارية فقط تغذي مكتب العمل بالمواعيد القادمة.', style: AppTextStyles.bodySmallSecondary),
                    ],
                  ),
                ),
                TextButton.icon(icon: const Icon(Icons.refresh, size: 16), label: const Text('إعادة ضبط'), onPressed: () {
                  notifier.state = _ArchiveWizardSelection(archiveStatus: selection.archiveStatus);
                  setState(() => _showingInputMethod = false);
                }),
              ],
            ),
            const Divider(height: 28),
            // الخطوة 1: النوع الفرعي للملف (بدلاً من الخطوة 2 القديمة)
            _wizardStep('1', 'النوع الفرعي للملف', 'اختر نوع الأرشيف المراد إدخاله، أو أضف نوعاً غير موجود.', Wrap(spacing: 8, runSpacing: 8, children: [
              ..._archiveFileKindOptions.entries.map((e) => _choiceChip(selection.fileKind == e.key, e.value, () => notifier.state = selection.copyWith(fileKind: e.key, caseType: null, courtLevel: null, companyGroup: null, companyType: null, procedureType: null, contractType: null, poaType: null))),
              ...{...selection.customFileKinds, ...persistedFileKinds}.map((v) => _choiceChip(selection.fileKind == v, v, () => notifier.state = selection.copyWith(fileKind: v))),
              ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('إضافة نوع جديد'), onPressed: () => _addCustomReferenceValue(context, ref, 'نوع ملف جديد', 'file_kind', null, (value) => notifier.state = selection.copyWith(customFileKinds: [...selection.customFileKinds, value], fileKind: value))),
            ])),
            if (kindDone) ...[
              const SizedBox(height: 16),
              _wizardDetailsForKind(context, ref, selection),
            ],
            if (selection.fileKind != null) ...[
              const SizedBox(height: 16),
              _documentsHint(context, ref, selection),
            ],
            if (selection.fileKind != null) ...[
              const SizedBox(height: 16),
              _archiveCurrentPathCard(selection),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                icon: Icon(selection.isRunning ? Icons.play_circle : Icons.archive),
                label: Text(selection.isRunning ? 'فتح شاشة إدخال ملف جارٍ' : 'فتح شاشة أرشفة ملف منتهٍ'),
                onPressed: canStart ? () => _startArchiveEntry(context, ref, selection) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _archiveCurrentPathCard(_ArchiveWizardSelection s) {
    final summary = _archiveSummary(s);
    final color = s.isRunning ? AppColors.success : AppColors.primaryNavy;
    final effect = s.archiveStatus == null
        ? 'حدد هل الأرشيف جارٍ أو منتهٍ حتى يعرف النظام أثر الملف على مكتب العمل.'
        : s.isRunning
            ? 'هذا المسار سيُدخل ملفاً حياً: المواعيد القادمة ستظهر في مكتب العمل والتقويم.'
            : 'هذا المسار للحفظ والبحث فقط: لن تظهر مواعيده ضمن العمل القادم.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(s.archiveStatus == null ? Icons.help_outline : (s.isRunning ? Icons.route : Icons.inventory_2), color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.isEmpty ? 'لم يكتمل مسار الأرشيف بعد' : summary, style: AppTextStyles.labelLarge.copyWith(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(effect, style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wizardStep(String number, String title, String subtitle, Widget child) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 14, backgroundColor: AppColors.secondaryGold, child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
        const SizedBox(height: 3),
        Text(subtitle, style: AppTextStyles.bodySmallSecondary),
        const SizedBox(height: 10),
        child,
      ])),
    ]);
  }

  Widget _archiveChoice({required bool selected, required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return SizedBox(
      width: 300,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: selected ? AppColors.primaryNavy.withOpacity(0.08) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? AppColors.primaryNavy : AppColors.cardBorder, width: selected ? 1.4 : 0.7)),
          child: Row(children: [
            CircleAvatar(backgroundColor: AppColors.primaryNavy.withOpacity(0.1), child: Icon(icon, color: AppColors.primaryNavy)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.labelLarge), Text(subtitle, style: AppTextStyles.bodySmallSecondary)])),
            if (selected) const Icon(Icons.check_circle, color: AppColors.success),
          ]),
        ),
      ),
    );
  }

  Widget _choiceChip(bool selected, String label, VoidCallback onTap) {
    return ChoiceChip(selected: selected, label: Text(label), selectedColor: AppColors.primaryNavy.withOpacity(0.12), labelStyle: TextStyle(color: selected ? AppColors.primaryNavy : AppColors.textPrimary, fontWeight: selected ? FontWeight.bold : FontWeight.normal), onSelected: (_) => onTap());
  }

  Widget _wizardDetailsForKind(BuildContext context, WidgetRef ref, _ArchiveWizardSelection s) {
    final notifier = ref.read(_archiveWizardProvider.notifier);
    if (s.fileKind == 'case') {
      final persistedCaseTypes = ref.watch(_archiveReferenceValuesProvider((category: 'case_type', parent: null))).maybeWhen(data: (values) => values, orElse: () => const <String>[]);
      final persistedCourts = s.caseType == null ? const <String>[] : ref.watch(_archiveReferenceValuesProvider((category: 'court_level', parent: s.caseType))).maybeWhen(data: (values) => values, orElse: () => const <String>[]);
      final caseTypes = {..._caseCourtMap.keys, ...s.customCaseTypes, ...persistedCaseTypes}.toList();
      final courts = s.caseType == null ? const <String>[] : {...(_caseCourtMap[s.caseType] ?? const <String>[]), ...(s.customCourtsByCaseType[s.caseType] ?? const <String>[]), ...persistedCourts}.toList();
      return _wizardStep('3', 'تصنيف الدعوى والمحكمة', 'اختر نوع الدعوى ثم المحكمة/درجة التقاضي. يمكن إضافة أي تصنيف أو محكمة غير موجودة.', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...caseTypes.map((v) => _choiceChip(s.caseType == v, v, () => notifier.state = s.copyWith(caseType: v, courtLevel: null))),
          ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('إضافة نوع دعوى'), onPressed: () => _addCustomReferenceValue(context, ref, 'نوع دعوى جديد', 'case_type', null, (value) => notifier.state = s.copyWith(customCaseTypes: [...s.customCaseTypes, value], caseType: value, courtLevel: null))),
        ]),
        if (s.caseType != null) ...[
          const SizedBox(height: 12),
          Text('المحكمة / درجة التقاضي', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...courts.map((v) => _choiceChip(s.courtLevel == v, v, () => notifier.state = s.copyWith(courtLevel: v))),
            ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('إضافة محكمة / درجة'), onPressed: () => _addCustomReferenceValue(context, ref, 'محكمة أو درجة جديدة', 'court_level', s.caseType, (value) {
              final updated = Map<String, List<String>>.from(s.customCourtsByCaseType);
              updated[s.caseType!] = [...(updated[s.caseType!] ?? const <String>[]), value];
              notifier.state = s.copyWith(customCourtsByCaseType: updated, courtLevel: value);
            })),
          ]),
        ],
      ]));
    }
    if (s.fileKind == 'company') {
      final groups = _companyTypeMap.keys.toList();
      final persistedCompanyTypes = s.companyGroup == null ? const <String>[] : ref.watch(_archiveReferenceValuesProvider((category: 'company_type', parent: s.companyGroup))).maybeWhen(data: (values) => values, orElse: () => const <String>[]);
      final subtypes = s.companyGroup == null ? const <String>[] : {...(_companyTypeMap[s.companyGroup] ?? const <String>[]), ...s.customCompanyTypes, ...persistedCompanyTypes}.toList();
      return _wizardStep('3', 'نوع الشركة ووثائقها', 'حدد إن كانت شركة أشخاص أو أموال، ثم نوعها التفصيلي.', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: groups.map((v) => _choiceChip(s.companyGroup == v, v, () => notifier.state = s.copyWith(companyGroup: v, companyType: null))).toList()),
        if (s.companyGroup != null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...subtypes.map((v) => _choiceChip(s.companyType == v, v, () => notifier.state = s.copyWith(companyType: v))),
            ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('إضافة نوع شركة'), onPressed: () => _addCustomReferenceValue(context, ref, 'نوع شركة جديد', 'company_type', s.companyGroup, (value) => notifier.state = s.copyWith(customCompanyTypes: [...s.customCompanyTypes, value], companyType: value))),
          ]),
        ],
      ]));
    }
    if (s.fileKind == 'procedure') {
      final persisted = ref.watch(_archiveReferenceValuesProvider((category: 'procedure_type', parent: null))).maybeWhen(data: (values) => values, orElse: () => const <String>[]);
      final items = {..._procedureTypeOptions, ...s.customProcedureTypes, ...persisted}.toList();
      return _wizardSimpleClassifier(context, ref, 'procedure_type', null, '3', 'نوع الإجراء / المعاملة', 'اختر تصنيف الإجراء أو أضف تصنيفاً جديداً.', items, s.procedureType, (v) => notifier.state = s.copyWith(procedureType: v), 'إضافة نوع إجراء', (v) => notifier.state = s.copyWith(customProcedureTypes: [...s.customProcedureTypes, v], procedureType: v));
    }
    if (s.fileKind == 'contract') {
      final persisted = ref.watch(_archiveReferenceValuesProvider((category: 'contract_type', parent: null))).maybeWhen(data: (values) => values, orElse: () => const <String>[]);
      final items = {..._contractTypeOptions, ...s.customContractTypes, ...persisted}.toList();
      return _wizardSimpleClassifier(context, ref, 'contract_type', null, '3', 'نوع العقد', 'اختر نوع العقد أو أضف نوعاً جديداً.', items, s.contractType, (v) => notifier.state = s.copyWith(contractType: v), 'إضافة نوع عقد', (v) => notifier.state = s.copyWith(customContractTypes: [...s.customContractTypes, v], contractType: v));
    }
    if (s.fileKind == 'poa') {
      final persisted = ref.watch(_archiveReferenceValuesProvider((category: 'poa_type', parent: null))).maybeWhen(data: (values) => values, orElse: () => const <String>[]);
      final items = {..._poaTypeOptions, ...s.customPoaTypes, ...persisted}.toList();
      return _wizardSimpleClassifier(context, ref, 'poa_type', null, '3', 'نوع الوكالة', 'اختر نوع الوكالة أو أضف نوعاً جديداً.', items, s.poaType, (v) => notifier.state = s.copyWith(poaType: v), 'إضافة نوع وكالة', (v) => notifier.state = s.copyWith(customPoaTypes: [...s.customPoaTypes, v], poaType: v));
    }
    return _wizardStep('3', 'أرشيف غير محدد', 'استخدم هذا المسار للمواد التي لا تنتمي لأي نوع معروف حالياً، مع إمكانية إضافة الوثائق المطلوبة يدوياً.', Text('سيتم حفظه كأرشيف يحتاج تصنيفاً لاحقاً.', style: AppTextStyles.bodyMediumSecondary));
  }

  Widget _wizardSimpleClassifier(BuildContext context, WidgetRef ref, String category, String? parent, String number, String title, String subtitle, List<String> items, String? selected, ValueChanged<String> onSelect, String addLabel, ValueChanged<String> onAdd) {
    return _wizardStep(number, title, subtitle, Wrap(spacing: 8, runSpacing: 8, children: [
      ...items.map((v) => _choiceChip(selected == v, v, () => onSelect(v))),
      ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text(addLabel), onPressed: () => _addCustomReferenceValue(context, ref, addLabel, category, parent, onAdd)),
    ]));
  }

  Widget _documentsHint(BuildContext context, WidgetRef ref, _ArchiveWizardSelection s) {
    final notifier = ref.read(_archiveWizardProvider.notifier);
    final docParent = s.fileKind ?? 'misc';
    final persistedDocs = ref.watch(_archiveReferenceValuesProvider((category: 'document_type', parent: docParent))).maybeWhen(data: (values) => values, orElse: () => const <String>[]);
    final docs = {..._defaultDocumentsFor(s), ...s.customDocumentTypes, ...persistedDocs}.toList();
    return _wizardStep('4', 'الوثائق والثبوتيات المتوقعة', 'هذه قائمة مساعدة فقط، ويمكن إضافة أي وثيقة يحتاجها المستخدم داخل الأرشفة.', Wrap(spacing: 8, runSpacing: 8, children: [
      ...docs.map((d) => Chip(label: Text(d), avatar: const Icon(Icons.description, size: 16))),
      ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('إضافة وثيقة'), onPressed: () => _addCustomReferenceValue(context, ref, 'اسم الوثيقة', 'document_type', docParent, (value) => notifier.state = s.copyWith(customDocumentTypes: [...s.customDocumentTypes, value]))),
    ]));
  }

  List<String> _defaultDocumentsFor(_ArchiveWizardSelection s) {
    List<String> unique(List<String> values) => values.where((v) => v.trim().isNotEmpty).toSet().toList();

    if (s.fileKind == 'case') {
      final docs = <String>[
        'استدعاء الدعوى',
        'الوكالة',
        'هوية/سجل الموكل',
        'هوية/بيانات الخصم',
        'المبرزات والثبوتيات',
        'ضبوط الجلسات',
        if ((s.caseType ?? '').contains('جزائ')) ...['ضبط الشرطة / الشكوى', 'قرار النيابة / قاضي التحقيق', 'قرار الإحالة'],
        if ((s.caseType ?? '').contains('شرع')) ...['بيان عائلي / إخراج قيد', 'عقد زواج / وثيقة طلاق', 'وثائق النفقة أو الحضانة'],
        if ((s.caseType ?? '').contains('تجار')) ...['سجل تجاري', 'فواتير / كشوف حساب', 'مراسلات تجارية'],
        if ((s.caseType ?? '').contains('إدار') || (s.caseType ?? '').contains('ادار')) ...['القرار الإداري المطعون فيه', 'التظلم الإداري', 'تبليغ القرار'],
        if ((s.courtLevel ?? '').contains('استئناف')) 'الحكم المستأنف',
        if ((s.courtLevel ?? '').contains('نقض')) 'القرار المطعون فيه وأسباب الطعن',
        if ((s.courtLevel ?? '').contains('مخاصمة')) 'أسباب المخاصمة والقرار محل المخاصمة',
        if (s.isRunning) 'موعد الجلسة / الإجراء القادم',
        if (s.isClosed) ...['الحكم / القرار النهائي', 'إشارة اكتساب الدرجة القطعية', 'إضبارة التنفيذ إن وجدت'],
      ];
      return unique(docs);
    }
    if (s.fileKind == 'company') {
      final docs = <String>[
        if (s.companyGroup == 'شركات أموال') ...['النظام الأساسي', 'طلب التأسيس', 'بيانات المساهمين / الشركاء', 'إيصال الرسوم'],
        if (s.companyGroup == 'شركات أشخاص') ...['عقد الشركة', 'بيانات الشركاء', 'إيصال الرسوم'],
        'السجل التجاري',
        'الرقم الوطني للشركة',
        'وثائق المقر / عقد الإيجار',
        'تفويض المدير / المفوض بالتوقيع',
        if (s.isRunning) 'موعد متابعة التأسيس / السجل',
        if (s.isClosed) 'آخر وضع قانوني محفوظ للشركة',
      ];
      return unique(docs.isEmpty ? ['وثائق الشركة الأساسية'] : docs);
    }
    if (s.fileKind == 'procedure') {
      return unique(['طلب المعاملة', 'الثبوتيات', 'الإيصالات', 'القرار / البيان النهائي إن وجد', if (s.isRunning) 'موعد المراجعة القادمة', if (s.isClosed) 'إشعار إنجاز أو حفظ المعاملة']);
    }
    if (s.fileKind == 'contract') {
      return unique(['نسخة العقد', 'وثائق الأطراف', 'مرفقات العقد', 'إيصالات أو حوالات مرتبطة', if (s.isRunning) 'موعد تجديد / متابعة', if (s.isClosed) 'مخالصة / انتهاء / فسخ إن وجد']);
    }
    if (s.fileKind == 'poa') return ['سند الوكالة', 'هوية الموكل', 'بيانات الوكيل', 'فرع النقابة / الكاتب بالعدل', 'نطاق الوكالة'];
    return ['اسم الوثيقة', 'وصف الوثيقة', 'مكان الأصل الورقي'];
  }

  bool _archiveSelectionReady(_ArchiveWizardSelection s) {
    if (s.archiveStatus == null || s.fileKind == null) return false;
    if (s.fileKind == 'case') return s.caseType != null && s.courtLevel != null;
    if (s.fileKind == 'company') return s.companyGroup != null && s.companyType != null;
    if (s.fileKind == 'procedure') return s.procedureType != null;
    if (s.fileKind == 'contract') return s.contractType != null;
    if (s.fileKind == 'poa') return s.poaType != null;
    return true;
  }

  Future<void> _addCustomReferenceValue(
    BuildContext context,
    WidgetRef ref,
    String title,
    String category,
    String? parentValue,
    ValueChanged<String> onAdd,
  ) async {
    await _addCustomValue(context, title, (value) async {
      await ref.read(archiveIntakeRepositoryProvider).addReferenceValue(category: category, value: value, parentValue: parentValue);
      ref.invalidate(_archiveReferenceValuesProvider((category: category, parent: parentValue)));
      onAdd(value);
    });
  }

  Future<void> _addCustomValue(BuildContext context, String title, FutureOr<void> Function(String value) onAdd) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'القيمة الجديدة')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('إضافة'))]));
    if (value == null || value.trim().isEmpty) return;
    await onAdd(value.trim());
  }

  Future<void> _startArchiveEntry(BuildContext context, WidgetRef ref, _ArchiveWizardSelection s) async {
    final route = _routeForArchiveKind(s.fileKind ?? 'misc');
    final requiredPermission = _permissionForArchiveKind(s.fileKind ?? 'misc');
    if (requiredPermission != null && !ref.read(permissionServiceProvider).can(requiredPermission)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_wizard', description: 'محاولة بدء إدخال أرشيف دون صلاحية للنوع المحدد', severity: 'warning');
      return;
    }
    await ref.read(auditServiceProvider).log(action: 'start_entry', category: 'archive', entityType: 'archive_wizard', entityTitle: _archiveSummary(s), description: 'بدء إدخال أرشيف قديم من المعالج الهرمي', after: {'status': s.archiveStatus, 'kind': s.fileKind, 'summary': _archiveSummary(s)}, severity: 'info');
    if (!context.mounted) return;
    if (route == null) {
      await _showMiscArchiveEntry(context, ref, s);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('سيتم فتح شاشة الإدخال الرسمية. الاختيار: ${_archiveSummary(s)}'), backgroundColor: AppColors.success));
    context.go(_routeWithArchiveQuery(route, s));
  }

  String _routeWithArchiveQuery(String route, _ArchiveWizardSelection s) {
    final uri = Uri(path: route, queryParameters: {
      'archiveStatus': s.archiveStatus ?? '',
      'archiveKind': s.fileKind ?? '',
      'archiveSummary': _archiveSummary(s),
      if (s.caseType != null) 'caseType': s.caseType!,
      if (s.courtLevel != null) 'courtLevel': s.courtLevel!,
      if (s.companyGroup != null) 'companyGroup': s.companyGroup!,
      if (s.companyType != null) 'companyType': s.companyType!,
      if (s.procedureType != null) 'procedureType': s.procedureType!,
      if (s.contractType != null) 'contractType': s.contractType!,
      if (s.poaType != null) 'poaType': s.poaType!,
    });
    return uri.toString();
  }

  Future<void> _showMiscArchiveEntry(BuildContext context, WidgetRef ref, _ArchiveWizardSelection s) async {
    final titleController = TextEditingController(text: 'أرشيف غير محدد - ${DateTime.now().toString().substring(0, 10)}');
    final notesController = TextEditingController();
    final customDocs = <String>[...s.customDocumentTypes];
    final files = <File>[];
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('إدخال ${_archiveSummary(s)}'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('هذا المسار مخصص لأي أرشيف لا يطابق الأنواع المعروفة. يمكن تسمية الوثائق ورفع الملفات الآن ثم تصنيفها لاحقاً من صندوق غير مصنف.', style: AppTextStyles.bodySmallSecondary),
                  const SizedBox(height: 12),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'اسم دفعة الأرشيف *')),
                  const SizedBox(height: 12),
                  TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات / وصف الأرشيف')),
                  const SizedBox(height: 12),
                  Text('أسماء الوثائق المطلوبة', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ..._defaultDocumentsFor(s).map((d) => Chip(label: Text(d), avatar: const Icon(Icons.description, size: 16))),
                    ...customDocs.map((d) => Chip(label: Text(d), avatar: const Icon(Icons.description, size: 16))),
                    ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('إضافة اسم وثيقة'), onPressed: () => _addCustomValue(ctx, 'اسم الوثيقة', (value) => setDialog(() => customDocs.add(value)))),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(files.isEmpty ? 'اختيار ملفات' : 'الملفات المختارة: ${files.length}'),
                    onPressed: () async {
                      final result = await fp.FilePicker.pickFiles(
                        allowMultiple: true,
                        type: fp.FileType.custom,
                        allowedExtensions:
                            AppConstants.allowedAttachmentExtensions,
                      );
                      if (result == null) return;
                      setDialog(() {
                        files
                          ..clear()
                          ..addAll(result.paths.whereType<String>().map(File.new));
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('حفظ كأرشيف غير مصنف'),
              onPressed: titleController.text.trim().isEmpty
                  ? null
                  : () async {
                      final batchId = await ref.read(archiveIntakeRepositoryProvider).createBatch(
                            name: titleController.text.trim(),
                            sourceType: 'mixed',
                            createdBy: ref.read(authControllerProvider).user?.fullName,
                            notes: [
                              _archiveSummary(s),
                              if (customDocs.isNotEmpty) 'وثائق مخصصة: ${customDocs.join('، ')}',
                              if (notesController.text.trim().isNotEmpty) notesController.text.trim(),
                            ].join('\n'),
                          );
                      if (files.isNotEmpty) {
                        await ref.read(archiveIntakeRepositoryProvider).importFilesToBatch(batchId, files);
                      }
                      await ref.read(auditServiceProvider).log(action: 'create_misc', category: 'archive', entityType: 'archive_batch', entityId: '$batchId', entityTitle: titleController.text.trim(), description: 'إنشاء أرشيف غير محدد من المعالج', after: {'files': files.length, 'summary': _archiveSummary(s)}, severity: 'info');
                      ref.read(_archiveIntakeRefreshProvider.notifier).state++;
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
            ),
          ],
        ),
      ),
    );
  }

  String? _permissionForArchiveKind(String kind) {
    switch (kind) {
      case 'case': return PermissionKeys.casesCreateNew;
      case 'company': return PermissionKeys.companiesCreate;
      case 'procedure': return PermissionKeys.proceduresCreate;
      case 'contract': return PermissionKeys.contractsCreate;
      case 'poa': return PermissionKeys.poaCreate;
      default: return PermissionKeys.archiveIntakeCreate;
    }
  }

  String? _routeForArchiveKind(String kind) {
    switch (kind) {
      case 'case': return '/cases/create';
      case 'company': return '/companies/create';
      case 'procedure': return '/procedures/create';
      case 'contract': return '/contracts/create';
      case 'poa': return '/poa';
      default: return null;
    }
  }

  String _archiveSummary(_ArchiveWizardSelection s) {
    final parts = <String>[
      if (s.archiveStatus != null) (s.isRunning ? 'جارٍ' : 'منتهٍ'),
      _archiveFileKindOptions[s.fileKind] ?? s.fileKind ?? '',
      if (s.caseType != null) s.caseType!,
      if (s.courtLevel != null) s.courtLevel!,
      if (s.companyGroup != null) s.companyGroup!,
      if (s.companyType != null) s.companyType!,
      if (s.procedureType != null) s.procedureType!,
      if (s.contractType != null) s.contractType!,
      if (s.poaType != null) s.poaType!,
    ].where((p) => p.trim().isNotEmpty).toList();
    return parts.join(' > ');
  }

  Widget _importTemplatesPanel(BuildContext context, WidgetRef ref) {
    final canExport = ref.watch(permissionServiceProvider).can(PermissionKeys.archiveIntakeImportExcel);
    final templates = const [
      (key: 'contacts', title: 'الأشخاص والجهات', file: 'contacts_template.csv', icon: Icons.people_alt),
      (key: 'cases', title: 'الدعاوى', file: 'cases_template.csv', icon: Icons.gavel),
      (key: 'poa', title: 'الوكالات', file: 'poa_template.csv', icon: Icons.assignment_ind),
      (key: 'documents', title: 'المستندات', file: 'documents_template.csv', icon: Icons.description),
      (key: 'opening_balances', title: 'الأرصدة الافتتاحية', file: 'opening_balances_template.csv', icon: Icons.account_balance_wallet),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'صدّر القالب المناسب، املأه من الأرشيف القديم، ثم استورده لاحقاً ضمن دفعة Excel / CSV بعد تثبيت حقول المطابقة النهائية.',
              style: AppTextStyles.bodyMediumSecondary,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: templates
                  .map(
                    (t) => OutlinedButton.icon(
                      icon: Icon(t.icon, size: 18),
                      label: Text(t.title),
                      onPressed: canExport ? () => _exportImportTemplate(context, ref, t.key, t.file) : null,
                    ),
                  )
                  .toList(),
            ),
            if (!canExport) ...[
              const SizedBox(height: 8),
              Text('لا تملك صلاحية تصدير/استيراد قوالب الأرشيف.', style: AppTextStyles.bodySmallSecondary.copyWith(color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportImportTemplate(BuildContext context, WidgetRef ref, String templateKey, String fileName) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveIntakeImportExcel)) {
      await ref.read(auditServiceProvider).log(
        action: 'access_denied',
        category: 'archive',
        entityType: 'archive_template',
        entityTitle: fileName,
        description: 'محاولة تصدير قالب استيراد أرشيف دون صلاحية',
        severity: 'warning',
      );
      return;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, AppConstants.appDataDirectoryName, 'import_templates'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(path.join(dir.path, fileName));
    await _writeArabicCsv(file, _templateContent(templateKey));
    await ref.read(auditServiceProvider).log(
      action: 'export_template',
      category: 'archive',
      entityType: 'archive_template',
      entityTitle: file.path,
      description: 'تصدير قالب استيراد للأرشيف القديم',
      after: {'template': templateKey},
      severity: 'info',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ القالب: ${file.path}'), backgroundColor: AppColors.success));
    }
  }

  String _templateContent(String key) {
    switch (key) {
      case 'contacts':
        return 'full_name,person_type,phone,email,national_id,address,notes\n"أحمد محمد","موكل","09xxxxxxxx","","","دمشق","مثال"\n';
      case 'cases':
        return 'internal_number,case_type,subject,court,base_number,status,client_name,opponent_name,next_session_date,notes\n"C-2026-001","مدني","مطالبة مالية","بداية مدني دمشق","123/2026","active","","","2026-01-01",""\n';
      case 'poa':
        return 'poa_number,poa_type,issued_at,delegate_name,bar_branch,principal_name,agent_name,notes\n"","عامة","2026-01-01","","دمشق","","",""\n';
      case 'documents':
        return 'file_name,document_type,related_file_type,related_file_number,paper_original_saved,paper_location,box,shelf,paper_folder,can_destroy_original,reviewed_by,notes\n"example.pdf","مستند أرشيف","دعوى","C-2026-001","yes","الخزانة 1","A-01","2","ملف ورقي 5","no","",""\n';
      case 'opening_balances':
        return 'client_name,file_number,fee_agreement_total,paid_amount,office_expenses,client_expenses,notes\n"","","0","0","0","0",""\n';
      default:
        return 'field_1,field_2,notes\n"","",""\n';
    }
  }

  Future<List<Map<String, Object?>>> _loadPaperArchiveRows(WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    await db.ensureArchiveTables();
    final rows = await db.customSelect('''
      SELECT
        d.id AS document_id,
        d.doc_name AS doc_name,
        d.doc_type AS doc_type,
        d.file_path AS file_path,
        d.date_added AS date_added,
        m.paper_original_saved AS paper_original_saved,
        m.paper_location AS paper_location,
        m.box AS box,
        m.shelf AS shelf,
        m.paper_folder AS paper_folder,
        m.can_destroy_original AS can_destroy_original,
        m.reviewed_by AS reviewed_by,
        m.reviewed_at AS reviewed_at,
        m.notes AS paper_notes
      FROM document_paper_metadata m
      JOIN documents d ON d.id = m.document_id
      ORDER BY m.paper_location COLLATE NOCASE, m.box COLLATE NOCASE, m.shelf COLLATE NOCASE, d.doc_name COLLATE NOCASE
    ''').get();
    return rows.map((row) => row.data).toList();
  }

  Future<void> _showPaperArchiveReport(BuildContext context, WidgetRef ref) async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.archiveQualityView)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'paper_archive', description: 'محاولة فتح كشف الأرشيف الورقي دون صلاحية', severity: 'warning');
      return;
    }
    final search = TextEditingController();
    String savedFilter = 'all';
    bool destroyableOnly = false;
    bool unreviewedOnly = false;
    await ref.read(auditServiceProvider).log(action: 'view', category: 'archive', entityType: 'paper_archive', description: 'عرض كشف الأرشيف الورقي', severity: 'info');
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('كشف الأرشيف الورقي'),
          content: SizedBox(
            width: 980,
            height: 640,
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _loadPaperArchiveRows(ref),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final filtered = _filterPaperRows(snapshot.data!, search.text, savedFilter, destroyableOnly, unreviewedOnly);
                return Column(
                  children: [
                    TextField(
                      controller: search,
                      decoration: const InputDecoration(labelText: 'بحث باسم المستند أو مكان الأصل أو الصندوق أو الرف', prefixIcon: Icon(Icons.search)),
                      onChanged: (_) => setDialog(() {}),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _archiveReviewFilterChip('all', 'كل الأصول', savedFilter, (v) => setDialog(() => savedFilter = v)),
                          _archiveReviewFilterChip('saved', 'الأصل محفوظ', savedFilter, (v) => setDialog(() => savedFilter = v)),
                          _archiveReviewFilterChip('missing', 'الأصل غير محفوظ', savedFilter, (v) => setDialog(() => savedFilter = v)),
                          FilterChip(label: const Text('قابل للإتلاف'), selected: destroyableOnly, onSelected: (v) => setDialog(() => destroyableOnly = v)),
                          const SizedBox(width: 8),
                          FilterChip(label: const Text('غير مراجع رقمياً'), selected: unreviewedOnly, onSelected: (v) => setDialog(() => unreviewedOnly = v)),
                          if (search.text.isNotEmpty || savedFilter != 'all' || destroyableOnly || unreviewedOnly)
                            TextButton.icon(
                              icon: const Icon(Icons.filter_alt_off, size: 16),
                              label: const Text('مسح'),
                              onPressed: () => setDialog(() {
                                search.clear();
                                savedFilter = 'all';
                                destroyableOnly = false;
                                unreviewedOnly = false;
                              }),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _paperArchiveStatsBar(filtered),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('لا توجد نتائج مطابقة في الأرشيف الورقي.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, index) => _paperArchiveRow(context, ref, filtered[index]),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.fact_check),
              label: const Text('تعليم المعروض كمراجع'),
              onPressed: () async {
                final rows = await _loadPaperArchiveRows(ref);
                final visible = _filterPaperRows(rows, search.text, savedFilter, destroyableOnly, unreviewedOnly);
                if (ctx.mounted) Navigator.pop(ctx);
                await _markPaperRowsReviewed(context, ref, visible);
              },
            ),
            if (permissions.can(PermissionKeys.archiveQualityExport))
              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('تصدير المعروض CSV'),
                onPressed: () async {
                  final rows = await _loadPaperArchiveRows(ref);
                  final visible = _filterPaperRows(rows, search.text, savedFilter, destroyableOnly, unreviewedOnly);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _exportPaperArchiveRows(context, ref, visible);
                },
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  List<Map<String, Object?>> _filterPaperRows(List<Map<String, Object?>> rows, String rawQuery, String savedFilter, bool destroyableOnly, bool unreviewedOnly) {
    final query = _normalizeSearchText(rawQuery);
    return rows.where((row) {
      final saved = ((row['paper_original_saved'] as int?) ?? 0) == 1;
      final destroyable = ((row['can_destroy_original'] as int?) ?? 0) == 1;
      final reviewed = ((row['reviewed_by'] as String?) ?? '').trim().isNotEmpty;
      final savedOk = savedFilter == 'all' || (savedFilter == 'saved' && saved) || (savedFilter == 'missing' && !saved);
      final destroyOk = !destroyableOnly || destroyable;
      final reviewedOk = !unreviewedOnly || !reviewed;
      final haystack = _normalizeSearchText([
        row['doc_name'], row['doc_type'], row['paper_location'], row['box'], row['shelf'], row['paper_folder'], row['reviewed_by'], row['paper_notes']
      ].whereType<Object>().join(' '));
      final queryOk = query.isEmpty || haystack.contains(query);
      return savedOk && destroyOk && reviewedOk && queryOk;
    }).toList();
  }

  Widget _paperArchiveStatsBar(List<Map<String, Object?>> rows) {
    final saved = rows.where((row) => ((row['paper_original_saved'] as int?) ?? 0) == 1).length;
    final missing = rows.length - saved;
    final destroyable = rows.where((row) => ((row['can_destroy_original'] as int?) ?? 0) == 1).length;
    final unreviewed = rows.where((row) => ((row['reviewed_by'] as String?) ?? '').trim().isEmpty).length;
    final reviewed = rows.length - unreviewed;
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _mini('المعروض', rows.length),
          _mini('محفوظ', saved),
          _mini('غير محفوظ', missing),
          _mini('قابل للإتلاف', destroyable),
          _mini('مراجع', reviewed),
          _mini('غير مراجع', unreviewed),
        ],
      ),
    );
  }

  Future<void> _markPaperRowsReviewed(BuildContext context, WidgetRef ref, List<Map<String, Object?>> rows) async {
    final ids = rows
        .where((row) => ((row['reviewed_by'] as String?) ?? '').trim().isEmpty)
        .map((row) => row['document_id'] as int?)
        .whereType<int>()
        .toList();
    if (ids.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا توجد عناصر غير مراجعة ضمن المعروض.'), backgroundColor: AppColors.info));
      return;
    }
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تعليم المعروض كمراجع'),
            content: Text('سيتم تعليم ${ids.length} مستند كمراجع رقمياً باسم المستخدم الحالي. هل تريد المتابعة؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    final user = ref.read(authControllerProvider).user?.fullName ?? 'المكتب';
    final db = ref.read(databaseProvider);
    await db.ensureArchiveTables();
    for (final id in ids) {
      await db.customStatement('''
        UPDATE document_paper_metadata
        SET reviewed_by = ?, reviewed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE document_id = ?
      ''', [user, id]);
    }
    await ref.read(auditServiceProvider).log(action: 'bulk_review', category: 'archive', entityType: 'paper_archive', description: 'تعليم مجموعة أصول ورقية كمراجعة رقمياً', after: {'count': ids.length, 'reviewedBy': user}, severity: 'info');
    _refreshArchiveDocumentProviders(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعليم ${ids.length} مستند كمراجع رقمياً'), backgroundColor: AppColors.success));
      await _showPaperArchiveReport(context, ref);
    }
  }

  Widget _paperArchiveRow(BuildContext context, WidgetRef ref, Map<String, Object?> row) {
    final saved = ((row['paper_original_saved'] as int?) ?? 0) == 1;
    final destroyable = ((row['can_destroy_original'] as int?) ?? 0) == 1;
    final reviewedBy = ((row['reviewed_by'] as String?) ?? '').trim();
    final reviewedAt = ((row['reviewed_at'] as String?) ?? '').trim();
    final location = _paperLocationFromRow(row);
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: (saved ? AppColors.success : AppColors.warning).withOpacity(0.12), child: Icon(saved ? Icons.inventory_2 : Icons.warning_amber, color: saved ? AppColors.success : AppColors.warning)),
        title: Text('${row['doc_name'] ?? 'مستند'}', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          saved ? 'الأصل محفوظ' : 'الأصل غير محفوظ',
          if (destroyable) 'قابل للإتلاف',
          if (location.isNotEmpty) location,
          if (reviewedBy.isNotEmpty) 'راجعه: $reviewedBy',
          if (reviewedAt.isNotEmpty) 'بتاريخ: ${reviewedAt.length >= 10 ? reviewedAt.substring(0, 10) : reviewedAt}',
        ].join(' • ')),
        trailing: Wrap(
          spacing: 6,
          children: [
            if (reviewedBy.isEmpty)
              TextButton.icon(
                icon: const Icon(Icons.fact_check, size: 16),
                label: const Text('تعليم كمراجع'),
                onPressed: () => _markPaperArchiveReviewed(context, ref, row),
              ),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('نسخ'),
              onPressed: () => _copyPaperArchiveRow(context, row),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('تعديل'),
              onPressed: () => _editPaperArchiveMetadata(context, ref, row),
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('فتح المستند'),
              onPressed: () => context.go('/documents/${row['document_id']}'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPaperArchiveRow(BuildContext context, Map<String, Object?> row) async {
    final lines = <String>[
      'مستند: ${row['doc_name'] ?? ''}',
      'رقم المستند: ${row['document_id'] ?? ''}',
      'نوع المستند: ${row['doc_type'] ?? ''}',
      'الأصل الورقي: ${((row['paper_original_saved'] as int?) ?? 0) == 1 ? 'محفوظ' : 'غير محفوظ'}',
      if (_paperLocationFromRow(row).isNotEmpty) 'الموقع الكامل: ${_paperLocationFromRow(row)}',
      'قابل للإتلاف: ${((row['can_destroy_original'] as int?) ?? 0) == 1 ? 'نعم' : 'لا'}',
      if (((row['reviewed_by'] as String?) ?? '').trim().isNotEmpty) 'راجع النسخة الرقمية: ${row['reviewed_by']}',
      if (((row['reviewed_at'] as String?) ?? '').trim().isNotEmpty) 'تاريخ المراجعة: ${row['reviewed_at']}',
      if (((row['paper_notes'] as String?) ?? '').trim().isNotEmpty) 'ملاحظات: ${row['paper_notes']}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تم نسخ بيانات الأصل الورقي'), backgroundColor: AppColors.success));
    }
  }

  void _refreshArchiveDocumentProviders(WidgetRef ref) {
    ref.invalidate(documentsFutureProvider);
    ref.invalidate(uiDocumentsProvider);
    ref.invalidate(uiFilesProvider);
  }

  Future<void> _markPaperArchiveReviewed(BuildContext context, WidgetRef ref, Map<String, Object?> row) async {
    final documentId = row['document_id'] as int?;
    if (documentId == null) return;
    final user = ref.read(authControllerProvider).user?.fullName ?? 'المكتب';
    final db = ref.read(databaseProvider);
    await db.ensureArchiveTables();
    await db.customStatement('''
      UPDATE document_paper_metadata
      SET reviewed_by = ?, reviewed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE document_id = ?
    ''', [user, documentId]);
    await ref.read(auditServiceProvider).log(action: 'review', category: 'archive', entityType: 'paper_archive', entityId: '$documentId', entityTitle: '${row['doc_name'] ?? ''}', description: 'تعليم الأصل الورقي كمراجع رقمياً', after: {'reviewedBy': user}, severity: 'info');
    _refreshArchiveDocumentProviders(ref);
    if (context.mounted) {
      Navigator.pop(context);
      await _showPaperArchiveReport(context, ref);
    }
  }

  Future<void> _editPaperArchiveMetadata(BuildContext context, WidgetRef ref, Map<String, Object?> row) async {
    final documentId = row['document_id'] as int?;
    if (documentId == null) return;
    bool paperSaved = ((row['paper_original_saved'] as int?) ?? 0) == 1;
    bool canDestroy = ((row['can_destroy_original'] as int?) ?? 0) == 1;
    final location = TextEditingController(text: (row['paper_location'] as String?) ?? '');
    final box = TextEditingController(text: (row['box'] as String?) ?? '');
    final shelf = TextEditingController(text: (row['shelf'] as String?) ?? '');
    final folder = TextEditingController(text: (row['paper_folder'] as String?) ?? '');
    final reviewedBy = TextEditingController(text: (row['reviewed_by'] as String?) ?? '');
    final notes = TextEditingController(text: (row['paper_notes'] as String?) ?? '');

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
              title: Text('تعديل بيانات الأصل الورقي — ${row['doc_name'] ?? ''}'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: paperSaved,
                        title: const Text('الأصل الورقي محفوظ'),
                        onChanged: (v) => setDialog(() => paperSaved = v ?? false),
                      ),
                      TextField(controller: location, decoration: const InputDecoration(labelText: 'مكان الأصل')),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: box, decoration: const InputDecoration(labelText: 'الصندوق'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: shelf, decoration: const InputDecoration(labelText: 'الرف'))),
                      ]),
                      const SizedBox(height: 8),
                      TextField(controller: folder, decoration: const InputDecoration(labelText: 'المجلد الورقي')),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canDestroy,
                        title: const Text('يجوز إتلاف الأصل لاحقاً'),
                        onChanged: (v) => setDialog(() => canDestroy = v ?? false),
                      ),
                      TextField(controller: reviewedBy, decoration: const InputDecoration(labelText: 'من راجع النسخة الرقمية؟')),
                      const SizedBox(height: 8),
                      TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok) return;

    final db = ref.read(databaseProvider);
    await db.ensureArchiveTables();
    await db.customStatement('''
      INSERT OR REPLACE INTO document_paper_metadata(
        document_id, paper_original_saved, paper_location, box, shelf, paper_folder,
        can_destroy_original, reviewed_by, reviewed_at, notes, updated_at
      ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, CURRENT_TIMESTAMP)
    ''', [
      documentId,
      paperSaved ? 1 : 0,
      location.text.trim().isEmpty ? null : location.text.trim(),
      box.text.trim().isEmpty ? null : box.text.trim(),
      shelf.text.trim().isEmpty ? null : shelf.text.trim(),
      folder.text.trim().isEmpty ? null : folder.text.trim(),
      canDestroy ? 1 : 0,
      reviewedBy.text.trim().isEmpty ? null : reviewedBy.text.trim(),
      notes.text.trim().isEmpty ? null : notes.text.trim(),
    ]);
    await ref.read(auditServiceProvider).log(action: 'edit', category: 'archive', entityType: 'paper_archive', entityId: '$documentId', entityTitle: '${row['doc_name'] ?? ''}', description: 'تعديل بيانات الأصل الورقي', after: {'paperSaved': paperSaved, 'location': location.text.trim(), 'box': box.text.trim(), 'shelf': shelf.text.trim(), 'folder': folder.text.trim(), 'canDestroy': canDestroy, 'reviewedBy': reviewedBy.text.trim()}, severity: 'info');
    _refreshArchiveDocumentProviders(ref);
    if (context.mounted) {
      Navigator.pop(context);
      await _showPaperArchiveReport(context, ref);
    }
  }

  String _paperLocationFromRow(Map<String, Object?> row) {
    final parts = <String>[
      ((row['paper_location'] as String?) ?? '').trim(),
      if (((row['box'] as String?) ?? '').trim().isNotEmpty) 'صندوق ${(row['box'] as String).trim()}',
      if (((row['shelf'] as String?) ?? '').trim().isNotEmpty) 'رف ${(row['shelf'] as String).trim()}',
      if (((row['paper_folder'] as String?) ?? '').trim().isNotEmpty) 'مجلد ${(row['paper_folder'] as String).trim()}',
    ].where((value) => value.isNotEmpty).toList();
    return parts.join(' • ');
  }

  Future<void> _exportPaperArchiveRows(BuildContext context, WidgetRef ref, List<Map<String, Object?>> rows) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport)) return;
    final buffer = StringBuffer('documentId,name,type,paperSaved,location,box,shelf,folder,canDestroy,reviewedBy,reviewedAt,notes\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final row in rows) {
      buffer.writeln([
        row['document_id'], esc(row['doc_name']), esc(row['doc_type']), ((row['paper_original_saved'] as int?) ?? 0) == 1,
        esc(row['paper_location']), esc(row['box']), esc(row['shelf']), esc(row['paper_folder']), ((row['can_destroy_original'] as int?) ?? 0) == 1,
        esc(row['reviewed_by']), esc(row['reviewed_at']), esc(row['paper_notes']),
      ].join(','));
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, AppConstants.appDataDirectoryName, 'paper_archive_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(path.join(dir.path, 'paper_archive_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await _writeArabicCsv(file, buffer.toString());
    await ref.read(auditServiceProvider).log(action: 'export', category: 'archive', entityType: 'paper_archive', entityTitle: file.path, description: 'تصدير كشف الأرشيف الورقي CSV', after: {'count': rows.length}, severity: 'info');
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تصدير كشف الأرشيف الورقي: ${file.path}'), backgroundColor: AppColors.success));
  }

  Future<void> _showActiveNeedsCompletion(BuildContext context, WidgetRef ref) async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.archiveInboxView)) {
      await ref.read(auditServiceProvider).log(
        action: 'access_denied',
        category: 'archive',
        entityType: 'archive_completion',
        description: 'محاولة فتح ملفات الأرشيف التي تحتاج استكمال دون صلاحية',
        severity: 'warning',
      );
      return;
    }
    final files = ref.read(filesProvider)
        .where((file) => file.status == FileStatus.active && (file.hasDeficiencies || file.hasMissingDocuments || !file.hasBaseNumber))
        .toList()
      ..sort((a, b) => b.deficiencyCount.compareTo(a.deficiencyCount));
    await ref.read(auditServiceProvider).log(
      action: 'view',
      category: 'archive',
      entityType: 'archive_completion',
      description: 'عرض الملفات الجارية التي تحتاج استكمال',
      after: {'count': files.length},
      severity: 'info',
    );
    if (!context.mounted) return;
    final search = TextEditingController();
    FileType? typeFilter;
    String reasonFilter = 'all';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final filtered = _filteredCompletionFiles(files, search.text, typeFilter, reasonFilter);
          return AlertDialog(
            title: const Text('ملفات جارية تحتاج استكمال'),
            content: SizedBox(
              width: 940,
              height: 620,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(labelText: 'بحث برقم الملف أو العنوان أو الجهة', prefixIcon: Icon(Icons.search)),
                    onChanged: (_) => setDialog(() {}),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _completionTypeChip(null, 'كل الأنواع', Icons.folder_copy, typeFilter, (v) => setDialog(() => typeFilter = v)),
                        ...FileType.values.map((type) => _completionTypeChip(type, type.displayName, _fileTypeIcon(type), typeFilter, (v) => setDialog(() => typeFilter = v))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _completionReasonChip('all', 'كل أسباب الاستكمال', reasonFilter, (v) => setDialog(() => reasonFilter = v)),
                        _completionReasonChip('deficiencies', 'نواقص', reasonFilter, (v) => setDialog(() => reasonFilter = v)),
                        _completionReasonChip('missing_docs', 'مستندات ناقصة', reasonFilter, (v) => setDialog(() => reasonFilter = v)),
                        _completionReasonChip('missing_base', 'بلا رقم/مرجع', reasonFilter, (v) => setDialog(() => reasonFilter = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _completionStatsBar(filtered),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('لا توجد ملفات جارية ناقصة مطابقة.'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, index) {
                              final file = filtered[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(backgroundColor: AppColors.error.withOpacity(0.12), child: Icon(_fileTypeIcon(file.type), color: AppColors.error)),
                                  title: Text('${file.fileNumber} — ${file.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(_completionReasons(file).join(' • ')),
                                  trailing: Wrap(
                                    spacing: 6,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.copy, size: 16),
                                        label: const Text('نسخ المطلوب'),
                                        onPressed: () => _copyCompletionFileDetails(context, file),
                                      ),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.open_in_new, size: 16),
                                        label: const Text('فتح الملف'),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _openOfficeFile(context, file);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              if (search.text.isNotEmpty || typeFilter != null || reasonFilter != 'all')
                TextButton.icon(
                  icon: const Icon(Icons.filter_alt_off, size: 16),
                  label: const Text('مسح الفلاتر'),
                  onPressed: () => setDialog(() {
                    search.clear();
                    typeFilter = null;
                    reasonFilter = 'all';
                  }),
                ),
              if (ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport))
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('تصدير المعروض CSV'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _exportCompletionFiles(context, ref, filtered);
                  },
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            ],
          );
        },
      ),
    );
  }

  List<FileItem> _filteredCompletionFiles(List<FileItem> files, String rawQuery, FileType? typeFilter, String reasonFilter) {
    final query = _normalizeSearchText(rawQuery);
    return files.where((file) {
      final typeOk = typeFilter == null || file.type == typeFilter;
      final reasonOk = switch (reasonFilter) {
        'deficiencies' => file.hasDeficiencies,
        'missing_docs' => file.hasMissingDocuments || file.documentCount == 0,
        'missing_base' => !file.hasBaseNumber,
        _ => true,
      };
      final queryOk = query.isEmpty ||
          _containsSearch(file.fileNumber, query) ||
          _containsSearch(file.title, query) ||
          _containsSearch(file.court, query) ||
          _containsSearch(file.baseNumber, query);
      return typeOk && reasonOk && queryOk;
    }).toList();
  }

  Widget _completionTypeChip(FileType? value, String label, IconData icon, FileType? selected, ValueChanged<FileType?> onSelected) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary),
        selected: isSelected,
        label: Text(label),
        selectedColor: AppColors.primaryNavy.withOpacity(0.10),
        labelStyle: TextStyle(color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        onSelected: (_) => onSelected(value),
      ),
    );
  }

  Widget _completionReasonChip(String value, String label, String selected, ValueChanged<String> onSelected) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        selectedColor: AppColors.warning.withOpacity(0.12),
        labelStyle: TextStyle(color: isSelected ? AppColors.warning : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        onSelected: (_) => onSelected(value),
      ),
    );
  }

  Widget _completionStatsBar(List<FileItem> files) {
    final missingBase = files.where((file) => !file.hasBaseNumber).length;
    final missingDocs = files.where((file) => file.hasMissingDocuments || file.documentCount == 0).length;
    final deficiencies = files.where((file) => file.hasDeficiencies).length;
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _mini('المعروض', files.length),
          _mini('نواقص', deficiencies),
          _mini('مستندات ناقصة', missingDocs),
          _mini('بلا رقم/مرجع', missingBase),
        ],
      ),
    );
  }

  Future<void> _copyCompletionFileDetails(BuildContext context, FileItem file) async {
    final lines = <String>[
      'ملف يحتاج استكمال',
      'رقم الملف: ${file.fileNumber}',
      'العنوان: ${file.title}',
      'النوع: ${file.type.displayName}',
      if (file.subCategory.isNotEmpty) 'التصنيف: ${file.subCategory}',
      if (file.court.isNotEmpty) 'الجهة/المحكمة: ${file.court}',
      if ((file.baseNumber ?? '').isNotEmpty) 'رقم/مرجع: ${file.baseNumber}',
      'عدد المستندات: ${file.documentCount}',
      'أسباب الاستكمال:',
      ..._completionReasons(file).map((reason) => '- $reason'),
      if (file.nextSessionDate != null) 'الموعد القادم: ${file.nextSessionDate!.toIso8601String()}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تم نسخ بيانات الاستكمال'), backgroundColor: AppColors.success));
    }
  }

  Future<void> _exportCompletionFiles(BuildContext context, WidgetRef ref, List<FileItem> files) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_completion', description: 'محاولة تصدير ملفات تحتاج استكمال دون صلاحية', severity: 'warning');
      return;
    }
    final buffer = StringBuffer('id,number,title,type,subcategory,status,court,baseNumber,documentCount,deficiencyCount,missingBase,missingDocuments,nextDate,reasons\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final file in files) {
      buffer.writeln([
        esc(file.id),
        esc(file.fileNumber),
        esc(file.title),
        esc(file.type.displayName),
        esc(file.subCategory),
        esc(file.status.displayName),
        esc(file.court),
        esc(file.baseNumber),
        file.documentCount,
        file.deficiencyCount,
        !file.hasBaseNumber,
        file.hasMissingDocuments,
        esc(file.nextSessionDate?.toIso8601String()),
        esc(_completionReasons(file).join(' | ')),
      ].join(','));
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, AppConstants.appDataDirectoryName, 'archive_completion_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(path.join(dir.path, 'archive_completion_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await _writeArabicCsv(file, buffer.toString());
    await ref.read(auditServiceProvider).log(action: 'export', category: 'archive', entityType: 'archive_completion', entityTitle: file.path, description: 'تصدير الملفات الجارية التي تحتاج استكمال CSV', after: {'count': files.length}, severity: 'info');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تصدير ملفات الاستكمال: ${file.path}'), backgroundColor: AppColors.success));
    }
  }

  List<String> _completionReasons(FileItem file) {
    return [
      if (!file.hasBaseNumber) 'بانتظار رقم أساس/مرجع',
      if (file.hasDeficiencies) 'نواقص: ${file.deficiencyCount}',
      if (file.hasMissingDocuments) 'مستندات ناقصة',
      if (file.documentCount == 0) 'لا توجد مستندات رقمية',
    ];
  }

  IconData _fileTypeIcon(FileType type) {
    switch (type) {
      case FileType.caseFile:
        return Icons.gavel;
      case FileType.contract:
        return Icons.description;
      case FileType.company:
        return Icons.business;
      case FileType.adminProcedure:
        return Icons.assignment;
      case FileType.agency:
        return Icons.assignment_ind;
    }
  }

  void _openOfficeFile(BuildContext context, FileItem file) {
    switch (file.type) {
      case FileType.caseFile:
        context.go('/cases/${file.id}');
        return;
      case FileType.contract:
        context.go('/contracts/${file.id}');
        return;
      case FileType.company:
        context.go('/companies/${file.id}');
        return;
      case FileType.adminProcedure:
        context.go('/procedures/${file.id}');
        return;
      case FileType.agency:
        context.go('/poa/${file.id}');
        return;
    }
  }

  Widget _batchesList(WidgetRef ref) {
    final repo = ref.watch(archiveIntakeRepositoryProvider);
    final query = _normalizeSearchText(ref.watch(_archiveBatchSearchProvider));
    final sourceFilter = ref.watch(_archiveBatchSourceFilterProvider);
    final statusFilter = ref.watch(_archiveBatchStatusFilterProvider);
    return FutureBuilder(
      future: repo.getBatches(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final allBatches = snapshot.data!;
        final batches = allBatches.where((b) {
          final queryOk = query.isEmpty ||
              _containsSearch(b.name, query) ||
              _containsSearch(_sourceLabel(b.sourceType), query) ||
              _containsSearch(_statusLabel(b.status), query) ||
              _containsSearch(b.createdBy, query) ||
              _containsSearch(b.sourcePath, query) ||
              _containsSearch(b.notes, query);
          final sourceOk = sourceFilter == 'all' || b.sourceType == sourceFilter;
          final statusOk = statusFilter == 'all' || b.status == statusFilter;
          return queryOk && sourceOk && statusOk;
        }).toList();
        final shownFiles = batches.fold<int>(0, (sum, b) => sum + b.totalFiles);
        final shownUnclassified = batches.fold<int>(0, (sum, b) => sum + b.unclassifiedFiles);
        final shownDuplicates = batches.fold<int>(0, (sum, b) => sum + b.duplicateFiles);
        final shownFailed = batches.fold<int>(0, (sum, b) => sum + b.failedFiles);
        final shownApproved = batches.fold<int>(0, (sum, b) => sum + b.approvedFiles);
        if (allBatches.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text('لا توجد دفعات إدخال بعد. ابدأ بإنشاء دفعة من المسارات أعلاه.', style: AppTextStyles.bodyMediumSecondary),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: ValueKey('archive-batch-search-${query.isEmpty ? 'empty' : 'active'}'),
              initialValue: query,
              decoration: const InputDecoration(labelText: 'بحث في دفعات الأرشيف', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => ref.read(_archiveBatchSearchProvider.notifier).state = value,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _archiveReviewFilterChip('all', 'كل المصادر', sourceFilter, (v) => ref.read(_archiveBatchSourceFilterProvider.notifier).state = v),
                  _archiveReviewFilterChip('paper', 'ورقي', sourceFilter, (v) => ref.read(_archiveBatchSourceFilterProvider.notifier).state = v),
                  _archiveReviewFilterChip('electronic', 'إلكتروني', sourceFilter, (v) => ref.read(_archiveBatchSourceFilterProvider.notifier).state = v),
                  _archiveReviewFilterChip('excel', 'Excel / CSV', sourceFilter, (v) => ref.read(_archiveBatchSourceFilterProvider.notifier).state = v),
                  _archiveReviewFilterChip('mixed', 'مختلط', sourceFilter, (v) => ref.read(_archiveBatchSourceFilterProvider.notifier).state = v),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _archiveReviewFilterChip('all', 'كل الحالات', statusFilter, (v) => ref.read(_archiveBatchStatusFilterProvider.notifier).state = v),
                  _archiveReviewFilterChip('new', 'جديدة', statusFilter, (v) => ref.read(_archiveBatchStatusFilterProvider.notifier).state = v),
                  _archiveReviewFilterChip('waiting_review', 'بانتظار المراجعة', statusFilter, (v) => ref.read(_archiveBatchStatusFilterProvider.notifier).state = v),
                  _archiveReviewFilterChip('completed', 'مكتملة', statusFilter, (v) => ref.read(_archiveBatchStatusFilterProvider.notifier).state = v),
                  _archiveReviewFilterChip('completed_with_errors', 'مكتملة مع أخطاء', statusFilter, (v) => ref.read(_archiveBatchStatusFilterProvider.notifier).state = v),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _mini('الدفعات المعروضة', batches.length),
                _mini('الملفات', shownFiles),
                _mini('معتمدة', shownApproved),
                _mini('غير مصنف', shownUnclassified),
                _mini('مكرر', shownDuplicates),
                _mini('فشل', shownFailed),
                if (query.isNotEmpty || sourceFilter != 'all' || statusFilter != 'all')
                  TextButton.icon(
                    icon: const Icon(Icons.filter_alt_off, size: 16),
                    label: const Text('مسح فلاتر الدفعات'),
                    onPressed: () {
                      ref.read(_archiveBatchSearchProvider.notifier).state = '';
                      ref.read(_archiveBatchSourceFilterProvider.notifier).state = 'all';
                      ref.read(_archiveBatchStatusFilterProvider.notifier).state = 'all';
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (batches.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text('لا توجد دفعات مطابقة للبحث الحالي.', style: AppTextStyles.bodyMediumSecondary),
                ),
              )
            else
              ...batches.map((b) {
            final canImport = ref.watch(permissionServiceProvider).can(PermissionKeys.archiveIntakeImportFiles);
            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.primaryNavy.withOpacity(0.12), child: Icon(_sourceIcon(b.sourceType), color: AppColors.primaryNavy)),
                title: Text(b.name, style: AppTextStyles.labelLarge),
                subtitle: _batchSubtitle(b),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _mini('ملفات', b.totalFiles),
                    _miniAction('غير مصنف', b.unclassifiedFiles, () => _showBatchDetails(context, ref, b.id, b.name, initialFilter: 'needs_review')),
                    _miniAction('مكرر', b.duplicateFiles, () => _showBatchDetails(context, ref, b.id, b.name, initialFilter: 'duplicate')),
                    if (b.failedFiles > 0) _miniAction('فشل', b.failedFiles, () => _showBatchDetails(context, ref, b.id, b.name, initialFilter: 'failed')),
                    if ((b.sourcePath ?? '').isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('فتح المصدر'),
                        onPressed: () => _openArchiveSourcePath(context, ref, b),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('نسخ الملخص'),
                      onPressed: () => _copyArchiveBatchSummary(context, b),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('تعديل'),
                      onPressed: () => _editArchiveBatch(context, ref, b),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('فتح'),
                      onPressed: () => _showBatchDetails(context, ref, b.id, b.name),
                    ),
                    if (canImport)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('إضافة ملفات'),
                        onPressed: () => _importFiles(context, ref, b.id, batchName: b.name),
                      ),
                    if (canImport)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_copy, size: 16),
                        label: const Text('إضافة مجلد'),
                        onPressed: () => _importFolder(context, ref, b.id, batchName: b.name),
                      ),
                    if (b.sourceType == 'excel' && ref.watch(permissionServiceProvider).can(PermissionKeys.archiveIntakeImportExcel))
                      OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart, size: 16),
                        label: const Text('استيراد CSV'),
                        onPressed: () => _importCsvRows(context, ref, b.id, batchName: b.name),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          ],
        );
      },
    );
  }

  Widget _mini(String label, int value) => Chip(label: Text('$label: $value'));

  Future<void> _copyArchiveBatchSummary(BuildContext context, ArchiveBatchRecord batch) async {
    final total = batch.totalFiles;
    final reviewed = total == 0 ? 0 : total - batch.unclassifiedFiles;
    final lines = <String>[
      'دفعة أرشيف #${batch.id}',
      'الاسم: ${batch.name}',
      'المصدر: ${_sourceLabel(batch.sourceType)}',
      'الحالة: ${_statusLabel(batch.status)}',
      if ((batch.sourcePath ?? '').isNotEmpty) 'مسار المصدر: ${batch.sourcePath}',
      'تاريخ الإنشاء: ${batch.createdAt.toString().substring(0, 19)}',
      if ((batch.createdBy ?? '').isNotEmpty) 'أنشأها: ${batch.createdBy}',
      'إجمالي الملفات: ${batch.totalFiles}',
      'تمت معالجتها: ${batch.processedFiles}',
      'تمت مراجعتها: $reviewed',
      'معتمدة: ${batch.approvedFiles}',
      'غير مصنفة: ${batch.unclassifiedFiles}',
      'مكررة: ${batch.duplicateFiles}',
      'فاشلة: ${batch.failedFiles}',
      if ((batch.notes ?? '').isNotEmpty) 'ملاحظات: ${batch.notes}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تم نسخ ملخص دفعة الأرشيف'), backgroundColor: AppColors.success));
    }
  }

  Future<void> _editArchiveBatch(BuildContext context, WidgetRef ref, ArchiveBatchRecord batch) async {
    final name = TextEditingController(text: batch.name);
    final sourcePath = TextEditingController(text: batch.sourcePath ?? '');
    final notes = TextEditingController(text: batch.notes ?? '');
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
              title: const Text('تعديل بيانات دفعة الأرشيف'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الدفعة *')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sourcePath,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'مصدر الدفعة',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () async {
                            final selected = await fp.FilePicker.getDirectoryPath(dialogTitle: 'اختر مصدر الدفعة');
                            if (selected != null) setDialog(() => sourcePath.text = selected);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok || name.text.trim().isEmpty) return;
    await ref.read(archiveIntakeRepositoryProvider).updateBatchDetails(
          id: batch.id,
          name: name.text.trim(),
          sourcePath: sourcePath.text,
          notes: notes.text,
        );
    await ref.read(auditServiceProvider).log(
      action: 'edit',
      category: 'archive',
      entityType: 'archive_batch',
      entityId: '${batch.id}',
      entityTitle: name.text.trim(),
      description: 'تعديل بيانات دفعة أرشيف',
      before: {'name': batch.name, 'sourcePath': batch.sourcePath, 'notes': batch.notes},
      after: {'name': name.text.trim(), 'sourcePath': sourcePath.text.trim(), 'notes': notes.text.trim()},
      severity: 'info',
    );
    ref.read(_archiveIntakeRefreshProvider.notifier).state++;
  }

  Future<void> _openArchiveSourcePath(BuildContext context, WidgetRef ref, ArchiveBatchRecord batch) async {
    final source = batch.sourcePath;
    if (source == null || source.trim().isEmpty) return;
    try {
      if (Platform.isWindows) {
        await Process.start('explorer', [source]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [source]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [source]);
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('مصدر الدفعة: $source'), backgroundColor: AppColors.info));
        return;
      }
      await ref.read(auditServiceProvider).log(action: 'open_source', category: 'archive', entityType: 'archive_batch', entityId: '${batch.id}', entityTitle: batch.name, description: 'فتح مصدر دفعة الأرشيف', after: {'sourcePath': source}, severity: 'info');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح مصدر الدفعة: $e'), backgroundColor: AppColors.error));
    }
  }

  Widget _miniAction(String label, int value, VoidCallback onTap) {
    return ActionChip(
      label: Text('$label: $value'),
      avatar: const Icon(Icons.filter_alt, size: 16),
      onPressed: value > 0 ? onTap : null,
    );
  }

  Widget _batchSubtitle(ArchiveBatchRecord batch) {
    final total = batch.totalFiles;
    final reviewed = total == 0 ? 0 : total - batch.unclassifiedFiles;
    final reviewProgress = total == 0 ? 0.0 : reviewed / total;
    final approvedProgress = total == 0 ? 0.0 : batch.approvedFiles / total;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_sourceLabel(batch.sourceType)} • ${_statusLabel(batch.status)} • ${batch.createdAt.toString().substring(0, 16)}', style: AppTextStyles.bodySmallSecondary),
          if ((batch.sourcePath ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('المصدر: ${batch.sourcePath}', style: AppTextStyles.bodySmallSecondary, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          if (total > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: reviewProgress.clamp(0, 1), color: AppColors.primaryNavy, backgroundColor: AppColors.primaryNavy.withOpacity(0.10), minHeight: 5)),
                const SizedBox(width: 8),
                Text('مراجعة ${reviewed}/$total', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryNavy)),
                const SizedBox(width: 12),
                Expanded(child: LinearProgressIndicator(value: approvedProgress.clamp(0, 1), color: AppColors.success, backgroundColor: AppColors.success.withOpacity(0.10), minHeight: 5)),
                const SizedBox(width: 8),
                Text('اعتماد ${batch.approvedFiles}/$total', style: AppTextStyles.labelSmall.copyWith(color: AppColors.success)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'paper': return Icons.document_scanner;
      case 'electronic': return Icons.folder_copy;
      case 'excel': return Icons.table_chart;
      case 'mixed': return Icons.all_inbox;
      default: return Icons.archive;
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'paper': return 'أرشيف ورقي';
      case 'electronic': return 'أرشيف إلكتروني';
      case 'excel': return 'Excel / CSV';
      case 'mixed': return 'أرشيف مختلط';
      default: return source;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new': return 'جديدة';
      case 'processing': return 'قيد المعالجة';
      case 'waiting_review': return 'بانتظار المراجعة';
      case 'completed': return 'مكتملة';
      case 'completed_with_errors': return 'مكتملة مع أخطاء';
      case 'cancelled': return 'ملغاة';
      default: return status;
    }
  }

  Future<void> _showCreateBatch(BuildContext context, WidgetRef ref, String sourceType) async {
    final name = TextEditingController(text: '${_sourceLabel(sourceType)} - ${DateTime.now().toString().substring(0, 10)}');
    final sourcePath = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('إنشاء دفعة ${_sourceLabel(sourceType)}'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الدفعة *')),
                const SizedBox(height: 12),
                TextField(
                  controller: sourcePath,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'مصدر الأرشيف / المجلد أو الملف الأصلي',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () async {
                        final selected = await fp.FilePicker.getDirectoryPath(dialogTitle: 'اختر مصدر الأرشيف');
                        if (selected != null) setDialog(() => sourcePath.text = selected);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء')),
          ],
        ),
      ),
    ) ?? false;
    if (!ok || name.text.trim().isEmpty) return;
    final user = ref.read(authControllerProvider).user;
    final id = await ref.read(archiveIntakeRepositoryProvider).createBatch(
      name: name.text.trim(),
      sourceType: sourceType,
      sourcePath: sourcePath.text.trim().isEmpty ? null : sourcePath.text.trim(),
      createdBy: user?.fullName,
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
    );
    await ref.read(auditServiceProvider).log(
      action: 'create',
      category: 'archive',
      entityType: 'archive_batch',
      entityId: '$id',
      entityTitle: name.text.trim(),
      description: 'إنشاء دفعة إدخال أرشيف',
      after: {'sourceType': sourceType, if (sourcePath.text.trim().isNotEmpty) 'sourcePath': sourcePath.text.trim()},
      severity: 'info',
    );
    ref.read(_archiveIntakeRefreshProvider.notifier).state++;
    if (context.mounted) {
      final canImportNow = ref.read(permissionServiceProvider).can(PermissionKeys.archiveIntakeImportFiles);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء دفعة الأرشيف: ${name.text.trim()}'),
          backgroundColor: AppColors.success,
          action: canImportNow
              ? SnackBarAction(
                  label: 'إضافة ملفات الآن',
                  textColor: Colors.white,
                  onPressed: () => _importFiles(context, ref, id, batchName: name.text.trim()),
                )
              : null,
        ),
      );
    }
  }

  Future<void> _importFiles(BuildContext context, WidgetRef ref, int batchId, {String? batchName}) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveIntakeImportFiles)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_batch', entityId: '$batchId', description: 'محاولة استيراد ملفات أرشيف دون صلاحية', severity: 'warning');
      return;
    }
    final result = await fp.FilePicker.pickFiles(
                        allowMultiple: true,
                        type: fp.FileType.custom,
                        allowedExtensions:
                            AppConstants.allowedAttachmentExtensions,
                      );
    if (result == null) return;
    final files = result.paths.whereType<String>().map(File.new).toList();
    if (files.isEmpty) return;
    final summary = await ref.read(archiveIntakeRepositoryProvider).importFilesToBatch(batchId, files);
    await ref.read(auditServiceProvider).log(
      action: 'import_files',
      category: 'archive',
      entityType: 'archive_batch',
      entityId: '$batchId',
      description: 'استيراد ملفات إلى دفعة أرشيف',
      after: {'files': files.length, 'imported': summary.imported, 'duplicates': summary.duplicates, 'failed': summary.failed},
      severity: 'info',
    );
    ref.read(_archiveIntakeRefreshProvider.notifier).state++;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت المعالجة: ${summary.imported} جديد، ${summary.duplicates} مكرر، ${summary.failed} فشل'),
          backgroundColor: summary.failed > 0 ? AppColors.warning : AppColors.success,
          action: SnackBarAction(
            label: 'فتح الدفعة',
            textColor: Colors.white,
            onPressed: () => _showBatchDetails(context, ref, batchId, batchName ?? 'دفعة #$batchId'),
          ),
        ),
      );
    }
  }

  Future<void> _importFolder(BuildContext context, WidgetRef ref, int batchId, {String? batchName}) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveIntakeImportFiles)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_batch', entityId: '$batchId', description: 'محاولة استيراد مجلد أرشيف دون صلاحية', severity: 'warning');
      return;
    }
    final directoryPath = await fp.FilePicker.getDirectoryPath(dialogTitle: 'اختر مجلد الأرشيف');
    if (directoryPath == null || directoryPath.trim().isEmpty) return;
    final root = Directory(directoryPath);
    if (!await root.exists()) return;
    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) files.add(entity);
    }
    if (files.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('المجلد المختار لا يحتوي ملفات.'), backgroundColor: AppColors.warning));
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('استيراد مجلد أرشيف'),
            content: Text('سيتم استيراد ${files.length} ملف من المجلد:\n$directoryPath\n\nسيتم فحص التكرارات بالبصمة وحفظ الملفات غير المكررة فقط.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استيراد')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(archiveIntakeRepositoryProvider).updateBatchSourcePath(batchId, directoryPath);
    final summary = await ref.read(archiveIntakeRepositoryProvider).importFilesToBatch(batchId, files);
    await ref.read(auditServiceProvider).log(action: 'import_folder', category: 'archive', entityType: 'archive_batch', entityId: '$batchId', entityTitle: batchName ?? 'دفعة #$batchId', description: 'استيراد مجلد إلى دفعة أرشيف', after: {'folder': directoryPath, 'files': files.length, 'imported': summary.imported, 'duplicates': summary.duplicates, 'failed': summary.failed}, severity: 'info');
    ref.read(_archiveIntakeRefreshProvider.notifier).state++;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استيراد المجلد: ${summary.imported} جديد، ${summary.duplicates} مكرر، ${summary.failed} فشل'),
          backgroundColor: summary.failed > 0 ? AppColors.warning : AppColors.success,
          action: SnackBarAction(
            label: 'فتح الدفعة',
            textColor: Colors.white,
            onPressed: () => _showBatchDetails(context, ref, batchId, batchName ?? 'دفعة #$batchId'),
          ),
        ),
      );
    }
  }

  Future<void> _importCsvRows(BuildContext context, WidgetRef ref, int batchId, {String? batchName}) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveIntakeImportExcel)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_batch', entityId: '$batchId', description: 'محاولة استيراد CSV دون صلاحية', severity: 'warning');
      return;
    }
    final result = await fp.FilePicker.pickFiles(type: fp.FileType.custom, allowedExtensions: const ['csv']);
    final pathValue = result?.files.single.path;
    if (pathValue == null) return;
    final csvFile = File(pathValue);
    final preview = await ref.read(archiveIntakeRepositoryProvider).previewCsvFile(csvFile);
    if (!context.mounted) return;
    final confirmed = await _confirmCsvImport(context, preview);
    if (!confirmed) return;
    await ref.read(archiveIntakeRepositoryProvider).updateBatchSourcePath(batchId, csvFile.path);
    final summary = await ref.read(archiveIntakeRepositoryProvider).importCsvRowsToBatch(batchId, csvFile);
    await ref.read(auditServiceProvider).log(action: 'import_csv', category: 'archive', entityType: 'archive_batch', entityId: '$batchId', description: 'استيراد صفوف CSV إلى دفعة أرشيف للمراجعة الآمنة', after: {'imported': summary.imported, 'duplicates': summary.duplicates, 'failed': summary.failed}, severity: 'info');
    ref.read(_archiveIntakeRefreshProvider.notifier).state++;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استيراد CSV: ${summary.imported} جديد، ${summary.duplicates} مكرر، فشل ${summary.failed}'),
          backgroundColor: summary.failed > 0 ? AppColors.warning : AppColors.success,
          action: SnackBarAction(
            label: 'فتح الدفعة',
            textColor: Colors.white,
            onPressed: () => _showBatchDetails(context, ref, batchId, batchName ?? 'دفعة #$batchId'),
          ),
        ),
      );
    }
  }

  Future<bool> _confirmCsvImport(BuildContext context, ArchiveCsvPreview preview) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('معاينة CSV: ${preview.fileName}'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('الفاصل: ${preview.delimiter} • عدد الصفوف: ${preview.rowCount}', style: AppTextStyles.bodySmallSecondary),
                    const SizedBox(height: 10),
                    Text('الأعمدة', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: preview.headers.map((h) => Chip(label: Text(h))).toList()),
                    if (preview.warnings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.warning.withOpacity(0.35))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('تنبيهات قبل الاستيراد', style: AppTextStyles.labelLarge.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            ...preview.warnings.map((warning) => Text('• $warning', style: AppTextStyles.bodySmallSecondary)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('عينة من أول الصفوف', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
                    const SizedBox(height: 6),
                    ...preview.sampleRows.map((row) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(row.entries.take(6).map((e) => '${e.key}: ${e.value}').join(' • '), style: AppTextStyles.bodySmallSecondary),
                          ),
                        )),
                    const SizedBox(height: 8),
                    Text('سيتم استيراد الصفوف كعناصر أرشيف تحتاج مراجعة، ولن يتم إنشاء سجلات تشغيلية مباشرة.', style: AppTextStyles.bodySmallSecondary.copyWith(color: AppColors.warning)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استيراد كعناصر مراجعة')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showDuplicates(BuildContext context, WidgetRef ref) async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.archiveDuplicatesView)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_duplicates', description: 'محاولة فتح المكررات دون صلاحية', severity: 'warning');
      return;
    }
    final search = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('الملفات المكررة'),
          content: SizedBox(
            width: 900,
            height: 580,
            child: Column(
              children: [
                TextField(
                  controller: search,
                  decoration: const InputDecoration(labelText: 'بحث في المكررات', prefixIcon: Icon(Icons.search)),
                  onChanged: (_) => setDialog(() {}),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: FutureBuilder<List<ArchiveItemRecord>>(
                    future: ref.read(archiveIntakeRepositoryProvider).getItemsByStatus('duplicate'),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final items = _filteredArchiveItems(snapshot.data!, search.text);
                      if (items.isEmpty) return const Center(child: Text('لا توجد ملفات مكررة مطابقة حالياً.'));
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final item = items[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(Icons.copy_all, color: AppColors.info),
                              title: Text(item.originalFileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('دفعة #${item.batchId} • ${item.errorMessage ?? 'ملف مكرر محتمل'}'),
                              trailing: Wrap(
                                spacing: 6,
                                children: [
                                  if ((item.sourcePath ?? '').isNotEmpty)
                                    TextButton(onPressed: () => _openArchiveOriginalSource(ctx, ref, item), child: const Text('المصدر')),
                                  TextButton(onPressed: () => _showArchiveItemDetails(ctx, ref, item), child: const Text('تفاصيل')),
                                  if (_duplicateSourceItemId(item) != null)
                                    TextButton(onPressed: () => _compareDuplicateWithSource(ctx, ref, item, _duplicateSourceItemId(item)!), child: const Text('مقارنة')),
                                  if (permissions.can(PermissionKeys.archiveDuplicatesResolve))
                                    TextButton(
                                      onPressed: () => _reviewArchiveItem(ctx, ref, item, 'rejected', 'rejected', actionLabel: 'تجاهل المكرر', defaultNote: 'تجاهل ملف مكرر بعد المراجعة'),
                                      child: const Text('تجاهل المكرر'),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (permissions.can(PermissionKeys.archiveQualityExport))
              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('تصدير المعروض CSV'),
                onPressed: () async {
                  final allItems = await ref.read(archiveIntakeRepositoryProvider).getItemsByStatus('duplicate');
                  final visible = _filteredArchiveItems(allItems, search.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _exportDuplicates(context, ref, itemsOverride: visible);
                },
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  Future<void> _exportDuplicates(BuildContext context, WidgetRef ref, {List<ArchiveItemRecord>? itemsOverride}) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_duplicates', description: 'محاولة تصدير المكررات دون صلاحية', severity: 'warning');
      return;
    }
    final items = itemsOverride ?? await ref.read(archiveIntakeRepositoryProvider).getItemsByStatus('duplicate');
    final buffer = StringBuffer('id,batchId,fileName,duplicateOf,status,reviewStatus,fileType,fileSize,sha256,error,reviewedBy,reviewedAt,reviewNote,createdAt,sourcePath\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final item in items) {
      buffer.writeln([
        item.id,
        item.batchId,
        esc(item.originalFileName),
        _duplicateSourceItemId(item) ?? '',
        esc(item.status),
        esc(item.reviewStatus),
        esc(item.fileType),
        item.fileSize,
        esc(item.sha256),
        esc(item.errorMessage),
        esc(item.reviewedBy),
        esc(item.reviewedAt?.toIso8601String()),
        esc(item.reviewNote),
        esc(item.createdAt.toIso8601String()),
        esc(item.sourcePath),
      ].join(','));
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, AppConstants.appDataDirectoryName, 'archive_duplicate_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(path.join(dir.path, 'archive_duplicates_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await _writeArabicCsv(file, buffer.toString());
    await ref.read(auditServiceProvider).log(action: 'export', category: 'archive', entityType: 'archive_duplicates', entityTitle: file.path, description: 'تصدير قائمة مكررات الأرشيف CSV', after: {'count': items.length}, severity: 'info');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تصدير المكررات: ${file.path}'), backgroundColor: AppColors.success));
    }
  }

  Future<void> _showQualityReport(BuildContext context, WidgetRef ref) async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.archiveQualityView)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_quality', description: 'محاولة فتح تقرير جودة الأرشيف دون صلاحية', severity: 'warning');
      return;
    }
    final batches = await ref.read(archiveIntakeRepositoryProvider).getBatches();
    final files = batches.fold<int>(0, (sum, b) => sum + b.totalFiles);
    final processed = batches.fold<int>(0, (sum, b) => sum + b.processedFiles);
    final failed = batches.fold<int>(0, (sum, b) => sum + b.failedFiles);
    final duplicates = batches.fold<int>(0, (sum, b) => sum + b.duplicateFiles);
    final unclassified = batches.fold<int>(0, (sum, b) => sum + b.unclassifiedFiles);
    final approved = batches.fold<int>(0, (sum, b) => sum + b.approvedFiles);
    final approvalRate = files == 0 ? 0.0 : approved / files;
    final reviewRate = files == 0 ? 0.0 : (files - unclassified) / files;
    final duplicateRate = files == 0 ? 0.0 : duplicates / files;
    final failureRate = files == 0 ? 0.0 : failed / files;
    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تقرير جودة الأرشيف'),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _qualityRow('عدد الدفعات', batches.length),
                _qualityRow('إجمالي الملفات', files),
                _qualityRow('تمت معالجتها', processed),
                _qualityRow('معتمدة', approved),
                _qualityRow('غير مصنفة', unclassified),
                _qualityRow('مكررة', duplicates),
                _qualityRow('فشلت', failed),
                const Divider(),
                _qualityPercentRow('نسبة الاعتماد', approvalRate, AppColors.success),
                _qualityPercentRow('نسبة المراجعة', reviewRate, AppColors.primaryNavy),
                _qualityPercentRow('نسبة التكرار', duplicateRate, AppColors.info),
                _qualityPercentRow('نسبة الفشل', failureRate, AppColors.error),
                const Divider(),
                ...batches.take(8).map((b) => ListTile(
                      dense: true,
                      title: Text(b.name),
                      subtitle: Text('${_sourceLabel(b.sourceType)} • ${_statusLabel(b.status)}'),
                      trailing: Text('${b.approvedFiles}/${b.totalFiles}'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showBatchDetails(context, ref, b.id, b.name);
                      },
                    )),
              ],
            ),
          ),
          actions: [
            if (permissions.can(PermissionKeys.archiveQualityExport))
              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('تصدير CSV'),
                onPressed: () async { Navigator.pop(ctx); await _exportQualityReport(context, ref, batches); },
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      );
    }
    await ref.read(auditServiceProvider).log(action: 'view', category: 'archive', entityType: 'archive_quality', description: 'عرض تقرير جودة الأرشيف', severity: 'info');
  }

  Future<void> _writeArabicCsv(File file, String content) async {
    // UTF-8 BOM يساعد Excel على قراءة العربية بشكل صحيح في ملفات CSV.
    await file.writeAsString('\uFEFF$content');
  }

  Future<void> _exportQualityReport(BuildContext context, WidgetRef ref, List<ArchiveBatchRecord> batches) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_quality', description: 'محاولة تصدير تقرير جودة الأرشيف دون صلاحية', severity: 'warning');
      return;
    }
    final buffer = StringBuffer('id,name,source,status,total,processed,approved,unclassified,duplicates,failed,approvalRate,reviewRate,duplicateRate,failureRate,createdAt\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    String rate(int value, int total) => total == 0 ? '0.00' : (value / total * 100).toStringAsFixed(2);
    for (final b in batches) {
      final reviewed = b.totalFiles - b.unclassifiedFiles;
      buffer.writeln([b.id, esc(b.name), esc(_sourceLabel(b.sourceType)), esc(_statusLabel(b.status)), b.totalFiles, b.processedFiles, b.approvedFiles, b.unclassifiedFiles, b.duplicateFiles, b.failedFiles, rate(b.approvedFiles, b.totalFiles), rate(reviewed, b.totalFiles), rate(b.duplicateFiles, b.totalFiles), rate(b.failedFiles, b.totalFiles), esc(b.createdAt.toIso8601String())].join(','));
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, AppConstants.appDataDirectoryName, 'archive_quality_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(path.join(dir.path, 'archive_quality_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await _writeArabicCsv(file, buffer.toString());
    await ref.read(auditServiceProvider).log(action: 'export', category: 'archive', entityType: 'archive_quality', entityTitle: file.path, description: 'تصدير تقرير جودة الأرشيف CSV', severity: 'warning');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تصدير تقرير الجودة: ${file.path}'), backgroundColor: AppColors.success));
    }
  }

  Widget _qualityRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [Expanded(child: Text(label, style: AppTextStyles.bodyMedium)), Text('$value', style: AppTextStyles.numberText.copyWith(color: AppColors.primaryNavy))]),
    );
  }

  Widget _qualityPercentRow(String label, double value, Color color) {
    final percent = (value * 100).clamp(0, 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Expanded(child: Text(label, style: AppTextStyles.bodySmallSecondary)), Text('$percent%', style: AppTextStyles.labelMedium.copyWith(color: color))]),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: value.clamp(0, 1), color: color, backgroundColor: color.withOpacity(0.12), minHeight: 6),
        ],
      ),
    );
  }

  Future<void> _showUnclassifiedInbox(BuildContext context, WidgetRef ref) async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.archiveInboxView)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_inbox', description: 'محاولة فتح صندوق الأرشيف غير المصنف دون صلاحية', severity: 'warning');
      return;
    }
    final search = TextEditingController();
    String statusFilter = 'all';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('صندوق الأرشيف غير المصنف'),
          content: SizedBox(
            width: 900,
            height: 600,
            child: Column(
              children: [
                TextField(
                  controller: search,
                  decoration: const InputDecoration(labelText: 'بحث باسم الملف أو النوع أو الملاحظة', prefixIcon: Icon(Icons.search)),
                  onChanged: (_) => setDialog(() {}),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _archiveReviewFilterChip('all', 'كل غير المصنف', statusFilter, (v) => setDialog(() => statusFilter = v)),
                      _archiveReviewFilterChip('imported', 'مستوردة', statusFilter, (v) => setDialog(() => statusFilter = v)),
                      _archiveReviewFilterChip('duplicate', 'مكررة', statusFilter, (v) => setDialog(() => statusFilter = v)),
                      _archiveReviewFilterChip('failed', 'فاشلة', statusFilter, (v) => setDialog(() => statusFilter = v)),
                      if (search.text.isNotEmpty || statusFilter != 'all')
                        TextButton.icon(
                          icon: const Icon(Icons.filter_alt_off, size: 16),
                          label: const Text('مسح'),
                          onPressed: () => setDialog(() {
                            search.clear();
                            statusFilter = 'all';
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: FutureBuilder<List<ArchiveItemRecord>>(
                    future: ref.read(archiveIntakeRepositoryProvider).getItemsByReviewStatus('needs_review'),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final searched = _filteredArchiveItems(snapshot.data!, search.text);
                      final filtered = _filteredArchiveItemsByStatus(searched, statusFilter);
                      return Column(
                        children: [
                          _archiveItemsStatsBar(filtered),
                          const SizedBox(height: 8),
                          Expanded(child: _itemsList(ctx, ref, filtered)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (permissions.can(PermissionKeys.archiveQualityExport))
              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('تصدير المعروض CSV'),
                onPressed: () async {
                  final allItems = await ref.read(archiveIntakeRepositoryProvider).getItemsByReviewStatus('needs_review');
                  final searched = _filteredArchiveItems(allItems, search.text);
                  final visible = _filteredArchiveItemsByStatus(searched, statusFilter);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _exportUnclassifiedInbox(context, ref, itemsOverride: visible);
                },
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  Future<void> _exportUnclassifiedInbox(BuildContext context, WidgetRef ref, {List<ArchiveItemRecord>? itemsOverride}) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_inbox', description: 'محاولة تصدير صندوق الأرشيف غير المصنف دون صلاحية', severity: 'warning');
      return;
    }
    final items = itemsOverride ?? await ref.read(archiveIntakeRepositoryProvider).getItemsByReviewStatus('needs_review');
    final buffer = StringBuffer('id,batchId,fileName,status,reviewStatus,fileType,fileSize,suggestedType,sha256,error,reviewedBy,reviewedAt,reviewNote,createdAt,sourcePath,storedPath\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final item in items) {
      buffer.writeln([
        item.id,
        item.batchId,
        esc(item.originalFileName),
        esc(item.status),
        esc(item.reviewStatus),
        esc(item.fileType),
        item.fileSize,
        esc(item.suggestedDocumentType),
        esc(item.sha256),
        esc(item.errorMessage),
        esc(item.reviewedBy),
        esc(item.reviewedAt?.toIso8601String()),
        esc(item.reviewNote),
        esc(item.createdAt.toIso8601String()),
        esc(item.sourcePath),
        esc(item.storedPath),
      ].join(','));
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, AppConstants.appDataDirectoryName, 'archive_inbox_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(path.join(dir.path, 'archive_inbox_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await _writeArabicCsv(file, buffer.toString());
    await ref.read(auditServiceProvider).log(action: 'export', category: 'archive', entityType: 'archive_inbox', entityTitle: file.path, description: 'تصدير صندوق الأرشيف غير المصنف CSV', after: {'count': items.length}, severity: 'info');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تصدير صندوق غير المصنف: ${file.path}'), backgroundColor: AppColors.success));
    }
  }

  Future<void> _showBatchDetails(BuildContext context, WidgetRef ref, int batchId, String batchName, {String initialFilter = 'all'}) async {
    final search = TextEditingController();
    String reviewFilter = initialFilter;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('تفاصيل الدفعة: $batchName'),
          content: SizedBox(
            width: 900,
            height: 600,
            child: Column(
              children: [
                TextField(
                  controller: search,
                  decoration: const InputDecoration(labelText: 'بحث داخل الدفعة', prefixIcon: Icon(Icons.search)),
                  onChanged: (_) => setDialog(() {}),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _archiveReviewFilterChip('all', 'كل العناصر', reviewFilter, (v) => setDialog(() => reviewFilter = v)),
                      _archiveReviewFilterChip('needs_review', 'تحتاج مراجعة', reviewFilter, (v) => setDialog(() => reviewFilter = v)),
                      _archiveReviewFilterChip('approved', 'معتمدة', reviewFilter, (v) => setDialog(() => reviewFilter = v)),
                      _archiveReviewFilterChip('rejected', 'مرفوضة', reviewFilter, (v) => setDialog(() => reviewFilter = v)),
                      _archiveReviewFilterChip('duplicate', 'مكررة', reviewFilter, (v) => setDialog(() => reviewFilter = v)),
                      _archiveReviewFilterChip('failed', 'فاشلة', reviewFilter, (v) => setDialog(() => reviewFilter = v)),
                      if (search.text.isNotEmpty || reviewFilter != 'all')
                        TextButton.icon(
                          icon: const Icon(Icons.filter_alt_off, size: 16),
                          label: const Text('مسح'),
                          onPressed: () => setDialog(() {
                            search.clear();
                            reviewFilter = 'all';
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: FutureBuilder<List<ArchiveItemRecord>>(
                    future: ref.read(archiveIntakeRepositoryProvider).getItemsForBatch(batchId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final searched = _filteredArchiveItems(snapshot.data!, search.text);
                      final filtered = _filteredArchiveItemsByReview(searched, reviewFilter);
                      return Column(
                        children: [
                          _archiveItemsStatsBar(filtered),
                          const SizedBox(height: 8),
                          Expanded(child: _itemsList(ctx, ref, filtered)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport))
              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('تصدير المعروض CSV'),
                onPressed: () async {
                  final allItems = await ref.read(archiveIntakeRepositoryProvider).getItemsForBatch(batchId);
                  final searched = _filteredArchiveItems(allItems, search.text);
                  final filtered = _filteredArchiveItemsByReview(searched, reviewFilter);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _exportBatchItems(context, ref, batchId, batchName, itemsOverride: filtered);
                },
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  Widget _archiveItemsStatsBar(List<ArchiveItemRecord> items) {
    final imported = items.where((item) => item.status == 'imported').length;
    final duplicates = items.where((item) => item.status == 'duplicate').length;
    final failed = items.where((item) => item.status == 'failed').length;
    final approved = items.where((item) => item.reviewStatus == 'approved').length;
    final rejected = items.where((item) => item.reviewStatus == 'rejected').length;
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _mini('المعروض', items.length),
          _mini('مستوردة', imported),
          _mini('معتمدة', approved),
          _mini('مكررة', duplicates),
          _mini('فاشلة', failed),
          _mini('مرفوضة', rejected),
        ],
      ),
    );
  }

  Future<void> _exportBatchItems(BuildContext context, WidgetRef ref, int batchId, String batchName, {List<ArchiveItemRecord>? itemsOverride}) async {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.archiveQualityExport)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_batch', entityId: '$batchId', description: 'محاولة تصدير عناصر دفعة أرشيف دون صلاحية', severity: 'warning');
      return;
    }
    final items = itemsOverride ?? await ref.read(archiveIntakeRepositoryProvider).getItemsForBatch(batchId);
    final buffer = StringBuffer('id,batchId,fileName,status,reviewStatus,fileType,fileSize,suggestedType,confirmedType,entityType,entityId,sha256,error,reviewedBy,reviewedAt,reviewNote,createdAt,sourcePath,storedPath\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final item in items) {
      buffer.writeln([
        item.id,
        item.batchId,
        esc(item.originalFileName),
        esc(item.status),
        esc(item.reviewStatus),
        esc(item.fileType),
        item.fileSize,
        esc(item.suggestedDocumentType),
        esc(item.confirmedDocumentType),
        item.confirmedEntityType ?? '',
        item.confirmedEntityId ?? '',
        esc(item.sha256),
        esc(item.errorMessage),
        esc(item.reviewedBy),
        esc(item.reviewedAt?.toIso8601String()),
        esc(item.reviewNote),
        esc(item.createdAt.toIso8601String()),
        esc(item.sourcePath),
        esc(item.storedPath),
      ].join(','));
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, AppConstants.appDataDirectoryName, 'archive_batch_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final safeName = batchName.replaceAll(RegExp(r'[^\w\u0600-\u06FF-]+'), '_');
    final file = File(path.join(dir.path, 'archive_batch_${batchId}_${safeName}_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await _writeArabicCsv(file, buffer.toString());
    await ref.read(auditServiceProvider).log(action: 'export', category: 'archive', entityType: 'archive_batch', entityId: '$batchId', entityTitle: file.path, description: 'تصدير عناصر دفعة الأرشيف CSV', after: {'count': items.length}, severity: 'info');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تصدير عناصر الدفعة: ${file.path}'), backgroundColor: AppColors.success));
    }
  }

  Widget _archiveReviewFilterChip(String value, String label, String selected, ValueChanged<String> onSelected) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        selectedColor: AppColors.primaryNavy.withOpacity(0.10),
        labelStyle: TextStyle(color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        onSelected: (_) => onSelected(value),
      ),
    );
  }

  List<ArchiveItemRecord> _filteredArchiveItemsByReview(List<ArchiveItemRecord> items, String filter) {
    if (filter == 'all') return items;
    if (filter == 'duplicate' || filter == 'failed') return items.where((item) => item.status == filter).toList();
    return items.where((item) => item.reviewStatus == filter).toList();
  }

  List<ArchiveItemRecord> _filteredArchiveItemsByStatus(List<ArchiveItemRecord> items, String filter) {
    if (filter == 'all') return items;
    return items.where((item) => item.status == filter).toList();
  }

  List<ArchiveItemRecord> _filteredArchiveItems(List<ArchiveItemRecord> items, String rawQuery) {
    final query = _normalizeSearchText(rawQuery);
    if (query.isEmpty) return items;
    return items.where((item) {
      return _containsSearch(item.originalFileName, query) ||
          _containsSearch(item.fileType, query) ||
          _containsSearch(item.status, query) ||
          _containsSearch(item.reviewStatus, query) ||
          _containsSearch(item.errorMessage, query) ||
          _containsSearch(_documentTypeLabel(item.suggestedDocumentType ?? 'archive_document'), query) ||
          _containsSearch(item.sha256, query);
    }).toList();
  }

  Widget _itemsList(BuildContext dialogContext, WidgetRef ref, List<ArchiveItemRecord> items) {
    final permissions = ref.watch(permissionServiceProvider);
    if (items.isEmpty) return const Center(child: Text('لا توجد عناصر مطابقة.'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: Icon(_itemIcon(item.status), color: _itemColor(item.status)),
            title: Text(item.originalFileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([
              'دفعة #${item.batchId}',
              'الحالة: ${_itemStatusLabel(item.status)}',
              'المراجعة: ${_reviewStatusLabel(item.reviewStatus)}',
              if ((item.fileType ?? '').isNotEmpty) 'النوع: ${item.fileType}',
              if (item.errorMessage != null) 'ملاحظة: ${item.errorMessage}',
            ].join(' • ')),
            trailing: Wrap(
              spacing: 6,
              children: [
                if ((item.storedPath ?? '').isNotEmpty)
                  TextButton(onPressed: () => _openArchiveItemFile(dialogContext, ref, item), child: const Text('فتح الملف')),
                if ((item.sourcePath ?? '').isNotEmpty)
                  TextButton(onPressed: () => _openArchiveOriginalSource(dialogContext, ref, item), child: const Text('المصدر')),
                if (_routeForConfirmedEntity(item) != null)
                  TextButton(onPressed: () { final route = _routeForConfirmedEntity(item)!; final router = GoRouter.of(dialogContext); Navigator.pop(dialogContext); router.go(route); }, child: const Text('فتح المرتبط')),
                TextButton(onPressed: () => _showArchiveItemDetails(dialogContext, ref, item), child: const Text('تفاصيل')),
                if (permissions.can(PermissionKeys.archiveInboxLink) && item.status != 'duplicate' && item.status != 'failed' && item.reviewStatus != 'approved')
                  TextButton(onPressed: () => _showLinkItemDialog(dialogContext, ref, item), child: const Text('ربط بملف')),
                if (permissions.can(PermissionKeys.archiveIntakeReview) && item.reviewStatus == 'rejected')
                  TextButton(onPressed: () => _restoreArchiveItemReview(dialogContext, ref, item), child: const Text('إعادة للمراجعة')),
                if (permissions.can(PermissionKeys.archiveInboxLink) && item.reviewStatus != 'approved' && item.reviewStatus != 'rejected')
                  TextButton(onPressed: () => _reviewArchiveItem(dialogContext, ref, item, 'imported', 'approved', actionLabel: 'اعتماد عام', defaultNote: 'اعتماد عام من مركز الأرشيف'), child: const Text('اعتماد عام')),
                if (permissions.can(PermissionKeys.archiveInboxReject) && item.status != 'rejected' && item.reviewStatus != 'rejected')
                  TextButton(onPressed: () => _reviewArchiveItem(dialogContext, ref, item, 'rejected', 'rejected', actionLabel: 'رفض', defaultNote: 'رفض / تجاهل من مركز الأرشيف'), child: const Text('رفض')),
              ],
            ),
          ),
        );
      },
    );
  }

  int? _duplicateSourceItemId(ArchiveItemRecord item) {
    final message = item.errorMessage ?? '';
    final match = RegExp(r'#(\d+)').firstMatch(message);
    return match == null ? null : int.tryParse(match.group(1) ?? '');
  }

  Future<void> _compareDuplicateWithSource(BuildContext context, WidgetRef ref, ArchiveItemRecord duplicate, int sourceId) async {
    final original = await ref.read(archiveIntakeRepositoryProvider).getItemById(sourceId);
    if (original == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لم يتم العثور على العنصر الأصلي #$sourceId'), backgroundColor: AppColors.warning));
      return;
    }
    await ref.read(auditServiceProvider).log(action: 'compare', category: 'archive', entityType: 'archive_duplicate', entityId: '${duplicate.id}', entityTitle: duplicate.originalFileName, description: 'مقارنة ملف مكرر مع أصله', after: {'sourceId': sourceId}, severity: 'info');
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('مقارنة المكرر #${duplicate.id} مع الأصل #$sourceId'),
        content: SizedBox(
          width: 900,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _archiveItemMiniDetails('الأصل', original)),
              const SizedBox(width: 12),
              Expanded(child: _archiveItemMiniDetails('المكرر', duplicate)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          if (ref.read(permissionServiceProvider).can(PermissionKeys.archiveDuplicatesResolve))
            ElevatedButton.icon(
              icon: const Icon(Icons.block),
              label: const Text('تجاهل المكرر'),
              onPressed: () async {
                await _reviewArchiveItem(ctx, ref, duplicate, 'rejected', 'rejected', actionLabel: 'تجاهل المكرر', defaultNote: 'تجاهل ملف مكرر بعد المقارنة مع الأصل');
              },
            ),
        ],
      ),
    );
  }

  Widget _archiveItemMiniDetails(String title, ArchiveItemRecord item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _detailRow('رقم العنصر', '#${item.id}'),
          _detailRow('اسم الملف', item.originalFileName),
          _detailRow('الدفعة', '#${item.batchId}'),
          _detailRow('الحالة', _itemStatusLabel(item.status)),
          _detailRow('الحجم', _formatFileSize(item.fileSize)),
          if ((item.sha256 ?? '').isNotEmpty) _detailRow('SHA-256', item.sha256!),
          if ((item.sourcePath ?? '').isNotEmpty) _detailRow('المسار الأصلي', item.sourcePath!),
          if ((item.storedPath ?? '').isNotEmpty) _detailRow('المسار المحفوظ', item.storedPath!),
        ],
      ),
    );
  }

  Future<void> _showArchiveItemDetails(BuildContext context, WidgetRef ref, ArchiveItemRecord item) async {
    await ref.read(auditServiceProvider).log(
      action: 'view',
      category: 'archive',
      entityType: 'archive_item',
      entityId: '${item.id}',
      entityTitle: item.originalFileName,
      description: 'عرض تفاصيل عنصر أرشيف',
      severity: 'info',
    );
    if (!context.mounted) return;
    final duplicateSourceId = _duplicateSourceItemId(item);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تفاصيل عنصر الأرشيف #${item.id}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('اسم الملف', item.originalFileName),
                _detailRow('الدفعة', '#${item.batchId}'),
                _detailRow('الحالة', _itemStatusLabel(item.status)),
                _detailRow('المراجعة', _reviewStatusLabel(item.reviewStatus)),
                _detailRow('نوع الملف', item.fileType ?? 'غير محدد'),
                _detailRow('الحجم', _formatFileSize(item.fileSize)),
                _detailRow('نوع المستند المقترح', _documentTypeLabel(item.suggestedDocumentType ?? 'archive_document')),
                if (item.confirmedDocumentType != null) _detailRow('نوع المستند المعتمد', _documentTypeLabel(item.confirmedDocumentType!)),
                if (item.confirmedEntityType != null || item.confirmedEntityId != null) _detailRow('الربط المعتمد', '${item.confirmedEntityType ?? '-'} / ${item.confirmedEntityId ?? '-'}'),
                if (_csvRowData(item) != null) _csvRowDetails(_csvRowData(item)!),
                if ((item.errorMessage ?? '').isNotEmpty && _csvRowData(item) == null) _detailRow('ملاحظة / خطأ', item.errorMessage!),
                if ((item.reviewedBy ?? '').isNotEmpty) _detailRow('راجعه', item.reviewedBy!),
                if (item.reviewedAt != null) _detailRow('تاريخ المراجعة', item.reviewedAt!.toString().substring(0, 19)),
                if ((item.reviewNote ?? '').isNotEmpty) _detailRow('ملاحظة المراجعة', item.reviewNote!),
                if ((item.sha256 ?? '').isNotEmpty) _detailRow('بصمة SHA-256', item.sha256!),
                if ((item.sourcePath ?? '').isNotEmpty) _detailRow('المسار الأصلي', item.sourcePath!),
                if ((item.storedPath ?? '').isNotEmpty) _detailRow('المسار المحفوظ', item.storedPath!),
                _detailRow('تاريخ الإدخال', item.createdAt.toString().substring(0, 19)),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('نسخ التفاصيل'),
            onPressed: () => _copyArchiveItemDetails(context, item),
          ),
          if ((item.sourcePath ?? '').isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.source),
              label: const Text('فتح المصدر الأصلي'),
              onPressed: () => _openArchiveOriginalSource(context, ref, item),
            ),
          if ((item.storedPath ?? '').isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('فتح الملف'),
              onPressed: () => _openArchiveItemFile(context, ref, item),
            ),
          if (_routeForConfirmedEntity(item) != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('فتح الملف المرتبط'),
              onPressed: () {
                Navigator.pop(ctx);
                context.go(_routeForConfirmedEntity(item)!);
              },
            ),
          if (duplicateSourceId != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.compare_arrows),
              label: Text('مقارنة مع الأصل #$duplicateSourceId'),
              onPressed: () async {
                Navigator.pop(ctx);
                await _compareDuplicateWithSource(context, ref, item, duplicateSourceId);
              },
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _copyArchiveItemDetails(BuildContext context, ArchiveItemRecord item) async {
    final lines = <String>[
      'عنصر أرشيف #${item.id}',
      'اسم الملف: ${item.originalFileName}',
      'الدفعة: #${item.batchId}',
      'الحالة: ${_itemStatusLabel(item.status)}',
      'المراجعة: ${_reviewStatusLabel(item.reviewStatus)}',
      if ((item.fileType ?? '').isNotEmpty) 'نوع الملف: ${item.fileType}',
      'الحجم: ${_formatFileSize(item.fileSize)}',
      if ((item.suggestedDocumentType ?? '').isNotEmpty) 'نوع المستند المقترح: ${_documentTypeLabel(item.suggestedDocumentType!)}',
      if ((item.confirmedDocumentType ?? '').isNotEmpty) 'نوع المستند المعتمد: ${_documentTypeLabel(item.confirmedDocumentType!)}',
      if (item.confirmedEntityType != null || item.confirmedEntityId != null) 'الربط المعتمد: ${item.confirmedEntityType ?? '-'} / ${item.confirmedEntityId ?? '-'}',
      if ((item.errorMessage ?? '').isNotEmpty) 'ملاحظة/خطأ: ${item.errorMessage}',
      if ((item.reviewedBy ?? '').isNotEmpty) 'راجعه: ${item.reviewedBy}',
      if (item.reviewedAt != null) 'تاريخ المراجعة: ${item.reviewedAt!.toString().substring(0, 19)}',
      if ((item.reviewNote ?? '').isNotEmpty) 'ملاحظة المراجعة: ${item.reviewNote}',
      if ((item.sha256 ?? '').isNotEmpty) 'SHA-256: ${item.sha256}',
      if ((item.sourcePath ?? '').isNotEmpty) 'المسار الأصلي: ${item.sourcePath}',
      if ((item.storedPath ?? '').isNotEmpty) 'المسار المحفوظ: ${item.storedPath}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تم نسخ تفاصيل عنصر الأرشيف'), backgroundColor: AppColors.success));
    }
  }

  String? _routeForConfirmedEntity(ArchiveItemRecord item) {
    final entityType = item.confirmedEntityType;
    final entityId = item.confirmedEntityId;
    if (entityType == null || entityId == null) return null;
    if (entityType == EntityType.caseEntity.index) return '/cases/$entityId';
    if (entityType == EntityType.contract.index) return '/contracts/$entityId';
    if (entityType == EntityType.company.index) return '/companies/$entityId';
    if (entityType == EntityType.adminProcedure.index) return '/procedures/$entityId';
    if (entityType == EntityType.powerOfAttorney.index) return '/poa/$entityId';
    if (entityType == EntityType.person.index) return '/persons/$entityId';
    return null;
  }

  Future<void> _openArchiveOriginalSource(BuildContext context, WidgetRef ref, ArchiveItemRecord item) async {
    final source = item.sourcePath;
    if (source == null || source.trim().isEmpty) return;
    try {
      final file = File(source);
      final directory = Directory(source);
      if (!await file.exists() && !await directory.exists()) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('المصدر الأصلي غير موجود حالياً على الجهاز'), backgroundColor: AppColors.warning));
        return;
      }
      if (Platform.isWindows) {
        await Process.start('explorer', [source]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [source]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [source]);
      }
      await ref.read(auditServiceProvider).log(action: 'open_source', category: 'archive', entityType: 'archive_item', entityId: '${item.id}', entityTitle: item.originalFileName, description: 'فتح المصدر الأصلي لعنصر أرشيف', after: {'sourcePath': source}, severity: 'info');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح المصدر الأصلي: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _openArchiveItemFile(BuildContext context, WidgetRef ref, ArchiveItemRecord item) async {
    final storedPath = item.storedPath;
    if (storedPath == null || storedPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا يوجد ملف محفوظ لهذا العنصر'), backgroundColor: AppColors.warning));
      return;
    }
    try {
      final file = await ref.read(fileStorageServiceProvider).getFileFromRelativePath(storedPath);
      if (file == null) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تعذر العثور على الملف المحفوظ'), backgroundColor: AppColors.warning));
        return;
      }
      if (Platform.isWindows) {
        await Process.start('explorer', [file.path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [file.path]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [file.path]);
      }
      await ref.read(auditServiceProvider).log(action: 'open_file', category: 'archive', entityType: 'archive_item', entityId: '${item.id}', entityTitle: item.originalFileName, description: 'فتح ملف عنصر أرشيف مستورد', severity: 'info');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الملف: $e'), backgroundColor: AppColors.error));
    }
  }

  Map<String, String>? _csvRowData(ArchiveItemRecord item) {
    if (item.fileType != 'csv_row') return null;
    var raw = item.errorMessage ?? '';
    if (raw.trim().isEmpty) return null;
    final jsonStart = raw.indexOf('{');
    if (jsonStart > 0) raw = raw.substring(jsonStart);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry('$key', '${value ?? ''}'));
    } catch (_) {
      return null;
    }
  }

  Widget _csvRowDetails(Map<String, String> data) {
    final entries = data.entries.where((entry) => entry.key.trim().isNotEmpty).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('بيانات صف CSV', style: AppTextStyles.labelLarge.copyWith(color: AppColors.info, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 170, child: Text(entry.key, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary))),
                    Expanded(child: SelectableText(entry.value.isEmpty ? '—' : entry.value, style: AppTextStyles.bodySmall)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          SelectableText(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryNavy)),
          const Divider(height: 12),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'غير محدد';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _restoreArchiveItemReview(BuildContext dialogContext, WidgetRef ref, ArchiveItemRecord item) async {
    final restoredStatus = (item.errorMessage ?? '').contains('مكرر') ? 'duplicate' : 'imported';
    await ref.read(archiveIntakeRepositoryProvider).updateItemReview(
      itemId: item.id,
      status: restoredStatus,
      reviewStatus: 'needs_review',
      reviewedBy: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
      reviewNote: 'إعادة العنصر إلى المراجعة بعد رفض/تجاهل سابق',
    );
    await ref.read(archiveIntakeRepositoryProvider).refreshBatchCounters(item.batchId);
    await ref.read(auditServiceProvider).log(
      action: 'restore_review',
      category: 'archive',
      entityType: 'archive_item',
      entityId: '${item.id}',
      entityTitle: item.originalFileName,
      description: 'إعادة عنصر أرشيف إلى حالة يحتاج مراجعة',
      severity: 'info',
    );
    ref.read(_archiveIntakeRefreshProvider.notifier).state++;
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  Future<void> _reviewArchiveItem(
    BuildContext dialogContext,
    WidgetRef ref,
    ArchiveItemRecord item,
    String status,
    String reviewStatus, {
    required String actionLabel,
    required String defaultNote,
  }) async {
    final noteController = TextEditingController(text: defaultNote);
    final note = await showDialog<String>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: Text(actionLabel),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.originalFileName, style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظة المراجعة'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, noteController.text.trim()), child: Text(actionLabel)),
        ],
      ),
    );
    if (note == null) return;
    await _setItemReview(dialogContext, ref, item.id, item.batchId, status, reviewStatus, reviewNote: note.isEmpty ? defaultNote : note);
  }

  Future<void> _setItemReview(BuildContext dialogContext, WidgetRef ref, int itemId, int batchId, String status, String reviewStatus, {String? reviewNote}) async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.archiveIntakeReview)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'archive', entityType: 'archive_item', entityId: '$itemId', description: 'محاولة مراجعة عنصر أرشيف دون صلاحية', severity: 'warning');
      return;
    }
    await ref.read(archiveIntakeRepositoryProvider).updateItemReview(
      itemId: itemId,
      status: status,
      reviewStatus: reviewStatus,
      reviewedBy: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
      reviewNote: reviewNote ?? (reviewStatus == 'approved' ? 'اعتماد عام من مركز الأرشيف' : 'رفض / تجاهل من مركز الأرشيف'),
    );
    await ref.read(archiveIntakeRepositoryProvider).refreshBatchCounters(batchId);
    await ref.read(auditServiceProvider).log(action: reviewStatus == 'approved' ? 'approve' : 'reject', category: 'archive', entityType: 'archive_item', entityId: '$itemId', description: reviewStatus == 'approved' ? 'اعتماد عنصر أرشيف' : 'رفض عنصر أرشيف', severity: reviewStatus == 'approved' ? 'info' : 'warning');
    ref.read(_archiveIntakeRefreshProvider.notifier).state++;
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  Future<void> _showLinkItemDialog(BuildContext context, WidgetRef ref, ArchiveItemRecord item) async {
    _ArchiveLinkTarget target = _ArchiveLinkTarget.caseFile;
    String documentType = _documentTypeOptions.containsKey(item.suggestedDocumentType) ? item.suggestedDocumentType! : 'archive_document';
    int? selectedId;
    String selectedTitle = '';
    final search = TextEditingController();
    final customDocumentType = TextEditingController();
    final paperLocation = TextEditingController();
    final paperBox = TextEditingController();
    final paperShelf = TextEditingController();
    final paperFolder = TextEditingController();
    final reviewedBy = TextEditingController();
    bool paperOriginalSaved = false;
    bool canDestroyOriginal = false;
    // حالة ملف المكتب للكيان المرتبط: جارٍ (يغذي مكتب العمل) أو منتهٍ (حفظ وبحث فقط).
    bool linkedFileIsClosed = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('ربط ملف: ${item.originalFileName}'),
          content: SizedBox(
            width: 780,
            height: 660,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<_ArchiveLinkTarget>(
                        value: target,
                        decoration: const InputDecoration(labelText: 'يرتبط هذا المستند بـ'),
                        items: _ArchiveLinkTarget.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                        onChanged: (v) => setDialog(() { target = v ?? target; selectedId = null; selectedTitle = ''; search.clear(); }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: documentType,
                        decoration: const InputDecoration(labelText: 'نوع المستند'),
                        items: _documentTypeOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (v) => setDialog(() => documentType = v ?? documentType),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: customDocumentType, decoration: const InputDecoration(labelText: 'نوع مستند آخر / غير موجود بالقائمة')),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: paperOriginalSaved,
                  title: const Text('هل الأصل الورقي محفوظ؟'),
                  onChanged: (v) => setDialog(() => paperOriginalSaved = v ?? false),
                ),
                if (paperOriginalSaved) ...[
                  TextField(controller: paperLocation, decoration: const InputDecoration(labelText: 'مكان الأصل')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: paperBox, decoration: const InputDecoration(labelText: 'الصندوق'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: paperShelf, decoration: const InputDecoration(labelText: 'الرف'))),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: paperFolder, decoration: const InputDecoration(labelText: 'المجلد الورقي')),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: canDestroyOriginal,
                    title: const Text('هل يجوز إتلاف الأصل لاحقاً؟'),
                    onChanged: (v) => setDialog(() => canDestroyOriginal = v ?? false),
                  ),
                ],
                TextField(controller: reviewedBy, decoration: const InputDecoration(labelText: 'من راجع النسخة الرقمية؟')),
                if (target != _ArchiveLinkTarget.person) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    value: linkedFileIsClosed,
                    decoration: const InputDecoration(labelText: 'حالة ملف المكتب المرتبط'),
                    items: const [
                      DropdownMenuItem(value: false, child: Text('جارٍ — يغذي مكتب العمل بالمواعيد القادمة')),
                      DropdownMenuItem(value: true, child: Text('منتهٍ — للحفظ والبحث فقط')),
                    ],
                    onChanged: (v) => setDialog(() => linkedFileIsClosed = v ?? false),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(controller: search, decoration: InputDecoration(labelText: 'بحث في ${target.label}', prefixIcon: const Icon(Icons.search)), onChanged: (_) => setDialog(() {})),
                const SizedBox(height: 8),
                SizedBox(height: 220, child: _linkChoices(ref, target, search.text, selectedId, (id, title) => setDialog(() { selectedId = id; selectedTitle = title; }))),
                if (selectedId != null) Align(alignment: Alignment.centerRight, child: Text('تم اختيار: $selectedTitle', style: AppTextStyles.bodySmallSecondary)),
              ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      try {
                        final effectiveDocumentType = customDocumentType.text.trim().isNotEmpty ? customDocumentType.text.trim() : documentType;
                        final paperNotes = [
                          'الأصل الورقي محفوظ: ${paperOriginalSaved ? 'نعم' : 'لا'}',
                          if (paperLocation.text.trim().isNotEmpty) 'مكان الأصل: ${paperLocation.text.trim()}',
                          if (paperBox.text.trim().isNotEmpty) 'الصندوق: ${paperBox.text.trim()}',
                          if (paperShelf.text.trim().isNotEmpty) 'الرف: ${paperShelf.text.trim()}',
                          if (paperFolder.text.trim().isNotEmpty) 'المجلد الورقي: ${paperFolder.text.trim()}',
                          'يجوز إتلاف الأصل: ${canDestroyOriginal ? 'نعم' : 'لا'}',
                          if (reviewedBy.text.trim().isNotEmpty) 'راجع النسخة الرقمية: ${reviewedBy.text.trim()}',
                        ].join('\n');
                        final docId = await ref.read(archiveIntakeRepositoryProvider).promoteItemToDocument(
                          itemId: item.id,
                          documentType: effectiveDocumentType,
                          entityType: target.entityType,
                          entityId: selectedId!,
                          userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
                          archiveNotes: paperNotes,
                          physicalLocation: paperOriginalSaved ? 0 : 1,
                          paperOriginalSaved: paperOriginalSaved,
                          paperLocation: paperLocation.text.trim().isEmpty ? null : paperLocation.text.trim(),
                          paperBox: paperBox.text.trim().isEmpty ? null : paperBox.text.trim(),
                          paperShelf: paperShelf.text.trim().isEmpty ? null : paperShelf.text.trim(),
                          paperFolder: paperFolder.text.trim().isEmpty ? null : paperFolder.text.trim(),
                          canDestroyOriginal: canDestroyOriginal,
                          reviewedBy: reviewedBy.text.trim().isEmpty ? null : reviewedBy.text.trim(),
                          officeFileStatus: linkedFileIsClosed ? OfficeFileStatus.closed : OfficeFileStatus.active,
                        );
                        await ref.read(auditServiceProvider).log(action: 'link', category: 'archive', entityType: 'archive_item', entityId: '${item.id}', entityTitle: item.originalFileName, description: 'ربط عنصر أرشيف بملف وإنشاء مستند رقم $docId', after: {'target': target.label, 'targetId': selectedId, 'documentType': effectiveDocumentType, 'paperOriginalSaved': paperOriginalSaved, 'paperLocation': paperLocation.text.trim(), 'box': paperBox.text.trim(), 'shelf': paperShelf.text.trim(), 'paperFolder': paperFolder.text.trim(), 'canDestroyOriginal': canDestroyOriginal, 'reviewedBy': reviewedBy.text.trim(), 'officeFileStatus': linkedFileIsClosed ? 'closed' : 'active'}, severity: 'info');
                        _refreshArchiveDocumentProviders(ref);
                        ref.read(_archiveIntakeRefreshProvider.notifier).state++;
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الربط: $e'), backgroundColor: AppColors.error));
                      }
                    },
              child: const Text('ربط واعتماد'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkChoices(WidgetRef ref, _ArchiveLinkTarget target, String rawQuery, int? selectedId, void Function(int id, String title) onSelect) {
    final query = _normalizeSearchText(rawQuery);
    switch (target) {
      case _ArchiveLinkTarget.caseFile:
        return ref.watch(allCasesProvider).when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Text('تعذر تحميل الدعاوى: $e'), data: (items) => _choiceList(items.where((c) => query.isEmpty || _containsSearch(c.internalNumber, query) || _containsSearch(c.subject, query) || _containsSearch(c.baseNumber, query)).take(20).map((c) => (id: c.id, title: '${c.internalNumber} — ${c.subject ?? 'دعوى'}')).toList(), selectedId, onSelect));
      case _ArchiveLinkTarget.procedure:
        return ref.watch(allProceduresProvider).when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Text('تعذر تحميل الإجراءات: $e'), data: (items) => _choiceList(items.where((p) => query.isEmpty || _containsSearch(p.title, query) || _containsSearch(p.transactionNumber, query)).take(20).map((p) => (id: p.id, title: '${p.title} — ${p.transactionNumber ?? p.procedureType}')).toList(), selectedId, onSelect));
      case _ArchiveLinkTarget.company:
        return ref.watch(allCompaniesProvider).when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Text('تعذر تحميل الشركات: $e'), data: (items) => _choiceList(items.where((c) => query.isEmpty || _containsSearch(c.name, query) || _containsSearch(c.internalNumber, query)).take(20).map((c) => (id: c.id, title: '${c.name} — ${c.internalNumber}')).toList(), selectedId, onSelect));
      case _ArchiveLinkTarget.contract:
        return ref.watch(allContractsProvider).when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Text('تعذر تحميل العقود: $e'), data: (items) => _choiceList(items.where((c) => query.isEmpty || _containsSearch(c.title, query) || _containsSearch(c.internalNumber, query)).take(20).map((c) => (id: c.id, title: '${c.title} — ${c.internalNumber}')).toList(), selectedId, onSelect));
      case _ArchiveLinkTarget.person:
        return ref.watch(allPersonsProvider(null)).when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Text('تعذر تحميل الأشخاص: $e'), data: (items) => _choiceList(items.where((p) => query.isEmpty || _containsSearch(p.fullName, query) || _containsSearch(p.phone1, query) || _containsSearch(p.nationalId, query)).take(20).map((p) => (id: p.id, title: p.fullName)).toList(), selectedId, onSelect));
      case _ArchiveLinkTarget.poa:
        return ref.watch(uiPersonsDirectoryProvider).when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Text('تعذر تحميل الوكالات: $e'), data: (state) => _choiceList(state.agencies.where((a) => query.isEmpty || _containsSearch(a.number, query) || _containsSearch(state.personById(a.principalPersonId)?.fullName, query)).take(20).map((a) => (id: int.tryParse(a.id) ?? 0, title: '${a.number} — ${state.personById(a.principalPersonId)?.fullName ?? 'موكل'}')).where((e) => e.id > 0).toList(), selectedId, onSelect));
    }
  }

  Widget _choiceList(List<({int id, String title})> choices, int? selectedId, void Function(int id, String title) onSelect) {
    if (choices.isEmpty) return const Center(child: Text('لا توجد نتائج مطابقة'));
    return ListView.builder(
      itemCount: choices.length,
      itemBuilder: (_, index) {
        final item = choices[index];
        final selected = selectedId == item.id;
        return ListTile(
          selected: selected,
          leading: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? AppColors.success : AppColors.textSecondary),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onSelect(item.id, item.title),
        );
      },
    );
  }

  IconData _itemIcon(String status) {
    switch (status) {
      case 'duplicate': return Icons.copy_all;
      case 'failed': return Icons.error_outline;
      case 'rejected': return Icons.block;
      default: return Icons.insert_drive_file;
    }
  }

  Color _itemColor(String status) {
    switch (status) {
      case 'duplicate': return AppColors.info;
      case 'failed': return AppColors.error;
      case 'rejected': return AppColors.error;
      default: return AppColors.primaryNavy;
    }
  }

  String _documentTypeLabel(String key) => _documentTypeOptions[key] ?? key;

  String _itemStatusLabel(String status) {
    switch (status) {
      case 'imported': return 'مستورد';
      case 'duplicate': return 'مكرر';
      case 'failed': return 'فشل';
      case 'rejected': return 'مرفوض';
      default: return status;
    }
  }

  String _reviewStatusLabel(String status) {
    switch (status) {
      case 'needs_review': return 'يحتاج مراجعة';
      case 'approved': return 'معتمد';
      case 'rejected': return 'مرفوض';
      default: return status;
    }
  }

  Widget _notice() {
    return Card(
      color: AppColors.warning.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.warning),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'يمكنك الآن إنشاء دفعات، إضافة ملفات، كشف المكررات، ربط العناصر بملفات المكتب، وتصدير قوالب CSV وتقارير الجودة. استيراد CSV المباشر سيُنفذ لاحقاً بحذر بعد تثبيت حقول المطابقة النهائية.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
