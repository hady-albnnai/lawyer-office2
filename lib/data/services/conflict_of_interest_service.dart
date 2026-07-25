import 'package:drift/drift.dart';

import '../../core/enums/app_enums.dart';
import '../database/database.dart';

/// درجة خطورة تنبيه تعارض المصالح.
enum ConflictSeverity {
  /// يستوجب انتباه المحامي قبل المتابعة.
  high,

  /// معلومة مهمة لا تمنع المتابعة.
  medium,
}

/// تنبيه واحد عن تعارض مصالح محتمل.
class ConflictWarning {
  final ConflictSeverity severity;
  final String title;
  final String detail;

  /// الملفات المرتبطة بالتعارض (أرقام داخلية) لتسهيل المراجعة.
  final List<String> relatedFiles;

  const ConflictWarning({
    required this.severity,
    required this.title,
    required this.detail,
    this.relatedFiles = const [],
  });
}

/// فحص تعارض المصالح قبل ربط شخص بملف جديد.
///
/// المرحلة العاشرة من خارطة التنفيذ تنص صراحة على أن هذا **تنبيه لا منع**:
/// القرار النهائي للمحامي، والنظام يكتفي بكشف الحالة.
class ConflictOfInterestService {
  final AppDatabase _db;

  ConflictOfInterestService(this._db);

  /// فحص شخص يُراد إسناده بصفة [asClient] في ملف جديد.
  Future<List<ConflictWarning>> checkPerson({
    required int personId,
    required bool asClient,
    int? excludeCaseId,
  }) async {
    if (personId <= 0) return const [];

    final warnings = <ConflictWarning>[];
    warnings.addAll(await _checkOpposingRoles(personId, asClient, excludeCaseId));
    warnings.addAll(await _checkRevokedAgencyOnActiveFile(personId));
    warnings.addAll(await _checkContradictoryRolesAcrossFiles(personId));
    return warnings;
  }

  /// 1) شخص كان خصماً في ملف سابق ويُراد جعله موكلاً (أو العكس).
  Future<List<ConflictWarning>> _checkOpposingRoles(
    int personId,
    bool asClient,
    int? excludeCaseId,
  ) async {
    // الصفة المعاكسة للصفة المطلوبة الآن.
    final opposingIsClient = !asClient;

    final rows = await _db.customSelect(
      '''
      SELECT c.internal_number, c.subject, cp.party_role
      FROM case_parties cp
      JOIN cases c ON c.id = cp.case_id
      WHERE cp.person_id = ?
        AND cp.is_client = ?
        ${excludeCaseId == null ? '' : 'AND cp.case_id <> ?'}
      ''',
      variables: [
        Variable.withInt(personId),
        Variable.withBool(opposingIsClient),
        if (excludeCaseId != null) Variable.withInt(excludeCaseId),
      ],
    ).get();

    if (rows.isEmpty) return const [];

    final files = rows
        .map((r) => (r.data['internal_number'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    return [
      ConflictWarning(
        severity: ConflictSeverity.high,
        title: asClient
            ? 'هذا الشخص كان خصماً في ملفات سابقة'
            : 'هذا الشخص موكل للمكتب في ملفات أخرى',
        detail: asClient
            ? 'تسنده الآن كموكل، وقد سبق أن كان خصماً في ${rows.length} ملف. راجع الوضع قبل المتابعة.'
            : 'تسنده الآن كخصم، وهو موكل للمكتب في ${rows.length} ملف. هذا تعارض مصالح مباشر.',
        relatedFiles: files,
      ),
    ];
  }

  /// 2) وكالة معزول عنها أو منتهية بينما الملف المرتبط ما زال جارياً.
  Future<List<ConflictWarning>> _checkRevokedAgencyOnActiveFile(int personId) async {
    final blocked = PoaStatus.values
        .where((s) => !s.isUsable)
        .map((s) => "'${s.dbValue}'")
        .join(', ');

    final rows = await _db.customSelect(
      '''
      SELECT p.poa_number, p.status, c.internal_number
      FROM poa_parties pp
      JOIN powers_of_attorney p ON p.id = pp.poa_id
      LEFT JOIN case_poa_links cpl ON cpl.poa_id = p.id
      LEFT JOIN cases c ON c.id = cpl.case_id AND c.status <> 'closed'
      WHERE pp.person_id = ?
        AND p.status IN ($blocked)
      ''',
      variables: [Variable.withInt(personId)],
    ).get();

    final linkedToActive = rows.where((r) => r.data['internal_number'] != null).toList();
    if (linkedToActive.isEmpty) return const [];

    return [
      ConflictWarning(
        severity: ConflictSeverity.high,
        title: 'وكالة غير صالحة مرتبطة بملف جارٍ',
        detail:
            'يوجد ${linkedToActive.length} وكالة معزول عنها أو منتهية ما زالت مرتبطة بملفات جارية لهذا الشخص.',
        relatedFiles: linkedToActive
            .map((r) => (r.data['internal_number'] as String?) ?? '')
            .where((e) => e.isNotEmpty)
            .toList(),
      ),
    ];
  }

  /// 3) صفة متضاربة لنفس الشخص/الجهة في أكثر من ملف (موكل وخصم معاً).
  Future<List<ConflictWarning>> _checkContradictoryRolesAcrossFiles(int personId) async {
    final rows = await _db.customSelect(
      '''
      SELECT
        SUM(CASE WHEN cp.is_client = 1 THEN 1 ELSE 0 END) AS as_client,
        SUM(CASE WHEN cp.is_client = 0 THEN 1 ELSE 0 END) AS as_opponent
      FROM case_parties cp
      WHERE cp.person_id = ?
      ''',
      variables: [Variable.withInt(personId)],
    ).get();

    if (rows.isEmpty) return const [];
    final asClient = (rows.first.data['as_client'] as int?) ?? 0;
    final asOpponent = (rows.first.data['as_opponent'] as int?) ?? 0;

    if (asClient > 0 && asOpponent > 0) {
      return [
        ConflictWarning(
          severity: ConflictSeverity.medium,
          title: 'صفة متضاربة في ملفات المكتب',
          detail:
              'هذا الشخص مسجّل موكلاً في $asClient ملف وخصماً في $asOpponent ملف. تأكد أن هذا مقصود.',
        ),
      ];
    }
    return const [];
  }
}
