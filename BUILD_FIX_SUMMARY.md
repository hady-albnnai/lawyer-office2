# ملخص إصلاح مشكلة بناء تطبيق مكتب المحاماة
## التاريخ: 30 يوليو 2026

## الحالة النهائية
✅ **التطبيق يبنى ويعمل بنجاح على Windows**

---

## المشاكل التي واجهت البناء والحلول المطبقة

جرى حل ثلاث مشاكل متتالية، كل واحدة كانت تحجب التي بعدها:

### 1. فشل تنزيل pdfium
**الخطأ:** `Build step for pdfium failed: 1`

حزمة `printing` تُنزّل مكتبة pdfium من الإنترنت أثناء أول بناء على
ويندوز. تعذّر إكمال التنزيل فتوقف البناء بعد ~327 ثانية.

**الحل:** استقرار الاتصال أثناء أول بناء. بعد نجاح التنزيل تُحفظ
المكتبة محلياً ولا يتكرر التنزيل في البناءات اللاحقة.

> **مهم:** لا تحذف `printing` من `pubspec.yaml` لتفادي هذا التنزيل.
> الحزمة مستخدمة فعلياً في 5 ملفات
> (`Printing.layoutPdf` / `sharePdf` / `PdfPreview`).

### 2. فشل native assets
**الخطأ:** `Target dart_build failed : Building native assets failed`

**السبب:** حزمة `sqlite3_flutter_libs` متوقفة رسمياً؛ آخر إصدار
`0.6.0+eol` ووصفه على pub.dev:
> *"Not used anymore, update to version 3.x of package:sqlite3 instead"*

النسخة `0.5.x` كانت تتعارض مع آلية native assets في Flutter 3.44.

**الحل:** إزالتها واعتماد `sqlite3: ^3.5.0` الذي يوفّر مكتبات المنصة
بنفسه. لا يوجد أي استيراد لها في الكود، فالإزالة كانت آمنة.

### 3. كسر واجهة file_picker
**الخطأ:** `Member not found: 'platform'` في 13 موضعاً

**السبب:** `file_picker 11.0.0` — تغيير جذري موثّق في CHANGELOG:
> *"Refactored `FilePicker` class to use `static` methods instead of an
> instance-based approach."*

**الحل:** `FilePicker.platform.pickFiles()` ← `FilePicker.pickFiles()`
في 13 موضعاً ضمن 8 ملفات.

---

## تحديثات الحزم

| الحزمة | قبل | بعد | السبب |
|--------|------|------|-------|
| `sqlite3_flutter_libs` | ^0.5.0 | **أُزيلت** | متوقفة (EOL) |
| `sqlite3` | — | ^3.5.0 | البديل الرسمي |
| `drift` / `drift_dev` | ^2.14.0 | ^2.34.3 | توافق SDK |
| `archive` | ^3.6.1 | ^4.0.9 | يتطلبه image 4.9 |
| `image` | 4.1–4.4 | ^4.9.1 | يتطلبه pdf 3.13 |
| `pdf` | 3.12.x | ^3.13.0 | يتطلبه printing 5.15 |
| `printing` | 5.14.x | ^5.15.0 | أحدث إصدار |
| `xml` | (تبعية) | ^7.0.1 | يتطلبه image 4.9 |
| `file_picker` | ^8.0.3 | ^11.0.2 | إصلاح ثغرة CWE-22 |
| `window_manager` | ^0.4.3 | ^0.5.2 | توافق |
| `flutter_lints` | ^3.0.1 | ^5.0.0 | توافق |
| SDK الأدنى | >=3.0.0 | >=3.10.0 | تتطلبه الحزم أعلاه |

### dependency_overrides
```yaml
dependency_overrides:
  archive: ^4.0.9
  image: ^4.9.1
  pdf: ^3.13.0
  printing: ^5.15.0
  xml: ^7.0.1
```

> **تنبيه:** `dependency_overrides` يتجاوز فحص التوافق بالقوة. نجح هنا
> لأن السلسلة `printing 5.15 → pdf 3.13 → image 4.9 → archive 4.0.9 + xml 7`
> متوافقة فعلياً. عند أي ترقية مستقبلية، راجع هذه السلسلة قبل التعديل.

---

## ⚠️ بند مفتوح: backup_service.dart

ترقية `archive` إلى 4.x غيّرت نوع `ArchiveFile.content`:

| | archive 3.x | archive 4.x |
|---|---|---|
| التوقيع | `dynamic get content` | `Uint8List get content => readBytes() ?? _emptyData` |

السطر 119 في `lib/data/services/backup_service.dart`:
```dart
final data = file.content as List<int>;
```

الـ cast يمرّ بالترجمة لأن `Uint8List` هي `List<int>`، **لكن** في 4.x
تُرجع `_emptyData` بدل `null` عند فشل القراءة — أي أن **استعادة نسخة
احتياطية قد تكتب ملفات فارغة بصمت** بدل رمي خطأ.

الإصلاح المقترح: التحقق من `readBytes()` صراحةً قبل الكتابة.

---

## نصائح للبناء المستقبلي

1. **لا تستخدم `flutter clean` إلا عند الضرورة** — يمسح مجلد `build`
   ويفرض إعادة ترجمة كاملة (5-10 دقائق على ويندوز). البناء التزايدي
   يستغرق أقل من دقيقة.
2. **استثنِ مجلدات المشروع من Windows Defender** — الفحص اللحظي لملفات
   `.obj` أثناء الترجمة يبطئ البناء 3-4 أضعاف:
   ```powershell
   Add-MpPreference -ExclusionPath "<مسار المشروع>"
   Add-MpPreference -ExclusionPath "C:\src\flutter"
   Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Pub\Cache"
   Add-MpPreference -ExclusionProcess "dart.exe"
   Add-MpPreference -ExclusionProcess "cl.exe"
   Add-MpPreference -ExclusionProcess "link.exe"
   Add-MpPreference -ExclusionProcess "MSBuild.exe"
   ```
3. **راجع توافق الحزم قبل الترقية** عبر `pub.dev` — خصوصاً سلسلة
   `printing → pdf → image → archive/xml` فهي مترابطة بإحكام.
4. **أول بناء بعد `pub get` يكون أبطأ** — قد يتضمن تنزيل pdfium.

---

## أوامر مرجعية

```cmd
flutter pub get
flutter run -d windows

:: عند تغيّر مخطط قاعدة البيانات أو ترقية drift
dart run build_runner build --delete-conflicting-outputs

:: عند مشاكل غير مفسّرة فقط
flutter clean && flutter pub get
```

---

## الملفات المرجعية

- `AGENTS.md` — نظام الأجندة والتحسينات
- `CONSTITUTION.md` — دستور التطوير الملزم
- `FUNCTIONAL_TESTING_PLAN.md` — خطة الاختبار الوظيفي
- `POA_FIX_REPORT.md` — إصلاحات الوكالات
