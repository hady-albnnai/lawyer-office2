import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/presentation/widgets/common/searchable_picker.dart';

/// البحث في الحقول المرجعية يجب ألا يفشل بسبب اختلاف كتابة الهمزة
/// أو التاء المربوطة، وإلا لن يجد المستخدم "أحمد" حين يكتب "احمد".
void main() {
  group('تطبيع النص العربي للبحث', () {
    test('توحيد الهمزات', () {
      expect(normalizeArabic('أحمد'), normalizeArabic('احمد'));
      expect(normalizeArabic('إبراهيم'), normalizeArabic('ابراهيم'));
      expect(normalizeArabic('آمنة'), normalizeArabic('امنة'));
    });

    test('توحيد التاء المربوطة والهاء', () {
      expect(normalizeArabic('حماة'), normalizeArabic('حماه'));
      expect(normalizeArabic('فاطمة'), normalizeArabic('فاطمه'));
    });

    test('توحيد الألف المقصورة والياء', () {
      expect(normalizeArabic('يحيى'), normalizeArabic('يحيي'));
      expect(normalizeArabic('مصطفى'), normalizeArabic('مصطفي'));
    });

    test('إزالة التشكيل', () {
      expect(normalizeArabic('مُحَمَّد'), normalizeArabic('محمد'));
    });

    test('توحيد المسافات المتكررة', () {
      expect(normalizeArabic('أحمد   محمد'), 'احمد محمد');
      expect(normalizeArabic('  سامر  '), 'سامر');
    });

    test('البحث الجزئي يطابق رغم اختلاف الكتابة', () {
      final haystack = normalizeArabic('شركة الأمل للتجارة');
      expect(haystack.contains(normalizeArabic('الامل')), isTrue);
      expect(haystack.contains(normalizeArabic('الأمل')), isTrue);
    });

    test('أسماء مختلفة تبقى مختلفة', () {
      expect(normalizeArabic('أحمد'), isNot(normalizeArabic('محمد')));
      expect(normalizeArabic('حمص'), isNot(normalizeArabic('حماة')));
    });
  });
}
