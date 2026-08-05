import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/constants/app_constants.dart';
import 'package:lawyer_office/core/constants/court_catalog.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/presentation/screens/cases/case_models.dart'
    show CaseType;

/// حراسة خارطة القضاء: الدرجات ومسارات الطعن وأماكن الانعقاد.
///
/// نشأت هذه الاختبارات من عطل رآه المستخدم: قائمة «نقل الدعوى إلى
/// مرحلة» كانت تعرض «جلسات» و«إثبات» و«حكم» كأنها محاكم، وتعرض
/// «صلح» بعد «استئناف»، وتُختار المحكمة بالمحافظة وحدها.
void main() {
  group('بنية الفهرس', () {
    test('لا تتكرر معرّفات أنواع المحاكم', () {
      final ids = CourtCatalog.all.map((k) => k.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'يوجد معرّف نوع محكمة مكرر');
    });

    test('كل مرجع في مسار الطعن يشير إلى نوع معرَّف', () {
      for (final kind in CourtCatalog.all) {
        for (final target in kind.appealsTo) {
          expect(CourtCatalog.byId(target), isNotNull,
              reason: '«${kind.label}» يطعن إلى معرّف مجهول: $target');
        }
      }
    });

    test('لكل نوع محكمة نوع دعوى واحد على الأقل', () {
      for (final kind in CourtCatalog.all) {
        expect(kind.caseTypes, isNotEmpty, reason: '${kind.label} بلا نوع دعوى');
      }
    });
  });

  group('مسار الطعن يصعد ولا ينحدر', () {
    test('الطعن لا يعود إلى درجة أدنى', () {
      for (final kind in CourtCatalog.all) {
        // التنفيذ والمخاصمة مساران مستقلان لا يخضعان لسلّم الدرجات.
        if (kind.degree == LitigationDegree.execution ||
            kind.degree == LitigationDegree.litigationAgainstJudges) {
          continue;
        }
        for (final next in CourtCatalog.nextStagesFrom(kind.id)) {
          expect(
            next.degree.index >= kind.degree.index,
            isTrue,
            reason: 'انحدار: «${kind.label}» → «${next.label}»',
          );
        }
      }
    });

    test('الصلح لا يظهر بين وجهات الاستئناف', () {
      final fromAppeal = CourtCatalog.nextStagesFrom(CourtCatalog.appealCivil)
          .map((k) => k.id);
      expect(fromAppeal, isNot(contains(CourtCatalog.conciliationCivil)));
      expect(fromAppeal, isNot(contains(CourtCatalog.firstInstanceCivil)));
    });

    test('البداية المدنية تُستأنف أمام الاستئناف المدنية', () {
      final next =
          CourtCatalog.nextStagesFrom(CourtCatalog.firstInstanceCivil);
      expect(next.map((k) => k.id), contains(CourtCatalog.appealCivil));
    });

    test('الاستئناف المدنية يُطعن بها نقضاً', () {
      final next = CourtCatalog.nextStagesFrom(CourtCatalog.appealCivil);
      expect(next.map((k) => k.id), contains(CourtCatalog.cassationCivil));
    });

    test('محكمة النقض قمة الهرم فلا مرحلة بعدها', () {
      expect(CourtCatalog.nextStagesFrom(CourtCatalog.cassationCivil), isEmpty);
      expect(
          CourtCatalog.nextStagesFrom(CourtCatalog.cassationCriminal), isEmpty);
      expect(CourtCatalog.nextStagesFrom(CourtCatalog.supremeAdministrativeCourt),
          isEmpty);
    });

    test('المسار الجزائي يمرّ بالتحقيق ثم الإحالة ثم الجنايات', () {
      expect(
        CourtCatalog.nextStagesFrom(CourtCatalog.investigatingJudge)
            .map((k) => k.id),
        contains(CourtCatalog.referralJudge),
      );
      expect(
        CourtCatalog.nextStagesFrom(CourtCatalog.referralJudge)
            .map((k) => k.id),
        contains(CourtCatalog.feloniesCourt),
      );
      expect(
        CourtCatalog.nextStagesFrom(CourtCatalog.feloniesCourt)
            .map((k) => k.id),
        contains(CourtCatalog.cassationCriminal),
      );
    });
  });

  group('مكان الانعقاد', () {
    test('محاكم النقض في دمشق وحدها', () {
      for (final id in [
        CourtCatalog.cassationCivil,
        CourtCatalog.cassationCriminal,
        CourtCatalog.cassationPersonalStatus,
      ]) {
        expect(CourtCatalog.byId(id)!.governorates, ['دمشق']);
      }
    });

    test('المحكمة الإدارية العليا ومحكمة القضاء الإداري في دمشق', () {
      expect(CourtCatalog.byId(CourtCatalog.supremeAdministrativeCourt)!
          .governorates, ['دمشق']);
      expect(CourtCatalog.byId(CourtCatalog.administrativeJudiciaryCourt)!
          .governorates, ['دمشق']);
    });

    test('محاكم الدرجة الأولى تنعقد في كل المحافظات', () {
      expect(
        CourtCatalog.byId(CourtCatalog.firstInstanceCivil)!.governorates.length,
        AppConstants.syrianGovernorates.length,
      );
    });

    test('لا تُقبل محكمة نقض في حماة', () {
      expect(
        CourtCatalog.allowsGovernorate(CourtCatalog.cassationCivil, 'حماة'),
        isFalse,
      );
      expect(
        CourtCatalog.allowsGovernorate(CourtCatalog.cassationCivil, 'دمشق'),
        isTrue,
      );
    });
  });

  group('حصر المحاكم بنوع الدعوى', () {
    test('الدعوى المدنية لا تُنظر أمام محكمة الجنايات', () {
      final ids = CourtCatalog.forCaseType(CaseType.civil).map((k) => k.id);
      expect(ids, isNot(contains(CourtCatalog.feloniesCourt)));
      expect(ids, contains(CourtCatalog.firstInstanceCivil));
    });

    test('الدعوى الجزائية لا تُنظر أمام محكمة النقض المدنية', () {
      final ids = CourtCatalog.forCaseType(CaseType.criminal).map((k) => k.id);
      expect(ids, isNot(contains(CourtCatalog.cassationCivil)));
      expect(ids, contains(CourtCatalog.cassationCriminal));
    });

    test('«محكمة عمالية» ليست من محاكم القضاء الإداري', () {
      // كانت خارطة الأرشيف تُدرج «محكمة عمالية» تحت الدعاوى الإدارية.
      final admin =
          CourtCatalog.forCaseType(CaseType.administrative).map((k) => k.id);
      expect(admin, isNot(contains(CourtCatalog.laborFirstInstance)));
      expect(admin, contains(CourtCatalog.administrativeCourt));
    });

    test('لا استئناف شرعي: المحكمة الشرعية تطعن بالنقض مباشرة', () {
      // المادة 498/د من قانون أصول المحاكمات المدنية 1/2016:
      // «تخضع الأحكام التي تصدرها المحكمة الشرعية لطرق الطعن
      // المتعلقة بالأحكام الصادرة بالدرجة الأخيرة»
      final next = CourtCatalog.nextStagesFrom(CourtCatalog.shariaCourt);
      expect(next.map((k) => k.id),
          contains(CourtCatalog.cassationPersonalStatus));
      // لا توجد درجة ثانية بين الشرعية والنقض.
      final secondDegree = next.where(
          (k) => k.degree == LitigationDegree.second);
      expect(secondDegree, isEmpty,
          reason: 'لا يوجد استئناف شرعي في سوريا');
    });

    test('خارطة الأرشيف لا تُدرج العقارية والعمالية كتبوببات رئيسية', () {
      // العقارية فرع من المدنية، والعمالية تتبع للقضاء الإداري/البداية.
      final map = CourtCatalog.archiveClassificationMap();
      expect(map.containsKey('عقارية'), isFalse);
      expect(map.containsKey('عمالية'), isFalse);
      expect(map.containsKey('مدنية'), isTrue);
      expect(map.containsKey('أحوال شخصية'), isTrue);
    });

    test('لا نقض إداري: أعلى درجة هي المحكمة الإدارية العليا', () {
      final admin = CourtCatalog.forCaseType(CaseType.administrative);
      final top = admin.where((k) => k.degree == LitigationDegree.cassation);
      expect(top.map((k) => k.id),
          contains(CourtCatalog.supremeAdministrativeCourt));
      expect(top.map((k) => k.id), isNot(contains(CourtCatalog.cassationCivil)));
    });

    test('درجات الدعوى المدنية مرتّبة تصاعدياً', () {
      final degrees = CourtCatalog.degreesFor(CaseType.civil);
      final indices = degrees.map((d) => d.index).toList();
      final sorted = [...indices]..sort();
      expect(indices, equals(sorted));
    });
  });

  group('استنتاج نوع المحكمة من نص قديم', () {
    test('«استئناف مدني» يُقرأ محكمة استئناف مدنية لا صلحاً', () {
      expect(
        CourtCatalog.inferKindFromText(
            degreeText: 'استئناف مدني', caseTypeText: 'مدنية'),
        CourtCatalog.appealCivil,
      );
    });

    test('«نقض جزائي» يُقرأ الدائرة الجزائية لا المدنية', () {
      expect(
        CourtCatalog.inferKindFromText(
            degreeText: 'نقض جزائي', caseTypeText: 'جزائية'),
        CourtCatalog.cassationCriminal,
      );
    });

    test('النقض يُفحص قبل البداية فلا تبتلعه مطابقة أعم', () {
      // «نقض» مع دعوى تجارية: الجواب دائرة النقض المدنية والتجارية
      // لا محكمة البداية التجارية.
      expect(
        CourtCatalog.inferKindFromText(
            degreeText: 'نقض تجاري', caseTypeText: 'تجارية'),
        CourtCatalog.cassationCivil,
      );
    });

    test('«صلح جزاء» يُقرأ صلحاً جزائياً لا مدنياً', () {
      expect(
        CourtCatalog.inferKindFromText(
            degreeText: 'صلح جزاء', caseTypeText: 'جزائية'),
        CourtCatalog.conciliationCriminal,
      );
    });

    test('النص المبهم يُرجع null بدل درجة مخترعة', () {
      expect(CourtCatalog.inferKindFromText(degreeText: '', caseTypeText: ''),
          isNull);
      expect(
        CourtCatalog.inferKindFromText(
            degreeText: 'شيء غير معروف', caseTypeText: ''),
        isNull,
      );
    });
  });

  group('الوصف المعروض', () {
    test('يجمع النوع والمحافظة والغرفة', () {
      final text = CourtCatalog.describeStored(
        kindId: CourtCatalog.appealCivil,
        governorate: 'حمص',
        chamberNumber: 2,
      );
      expect(text, contains('الاستئناف'));
      expect(text, contains('حمص'));
      expect(text, contains('2'));
    });

    test('لا تُعرض غرفة لمحكمة بلا غرف', () {
      final text = CourtCatalog.describeStored(
        kindId: CourtCatalog.supremeAdministrativeCourt,
        governorate: 'دمشق',
        chamberNumber: 5,
      );
      expect(text, isNot(contains('الغرفة')));
    });

    test('السجل القديم بلا نوع يعرض المحافظة لا فراغاً', () {
      expect(
        CourtCatalog.describeStored(kindId: null, governorate: 'درعا'),
        'درعا',
      );
    });
  });

  group('قاعدة البيانات', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('الحقن الافتراضي يُنشئ سجلاً لكل (نوع × محافظة)', () async {
      final expected = CourtCatalog.all
          .fold<int>(0, (sum, k) => sum + k.governorates.length);
      final rows = await db
          .customSelect('SELECT COUNT(*) AS c FROM courts WHERE court_kind IS NOT NULL')
          .getSingle();
      expect(rows.data['c'], expected);
    });

    test('لا توجد محكمة نقض خارج دمشق في البيانات المحقونة', () async {
      final rows = await db.customSelect(
        "SELECT name FROM courts WHERE court_kind = ?",
        variables: [Variable.withString(CourtCatalog.cassationCivil)],
      ).get();
      expect(rows.length, 1);
      expect(rows.first.data['name'], 'دمشق');
    });

    test('استكمال الصفوف قابل لإعادة التنفيذ دون تكرار', () async {
      Future<int> count() async {
        final r = await db
            .customSelect('SELECT COUNT(*) AS c FROM courts')
            .getSingle();
        return r.data['c'] as int;
      }

      final before = await count();
      await db.ensureCourtKindRows();
      await db.ensureCourtKindRows();
      expect(await count(), before);
    });

    test('الترحيل يستنتج نوع المحكمة للدعاوى القديمة', () async {
      await db.customStatement(
        "INSERT INTO cases (internal_number, year, case_type, sub_type, status) "
        "VALUES ('2020/001', 2020, 'مدني', 'استئناف مدني', 'registered')",
      );
      await db.customStatement(
        "INSERT INTO cases (internal_number, year, case_type, sub_type, status) "
        "VALUES ('2020/002', 2020, 'جزائي', 'نقض جزائي', 'registered')",
      );

      await db.backfillCourtKinds();

      final rows = await db
          .customSelect('SELECT internal_number, court_kind FROM cases')
          .get();
      final byNumber = {
        for (final r in rows)
          r.data['internal_number'] as String: r.data['court_kind'] as String?
      };

      expect(byNumber['2020/001'], CourtCatalog.appealCivil);
      expect(byNumber['2020/002'], CourtCatalog.cassationCriminal);
    });
  });
}
