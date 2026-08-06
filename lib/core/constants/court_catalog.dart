// CaseType معرّف في نماذج شاشة الدعاوى لا في app_enums؛ يُستورد
// بـ show حتى لا تُسحب بقية النماذج إلى طبقة الثوابت.
import '../../presentation/screens/cases/case_models.dart' show CaseType;
import 'app_constants.dart';

/// خارطة القضاء السوري: درجات التقاضي وأنواع المحاكم ومسارات الطعن.
///
/// نشأ هذا الملف من عطل واقعي: كانت شاشة نقل الدعوى تعرض «المرحلة
/// الجديدة» من قائمة `CasePhaseType` كاملة، فتظهر «جلسات» و«إثبات»
/// و«حكم» كأنها درجات تقاضٍ، ويظهر «صلح» خياراً بعد «استئناف».
/// وكانت المحكمة تُختار بالمحافظة وحدها، فيصير الجواب عن سؤال
/// «أمام أي محكمة استُؤنفت؟» هو «دمشق» — وهذا ليس اسم محكمة.
///
/// المرجع البنيوي: قانون السلطة القضائية وقانون أصول المحاكمات
/// المدنية والجزائية:
///   - الدرجة الأولى: الصلح والبداية والمحاكم الشرعية والأحداث.
///   - الدرجة الثانية: محاكم الاستئناف (غرف) ومحكمة الجنايات.
///   - النقض: محكمة واحدة مقرها دمشق، دوائرها مدنية وجزائية وأحوال
///     شخصية، ولا تُعدّ درجة تقاضٍ بل محكمة قانون.
///   - القضاء الإداري: المحكمة الإدارية ← محكمة القضاء الإداري ←
///     المحكمة الإدارية العليا (الأخيرتان في دمشق).
///
/// القاعدة الحاكمة: **المحكمة = نوعها + محافظتها + غرفتها**. المحافظة
/// وحدها لا تعرّف محكمة، ولذلك يخزَّن `courtKind` إلى جانب `courtId`.

/// درجة التقاضي: موقع المحكمة في سلّم الطعون لا تخصصها.
enum LitigationDegree {
  /// ما قبل المحاكمة: النيابة العامة وقاضي التحقيق وقاضي الإحالة.
  preTrial('ما قبل المحاكمة'),

  /// الدرجة الأولى: الصلح والبداية والشرعية والأحداث والإدارية.
  first('الدرجة الأولى'),

  /// الدرجة الثانية: الاستئناف بغرفه ومحكمة الجنايات.
  second('الدرجة الثانية (الاستئناف)'),

  /// النقض والمحكمة الإدارية العليا: محاكم قانون لا موضوع.
  cassation('النقض / الطعن الأعلى'),

  /// التنفيذ: دائرة التنفيذ ورئيسها، مسار مستقل عن سلّم الطعون.
  execution('التنفيذ'),

  /// المخاصمة: دعوى أصلية على القاضي لا طعن في حكمه.
  litigationAgainstJudges('المخاصمة');

  final String label;
  const LitigationDegree(this.label);
}

/// نوع محكمة واحد: اسمه ودرجته وأين ينعقد وهل له غرف مرقّمة.
class CourtKind {
  /// معرّف ثابت يُخزَّن في قاعدة البيانات. لا يُترجم ولا يُغيَّر.
  final String id;

  /// الاسم المعروض للمستخدم، بلا اسم المحافظة (يُضاف عند العرض).
  final String label;

  final LitigationDegree degree;

  /// أنواع الدعاوى التي تُنظر أمام هذه المحكمة.
  final List<CaseType> caseTypes;

  /// المحاكم التي تنعقد في دمشق وحدها: النقض والقضاء الإداري
  /// والمحكمة الإدارية العليا. عرض بقية المحافظات معها خطأ.
  final bool damascusOnly;

  /// هل تُقسم إلى غرف مرقّمة (الصلح، البداية، الاستئناف، الجنايات)؟
  /// دوائر النقض ليست غرفاً مرقّمة يختارها المحامي.
  final bool hasChambers;

  /// المحاكم التي يُطعن أمامها بقرارات هذه المحكمة.
  final List<String> appealsTo;

  const CourtKind({
    required this.id,
    required this.label,
    required this.degree,
    required this.caseTypes,
    this.damascusOnly = false,
    this.hasChambers = false,
    this.appealsTo = const [],
  });

  /// المحافظات التي يجوز أن تنعقد فيها هذه المحكمة.
  List<String> get governorates =>
      damascusOnly ? const ['دمشق'] : AppConstants.syrianGovernorates;

  /// وصف كامل للعرض والطباعة: النوع + المحافظة + الغرفة.
  String describe({String? governorate, int? chamberNumber}) {
    final buffer = StringBuffer(label);
    if (governorate != null && governorate.trim().isNotEmpty) {
      buffer.write(' في $governorate');
    }
    if (hasChambers && chamberNumber != null) {
      buffer.write(' — الغرفة $chamberNumber');
    }
    return buffer.toString();
  }
}

/// الفهرس الكامل لأنواع المحاكم ومسارات الطعن بينها.
class CourtCatalog {
  CourtCatalog._();

  // ---------------------------------------------------------------------------
  // معرّفات ثابتة: تُستعمل في الكود وتُخزَّن في العمود courtKind
  // ---------------------------------------------------------------------------
  static const String conciliationCivil = 'conciliation_civil';
  static const String firstInstanceCivil = 'first_instance_civil';
  static const String firstInstanceCommercial = 'first_instance_commercial';
  static const String appealCivil = 'appeal_civil';
  static const String appealCommercial = 'appeal_commercial';
  static const String cassationCivil = 'cassation_civil';

  static const String publicProsecution = 'public_prosecution';
  static const String investigatingJudge = 'investigating_judge';
  static const String referralJudge = 'referral_judge';
  static const String conciliationCriminal = 'conciliation_criminal';
  static const String firstInstanceCriminal = 'first_instance_criminal';
  static const String juvenileCourt = 'juvenile_court';
  static const String appealMisdemeanor = 'appeal_misdemeanor';
  static const String feloniesCourt = 'felonies_court';
  static const String cassationCriminal = 'cassation_criminal';

  static const String shariaCourt = 'sharia_court';
  // ملاحظة: لا توجد محكمة استئناف شرعية في سوريا. المحكمة الشرعية
  // تحكم بالدرجة الأخيرة ويُطعن بأحكامها بالنقض مباشرة (المادة 498/د
  // من قانون أصول المحاكمات المدنية 1/2016).
  static const String cassationPersonalStatus = 'cassation_personal_status';

  static const String administrativeCourt = 'administrative_court';
  static const String administrativeJudiciaryCourt =
      'administrative_judiciary_court';
  static const String supremeAdministrativeCourt =
      'supreme_administrative_court';

  static const String realEstateJudge = 'real_estate_judge';
  static const String laborFirstInstance = 'labor_first_instance';
  static const String dismissalCommittee = 'dismissal_committee';

  static const String executionDepartment = 'execution_department';

  static const String appealAgainstJudges = 'appeal_against_judges';
  static const String cassationAgainstJudges = 'cassation_against_judges';

  static const String constitutionalCourt = 'constitutional_court';

  /// كل أنواع المحاكم. الترتيب هنا هو ترتيب العرض في القوائم.
  static const List<CourtKind> all = [
    // ----------------------- مدني وتجاري -----------------------
    CourtKind(
      id: conciliationCivil,
      label: 'محكمة الصلح المدنية',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.civil],
      hasChambers: true,
      appealsTo: [appealCivil],
    ),
    CourtKind(
      id: firstInstanceCivil,
      label: 'محكمة البداية المدنية',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.civil],
      hasChambers: true,
      appealsTo: [appealCivil],
    ),
    CourtKind(
      id: firstInstanceCommercial,
      label: 'محكمة البداية المدنية (الغرفة التجارية)',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.commercial],
      hasChambers: true,
      appealsTo: [appealCommercial],
    ),
    CourtKind(
      id: appealCivil,
      label: 'محكمة الاستئناف المدنية',
      degree: LitigationDegree.second,
      caseTypes: [CaseType.civil],
      hasChambers: true,
      appealsTo: [cassationCivil],
    ),
    CourtKind(
      id: appealCommercial,
      label: 'محكمة الاستئناف (الغرفة التجارية)',
      degree: LitigationDegree.second,
      caseTypes: [CaseType.commercial],
      hasChambers: true,
      appealsTo: [cassationCivil],
    ),
    CourtKind(
      id: cassationCivil,
      label: 'محكمة النقض — الدائرة المدنية والتجارية',
      degree: LitigationDegree.cassation,
      caseTypes: [
        CaseType.civil,
        CaseType.commercial,
      ],
      damascusOnly: true,
    ),

    // -------------------------- جزائي --------------------------
    CourtKind(
      id: publicProsecution,
      label: 'النيابة العامة',
      degree: LitigationDegree.preTrial,
      caseTypes: [CaseType.criminal],
      appealsTo: [investigatingJudge, conciliationCriminal],
    ),
    CourtKind(
      id: investigatingJudge,
      label: 'قاضي التحقيق',
      degree: LitigationDegree.preTrial,
      caseTypes: [CaseType.criminal],
      appealsTo: [referralJudge],
    ),
    CourtKind(
      id: referralJudge,
      label: 'قاضي الإحالة',
      degree: LitigationDegree.preTrial,
      caseTypes: [CaseType.criminal],
      appealsTo: [feloniesCourt, firstInstanceCriminal],
    ),
    CourtKind(
      id: conciliationCriminal,
      label: 'محكمة الصلح الجزائية',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.criminal],
      hasChambers: true,
      appealsTo: [appealMisdemeanor],
    ),
    CourtKind(
      id: firstInstanceCriminal,
      label: 'محكمة بداية الجزاء',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.criminal],
      hasChambers: true,
      appealsTo: [appealMisdemeanor],
    ),
    CourtKind(
      id: juvenileCourt,
      label: 'محكمة الأحداث',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.criminal],
      appealsTo: [appealMisdemeanor],
    ),
    CourtKind(
      id: appealMisdemeanor,
      label: 'محكمة استئناف الجنح',
      degree: LitigationDegree.second,
      caseTypes: [CaseType.criminal],
      hasChambers: true,
      appealsTo: [cassationCriminal],
    ),
    CourtKind(
      id: feloniesCourt,
      label: 'محكمة الجنايات',
      degree: LitigationDegree.second,
      caseTypes: [CaseType.criminal],
      hasChambers: true,
      appealsTo: [cassationCriminal],
    ),
    CourtKind(
      id: cassationCriminal,
      label: 'محكمة النقض — الدائرة الجزائية',
      degree: LitigationDegree.cassation,
      caseTypes: [CaseType.criminal],
      damascusOnly: true,
    ),

    // ------------------ شرعي / أحوال شخصية ---------------------
    CourtKind(
      id: shariaCourt,
      label: 'المحكمة الشرعية',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.personalStatus],
      hasChambers: true,
      // المحكمة الشرعية تحكم بالدرجة الأخيرة — الطعن بالنقض مباشرة.
      appealsTo: [cassationPersonalStatus],
    ),
    CourtKind(
      id: cassationPersonalStatus,
      label: 'محكمة النقض — دائرة الأحوال الشخصية',
      degree: LitigationDegree.cassation,
      caseTypes: [CaseType.personalStatus],
      damascusOnly: true,
    ),

    // -------------------------- إداري --------------------------
    CourtKind(
      id: administrativeCourt,
      label: 'المحكمة الإدارية',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.administrative],
      appealsTo: [administrativeJudiciaryCourt],
    ),
    CourtKind(
      id: administrativeJudiciaryCourt,
      label: 'محكمة القضاء الإداري',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.administrative],
      damascusOnly: true,
      appealsTo: [supremeAdministrativeCourt],
    ),
    CourtKind(
      id: supremeAdministrativeCourt,
      label: 'المحكمة الإدارية العليا',
      degree: LitigationDegree.cassation,
      caseTypes: [CaseType.administrative],
      damascusOnly: true,
    ),

    // ------------------ عقاري وعمالي وتنفيذ --------------------
    CourtKind(
      id: realEstateJudge,
      label: 'القاضي العقاري',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.civil], // العقارية فرع من المدنية
      appealsTo: [appealCivil],
    ),
    CourtKind(
      id: laborFirstInstance,
      label: 'محكمة البداية المدنية (الدعاوى العمالية)',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.civil], // العمالية تتبع البداية المدنية
      hasChambers: true,
      appealsTo: [appealCivil],
    ),
    CourtKind(
      id: dismissalCommittee,
      label: 'لجنة قضايا التسريح',
      degree: LitigationDegree.first,
      caseTypes: [CaseType.civil], // العمالية تتبع المدنية
      appealsTo: [appealCivil],
    ),
    CourtKind(
      id: executionDepartment,
      label: 'دائرة التنفيذ',
      degree: LitigationDegree.execution,
      caseTypes: [
        CaseType.civil,
        CaseType.commercial,
        CaseType.personalStatus,
      ],
      hasChambers: true,
      appealsTo: [appealCivil],
    ),

    // ------------------------- المخاصمة ------------------------
    CourtKind(
      id: appealAgainstJudges,
      label: 'محكمة الاستئناف (مخاصمة قضاة الدرجة الأولى)',
      degree: LitigationDegree.litigationAgainstJudges,
      caseTypes: [
        CaseType.civil,
        CaseType.commercial,
        CaseType.criminal,
        CaseType.personalStatus,
      ],
      appealsTo: [cassationAgainstJudges],
    ),
    CourtKind(
      id: cassationAgainstJudges,
      label: 'محكمة النقض (مخاصمة قضاة الاستئناف)',
      degree: LitigationDegree.litigationAgainstJudges,
      caseTypes: [
        CaseType.civil,
        CaseType.commercial,
        CaseType.criminal,
        CaseType.personalStatus,
      ],
      damascusOnly: true,
    ),

    // ------------------------- دستوري --------------------------
    CourtKind(
      id: constitutionalCourt,
      label: 'المحكمة الدستورية العليا',
      degree: LitigationDegree.cassation,
      caseTypes: [CaseType.administrative],
      damascusOnly: true,
    ),
  ];

  /// بحث بالمعرّف. يُرجع `null` للمعرّف المجهول بدل رمي استثناء،
  /// لأن السجلات القديمة قد تحمل قيماً لم تعد في الفهرس.
  static CourtKind? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final kind in all) {
      if (kind.id == id) return kind;
    }
    return null;
  }

  /// أنواع المحاكم التي تنظر نوع دعوى معيناً، مرتّبة بالدرجة.
  static List<CourtKind> forCaseType(CaseType caseType) {
    final matches = all.where((k) => k.caseTypes.contains(caseType)).toList();
    matches.sort((a, b) => a.degree.index.compareTo(b.degree.index));
    return matches;
  }

  /// أنواع المحاكم لنوع دعوى ودرجة محددين.
  static List<CourtKind> forCaseTypeAndDegree(
    CaseType caseType,
    LitigationDegree degree,
  ) =>
      forCaseType(caseType).where((k) => k.degree == degree).toList();

  /// الدرجات المتاحة فعلاً لنوع دعوى، بترتيب سلّم التقاضي.
  ///
  /// لا تُعرض درجة لا محكمة لها في هذا النوع: الدعوى الدستورية
  /// مثلاً ليس لها صلح ولا استئناف.
  static List<LitigationDegree> degreesFor(CaseType caseType) {
    final degrees = forCaseType(caseType).map((k) => k.degree).toSet().toList();
    degrees.sort((a, b) => a.index.compareTo(b.index));
    return degrees;
  }

  /// المحاكم التي يجوز الانتقال إليها من محكمة حالية.
  ///
  /// هذه هي الدالة التي تمنع ظهور «صلح» بعد «استئناف»: المسار
  /// مُعرَّف صعوداً في `appealsTo` ولا يُشتق من ترتيب قائمة عرض.
  static List<CourtKind> nextStagesFrom(String? currentKindId) {
    final current = byId(currentKindId);
    if (current == null) return const [];
    return current.appealsTo
        .map(byId)
        .whereType<CourtKind>()
        .toList(growable: false);
  }

  /// هل يجوز أن تنعقد هذه المحكمة في هذه المحافظة؟
  static bool allowsGovernorate(String? kindId, String? governorate) {
    final kind = byId(kindId);
    if (kind == null || governorate == null) return true;
    return kind.governorates.contains(governorate);
  }

  /// وصف جاهز للعرض من القيم المخزَّنة، مع تدبير القيم الناقصة.
  static String describeStored({
    String? kindId,
    String? governorate,
    int? chamberNumber,
  }) {
    final kind = byId(kindId);
    if (kind == null) {
      // سجل قديم بلا نوع محكمة: تُعرض المحافظة وحدها بدل فراغ.
      return governorate?.trim().isNotEmpty == true
          ? governorate!.trim()
          : 'غير محددة';
    }
    return kind.describe(
      governorate: governorate,
      chamberNumber: chamberNumber,
    );
  }

  /// استنتاج نوع المحكمة من نص حر يصف الدرجة.
  ///
  /// يُستعمل في موضعين: ترحيل السجلات القديمة، وقراءة الدرجة التي
  /// اختارها المستخدم في شاشة الأرشيف. المنطق واحد ومكانه واحد كي
  /// لا ينحرف المصدران.
  ///
  /// يُرجع `null` عند الالتباس: الفجوة الصريحة أسلم من درجة مخترعة
  /// يُبنى عليها مسار طعن خاطئ.
  static String? inferKindFromText({
    String? degreeText,
    String? caseTypeText,
  }) {
    String norm(String? s) => (s ?? '')
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .trim();

    final degree = norm(degreeText);
    final type = norm(caseTypeText);
    if (degree.isEmpty) return null;

    final isCriminal = type.contains('جزائ') ||
        type.contains('جنائ') ||
        type.contains('criminal') ||
        degree.contains('جزاء') ||
        degree.contains('جزائ') ||
        degree.contains('جنح') ||
        degree.contains('جناي');
    final isCommercial = type.contains('تجار') ||
        type.contains('commercial') ||
        degree.contains('تجار');
    final isSharia = type.contains('شرع') ||
        type.contains('احوال') ||
        type.contains('personalstatus') ||
        degree.contains('شرع');
    final isAdministrative =
        type.contains('اداري') || type.contains('administrative');

    // النقض أولاً: «نقض مدني» يحوي «مدني» أيضاً، فلو فُحص الصلح أو
    // البداية قبله لالتقطته المطابقة الأعم.
    if (degree.contains('نقض') || degree.contains('تمييز')) {
      if (isCriminal) return cassationCriminal;
      if (isSharia) return cassationPersonalStatus;
      return cassationCivil;
    }
    if (degree.contains('اداريه العليا')) return supremeAdministrativeCourt;
    if (degree.contains('قضاء اداري')) return administrativeJudiciaryCourt;
    if (isAdministrative && degree.contains('اداري')) {
      return administrativeCourt;
    }
    if (degree.contains('مخاصمه')) {
      return degree.contains('استئناف') || degree.contains('نقض')
          ? cassationAgainstJudges
          : appealAgainstJudges;
    }
    if (degree.contains('جناي')) return feloniesCourt;
    if (degree.contains('استئناف')) {
      if (isCriminal) return appealMisdemeanor;
      // لا يوجد استئناف شرعي: المحكمة الشرعية تحكم بالدرجة الأخيرة.
      if (isCommercial) return appealCommercial;
      return appealCivil;
    }
    if (degree.contains('احداث')) return juvenileCourt;
    if (degree.contains('تحقيق')) return investigatingJudge;
    if (degree.contains('احاله')) return referralJudge;
    if (degree.contains('نيابه')) return publicProsecution;
    if (degree.contains('تنفيذ')) return executionDepartment;
    if (degree.contains('عمالي')) return laborFirstInstance;
    if (degree.contains('صلح')) {
      return isCriminal ? conciliationCriminal : conciliationCivil;
    }
    if (degree.contains('بدايه') || degree.contains('بدائي')) {
      if (isCriminal) return firstInstanceCriminal;
      if (isCommercial) return firstInstanceCommercial;
      return firstInstanceCivil;
    }
    if (isSharia) return shariaCourt;
    return null;
  }

  /// تصنيف الأرشيف: أنواع الدعاوى وما يقابلها من محاكم بالاسم.
  ///
  /// شاشة إدخال الأرشيف كانت تحمل خارطة يدوية منفصلة انحرفت عن
  /// الواقع (أدرجت «محكمة عمالية» تحت الإدارية، و«نقض» مجرداً).
  /// اشتقاقها من الفهرس يمنع تباعد المصدرين.
  static Map<String, List<String>> archiveClassificationMap() {
    final map = <String, List<String>>{};
    // كل أنواع الدعاوى متاحة في إدخال الأرشيف
    for (final caseType in CaseType.values) {
      if (caseType == CaseType.other) continue; // "أخرى" بدون محاكم محددة
      final courts = forCaseType(caseType);
      map[caseType.displayName] = courts.isNotEmpty
          ? courts.map((k) => k.label).toList()
          : ['غير محدد'];
    }
    return map;
  }
}
