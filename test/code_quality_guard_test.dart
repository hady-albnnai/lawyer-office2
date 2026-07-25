import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// المرحلة السابعة عشرة: تنظيف الجودة التقنية.
/// اختبارات تفحص الشيفرة نفسها لمنع عودة الأنماط الخطرة.
void main() {
  Iterable<File> dartFiles() sync* {
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.dart') && !e.path.endsWith('.g.dart')) {
        yield e;
      }
    }
  }

  test('No commented-out dispose() calls remain', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      for (final line in f.readAsLinesSync()) {
        final t = line.trim();
        if (t.startsWith('//') && t.contains('.dispose()')) {
          offenders.add('${f.path}: $t');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'dispose معطّلة تسبب تسريب ذاكرة:\n${offenders.join('\n')}');
  });

  test('Every State.dispose calls super.dispose', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      final src = f.readAsStringSync();
      final matches = RegExp(r'void dispose\(\)\s*\{').allMatches(src);
      for (final m in matches) {
        // اقرأ جسم الدالة حتى أول إغلاق على نفس المستوى تقريباً
        final body = src.substring(m.end, (m.end + 900).clamp(0, src.length));
        final end = body.indexOf('\n  }');
        final scoped = end == -1 ? body : body.substring(0, end);
        if (!scoped.contains('super.dispose()')) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'dispose بلا super.dispose():\n${offenders.toSet().join('\n')}');
  });

  test('No print/debugPrint left in production code', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      for (final line in f.readAsLinesSync()) {
        final t = line.trim();
        if (t.startsWith('//')) continue;
        if (RegExp(r'(?<!\w)(print|debugPrint)\(').hasMatch(t)) {
          offenders.add('${f.path}: $t');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
