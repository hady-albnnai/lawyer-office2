import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/constants/court_catalog.dart';
import 'package:lawyer_office/data/database/database.dart';

/// مسار الانتقال من الدرجة الأولى إلى الاستئناف على قاعدة حقيقية.
///
/// السيناريو هو ما شكا منه المستخدم حرفياً: دعوى مدنية أمام البداية
/// في حمص تُستأنف. قبل الإصلاح كانت المحكمة تُخزَّن كمحافظة مجرّدة
/// والدرجة نصاً حراً، فيظهر في الاستئناف «حمص» بلا معنى.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> courtIdOf(String kindId, String governorate) async {
    final row = await db.customSelect(
      'SELECT id FROM courts WHERE court_kind = ? AND name = ?',
      variables: [
        Variable.withString(kindId),
        Variable.withString(governorate),
      ],
    ).getSingle();
    return row.data['id'] as int;
  }

  test('البداية المدنية في حمص موجودة كسجل مستقل', () async {
    final id = await courtIdOf(CourtCatalog.firstInstanceCivil, 'حمص');
    expect(id, greaterThan(0));

    // ونفس المحافظة لها سجل استئناف منفصل: التمييز بينهما هو
    // ما كان مفقوداً.
    final appealId = await courtIdOf(CourtCatalog.appealCivil, 'حمص');
    expect(appealId, isNot(id));
  });

  test('الدعوى تحفظ نوع المحكمة والغرفة لا المحافظة وحدها', () async {
    final courtId = await courtIdOf(CourtCatalog.firstInstanceCivil, 'حمص');

    await db.customStatement(
      'INSERT INTO cases (internal_number, year, case_type, sub_type, '
      'status, court_id, court_kind, chamber_number) '
      "VALUES ('2026/001', 2026, 'مدنية', ?, 'registered', ?, ?, 3)",
      [
        CourtCatalog.byId(CourtCatalog.firstInstanceCivil)!.label,
        courtId,
        CourtCatalog.firstInstanceCivil,
      ],
    );

    final row = await db
        .customSelect('SELECT court_kind, chamber_number FROM cases')
        .getSingle();
    expect(row.data['court_kind'], CourtCatalog.firstInstanceCivil);
    expect(row.data['chamber_number'], 3);

    final described = CourtCatalog.describeStored(
      kindId: row.data['court_kind'] as String?,
      governorate: 'حمص',
      chamberNumber: row.data['chamber_number'] as int?,
    );
    expect(described, 'محكمة البداية المدنية في حمص — الغرفة 3');
  });

  test('وجهات الاستئناف من البداية المدنية معقولة ومحصورة', () {
    final next = CourtCatalog.nextStagesFrom(CourtCatalog.firstInstanceCivil);

    // وجهة واحدة صحيحة، لا قائمة تضم «جلسات» و«إثبات» و«حكم».
    expect(next.map((k) => k.id), [CourtCatalog.appealCivil]);
    for (final kind in next) {
      expect(kind.degree, LitigationDegree.second);
    }
  });

  test('لا تظهر مراحل إجرائية بين وجهات الانتقال', () {
    // «جلسات» و«إثبات» و«حكم» أطوار داخل المحاكمة لا محاكم؛
    // يجب ألا يوجد لها نظير في فهرس المحاكم أصلاً.
    final labels = CourtCatalog.all.map((k) => k.label).join(' ');
    for (final procedural in ['جلسات', 'إثبات']) {
      expect(labels.contains(procedural), isFalse,
          reason: '«$procedural» طور إجرائي أُدرج بين المحاكم');
    }
  });

  test('كل محافظة لها سجل بداية واستئناف منفصلان', () async {
    final rows = await db.customSelect(
      'SELECT COUNT(DISTINCT name) AS c FROM courts WHERE court_kind = ?',
      variables: [Variable.withString(CourtCatalog.appealCivil)],
    ).getSingle();
    expect(rows.data['c'], 14);
  });
}
