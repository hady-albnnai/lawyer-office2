// اختبار إقلاع أساسي للتطبيق
//
// يتحقق أن شجرة الواجهة تُبنى دون استثناءات، وأن التطبيق
// يعمل ضمن ProviderScope كما هو معرّف في main.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lawyer_office/app.dart';

void main() {
  testWidgets('التطبيق يُبنى دون أخطاء', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LawyerOfficeApp(),
      ),
    );

    // إطار واحد يكفي للتأكد من عدم وجود استثناء أثناء البناء
    await tester.pump();

    expect(find.byType(MaterialApp), findsWidgets);
  });
}
