# تحليل المشاكل المكتشفة والميزات المطلوبة

## 📋 قائمة المشاكل والميزات (10 نقاط)

---

## 1️⃣ إضافة شخص جديد غير موجود مسبقاً

### المشكلة:
حالياً يمكن فقط اختيار أشخاص موجودين في قاعدة البيانات. لا يمكن إضافة شخص جديد أثناء إنشاء العقد.

### الحل:
إضافة زر "إضافة شخص جديد" بجانب كل dropdown لاختيار الشخص. عند الضغط عليه، يفتح dialog لإدخال بيانات الشخص الجديد وحفظه في قاعدة البيانات، ثم اختياره تلقائياً.

### التعديلات المطلوبة:
- إضافة زر "+" بجانب dropdown اختيار الشخص
- إنشاء dialog لإدخال: الاسم الكامل، رقم الهوية، الهاتف
- حفظ الشخص الجديد في جدول `Persons`
- تحديث قائمة الأشخاص المتاحة
- اختيار الشخص الجديد تلقائياً

---

## 2️⃣ مطابقة الأسماء بين الطرفين (منع التكرار)

### المشكلة:
يمكن اختيار نفس الشخص في طرفين مختلفين (مثلاً: نفس الشخص في "الطرف الأول" و"الطرف الثاني").

### الحل:
عند اختيار شخص في طرف معين، يتم تعطيله (disabled) في قوائم الأطراف الأخرى.

### التعديلات المطلوبة:
- تتبع جميع `personId` المختارة في جميع الأطراف
- عند بناء dropdown لكل طرف، استبعاد الأشخاص المختارين في أطراف أخرى
- عرض رسالة تحذيرية إذا حاول المستخدم اختيار شخص مكرر

---

## 3️⃣ الوقت الافتراضي للقسط (شهري - يحدده المستخدم)

### المشكلة الحالية:
```dart
dueDate: DateTime(startDate.year, startDate.month + i + 1, startDate.day)
```
هذا يضيف شهر واحد لكل قسط، لكن المستخدم لا يتحكم في الفترة.

### الحل:
إضافة dropdown لاختيار الفترة بين الأقساط:
- شهري (30 يوم)
- كل شهرين (60 يوم)
- كل 3 أشهر (90 يوم)
- كل 6 أشهر (180 يوم)
- سنوي (365 يوم)

### التعديلات المطلوبة:
- إضافة متغير `_installmentPeriod` (افتراضي: شهري)
- إضافة dropdown لاختيار الفترة
- تعديل `_generateInstallments()` لاستخدام الفترة المختارة
- إضافة خيار "مخصص" يسمح للمستخدم بتعديل كل تاريخ يدوياً

---

## 4️⃣ التذكيرات التلقائية للأقساط

### المشكلة:
عند تحديد أقساط، لا يتم إنشاء تذكيرات تلقائية لكل قسط.

### الحل:
عند توليد الأقساط، يتم إنشاء تذكير تلقائي لكل قسط قبل 3 أيام من تاريخ الاستحقاق (قابل للتخصيص).

### التعديلات المطلوبة:
- إضافة checkbox "إنشاء تذكيرات تلقائية للأقساط" (مفعّل افتراضياً)
- إضافة dropdown "التذكير قبل X يوم" (افتراضي: 3 أيام)
- عند توليد الأقساط، إضافة تذكيرات تلقائية إلى `_reminders`
- عرض التذكيرات المضافة تلقائياً بلون مختلف (مثلاً: أزرق فاتح)
- إمكانية حذف التذكيرات التلقائية يدوياً

---

## 5️⃣ مشكلة المرفقات (Dialog يُغلق عند اختيار ملف)

### المشكلة:
عند اختيار ملف في dialog إرفاق المستند:
```dart
onPressed: () async {
  final result = await file_picker.FilePicker.pickFiles();
  if (result != null) {
    selectedFile = File(result.files.single.path!);
    Navigator.pop(ctx);  // ← يغلق الـ dialog!
    _showAttachDocumentDialog(baseDecoration);  // ← يعيد فتحه لكن البيانات تضيع!
  }
}
```

### السبب:
`Navigator.pop(ctx)` يغلق الـ dialog، ثم `_showAttachDocumentDialog` يعيد فتحه لكن `nameController` و `docType` يتم إعادة إنشائها من جديد.

### الحل:
استخدام `StatefulBuilder` داخل الـ dialog للحفاظ على الحالة:

```dart
showDialog(
  context: context,
  builder: (ctx) => StatefulBuilder(
    builder: (context, setState) => AlertDialog(
      // ... content
      ElevatedButton.icon(
        onPressed: () async {
          final result = await file_picker.FilePicker.pickFiles();
          if (result != null) {
            selectedFile = File(result.files.single.path!);
            setState(() {});  // ← يحدث الـ dialog بدون إغلاقه!
          }
        },
      ),
    ),
  ),
);
```

---

## 6️⃣ خطأ دافع الأتعاب (DropdownButton value not found)

### المشكلة:
```
Failed assertion: 'items.where((item) => item.value == value).length == 1': 
There should be exactly one item with [DropdownButton]'s value: 6
```

### السبب:
1. إذا كان نفس الشخص (personId = 6) موجود في طرفين مختلفين، يتم إنشاء عنصرين بنفس القيمة في القائمة
2. النص المعروض هو `'${party.role} (ID: ${person.personId})'` - غير مفيد
3. إذا تم حذف شخص من الأطراف بعد اختياره كدافع أتعاب، `_feePartyId` سيبقى بقيمته لكن العنصر لن يكون موجوداً

### الحل:
1. استخدام `Set` لتجنب التكرار
2. جلب اسم الشخص الفعلي من قاعدة البيانات
3. التحقق من أن `_feePartyId` موجود في القائمة قبل عرض الـ dropdown

### التعديلات المطلوبة:
```dart
Widget _buildFeePartyPicker(InputDecoration baseDecoration) {
  final uniquePartyIds = <int>{};
  final clientParties = <DropdownMenuItem<int>>[];
  
  for (final party in _parties) {
    for (final person in party.persons) {
      if (person.personId != null && uniquePartyIds.add(person.personId)) {
        // جلب اسم الشخص من قاعدة البيانات
        final personName = _getPersonName(person.personId!);
        clientParties.add(DropdownMenuItem(
          value: person.personId,
          child: Text('$personName (${party.role})'),
        ));
      }
    }
  }
  
  // التحقق من أن _feePartyId موجود في القائمة
  final isValidValue = clientParties.any((item) => item.value == _feePartyId);
  
  return DropdownButtonFormField<int>(
    value: isValidValue ? _feePartyId : null,
    decoration: baseDecoration.copyWith(labelText: 'الموكل (دافع الأتعاب)'),
    items: clientParties,
    onChanged: (v) => setState(() => _feePartyId = v),
  );
}
```

---

## 7️⃣ إرفاق صورة التحويل/الشيك

### المشكلة:
عند اختيار "شيك" أو "تحويل بنكي" كطريقة دفع، لا يوجد خيار لإرفاق صورة الشيك أو إيصال التحويل.

### الحل:
عند اختيار شيك أو تحويل بنكي، يظهر حقل إضافي لإرفاق صورة.

### التعديلات المطلوبة:
- إضافة متغير `File? _paymentProofFile`
- عند اختيار شيك أو تحويل بنكي، يظهر زر "إرفاق صورة الشيك/التحويل"
- حفظ الصورة في مجلد `payment_proofs`
- إضافة حقل `paymentProofPath` في جدول `Contracts` (يتطلب migration)
- عرض الصورة في شاشة التفاصيل

---

## 8️⃣ إضافة تصنيف رئيسي/فرعي مخصص

### المشكلة:
التصنيفات محددة مسبقاً ولا يمكن للمستخدم إضافة تصنيفات جديدة.

### الحل:
إضافة زر "إضافة تصنيف جديد" بجانب كل dropdown.

### التعديلات المطلوبة:
- إضافة زر "+" بجانب dropdown التصنيف الرئيسي
- عند الضغط عليه، يفتح dialog لإدخال اسم التصنيف الجديد
- حفظ التصنيف في جدول `ContractTypesLookup`
- تحديث قائمة التصنيفات المتاحة
- نفس الشيء للتصنيف الفرعي

---

## 9️⃣ النماذج لا تُحفظ في المكتبة

### المشكلة:
بعد إضافة 5 عقود، لا توجد نماذج في المكتبة.

### السبب:
النماذج تُحفظ فقط عند اختيار "استيراد نموذج" (`_creationMethod == 'uploaded'`). لكن:
- النماذج من المكتبة: موجودة أصلاً
- الورقة الفارغة: لا يوجد نموذج لحفظه

### الحل:
1. عند اختيار "ورقة فارغة"، إنشاء ملف Word فارغ وحفظه كنموذج
2. إضافة خيار "حفظ هذا العقد كنموذج" بعد الإنشاء
3. التحقق من أن `saveTemplate` يعمل بشكل صحيح

### التعديلات المطلوبة:
```dart
// عند اختيار ورقة فارغة
if (_creationMethod == 'blank') {
  // إنشاء ملف Word فارغ
  final blankFile = await _createBlankWordFile();
  wordFile = blankFile;
  
  // حفظه كنموذج إذا أراد المستخدم
  if (_saveBlankAsTemplate) {
    await _saveTemplateToLibrary(blankFile, _templateNameController.text);
  }
}
```

---

## 🔟 مشكلة فتح Word وشاشة التفاصيل

### المشكلة:
عند اختيار "ورقة فارغة" والضغط على "إنشاء العقد وفتحه في Word":
1. لا يفتح Word
2. ينتقل لشاشة التفاصيل (4 تبويبات)
3. المستخدم يقول "المفروض ماعد تطلع هي الشاشة"

### السبب:
1. `DesktopIntegrationService.openInWord()` غير موجود (تم comment out)
2. `context.go('/contracts/$contractId')` ينتقل لشاشة التفاصيل

### الحل:
1. إضافة دالة `openInWord` تستخدم `Process.start`:
```dart
static Future<void> openInWord(String filePath) async {
  if (Platform.isWindows) {
    await Process.start('explorer', [filePath]);
  } else if (Platform.isMacOS) {
    await Process.start('open', [filePath]);
  } else {
    await Process.start('xdg-open', [filePath]);
  }
}
```

2. عدم الانتقال لشاشة التفاصيل فوراً:
```dart
// بدلاً من:
context.go('/contracts/$contractId');

// استخدام:
context.pop();  // العودة لقائمة العقود
```

3. عرض رسالة "تم إنشاء العقد وفتحه في Word. يمكنك الوصول إليه لاحقاً من قائمة العقود."

---

## 📊 ملخص الأولويات

| # | المشكلة | الأولوية | الصعوبة |
|---|---------|----------|---------|
| 1 | إضافة شخص جديد | عالي | متوسط |
| 2 | مطابقة الأسماء | عالي | سهل |
| 3 | فترة الأقساط | متوسط | سهل |
| 4 | تذكيرات تلقائية للأقساط | متوسط | سهل |
| 5 | مشكلة المرفقات | عالي | سهل |
| 6 | خطأ دافع الأتعاب | عالي | سهل |
| 7 | إرفاق صورة الشيك/التحويل | متوسط | متوسط |
| 8 | تصنيفات مخصصة | منخفض | متوسط |
| 9 | حفظ النماذج | عالي | متوسط |
| 10 | فتح Word | عالي | سهل |

---

## 🎯 التوصيات

### المرحلة 1 (إصلاحات عاجلة):
1. ✅ مشكلة المرفقات (#5)
2. ✅ خطأ دافع الأتعاب (#6)
3. ✅ فتح Word (#10)
4. ✅ مطابقة الأسماء (#2)

### المرحلة 2 (ميزات مهمة):
5. ✅ إضافة شخص جديد (#1)
6. ✅ حفظ النماذج (#9)
7. ✅ فترة الأقساط (#3)
8. ✅ تذكيرات تلقائية (#4)

### المرحلة 3 (ميزات إضافية):
9. ✅ إرفاق صورة الشيك/التحويل (#7)
10. ✅ تصنيفات مخصصة (#8)
