import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/constants/app_constants.dart';
import 'package:lawyer_office/data/database/database.dart';

/// المحكمة تُعرَّف بالمحافظة ورقم الغرفة، لا باسم مركّب يدمج الدرجة.
///
/// كانت التسميات مثل "محكمة البداية المدنية الأولى بدمشق" تخلط ثلاثة
/// مفاهيم: المكان، والدرجة (شأن JudicialPhases)، وترتيب الغرفة.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> courtNames() async {
    final rows = await db.customSelect('SELECT name FROM courts').get();
    return rows.map((r) => r.data['name'] as String).toList();
  }

  test('عمود الاسم يحمل المحافظة وحدها لكل المحاكم المحقونة', () async {
    final names = await courtNames();

    // صار لكل (نوع محكمة × محافظة) سجل، فالعدد أكبر من عدد
    // المحافظات، لكن عمود الاسم يبقى محافظةً خالصة والنوع في
    // court_kind. هذا هو جوهر الفصل الذي أُدخل في الإصدار 6.
    for (final gov in AppConstants.syrianGovernorates) {
      expect(names, contains(gov));
    }
    for (final name in names) {
      expect(
        AppConstants.syrianGovernorates.contains(name),
        isTrue,
        reason: 'اسم المحكمة "$name" ليس اسم محافظة',
      );
    }
  });

  test('لا يرد ذكر الدرجات في أسماء المحاكم', () async {
    final names = await courtNames();
    const degrees = ['نقض', 'استئناف', 'بداية', 'صلح'];

    for (final name in names) {
      for (final degree in degrees) {
        expect(
          name.contains(degree),
          isFalse,
          reason: 'اسم المحكمة "$name" يحوي درجة التقاضي "$degree"',
        );
      }
    }
  });

  test('حماة مكتوبة بالتاء المربوطة لا "حما"', () async {
    final names = await courtNames();

    expect(names, contains('حماة'));
    expect(names.any((n) => n == 'حما'), isFalse);
  });

  test('عمود رقم الغرفة موجود ويقبل ما يتجاوز 16', () async {
    final info = await db.customSelect('PRAGMA table_info(courts)').get();
    final columns = info.map((r) => r.data['name'] as String).toSet();
    expect(columns, contains('chamber_number'));

    await db.customStatement(
      "INSERT INTO courts (name, city, chamber_number, is_active) "
      "VALUES ('دمشق', 'دمشق', 17, 1)",
    );

    final row = await db
        .customSelect('SELECT chamber_number FROM courts WHERE chamber_number = 17')
        .getSingle();
    expect(row.data['chamber_number'], 17);
  });

  test('تطبيع الأسماء القديمة يستخرج المحافظة', () async {
    // محاكاة سجلات أُنشئت قبل إعادة الهيكلة.
    await db.customStatement(
      "INSERT INTO courts (name, type, city, is_active) VALUES "
      "('محكمة البداية المدنية الأولى بدمشق', 'بداية', 'دمشق', 1)",
    );
    await db.customStatement(
      "INSERT INTO courts (name, type, city, is_active) VALUES "
      "('محكمة حما', 'بداية', NULL, 1)",
    );
    await db.customStatement(
      "INSERT INTO courts (name, type, city, is_active) VALUES "
      "('المحكمة الشرعية بالسويداء', 'شرعية', 'السويداء', 1)",
    );

    await db.normalizeCourtNames();

    final names = await courtNames();
    expect(names, contains('دمشق'));
    expect(names, contains('حماة'));
    expect(names, contains('السويداء'));
    expect(
      names.any((n) => n.contains('البداية') || n.contains('الشرعية')),
      isFalse,
      reason: 'بقيت تسمية مركّبة بعد التطبيع',
    );
  });

  test('التطبيع قابل لإعادة التنفيذ دون تغيير النتيجة', () async {
    await db.normalizeCourtNames();
    final first = await courtNames()
      ..sort();
    await db.normalizeCourtNames();
    final second = await courtNames()
      ..sort();

    expect(second, equals(first));
  });
}
