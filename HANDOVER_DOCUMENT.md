# 📋 ملف التسليم - ويزارد العقود

## ⚠️ تنبيه مهم جداً للمساعد القادم

**يجب الالتزام الصارم بالدستور (CONSTITUTION.md) في كل تعديل!**

كل تعديل في هذا المشروع هو **تجهيز للذكاء الاصطناعي القادم**. لذلك:
- ✅ البيانات يجب أن تكون منظمة وقابلة للبحث
- ✅ الجداول يجب أن تكون مرتبطة بشكل صحيح
- ✅ الـ migrations يجب أن تعمل بشكل صحيح
- ✅ الـ UI يجب أن يكون بسيط وسريع
- ✅ لا تختصر - نفذ كل شيء بشكل كامل من المرة الأولى

---

## 🎯 الهدف الرئيسي

**تبسيط ويزارد إنشاء العقود من 6 خطوات إلى 2 خطوة فقط**، مع:
- جمع كل المعلومات الأساسية في خطوة واحدة
- فتح Word مباشرة بعد اختيار النموذج
- تجهيز البيانات للذكاء الاصطناعي

---

## ✅ الطلبات المنجزة بنجاح (11/15)

### التحسينات الهيكلية:
1. ✅ **تبسيط الويزارد** - من 6 خطوات إلى 2 خطوة
2. ✅ **إعادة ترتيب التبويبات** - من 7 إلى 4 تبويبات في شاشة التفاصيل
3. ✅ **جدول الأقساط** - `ContractInstallments` في قاعدة البيانات
4. ✅ **متابعة الأقساط** - تسجيل التسديد من شاشة التفاصيل

### الإصلاحات الحرجة:
5. ✅ **مشكلة المرفقات (Dialog)** - استخدام `StatefulBuilder`
6. ✅ **خطأ دافع الأتعاب** - استخدام `Set` لتجنب التكرار + جلب اسم الشخص
7. ✅ **فتح Word** - استخدام `Process.start` + عدم الانتقال للتفاصيل
8. ✅ **مطابقة الأسماء (تحقق لحظي)** - تعطيل الأشخاص المختارين في أطراف أخرى
9. ✅ **خطأ SQLite: template_source** - Migration v10 باستخدام `ALTER TABLE`
10. ✅ **رفع صورة الشيك/التحويل** - يظهر عند اختيار شيك أو تحويل بنكي

### الميزات الجديدة:
11. ✅ **التذكيرات التلقائية للأقساط** - checkbox لإنشاء تذكيرات مع خيار تحديد الأيام

---

## ❌ الطلبات الفاشلة - يجب إنجازها (4/15)

### 12. ❌ إضافة شخص جديد (طلب متكرر 3 مرات!)

**المطلوب:**
- زر "+" بجانب dropdown اختيار الشخص في كل طرف
- عند الضغط عليه، يفتح dialog لإدخال:
  - الاسم الكامل (إجباري)
  - رقم الهاتف (اختياري)
  - رقم الهوية (اختياري)
- حفظ الشخص الجديد في جدول `Persons` في قاعدة البيانات
- اختياره تلقائياً بعد الإضافة
- يظهر في القائمة في المرات القادمة

**المشكلة:**
- الزر موجود في الكود لكن لا يعمل بشكل صحيح
- قد يكون هناك خطأ في الـ dialog أو في الحفظ

**الحل:**
```dart
// في _buildPersonInPartyRow
Row(
  children: [
    Expanded(child: DropdownButtonFormField(...)),
    IconButton(
      icon: Icon(Icons.person_add),
      onPressed: () => _showAddPersonDialog(person),
    ),
  ],
)

// Method
Future<void> _showAddPersonDialog(_PersonInParty person) async {
  // Show dialog
  // Save to database: db.into(db.persons).insert(...)
  // Refresh list: ref.invalidate(allPersonsProvider(null))
  // Select: setState(() => person.personId = newId)
}
```

---

### 13. ❌ الفترة بين الأقساط - خيار مخصص بالأيام

**المطلوب:**
- dropdown لاختيار الفترة:
  - شهري (30 يوم)
  - كل شهرين (60 يوم)
  - كل 3 أشهر (90 يوم)
  - كل 6 أشهر (180 يوم)
  - سنوي (365 يوم)
  - **مخصص (بالأيام)** ← مهم!
- عند اختيار "مخصص"، يظهر TextField لإدخال عدد الأيام
- تعديل `_generateInstallments` لاستخدام `Duration(days: customDays)`

**المشكلة:**
- الكود موجود لكن قد لا يعمل بشكل صحيح
- أو أن UI لا يظهر بشكل صحيح

**الحل:**
```dart
// في _buildInstallmentsSection
DropdownButtonFormField<String>(
  value: _installmentPeriod,
  items: [
    DropdownMenuItem(value: 'شهري', child: Text('شهري (30 يوم)')),
    // ... باقي الخيارات
    DropdownMenuItem(value: 'مخصص', child: Text('مخصص (بالأيام)')),
  ],
  onChanged: (v) => setState(() => _installmentPeriod = v ?? 'شهري'),
),
if (_installmentPeriod == 'مخصص')
  TextFormField(
    decoration: InputDecoration(labelText: 'عدد الأيام'),
    onChanged: (v) => setState(() => _customDays = int.tryParse(v) ?? 30),
  ),

// في _generateInstallments
int daysToAdd = 30;
switch (_installmentPeriod) {
  case 'مخصص':
    daysToAdd = _customDays;
    break;
  // ... باقي الحالات
}
final dueDate = startDate.add(Duration(days: (i + 1) * daysToAdd));
```

---

### 14. ❌ التصنيفات الرئيسية والفرعية الدائمة

**المطلوب:**
- زر "+" بجانب dropdown التصنيف الرئيسي
- زر "+" بجانب dropdown التصنيف الفرعي
- عند الضغط على "+"، يفتح dialog لإدخال اسم التصنيف الجديد
- **حفظ دائم** في جدول `ContractTypesLookup` في قاعدة البيانات
- يظهر في القائمة في المرات القادمة

**المشكلة:**
- الكود موجود لكن لا يعمل بشكل صحيح
- التصنيفات تُحفظ مؤقتاً فقط (في قائمة محلية)
- لا تُحفظ في قاعدة البيانات بشكل دائم

**الحل:**
```dart
// في _buildClassificationFields
Row(
  children: [
    Expanded(child: DropdownButtonFormField(...)), // التصنيف الرئيسي
    IconButton(
      icon: Icon(Icons.add_circle),
      onPressed: () => _showAddCategoryDialog(isMainCategory: true),
    ),
    Expanded(child: DropdownButtonFormField(...)), // التصنيف الفرعي
    IconButton(
      icon: Icon(Icons.add_circle),
      onPressed: () => _showAddCategoryDialog(isMainCategory: false),
    ),
  ],
)

// Method
Future<void> _showAddCategoryDialog({required bool isMainCategory}) async {
  final nameController = TextEditingController();
  
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isMainCategory ? 'إضافة تصنيف رئيسي' : 'إضافة تصنيف فرعي'),
      content: TextField(controller: nameController),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, nameController.text),
          child: Text('إضافة'),
        ),
      ],
    ),
  );
  
  if (result != null && result.isNotEmpty) {
    // حفظ في قاعدة البيانات
    final db = ref.read(databaseProvider);
    await db.into(db.contractTypesLookup).insert(
      ContractTypesLookupCompanion.insert(
        name: result,
        category: Value(isMainCategory ? null : _legalCategory),
      ),
    );
    
    setState(() {
      if (isMainCategory) {
        _legalCategory = result;
      } else {
        _legalSubcategory = result;
      }
    });
  }
}

// تعديل _getSubcategories لجلب من قاعدة البيانات
Future<List<DropdownMenuItem<String>>> _getSubcategories() async {
  final db = ref.read(databaseProvider);
  final query = db.select(db.contractTypesLookup)
    ..where((t) => t.category.equals(_legalCategory ?? ''))
    ..where((t) => t.isActive.equals(true));
  
  final dbSubcats = await query.get();
  
  if (dbSubcats.isNotEmpty) {
    return dbSubcats.map((s) => DropdownMenuItem(
      value: s.name,
      child: Text(s.name),
    )).toList();
  }
  
  // Fallback to default
  // ...
}
```

**ملاحظة مهمة:** يجب استخدام `FutureBuilder` أو `StreamBuilder` في `_buildClassificationFields` لأن `_getSubcategories` الآن يُرجع `Future`.

---

### 15. ❌ تجمد الشاشة عند اختيار التقسيط

**المشكلة:**
- عند اختيار "تقسيط" كطريقة دفع، تتجمد الشاشة
- السبب غير معروف بالضبط

**الأسباب المحتملة:**
1. خطأ في `_buildInstallmentsSection`
2. loop لا نهائي في `setState`
3. خطأ في dropdown الفترة

**الحل:**
- تحقق من `_buildInstallmentsSection` للتأكد من عدم وجود loop
- تأكد من أن `setState` لا يُستدعى بشكل متكرر
- جرب comment out أجزاء من الكود لتحديد المشكلة

---

## 📊 جدول الجداول المهمة

### جداول قاعدة البيانات:
1. **Contracts** - بيانات العقد الأساسية
2. **ContractParties** - أطراف العقد
3. **ContractReminders** - التذكيرات الزمنية
4. **ContractInstallments** - الأقساط (جديد)
5. **ContractTemplates** - قوالب العقود
6. **ContractVersions** - نسخ العقود
7. **ContractTypesLookup** - التصنيفات الرئيسية والفرعية
8. **Persons** - الأشخاص
9. **Documents** - المستندات
10. **DocumentLinks** - ربط المستندات بالكيانات
11. **FeeAgreements** - اتفاقيات الأتعاب

### الملفات المهمة:
- `lib/data/database/schema.dart` - تعريف الجداول
- `lib/data/database/database.dart` - الـ migrations
- `lib/data/database/daos/contract_dao.dart` - دوال الوصول للبيانات
- `lib/data/repositories/contract_repository.dart` - مستودع العقود
- `lib/presentation/screens/contracts/create_contract_wizard.dart` - الويزارد (1900+ سطر)
- `lib/presentation/screens/contracts/contract_detail_screen.dart` - شاشة التفاصيل

---

## ⚠️ أخطاء شائعة يجب تجنبها

### 1. وضع الدوال خارج الـ State class
**خطأ:**
```dart
class _MyScreenState extends State<MyScreen> {
  // ... methods
}

Future<void> _showDialog() async {  // ❌ خارج الـ class
  // ...
}
```

**صحيح:**
```dart
class _MyScreenState extends State<MyScreen> {
  // ... methods
  
  Future<void> _showDialog() async {  // ✅ داخل الـ class
    // ...
  }
}
```

### 2. استخدام Future في build method بدون FutureBuilder
**خطأ:**
```dart
Widget build(BuildContext context) {
  final items = _getItems(); // Future<List>
  return DropdownButton(items: items); // ❌ خطأ
}
```

**صحيح:**
```dart
Widget build(BuildContext context) {
  return FutureBuilder(
    future: _getItems(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator();
      return DropdownButton(items: snapshot.data);
    },
  );
}
```

### 3. استخدام TableMigration لإضافة عمود جديد
**خطأ:**
```dart
if (from < 10) {
  await m.alterTable(TableMigration(contractTemplates)); // ❌ يحاول نسخ البيانات
}
```

**صحيح:**
```dart
if (from < 10) {
  await customStatement(
    'ALTER TABLE contract_templates ADD COLUMN template_source TEXT NOT NULL DEFAULT \'ready\''
  );
}
```

### 4. نسيان invalidate بعد إضافة بيانات
**خطأ:**
```dart
await db.into(db.persons).insert(...);
// لا refresh ❌
```

**صحيح:**
```dart
await db.into(db.persons).insert(...);
ref.invalidate(allPersonsProvider(null)); // ✅ refresh
```

---

## 🎯 checklist قبل التسليم

- [ ] جميع الطلبات الـ 15 منجزة
- [ ] لا توجد أخطاء بناء
- [ ] الـ migrations تعمل بشكل صحيح
- [ ] البيانات تُحفظ في قاعدة البيانات بشكل دائم
- [ ] الـ UI يعمل بدون تجمد
- [ ] التصنيفات الجديدة تظهر في القائمة لاحقاً
- [ ] الأشخاص الجدد يظهرون في القائمة لاحقاً
- [ ] الأقساط تُنشأ بشكل صحيح
- [ ] التذكيرات التلقائية تعمل
- [ ] Word يفتح مباشرة بعد الإنشاء

---

## 📞 معلومات الاتصال

إذا واجهت مشاكل:
1. راجع `CONSTITUTION.md` أولاً
2. تحقق من الـ migrations في `database.dart`
3. تأكد من أن الجداول مرتبطة بشكل صحيح
4. جرب حذف قاعدة البيانات وإعادة إنشائها (للتطوير فقط)

---

## 💡 نصيحة أخيرة

**لا تختصر!** نفذ كل شيء بشكل كامل من المرة الأولى. المستخدم محبط جداً من التكرار والفشل. كل طلب طلبه يجب أن يعمل بشكل صحيح من أول محاولة.

**تذكر:** كل تعديل هو تجهيز للذكاء الاصطناعي القادم. البيانات المنظمة = ذكاء اصطناعي أفضل.

---

**بالتوفيق!** 🚀
