/// خدمة فلترة الوكالات حسب نوع الدعوى
///
/// القواعد الأساسية:
/// - الوكالة العامة: صالحة لجميع أنواع الدعاوى
/// - سند التوكيل الخاص: صالح فقط لموضوع الوكالة المحدد
library;

import '../database/database.dart';
import '../../presentation/screens/cases/case_models.dart';

/// نتيجة فلترة الوكالة
class PoaFilterResult {
  final PowerOfAttorney poa;
  final bool isValid;
  final String? reason;
  final bool canOverride;

  const PoaFilterResult({
    required this.poa,
    required this.isValid,
    this.reason,
    this.canOverride = false,
  });
}

/// خدمة فلترة الوكالات
class PoaFilterService {
  /// فلترة الوكالات حسب نوع الدعوى
  List<PoaFilterResult> filterPoasForCaseType(
    List<PowerOfAttorney> poas,
    CaseType caseType,
  ) {
    return poas.map((poa) {
      final isValid = isPoaValidForCaseType(poa, caseType);

      return PoaFilterResult(
        poa: poa,
        isValid: isValid,
        reason: isValid
            ? null
            : (poa.poaType == 0 // عام
                ? 'الوكالة العامة صالحة لجميع الدعاوى'
                : 'سند التوكيل الخاص لا يغطي دعاوى ${_getCaseTypeName(caseType)}'),
        canOverride: !isValid && poa.poaType == 1, // خاص
      );
    }).toList();
  }

  /// هل الوكالة صالحة لهذا النوع من الدعاوى؟
  bool isPoaValidForCaseType(PowerOfAttorney poa, CaseType caseType) {
    // الوكالات العامة (poaType == 0) صالحة دائماً
    if (poa.poaType == 0) {
      return true;
    }

    // سندات التوكيل الخاصة (poaType == 1) تحتاج تحقق
    if (poa.poaType == 1) {
      return _checkSpecialPoaCoverage(poa, caseType);
    }

    // الأنواع الأخرى غير صالحة
    return false;
  }

  /// التحقق من تغطية سند التوكيل الخاص
  bool _checkSpecialPoaCoverage(PowerOfAttorney poa, CaseType caseType) {
    final category = poa.category?.toLowerCase() ?? '';
    final subType = poa.subType?.toLowerCase() ?? '';
    final scopeText = poa.scopeText?.toLowerCase() ?? '';
    final combined = '$category $subType $scopeText';

    switch (caseType) {
      case CaseType.civil:
        return combined.contains('مدني');

      case CaseType.criminal:
        return combined.contains('جزائي') || combined.contains('جنائي');

      case CaseType.commercial:
        return combined.contains('تجاري');

      case CaseType.personalStatus:
        return combined.contains('أحوال شخصية') ||
            combined.contains('احوال شخصية') ||
            combined.contains('شرعي');

      case CaseType.labor:
        return combined.contains('عمالي') || combined.contains('عمل');

      case CaseType.realEstate:
        return combined.contains('عقاري') || combined.contains('عقار');

      case CaseType.administrative:
        return combined.contains('إداري') || combined.contains('اداري');

      case CaseType.constitutional:
        return combined.contains('دستوري');

      case CaseType.other:
        return true; // نوع آخر = يقبل أي وكالة
    }
  }

  /// الحصول على اسم نوع الدعوى
  String _getCaseTypeName(CaseType caseType) {
    switch (caseType) {
      case CaseType.civil:
        return 'مدنية';
      case CaseType.criminal:
        return 'جزائية';
      case CaseType.commercial:
        return 'تجارية';
      case CaseType.personalStatus:
        return 'أحوال شخصية';
      case CaseType.labor:
        return 'عمالية';
      case CaseType.realEstate:
        return 'عقارية';
      case CaseType.administrative:
        return 'إدارية';
      case CaseType.constitutional:
        return 'دستورية';
      case CaseType.other:
        return 'أخرى';
    }
  }

  /// الحصول على وصف نوع الوكالة
  String getPoaTypeDescription(PowerOfAttorney poa) {
    if (poa.poaType == 0) {
      return 'عامة - صالحة لكل الدعاوى';
    } else if (poa.poaType == 1) {
      return 'خاصة - ${poa.subType ?? 'غير محدد'}';
    }
    return 'غير محدد';
  }

  /// التحقق إذا كانت الوكالة عامة
  bool isGeneralPoa(PowerOfAttorney poa) {
    return poa.poaType == 0;
  }

  /// التحقق إذا كانت الوكالة خاصة
  bool isSpecialPoa(PowerOfAttorney poa) {
    return poa.poaType == 1;
  }
}
