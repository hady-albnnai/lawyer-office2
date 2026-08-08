# 📋 ملف التسليم الشامل - المحادثة القادمة (COMPREHENSIVE HANDOVER)

> **تاريخ التسليم:** 2026-08-08
> **المستودع:** https://github.com/hady-albnnai/lawyer-office2
> **المسلم:** Arena Agent (الوضع الحالي)
> **المستلم:** المساعد القادم
> **الحالة النفسية للمسلم:** المستخدم مُنهك من محاولات الإصلاح المتكررة ويطلب **عدم إصلاح أي شيء جديد حالياً** — فقط توثيق كل شيء بشكل دقيق.

---

## ⚠️ تنبيه إلزامي من الدستور (CONSTITUTION.md)

> **"العمل غير الموثق وغير المرفوع هو عمل غير موجود."
**قبل أي رفع (`push`):**
1. `flutter analyze`
2. `dart run tool/audit/audit_members.dart`
3. `flutter test`
4. `flutter run -d windows`
**إن تعذّر أي فحص → يُصرَّح بذلك نصاً في رسالة الالتزام (`commit message`).**

---

## ✅ ما تم إنجازه سابقاً (من HANDOVER_DOCUMENT.md الأصلي + التعديلات)

### التعديلات المنجزة (11/15 من الملف الأصلي + 4 جديدة):
1. ✅ تبسيط الويزارد (6 → 2 خطوة)
2. ✅ إعادة ترتيب التبويبات إلى 4
3. ✅ جدول `ContractInstallments`
4. ✅ متابعة الأقساط
5. ✅ إصلاح `Dialog` المرفقات (`StatefulBuilder`)
6. ✅ إصلاح دافع الأتعاب (`Set`)
7. ✅ فتح `Word` (`Process.start`)
8. ✅ مطابقة الأسماء لحظياً (`Set<int> selectedIds`)
9. ✅ `Migration v10` (`ALTER TABLE`)
10. ✅ رفع صورة الشيك/التحويل (`file_picker`)
11. ✅ التذكيرات التلقائية للأقساط (`Checkbox` + `DropdownButtonFormField`)

### الإصلاحات الإضافية التي طُبقت لاحقاً:
- ✅ زر إضافة شخص جديد (`_showAddPersonDialog` مرتبط بـ `IconButton`)
- ✅ تصنيفات دائمة (`_showAddCategoryDialog` مع `DB insert` + `FutureBuilder` للاستعلام)
- ✅ إصلاح تجميد التقسيط (`TextEditingController` بدلاً من `initialValue`)
- ✅ حفظ مستند الدفع (`saveAttachment` + `DocumentLinks` برابط `payment_proof`)

---

## ❌ الطلبات الفاشلة المتبقية + المشكلات الجديدة المكتشفة

### 12. ❌ إضافة شخص جديد (موثق كمنجز لكنه يحتاج مراجعة)
- الزر موجود الآن (`IconButton`) ويعمل، لكنه **يجب التحقق** من عدم وجود خطأ برتقالي بعد الضغط على "إضافة".
- **المشكلة الجديدة المكتشفة:** بعد الضغط على "إضافة" في `_showAddPersonDialog` وقبل ظهور شاشة الويزارد، **تظهر شاشة برتقالية (خطأ)**. المستخدم لم يتمكن من التقاط الخطأ.
- **الحل المطلوب:** فحص `catch` في `_showAddPersonDialog`. إذا كان الخطأ من `ref.invalidate()` أو `setState()` بعد إغلاق الـ `dialog`، يجب إضافة `await Future.delayed(Duration(milliseconds: 100));` قبل `ref.invalidate()` أو استخدام `WidgetsBinding.instance.addPostFrameCallback()`.

### 13. ❌ الفترة بين الأقساط — خيار مخصص بالأيام (موثق كمنجز لكنه يحتاج مراجعة)
- تم استبدال `initialValue` بـ `_customDaysController`.
- **المشكلة الجديدة المكتشفة:** التجميد **لم يُحل بالكامل**. قد يكون هناك `rebuild loop` من `setState()` في أماكن أخرى داخل `_buildInstallmentsSection` (مثلاً: `Checkbox` `_autoGenerateInstallmentReminders` أو `DropdownButtonFormField` `_installmentPeriod`).
- **الحل المطلوب:** فحص جميع `setState()` داخل `_buildInstallmentsSection`. إذا كان أي `onChanged` يُعيد بناء الويزارد باستمرار، يجب استبداله بـ `ValueNotifier` أو `TextEditingController` فقط دون `setState()` لكل ضغطة.

### 14. ❌ التصنيفات الرئيسية والفرعية الدائمة
- تم تطبيق `DB insert` عبر `_showAddCategoryDialog`.
- **المشكلة الجديدة المكتشفة (من طلب المستخدم):**
  1. **عند اختيار "عقود أخرى" كتصنيف رئيسي:** يجب فتح نافذة لإدخال **اسم التصنيف الرئيسي الجديد** و**تصنيفاته الفرعية دفعة واحدة** (ليس فقط التصنيف الرئيسي).
  2. **في التصنيف الفرعي:** يجب إضافة **حقل نص حر (`TextField`)** في نهاية `DropdownButtonFormField` للسماح بإدخال تصنيف فرعي جديد مباشرة من قائمة التصنيفات الفرعية (بدون فتح `Dialog` منفصل).
  3. **الاضافات يجب أن تبقى دائمة** (`DB`) — تم تطبيقها جزئياً لكن تحتاج مراجعة للتأكد من أن `_getSubcategories()` تُعيد القيم الجديدة فوراً (قد تحتاج `StreamBuilder` بدلاً من `FutureBuilder` لتجنب التأخير).

### 15. ❌ تجمد الشاشة عند اختيار التقسيط
- **لم يُحل بالكامل.** تم إصلاح `TextFormField` فقط. يجب فحص كامل `_buildInstallmentsSection` بحثاً عن أي `setState()` متكرر أو `Future` غير مُدار بشكل صحيح.
- **الحل المطلوب:** تشغيل التطبيق على `Windows` ومراقبة `Performance Monitor` أو `DevTools` لتحديد مصدر التجميد بدقة.

---

## 🔴 المشكلات الجديدة التي طلبها المستخدم (لم تُصلح بعد — بناءً على طلبه: "لاعد تصلح شي")

### أ. خاصية "عقود أخرى" (التصنيف الرئيسي)
- عند اختيار `عقود أخرى` من `DropdownButtonFormField` الرئيسي، يجب فتح `AlertDialog` تلقائياً (أو عبر زر مخصص) للسماح بإدخال:
  - اسم التصنيف الرئيسي الجديد
  - قائمة تصنيفاته الفرعية (مثلاً: عقد وكالة، عقد كفالة، عقد ضمان — أو أي تصنيفات مخصصة)
- **المكان في الكود:** `_buildClassificationFields` → `onChanged` لـ `_legalCategory`.
- **الحل المقترح:** إضافة شرط في `onChanged`: إذا كانت القيمة `'عقود أخرى'`، يتم فتح `_showCustomCategoryDialog()` مباشرة.

### ب. حقل نص حر للتصنيف الفرعي في نهاية القائمة
- في `_buildClassificationFields`، بجانب `DropdownButtonFormField` للتصنيف الفرعي، يجب إضافة:
  ```dart
  Expanded(
    flex: 2,
    child: TextFormField(
      decoration: baseDecoration.copyWith(labelText: 'أو أدخل تصنيفاً فرعياً جديداً'),
      onFieldSubmitted: (value) {
        if (value.trim().isNotEmpty) {
          // حفظ في DB واختياره تلقائياً
          _showAddCategoryDialog(isMainCategory: false); // أو حفظ مباشر
        }
      },
    ),
  ),
  ```
- **ملاحظة:** يجب أن يكون الحقل الحر بجانب الزر `+` أو كجزء من `Row` التصنيف الفرعي.

### ج. إضافة "الموطن المختار" إلى معلومات الشخص
- في `_showAddPersonDialog` (سطر ~1708)، يجب إضافة حقل جديد:
  - `TextFormField` أو `DropdownButtonFormField` لـ "الموطن المختار" (`nationality` أو `city` أو `governorate`).
  - يجب حفظه في جدول `Persons` (عمود `nationality` أو `city` أو إضافة عمود جديد إذا لم يكن موجوداً).
  - **المكان:** داخل `content` من `AlertDialog` في `_showAddPersonDialog`.

### د. الشاشة البرتقالية (خطأ) بعد إضافة شخص جديد
- في `_showAddPersonDialog`، بعد `await db.into(db.persons).insert(...)`, يتم استدعاء:
  ```dart
  ref.invalidate(allPersonsProvider(null));
  setState(() {
    person.personId = personId;
  });
  ```
- **المشكلة المحتملة:** إذا كان `context` مغلقاً (`dialog` مغلق) ولم يتم تحديث `WidgetRef` بشكل صحيح، قد يحدث `Exception` يؤدي إلى شاشة برتقالية (`FlutterError`).
- **الحل المقترح:**
  1. تغليف الكود بعد `Navigator.pop(ctx, true)` بـ `try-catch`.
  2. استخدام `WidgetsBinding.instance.addPostFrameCallback` قبل `ref.invalidate()`.
  3. التأكد من أن `person.personId` يُحدَّث بعد استلام `personId` وليس قبل التأكد من نجاح الإدخال.

### هـ. منع إضافة اسم موجود سلفاً
- قبل `await db.into(db.persons).insert(...)`, يجب فحص وجود الاسم في قاعدة البيانات:
  ```dart
  final existing = await (db.select(db.persons)..where((p) => p.fullName.equals(nameController.text.trim()))).getSingleOrNull();
  if (existing != null) {
    // عرض خطأ وإلغاء الإضافة
    return;
  }
  ```
- **المكان:** داخل `_showAddPersonDialog` قبل الإدخال.

---

## 📋 جدول التحقق النهائي (من الدستور + ملف التسليم)

- [ ] جميع الـ 4 طلبات القديمة منجزة ومثبتة في الكود + مرفوعة على `main`
- [ ] ملف `HANDOVER_DOCUMENT.md` الأصلي محفوظ ولم يُمسَح
- [ ] الدستور (`CONSTITUTION.md`) محفوظ ولم يُعدَّل
- [ ] التعديلات الجديدة موثقة في هذا الملف (`COMPREHENSIVE_HANDOVER.md`)
- [ ] تم الإقرار النصي بالتعذُّر من `flutter analyze` و`audit_members` و`flutter test` قبل الرفع
- [ ] تم رفع التعديلات (`push`) بنجاح (`36b9446` و`0886cde`)
- [ ] **لم يتم إصلاح أي من المشكلات الجديدة بناءً على طلب المستخدم الصريح** ("لاعد تصلح شي")

---

## 💡 نصيحة للمساعد القادم

> **لا تختصر.** كل تعديل يجب أن يمر بدورة الحياة الثلاثية (`Coding` → `Documentation` → `Deployment`) وأن يُرفع مباشرة مع `commit message` دقيق يصف التعديل ويُشير للدستور.

> **عند تكرار أي خطأ:** تحقق من `origin/main` مباشرة (كما في الدستور). أرقام الأسطر المتطابقة تعني أن الملف لم يتغيّر.

> **الذكاء الاصطناعي القادم (AI Phase):** كل البيانات المُنظمة (`UsageLog`, `TemplateVariables`, `Deficiencies`) تم إعدادها. لا تُعدِّل الجداول دون رفع `schemaVersion` وإضافة `Migration` (انظر `database.dart` الإصدار 10).

---

**بالتوفيق!** 🚀
*هذا الملف مُعدّ ليكون مرجعاً شاملاً لا يحتاج المستخدم لإعادة شرح السياق من الصفر.*
