import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// حارس ضد عودة البيانات المُصطنعة إلى شاشات الإنتاج.
///
/// تكرر في المشروع نمط خطير: عرض أسماء أطراف أو مستندات أو أحجام ملفات
/// مخترعة داخل شاشات تعرض بيانات حقيقية، فيظنها المستخدم صحيحة.
/// هذه الاختبارات تفحص الشيفرة نفسها لا سلوك التطبيق.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// يزيل أسطر التعليقات حتى لا تُحسب الملاحظات التوضيحية مخالفات.
  String withoutComments(String source) {
    return source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
  }

  test('Case wizard picks opponents and POAs from the database', () {
    final source = withoutComments(read('lib/presentation/screens/cases/create_case_wizard.dart'));

    // لا قوائم أشخاص ثابتة بمعرّفات مخترعة
    expect(source.contains("{'id': 1, 'name': 'محمد أحمد'"), isFalse,
        reason: 'قائمة خصوم ثابتة تربط الدعوى بمعرّف قد يقابل شخصاً آخر');
    expect(source.contains("'number': 'POA-2026-001'"), isFalse,
        reason: 'قائمة وكالات ثابتة تربط الدعوى بسند توكيل غير موجود');

    // والمصدر الحقيقي مستخدم فعلاً
    expect(source.contains('allPersonsProvider'), isTrue);
    expect(source.contains('allPoasProvider'), isTrue);
  });

  test('Case screens do not fabricate document metadata', () {
    for (final path in const [
      'lib/presentation/screens/cases/cases_screen.dart',
      'lib/presentation/screens/cases/case_detail_screen.dart',
      'lib/presentation/screens/files/files_screen.dart',
    ]) {
      final source = withoutComments(read(path));
      expect(source.contains('fileSize: 512 * 1024'), isFalse,
          reason: '$path يخترع حجم ملف لمستند غير مقروء من الأرشيف');
      expect(source.contains("filePath: 'docs/cases/"), isFalse,
          reason: '$path يخترع مسار ملف غير موجود على القرص');
    }
  });

  test('Case party names are resolved from the persons directory', () {
    final source = read('lib/presentation/screens/cases/case_detail_screen.dart');

    // كان اسم الطرف يُعرض كرقم: name: p.personId.toString()
    expect(source.contains('name: p.personId.toString()'), isFalse,
        reason: 'اسم الطرف يجب أن يأتي من دليل الأشخاص لا أن يكون معرّفاً رقمياً');
    expect(source.contains('personById[p.personId]?.fullName'), isTrue);
  });

  test('Date columns are never queried with DATE() in SQL', () {
    final dir = Directory('lib');
    final offenders = <String>[];

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final line in withoutComments(entity.readAsStringSync()).split('\n')) {
        // DATE(...) داخل استعلام SQL على عمود مخزَّن كعدد Unix epoch يعيد NULL
        if (RegExp(r'\bDATE\s*\(').hasMatch(line) && !line.contains('unixepoch')) {
          offenders.add('${entity.path}: ${line.trim()}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'التواريخ مخزّنة كأعداد epoch؛ استخدم مقارنة مجال مع Variable.withDateTime:\n${offenders.join('\n')}');
  });
}
