import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/court_catalog.dart';
import '../../../data/database/database.dart' as db;
import '../../providers/app_providers.dart';
import '../../screens/cases/case_models.dart' show CaseType;
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'searchable_picker.dart';

/// اختيار محكمة كاملة: الدرجة ← نوع المحكمة ← المحافظة ← الغرفة.
///
/// كانت المحكمة تُختار بالمحافظة وحدها، فيصير جواب «أمام أي محكمة؟»
/// هو «حمص». هنا تُبنى المحكمة من أجزائها الأربعة، وتُقصر الخيارات
/// على ما يقبله نوع الدعوى فعلاً: لا استئناف للدعوى الدستورية، ولا
/// محكمة نقض في حماة.
class CourtSelection {
  /// معرّف نوع المحكمة من `CourtCatalog`.
  final String? kindId;

  /// المحافظة التي تنعقد فيها.
  final String? governorate;

  /// معرّف سجل المحكمة في قاعدة البيانات (مفتاح أجنبي حقيقي).
  final int? courtId;

  /// رقم الغرفة، إن كانت المحكمة تُقسم إلى غرف.
  final int? chamberNumber;

  const CourtSelection({
    this.kindId,
    this.governorate,
    this.courtId,
    this.chamberNumber,
  });

  CourtKind? get kind => CourtCatalog.byId(kindId);

  /// جاهزة للحفظ: النوع والمحافظة ومعرّف السجل كلها محددة.
  ///
  /// الغرفة لا تدخل في الشرط لأن بعض المحاكم بلا غرف مرقّمة
  /// (قاضي التحقيق، المحكمة الإدارية العليا).
  bool get isComplete =>
      kindId != null && governorate != null && courtId != null;

  String get description => CourtCatalog.describeStored(
        kindId: kindId,
        governorate: governorate,
        chamberNumber: chamberNumber,
      );

  CourtSelection copyWith({
    Object? kindId = _keep,
    Object? governorate = _keep,
    Object? courtId = _keep,
    Object? chamberNumber = _keep,
  }) {
    return CourtSelection(
      kindId: kindId == _keep ? this.kindId : kindId as String?,
      governorate:
          governorate == _keep ? this.governorate : governorate as String?,
      courtId: courtId == _keep ? this.courtId : courtId as int?,
      chamberNumber: chamberNumber == _keep
          ? this.chamberNumber
          : chamberNumber as int?,
    );
  }

  static const Object _keep = Object();
}

/// حقل اختيار المحكمة المركّب.
///
/// [caseType] يحصر أنواع المحاكم المعروضة. [restrictToKinds] يحصرها
/// أكثر عند النقل لمرحلة أعلى، فلا يُعرض إلا ما يقبله مسار الطعن.
class CourtSelector extends ConsumerWidget {
  const CourtSelector({
    super.key,
    required this.caseType,
    required this.value,
    required this.onChanged,
    this.restrictToKinds,
    this.showDegreeFilter = true,
    this.errorText,
    this.preferredGovernorate,
  });

  final CaseType caseType;
  final CourtSelection value;
  final ValueChanged<CourtSelection> onChanged;

  /// حصر الأنواع المعروضة بمعرّفات بعينها (مسار الطعن المسموح).
  final List<String>? restrictToKinds;

  /// إظهار شريحة الدرجة. تُخفى عند النقل لأن الدرجة محسومة سلفاً.
  final bool showDegreeFilter;

  final String? errorText;

  /// محافظة تُختار تلقائياً عند توفّرها في قائمة المحكمة.
  ///
  /// تأتي من شاشة الأرشيف حيث حدّد المستخدم المحافظة قبل فتح
  /// الويزارد، فلا يُعاد سؤاله عنها.
  final String? preferredGovernorate;

  /// أنواع المحاكم المتاحة بعد تطبيق نوع الدعوى وقيد مسار الطعن.
  List<CourtKind> _availableKinds() {
    final byCaseType = CourtCatalog.forCaseType(caseType);
    if (restrictToKinds == null) return byCaseType;

    // مسار الطعن يعلو على نوع الدعوى: قد يُستأنف حكم عمالي أمام
    // غرفة مدنية لا تُدرج ضمن محاكم النوع العمالي.
    final allowed = restrictToKinds!.toSet();
    final fromPath = CourtCatalog.all.where((k) => allowed.contains(k.id));
    final merged = <String, CourtKind>{
      for (final k in byCaseType.where((k) => allowed.contains(k.id))) k.id: k,
      for (final k in fromPath) k.id: k,
    };
    final result = merged.values.toList();
    result.sort((a, b) => a.degree.index.compareTo(b.degree.index));
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kinds = _availableKinds();

    if (kinds.isEmpty) {
      return _notice(
        'لا توجد محاكم مسجّلة لهذا النوع من الدعاوى.',
        AppColors.warning,
      );
    }

    final selectedKind = CourtCatalog.byId(value.kindId);
    final degrees = kinds.map((k) => k.degree).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    // الدرجة المعروضة تتبع النوع المختار؛ وقبل الاختيار تُعرض
    // الدرجة الأولى لأنها مبدأ التقاضي المعتاد.
    final activeDegree = selectedKind?.degree ?? degrees.first;
    final kindsInDegree =
        kinds.where((k) => k.degree == activeDegree).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDegreeFilter && degrees.length > 1) ...[
          Text('درجة التقاضي', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final degree in degrees)
                ChoiceChip(
                  label: Text(degree.label),
                  selected: degree == activeDegree,
                  onSelected: (_) {
                    // تغيير الدرجة يلغي كل ما بُني على الدرجة
                    // السابقة: النوع والسجل والغرفة.
                    final first =
                        kinds.firstWhere((k) => k.degree == degree);
                    onChanged(CourtSelection(kindId: first.id));
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ---------------------- نوع المحكمة ----------------------
        DropdownButtonFormField<String>(
          initialValue: kindsInDegree.any((k) => k.id == value.kindId)
              ? value.kindId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'المحكمة',
            hintText: 'اختر نوع المحكمة',
            prefixIcon: const Icon(Icons.account_balance),
            errorText: errorText,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            for (final kind in kindsInDegree)
              DropdownMenuItem(
                value: kind.id,
                child: Text(kind.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) => onChanged(CourtSelection(kindId: id)),
        ),

        if (selectedKind != null) ...[
          const SizedBox(height: 16),
          _governorateField(ref, selectedKind),
          if (selectedKind.hasChambers) ...[
            const SizedBox(height: 16),
            _chamberField(selectedKind),
          ],
          const SizedBox(height: 12),
          _summary(selectedKind),
        ],
      ],
    );
  }

  /// اختيار المحافظة من سجلات المحاكم الحقيقية.
  ///
  /// القائمة تأتي من قاعدة البيانات لا من ثابت، لأن `courtId` مفتاح
  /// أجنبي يجب أن يشير إلى سجل قائم فعلاً.
  Widget _governorateField(WidgetRef ref, CourtKind kind) {
    // محكمة دمشق وحدها: لا معنى لقائمة من عنصر واحد، تُثبَّت تلقائياً.
    if (kind.damascusOnly) {
      return ref.watch(courtsOfKindProvider(kind.id)).when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => _notice('تعذّر تحميل المحكمة: $e', AppColors.error),
            data: (courts) {
              final court = courts.isEmpty ? null : courts.first;
              if (court == null) {
                return _notice(
                  'سجل هذه المحكمة غير موجود. أعد تشغيل التطبيق لاستكمال القوائم.',
                  AppColors.error,
                );
              }
              if (value.courtId != court.id) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onChanged(value.copyWith(
                    governorate: court.name,
                    courtId: court.id,
                  ));
                });
              }
              return InputDecorator(
                decoration: InputDecoration(
                  labelText: 'مقر المحكمة',
                  prefixIcon: const Icon(Icons.location_city),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('${court.name} (مقرها القانوني)',
                    style: AppTextStyles.bodyMedium),
              );
            },
          );
    }

    return ref.watch(courtsOfKindProvider(kind.id)).when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => _notice('تعذّر تحميل المحاكم: $e', AppColors.error),
          data: (courts) {
            if (courts.isEmpty) {
              return _notice(
                'لا توجد سجلات لهذه المحكمة. أعد تشغيل التطبيق لاستكمال القوائم.',
                AppColors.error,
              );
            }
            // اختيار محافظة الأرشيف تلقائياً مرة واحدة.
            if (value.courtId == null && preferredGovernorate != null) {
              final match = courts
                  .where((c) => c.name == preferredGovernorate)
                  .firstOrNull;
              if (match != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onChanged(value.copyWith(
                    governorate: match.name,
                    courtId: match.id,
                  ));
                });
              }
            }
            return SearchablePicker<db.Court>(
              label: 'المحافظة',
              hintText: 'اختر المحافظة',
              prefixIcon: const Icon(Icons.location_city),
              items: courts,
              labelOf: (c) => c.name,
              searchTermsOf: (c) => [c.city ?? ''],
              value: value.courtId == null
                  ? null
                  : courts.where((c) => c.id == value.courtId).firstOrNull,
              onSelected: (c) => onChanged(
                value.copyWith(governorate: c.name, courtId: c.id),
              ),
            );
          },
        );
  }

  Widget _chamberField(CourtKind kind) {
    return DropdownButtonFormField<int>(
      initialValue: value.chamberNumber,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'الغرفة (اختياري)',
        hintText: 'اختر رقم الغرفة',
        prefixIcon: const Icon(Icons.meeting_room_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [
        for (int i = 1; i <= 16; i++)
          DropdownMenuItem(value: i, child: Text('الغرفة $i')),
        if (value.chamberNumber != null && value.chamberNumber! > 16)
          DropdownMenuItem(
            value: value.chamberNumber,
            child: Text('الغرفة ${value.chamberNumber}'),
          ),
      ],
      onChanged: (v) => onChanged(value.copyWith(chamberNumber: v)),
    );
  }

  /// سطر يعرض المحكمة كما ستُحفظ وتُطبع، فيرى المحامي النتيجة قبل الحفظ.
  Widget _summary(CourtKind kind) {
    final text = kind.describe(
      governorate: value.governorate,
      chamberNumber: value.chamberNumber,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel, size: 16, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.labelMedium)),
        ],
      ),
    );
  }

  Widget _notice(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(message, style: AppTextStyles.bodySmall),
    );
  }
}
