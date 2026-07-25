# 🧪 سجل اختبار Windows - المرحلة 5

> التاريخ: 2026-07-10  
> النطاق: `cases_screen.dart`، `create_case_wizard.dart`، `case_detail_screen.dart`  
> الحالة: ⚠️ لم يتم تشغيل اختبار Windows الحقيقي داخل بيئة Arena الحالية

---

## 1. نتيجة فحص توفر الأدوات

```text
flutter --version => command not found
dart --version    => command not found
```

لا تحتوي بيئة التنفيذ الحالية على Flutter أو Dart، وهي ليست بيئة Windows رسومية. لذلك لا يمكن تأكيد تشغيل التطبيق على Windows من داخل هذه الجلسة.

---

## 2. الفحوصات المنفذة بدل الاختبار التشغيلي

تم تنفيذ فحص ثابت وحفظ نتيجته في `STAGE_5_STATIC_VALIDATION_LOG.md`:

- ✅ فحص مسارات الاستيراد النسبية.
- ✅ التأكد من وجود `case_detail_screen.dart`.
- ✅ التأكد من استخدام `AppTheme.lightTheme` داخل شاشة التفاصيل.
- ✅ التأكد من استخدام `AppColors` و`AppTextStyles`.
- ✅ التأكد من استخدام Riverpod.
- ✅ التأكد من وجود 9 تبويبات.
- ✅ التأكد من عدم وجود `Colors.*` أو `Color(0x...)` أو `TextStyle(...)` داخل `case_detail_screen.dart`.
- ✅ التأكد من وجود route `/cases/:caseId` و`/cases/create`.
- ✅ التأكد من حذف الشاشة القديمة غير المستخدمة `cases_list_screen.dart`.

---

## 3. اختبارات Windows المطلوبة عند توفر Flutter على Windows

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

ثم التحقق يدوياً من:

- فتح قائمة الدعاوى.
- الانتقال من كرت الدعوى إلى `/cases/:caseId`.
- عرض التبويبات التسعة.
- إضافة جلسة جديدة.
- رفع/ربط/فتح/حذف مستند.
- إضافة/إغلاق نقص.
- فلترة الخط الزمني.
- تنفيذ شاشة الإنهاء مع التأكيد.
- دعم RTL واتجاه النصوص.
- الثيم الموحد والألوان الرسمية.

---

## 4. الحالة الدستورية

لا يتم إعلان اكتمال المرحلة 5 نهائياً قبل تنفيذ اختبار Windows الحقيقي ونجاحه ثم رفع التغييرات إلى GitHub.
