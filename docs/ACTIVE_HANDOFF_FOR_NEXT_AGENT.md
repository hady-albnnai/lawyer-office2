# ACTIVE HANDOFF — متابعة مشروع ميزان بدقة

تاريخ التسليم: 2026-07-24  
المستودع: `https://github.com/hady-albnnai/lawyer-office`  
الفرع الوحيد المعتمد: `main`  
آخر commit عند كتابة هذا الملف:

```text
322800c fix(agenda): preserve result source context
```

---

## 1. تعليمات إلزامية للمحادثة الجديدة

اقرأ هذا الملف أولاً قبل أي كود. لا تعتمد على ملخصات عامة.

قواعد المستخدم:

- المستخدم يتكلم عربي/سوري ويفضل جواب مباشر.
- لا تغيّر أي شيء خارج المطلوب.
- لا تنفيذ جزئي لميزة كبيرة ثم إعلانها مكتملة.
- لا تقل «تم/انتهى» إلا بعد: كود + توثيق + commit + push.
- Flutter/Dart غير مثبتين عند المساعد. المستخدم يشغل `flutter analyze` و `flutter run -d windows` ويرسل الأخطاء.
- كل بيانات التطبيق الحالية تجريبية ومسموح reset لها.
- محتوى المكتبة القانونية مؤجل بالكامل. لا تجمع محتوى، ولا تحذف الدستور، ولا تعدّل ملفات المكتبة إلا إذا طُلب صراحة.
- التصميم الشكلي النهائي مؤجل.
- أبقِ المستودع على `main` فقط.
- قلّل مخرجات الطرفية حتى لا تتجمد المحادثة. نفذ دفعات صغيرة مرفوعة.

---

## 2. أوامر بداية المحادثة الجديدة

ابدأ دائماً بـ:

```bash
cd /home/user/lawyer-office
git remote add origin https://github.com/hady-albnnai/lawyer-office.git 2>/dev/null || git remote set-url origin https://github.com/hady-albnnai/lawyer-office.git
git fetch origin --prune
git status --short
git log --oneline -5
```

إذا كانت الحالة متسخة بسبب snapshot قديم، احفظها في stash فقط إن لزم، ثم ارجع إلى `origin/main` قبل العمل.

---

## 3. الهدف الكبير المتفق عليه

تحويل التطبيق من CRUD عام إلى نظام مكتب محاماة سوري عملي حول:

```text
OfficeFiles + OfficeFileSequences
```

مع فصل واضح بين:

```text
العمل الجديد بعد نزول التطبيق
الأرشيف القديم
الملفات الجارية
الملفات المنتهية
```

وإنشاء جديد فقط من مكتب العمل، لا من شاشة ملفات المكتب.

---

## 4. ملفات الخطة المرجعية

الأهم:

```text
docs/FINAL_IMPLEMENTATION_ROADMAP.md
docs/FINAL_ROADMAP_COVERAGE_AUDIT.md
docs/UPDATED_TECHNICAL_UPDATE_REQUIREMENTS.md
EXECUTION_PLAN.md
```

لكن لا تعتمد على عبارة «اكتملت الخطة» في أي ملف؛ افحص الكود دائماً.

---

## 5. ما تم تنفيذه فعلياً حتى الآن

### 5.1 نواة OfficeFiles

في `lib/data/database/database.dart`:

- أضيفت دالة:
  - `ensureOfficeFileTables()`
- تنشئ SQL-managed tables:
  - `office_files`
  - `office_file_sequences`
- تم استدعاؤها في `beforeOpen`.

اختير SQL-managed مؤقتاً لتجنب كسر `database.g.dart` لأن `build_runner` غير متاح لدى المساعد.

### 5.2 Enums

في `lib/core/enums/app_enums.dart`:

- `OfficeFileType`
- `OfficeFileSource`
- `OfficeFileStatus`

### 5.3 Repository

أضيف:

```text
lib/data/repositories/office_file_repository.dart
```

وفيه:

- `createOfficeFile()`
- `linkOfficeFile()`
- `getAll()`
- `getById()`
- `getByLinkedEntity()`
- `closeOfficeFile()`
- `reopenOfficeFile()`
- `createFromOldArchive()`
- `updatePendingFlagsByLinkedEntity()`

### 5.4 Provider

في `lib/presentation/providers/app_providers.dart`:

- `officeFileRepositoryProvider`

### 5.5 ربط الكيانات الأساسية بـ OfficeFiles

تم ربط إنشاء:

- دعوى: `CaseRepository`
- إجراء: `AdminProcedureRepository`
- عقد: `ContractRepository`
- شركة: `CompanyRepository`
- وكالة: `PoaRepository`

بأرقام:

```text
دعوى/2026/0001
إجراء/2026/0001
عقد/2026/0001
شركة/2026/0001
وكالة/2026/0001
```

### 5.6 شاشة الملفات

في `ui_data_providers.dart`:

- بدأ `uiFilesProvider` يستخدم `office_files` للأرقام والحالات إن وجد، مع fallback للأرقام القديمة.
- أضيف `officeFileCountsProvider`.

في `files_screen.dart`:

- تم تغيير `عاملة` إلى `جارية`.
- أضيفت واجهة أولية للإغلاق الإداري وإعادة الفتح:
  - `CloseOfficeFileDialog`
  - `ReopenOfficeFileDialog`

### 5.7 الأجندة والنتائج

في `agenda_screen.dart`:

- تقرأ من `case_sessions` و `daily_tasks`.
- أضيف `entityId/entityType` إلى `UnifiedAgendaItem`.
- تمرر السياق إلى `ResultEntryDialog`.

في `result_entry_dialog.dart`:

- لا يحذف النواقص؛ يحدّثها `resolved` بأمان.
- يحفظ `source_type/source_id` حسب السياق.
- المصروف التلقائي يسجل فقط إذا السياق دعوى واضح.

### 5.8 أوامر العمل

في `work_order_dialogs.dart`:

- تحسين واتساب:
  - نسخ الرسالة دائماً.
  - تجربة `whatsapp://send` ثم `wa.me`.
  - لا تحديث حالة مرسل عند الفشل إلا بتأكيد المستخدم.

في `work_order_models.dart`:

- تبسيط حالات العرض للمستخدم:
  - مفتوح
  - نتيجة مدخلة
  - معتمد
  - مؤجل
  - ملغى
  - يحتاج تصحيح

في `work_order_repository.dart`:

- تحديث مؤشر `has_post_closure_actions` في OfficeFile عند إنشاء/تغيير/اعتماد أمر عمل.

### 5.9 المالية والمستندات

في `FinanceRepository`:

- عند إنشاء اتفاق/دفعة/مصروف يتم تحديث `has_pending_finance` في OfficeFile المرتبط.

في `DocumentRepository`:

- عند إضافة مستند مع بيانات أصل ورقي يتم تحديث `has_pending_paper_original`.

### 5.10 الصلاحيات

في `AuthRepository` و `database.dart`:

- الدور الافتراضي صار `مالك المكتب` بدل `صاحب المكتب`.
- إضافة SQL-managed column:
  - `hierarchy_level`
- مستويات مبدئية:
  - مالك = 100
  - مدير = 80
  - محامي أستاذ = 60
- منع تعطيل آخر مالك فعال.

---

## 6. آخر commits مهمة

```text
322800c fix(agenda): preserve result source context
8101c39 feat(office-files): sync work order pending flags
8faafe5 feat(office-files): sync finance and paper flags
18a5974 fix(work-orders): simplify displayed lifecycle statuses
8002da5 fix(auth): align owner role naming and protect last owner
789aac7 fix(work-orders): improve whatsapp send fallback
3d0143a fix(office-files): correct agenda result linkage and person office files
776fd09 docs: add F8_RELEASE_CHECKLIST.md for final delivery
```

---

## 7. ما لم يثبت بعد / المتبقي

لا تعتبر الخطة كاملة حتى يتم فحص هذه النقاط بالكود:

1. شاشة الملفات ما زالت مركبة من الكيانات مع OfficeFile fallback، وليست OfficeFiles source-of-truth بالكامل.
2. مركز اليوم/الغد وغير المكتمل لم يكتمل بالكامل حسب المفهوم المتفق عليه.
3. الأرشيف القديم مربوط جزئياً بـ `createFromOldArchive`، لكن يحتاج تدقيق الجاري/المنتهي وحالة `closed` للأرشيف المنتهي.
4. منع التصعيد في الصلاحيات جزئي فقط؛ تم فقط حماية آخر مالك وتسميات أولية.
5. ربط المالية والمستندات بـ OfficeFile تم كمؤشرات، وليس إعادة هيكلة مالية كاملة أو مبالغ لحساب الموكل.
6. التقارير النهائية غير مكتملة.
7. لم يتم تشغيل build بعد بعد هذه التعديلات.

---

## 8. تحذيرات مهمة من أخطاء سابقة

- لا تنشئ OfficeFile للأشخاص العاديين. الأشخاص دليل مركزي، وليسوا ملفات مكتب.
- لا تحذف النواقص بـ `delete`; استخدم update إلى `resolved` مع فلترة دقيقة.
- لا تمرر ResultEntryDialog بلا `entityId/entityType` عند وجود كيان.
- لا تحدث حالة واتساب كمرسل إذا فشل الفتح إلا بعد تأكيد المستخدم.
- لا تجمع محتوى قانوني الآن.

---

## 9. طريقة العمل المقترحة لتجنب التجميد

نفذ دفعات صغيرة:

- ملفان أو ثلاثة كحد أقصى.
- commit/push بعد كل دفعة.
- رد مختصر جداً للمستخدم: ماذا تغير + commit.
- لا تطبع مخرجات طويلة.

---

## 10. الخطوة التالية المقترحة

أفضل دفعة قادمة:

```text
تدقيق وربط الأرشيف القديم بحالة OfficeFile صحيحة:
- oldArchive جاري => active
- oldArchive منتهي => closed
- عدم ابتلاع أخطاء OfficeFile بصمت في ArchiveIntakeRepository
```

أو إذا أراد المستخدم build أولاً:

```bash
flutter analyze
flutter run -d windows
```

ثم إصلاح أخطاء البناء مباشرة.

---

## 11. سجل الجلسة 2026-07-24 (متابعة)

### دفعة 1 — تصحيح ربط الأرشيف القديم بحالة OfficeFile

الملفات:

```text
lib/data/repositories/office_file_repository.dart
lib/data/repositories/archive_intake_repository.dart
lib/presentation/screens/archive_intake/archive_intake_screen.dart
```

ما تغير:

- `setStatusByLinkedEntity()`: مزامنة حالة ملف المكتب لكيان مرتبط (active/closed) دون إغلاق إداري كامل.
- `createFromOldArchive()`: صار يقبل `status` بدل فرض `active` دائماً.
- `ensureOldArchiveOfficeFile()`: يمنع إنشاء ملف مكتب مكرر لنفس الكيان، ويكتفي بمزامنة الحالة إن وُجد.
- `promoteItemToDocument()`: يقبل `officeFileStatus`، ولم يعد يبتلع فشل OfficeFile بصمت؛ يسجل تحذيراً في مراجعة العنصر وحدثاً `office_file_sync_failed` في الخط الزمني.
- شاشة الأرشيف: حقل «حالة ملف المكتب المرتبط» (جارٍ/منتهٍ) في حوار الربط، ولا يظهر للأشخاص.

تحقق: `flutter analyze` على الملفات الثلاثة = No issues found.

### ملاحظة حرجة: البناء الحالي مكسور قبل هذه الدفعة

`flutter analyze` على كامل المشروع أظهر 22 خطأ موجودة مسبقاً على main وليست من هذه الدفعة:

```text
lib/presentation/providers/ui_data_providers.dart   (CaseFee, CaseExpense, getFeesByEntity, getExpensesByEntity)
lib/presentation/screens/cases/case_detail_screen.dart   (uiDocumentsProvider, financeByEntityProvider)
lib/presentation/screens/search_reports/search_report_models.dart   (Case, DocumentItem, uiCasesProvider, null safety)
lib/presentation/widgets/sidebar/nav_sidebar.dart   (SidebarItemModelExtension مكرر)
test/stage12_remaining_modules_test.dart، test/stage8_search_reports_test.dart
```

الأولوية التالية: إصلاح أخطاء البناء هذه قبل أي ميزة جديدة.

### دفعة 2 — إصلاح كل أخطاء البناء المكسورة مسبقاً

الحالة النهائية: **0 error** في `flutter analyze` على كامل المشروع (lib + test)، و**32/32 اختبار ناجح**.

ما تم إصلاحه:

1. `lib/data/database/daos/finance_dao.dart`
   - `getAgreementsByEntity()` و `getPaymentsByAgreements()` و `getExpensesByEntity()`.
2. `lib/data/repositories/finance_repository.dart`
   - `getAgreementsByEntity()` و `getPaymentsByEntity()` و `getExpensesByEntity()` (الدوال التي كانت الواجهة تناديها وغير موجودة).
3. `lib/presentation/providers/ui_data_providers.dart`
   - إعادة كتابة `financeByEntityProvider` ليقرأ من قاعدة البيانات الحقيقية ويحوّل إلى `CaseFee` / `CaseExpense`.
   - أضيف `totalPaid` و `remaining` إلى `EntityFinanceData`، ودالة `_entityTypeFromKey`.
4. `lib/presentation/screens/cases/case_detail_screen.dart`
   - استيراد `uiDocumentsProvider` و `financeByEntityProvider`، وتصحيح تمرير الـ record `('case', id)`.
5. `lib/presentation/screens/search_reports/search_report_models.dart`
   - استيرادات `ui_case` و `ui_doc` و `uiCasesProvider`.
   - **فهرسة العقود فعلياً**: `ContractSearchSeed` + `SearchScope.contracts` صار يُبنى من `allContractsProvider` الحقيقي (كان مفقوداً بالكامل من الفهرس).
6. `lib/presentation/widgets/sidebar/nav_sidebar.dart`
   - حذف نسخة مكررة حرفياً من `extension SidebarItemModelExtension`.
7. `lib/presentation/screens/persons/person_models.dart`
   - إضافة `PersonsDirectoryNotifier.withDemoSeed()` مع `@visibleForTesting`.
   - التطبيق الفعلي يبقى يبدأ فارغاً ويُغذّى من DB عبر `hydrateFromDb` (بدون بيانات وهمية في الإنتاج).
8. `test/stage12_remaining_modules_test.dart`
   - تصحيح توقيع `CaseRepository` القديم إلى: `caseDao, TaskSyncService, DeficiencyService, FileStorageService, OfficeFileRepository`.
9. `test/stage8_search_reports_test.dart` و `test/stage6_person_directory_test.dart`
   - تمرير `realCases` و `contracts`، واستخدام `withDemoSeed()`.

ملاحظة للمساعد التالي: بقي 202 تنبيه من نوع info/warning فقط (prefer_single_quotes، unused_import، must_call_super، dangling doc comments) ولا يمنع أي منها البناء.

### حالة التحقق

```text
flutter analyze  =>  0 errors (202 info/warning)
flutter test     =>  All tests passed! (32/32)
```

لم يتم تشغيل `flutter run -d windows` (لا يوجد ويندوز عند المساعد) — يبقى على المستخدم.

### دفعة 3 — التقارير على بيانات حقيقية + إصلاح خلل تواريخ خطير

#### أ. التقارير كانت تطبع بيانات مخترعة

في `search_report_models.dart` كانت `sessions` و `overdue` و `deficient` صفوفاً ثابتة
مكتوبة داخل الكود («دعوى تعويض / محكمة دمشق الأولى / 2026/001»). أي أن كشف الجلسات
وكشف المتأخرات وكشف الملفات الناقصة كانت تطبع أرقاماً لا علاقة لها بقاعدة البيانات.

الحل: ملف جديد

```text
lib/presentation/providers/report_data_providers.dart
```

يحتوي:

- `sessionsReportProvider` — جلسات يوم محدد من `case_sessions` + `cases` + `courts`.
- `overdueReportProvider` — المتأخرات من ثلاثة مصادر: `daily_tasks` غير المنجزة،
  جلسات فات موعدها بلا نتيجة، و `work_orders` غير المعتمدة.
- `deficientReportProvider` — تجميع `deficiencies` المفتوحة لكل دعوى مع رقم الأساس
  وبيان المستندات الناقصة.
- `reportDataBundleProvider` — يجمعها ويغذّي `searchReportEngineProvider`.

`buildFromSources` صار يقبل `reportData` بدل توليد صفوف ثابتة.

#### ب. خلل حرج: DATE() على أعمدة التاريخ لا تعمل إطلاقاً

Drift يخزّن `DateTime` كعدد **Unix epoch** (integer)، وبالتالي:

```text
DATE(session_date)  =>  NULL   دائماً
```

يعني أي استعلام يستخدم `DATE(col)` كان **يُرجع صفر صفوف دائماً**. تم التحقق عملياً:

```text
session_date = 1784851200, typeof = integer, DATE(session_date) = null
```

المواضع المصابة والمصلحة:

1. `lib/presentation/screens/agenda/agenda_screen.dart`
   - جلسات اليوم ومهام اليوم: **الأجندة كانت تظهر فارغة دائماً**.
2. `lib/presentation/screens/agenda/result_entry_dialog.dart`
   - `UPDATE case_sessions ... WHERE DATE(session_date) = DATE(?)` لم يكن يطابق أي صف،
     أي أن نتيجة الجلسة لم تكن تُحفظ على الجلسة إطلاقاً.
3. استعلامات التقارير الجديدة.

الأسلوب المعتمد: مقارنة مجال نصف مفتوح بدل `DATE()`

```sql
WHERE session_date >= ? AND session_date < ?   -- [بداية اليوم، بداية الغد)
```

مع `Variable.withDateTime(...)`.

قاعدة للمساعد التالي: **لا تستخدم `DATE()` أو `strftime()` على أعمدة DateTime في هذا
المشروع.** استخدم مقارنة مجال بـ `Variable.withDateTime`.

#### ج. اختبارات جديدة

`test/reports_real_data_test.dart` — 5 اختبارات تُدخل صفوفاً حقيقية في قاعدة بيانات
في الذاكرة وتتحقق أن الاستعلامات تُرجعها فعلاً: فلترة اليوم الصحيح، استثناء المنجز
والملغى، استثناء أوامر العمل المعتمدة، تجميع النواقص المفتوحة، وأن قاعدة نظيفة
تُرجع فراغاً بدل صفوف مخترعة.

### حالة التحقق بعد الدفعة 3

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (37/37)
```

### دفعة 4 — منع التصعيد في الصلاحيات (Privilege Escalation)

#### المشكلة

`hierarchy_level` كان موجوداً في `database.dart` فقط، بصفر استخدام في أي مكان آخر.
لم يكن هناك أي منطق يمنع مستخدماً من:

- منح صلاحيات لا يملكها هو أصلاً.
- إنشاء دور بمستوى يساوي مستواه أو يعلوه.
- ترقية دوره هو نفسه إلى مستوى المالك.
- تعديل/تعطيل/تغيير كلمة مرور مستخدم أعلى منه (بما فيهم المالك).
- إسناد دور المالك لنفسه أو لمستخدم جديد.

المحمي الوحيد سابقاً كان «آخر مالك فعال».

#### الحل في `lib/data/repositories/auth_repository.dart`

- `AuthRepository.ownerLevel = 100` ثابت مرجعي.
- `AuthUser.hierarchyLevel` و `AuthUser.effectiveLevel` (المالك دائماً 100).
- `AuthRole.hierarchyLevel`.
- تحميل `hierarchy_level` فعلياً في `login()` و `getUsers()` و `getRoles()`
  (كان لا يُقرأ إطلاقاً)، وترتيب الأدوار هرمياً.
- ثلاث حراسات مركزية:
  - `_assertNoPermissionEscalation` — لا تمنح ما لا تملك.
  - `_assertCanManageLevel` — لا تتعامل مع مستوى يساويك أو يعلوك.
  - `_assertCanManageUser` — لا تتعامل مع مستخدم أعلى (مع السماح بالحساب الشخصي).
- طُبّقت على: `createRole` و `updateRole` و `duplicateRole` و `setRoleActive`
  و `createUser` و `updateUser` و `changeUserPassword` و `setUserActive`.
- `createOwner` صار يثبّت مستوى المالك = 100.
- `duplicateRole` صار ينسخ المستوى بدل تركه صفراً.

المالك وحده معفى من هذه القيود.

#### واجهة الإعدادات `settings_screen.dart`

- حقل «مستوى الدور في الهرم الإداري» في حوار الدور، مع سقف = مستوى المنفّذ ناقص 1.
- قائمة الأدوار في حوار المستخدم تُفلتر لتعرض الأدنى فقط.
- منع فتح حوار تعديل دور/مستخدم أعلى من المنفّذ من الأساس.
- عرض المستوى في قائمتي الأدوار والمستخدمين.
- **كل أخطاء منع التصعيد صارت تُعرض للمستخدم** بدل ابتلاعها بصمت
  (حوار المستخدم، كلمة المرور، نسخ الدور، مفتاح تفعيل المستخدم).

#### اختبارات

`test/privilege_escalation_test.dart` — 10 اختبارات تحاول التصعيد فعلياً وتتأكد من الرفض:
منح صلاحيات غير مملوكة، إنشاء دور مساوٍ/أعلى، ترقية الدور الذاتي، تعطيل المالك،
تغيير كلمة مرور المالك، إسناد دور أعلى للنفس، إنشاء مستخدم بدور أعلى، نسخ دور أعلى،
مع التأكد أن المدير ما زال يدير من هم أدنى منه بشكل طبيعي.

### حالة التحقق بعد الدفعة 4

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (47/47)
```

### دفعة 5 — شاشة الملفات: OfficeFiles مصدر الحقيقة

#### المشكلة

`uiFilesProvider` كان يلفّ على الكيانات (دعاوى، عقود، شركات، إجراءات، وكالات)
ثم يبحث عن OfficeFile مطابق ويستخدمه كـ fallback فقط. النتيجة:

- كيان بلا OfficeFile يظهر برقمه القديم، فيتعايش نظاما ترقيم في نفس الشاشة.
- حالة الملف تُشتق من الكيان لا من ملف المكتب.
- الإغلاق الإداري على OfficeFile قد لا ينعكس.

#### الحل

1. `OfficeFileRepository.ensureOfficeFileForEntity()` — يستكمل ملف مكتب لأي كيان
   قائم أُنشئ قبل اعتماد النظام، بمصدر `manual_admin`، ويحفظ الرقم القديم في
   `notes` للمرجعية. لا ينشئ ملفاً لكيان بمعرّف غير صالح.

2. إعادة بناء `uiFilesProvider` على ثلاث مراحل:
   - استكمال ملفات المكتب الناقصة للكيانات القائمة (backfill).
   - قراءة `office_files` كمصدر أساسي.
   - إلباس كل سجل تفاصيل الكيان المرتبط عبر خرائط `id -> entity`.

   النتيجة: **رقم الملف والحالة يأتيان من OfficeFile حصراً**، ولم يعد هناك
   `getFileNumber(fallback)` ولا `statusFromOffice(fallback)`.
   كما أُدمج `hasPendingPaperOriginal` في مؤشر المستندات الناقصة.

   ملاحظة: ملف مكتب بلا كيان مرتبط لا يُعرض في الشاشة التشغيلية.

#### اختبارات

`test/office_files_source_of_truth_test.dart` — 5 اختبارات: استكمال كيان قديم،
عدم تكرار الرقم عند إعادة التنفيذ، الكيان المنتهي يُستكمل كملف مغلق، استقلال
التسلسل حسب النوع والسنة، ورفض المعرّف غير الصالح.

### حالة التحقق بعد الدفعة 5

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (52/52)
```

### دفعة 6 — حساب الموكل والأمانات

#### المشكلة

لم يكن هناك مفهوم «حساب موكل» في التطبيق إطلاقاً (بحث عن `حساب الموكل` أو
`أمانات` كان يعطي صفر نتيجة). الموجود كان `ClientReceivable.remaining` وهو
`أتعاب − مقبوض` فقط:

- المصاريف التي يصرفها المكتب عن ملفات الموكل لا تُحمَّل عليه.
- الدفع الزائد يظهر كرقم سالب بلا معنى، ولا يوجد مفهوم أمانة.

#### الحل في `finance_models.dart`

على `ClientReceivable`:

- `totalDue` — أتعاب + مصاريف صُرفت على ملفاته.
- `accountBalance` — موجب: على الموكل، سالب: أمانة له لدى المكتب.
- `hasCredit` و `creditAmount` و `accountStatusLabel`.
- `remaining` بقيت كما هي (أتعاب غير مقبوضة فقط) لعدم كسر السلوك القائم.

نموذجان جديدان:

- `ClientStatementEntry` — حركة واحدة (مدين/دائن).
- `ClientStatement` — كشف حساب مرتب زمنياً مع `runningBalances` والرصيد النهائي.

ودالة `FinanceState.clientStatement(partyId)` تبنيه من البيانات الفعلية.

**قاعدة محاسبية مطبقة:** المصروف يُحمَّل على الموكل فقط إذا كان على كيان له فيه
اتفاق أتعاب، حتى لا تُحمَّل مصاريف ملف على موكل لا علاقة له به.

#### التقارير والواجهة

- نوع تقرير جديد `ReportKind.clientAccounts` — «كشف حسابات الموكلين» بأعمدة:
  الموكل، أتعاب، مصاريف عنه، المقبوض، الرصيد، الحالة. وملخصه يشمل الأمانات.
- شاشة المالية: بطاقة الموكل تعرض «رصيد الحساب» أو «أمانة له»، بلون مميز
  (أزرق للأمانة، أخضر مسدّد، برتقالي ذمة)، والتقرير المختصر يعرض إجمالي
  المستحق والذمم القائمة والأمانات.

#### اختبارات

`test/client_account_test.dart` — 7 اختبارات: تحميل المصاريف، الدفع الزائد كأمانة،
الحساب المسدّد، عدم تحميل مصاريف ملفات غير مرتبطة، ترتيب كشف الحساب والرصيد
التراكمي، وكشف حسابات الموكلين في التقارير.

### حالة التحقق بعد الدفعة 6

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (59/59)
```

### دفعة 7 — تدقيق مركز اليوم/الغد وتفعيل الأزرار المعطلة

#### نتيجة التدقيق مقابل `docs/DAILY_WORK_CENTER_RESTRUCTURE_PLAN.md`

المطابق للخطة أصلاً (تم التحقق بالكود لا بالملخصات):

- التبويبات الأربعة: اليوم / الغد / الأسبوع / التقويم — مطابقة للبند 2.
- قاعدة العرض حسب تاريخ التبويب — البند 4، مطبقة عبر `sameDay`.
- احترام الصلاحيات لكل نوع عنصر — البند 4، مطبق على الجلسات وأوامر العمل
  والمهام حسب `taskType` والنواقص.
- قسم «يحتاج انتباه» في تبويب اليوم — البند 9.
- القراءة من قاعدة البيانات الحقيقية عبر `tasksByDateProvider` و
  `uiWorkOrdersProvider` و `openDeficienciesProvider`.

#### الفجوات المكتشفة والمصلحة

كانت هناك أزرار تظهر للمستخدم كأنها فعّالة لكنها تعرض رسالة «سيتم لاحقاً»:

1. **إدخال نتيجة الجلسة** كان يعرض:
   «سيتم فتح نافذة نتيجة الجلسة التفصيلية في مرحلة مكتب العمل».
   مع أن `ResultEntryDialog` جاهز ومستخدم في الأجندة. تم ربطه فعلياً مع تمرير
   `entityId` و `entityType: 'case'` حتى تُحدَّث الجلسة والنواقص والموعد القادم.

2. **معالجة النقص** كانت تعرض:
   «سيتم تفعيل إغلاق النواقص من مكتب العمل في المرحلة التالية».
   تم بناء حوار حقيقي: «تم الاستكمال» يستدعي `resolveDeficiency`، و«تجاهل»
   يستدعي `ignoreDeficiency` مع إلزام كتابة السبب، وكلاهما يسجل في سجل
   المسؤولية ويحدّث القائمة.

3. تنظيف تحذيرَي `dead_null_aware_expression` على حقول غير قابلة للـ null.

#### ما زال مؤجلاً عن قصد

زر «تعيين / تحضير» في تبويب الغد ما زال رسالة مؤجلة، لأنه يتبع بند «المهام
المخصصة وقوالبها» (البنود 16-19) وهو مسار كامل لم يُطلب تنفيذه بعد.

### حالة التحقق بعد الدفعة 7

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (59/59)
```

### دفعة 8 — تفعيل «تعيين / تحضير» في تبويب الغد (تصحيح لقرار سابق)

#### تصحيح

في الدفعة 7 أُجّل هذا الزر بحجة أنه يتبع «المهام المخصصة وقوالبها»
(البنود 16-19). هذا التبرير كان **خاطئاً**. الزر يتبع البند 22 «الغد والتحضير»:

```text
تعيين مكلف
إضافة ملاحظة تحضير
إنشاء أمر عمل
طباعة المهمة
فتح الملف
```

ولا يعتمد على قوالب المهام إطلاقاً. كل المكونات المطلوبة كانت متوفرة أصلاً.

#### ما نُفّذ

- `TaskDao.assignTask()` — تحديث `assigned_to` و `notes`.
  استُخدم `Value.absent()` للحقول غير الممررة حتى لا يُمسح المكلف عند تحديث
  الملاحظة وحدها.
- `TaskRepository.assignTask()` — يضيف حركة `assigned` في `task_history`
  مع اسم المنفّذ.
- `_showPrepareTaskDialog` في مكتب العمل: حقل المكلف مع اقتراح أسماء فريق
  المكتب من الدليل المركزي (مع إبقاء الإدخال الحر للمعقب الخارجي)، وحقل
  ملاحظة التحضير، وتسجيل في سجل المسؤولية.
- الزر يظهر فقط لمن يملك `tasks.assign`، ويختفي للعناصر غير القابلة للتعيين
  (الجلسات وأوامر العمل لها مساراتها الخاصة) بدل أن يظهر ويعتذر.

#### اختبارات

`test/tomorrow_prepare_test.dart` — 5 اختبارات: حفظ المكلف والملاحظة، تسجيل
الحركة في تاريخ المهمة، **عدم مسح المكلف عند تحديث الملاحظة فقط**، إعادة
التعيين، وإزالة المكلف.

#### ما زال مؤجلاً من البند 22

«إنشاء أمر عمل» و«طباعة المهمة» من داخل بطاقة الغد. الطباعة موجودة على مستوى
لائحة اليوم/الغد كاملة، وإنشاء أمر العمل متاح من شاشة أوامر العمل.

### حالة التحقق بعد الدفعة 8

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (64/64)
```

### دفعة 9 — تدقيق آخر موضعين مؤجلين (اكتشاف فقدان مرفقات صامت)

#### أ. مرفقات إنشاء الدعوى كانت وهمية بالكامل

في `create_case_wizard.dart` كان زر «إضافة مرفق» ينفذ:

```dart
_attachmentPaths.add('مستند_${_attachmentPaths.length + 1}.pdf');
```

أي أنه يضيف **اسم ملف مخترع بلا أي ملف حقيقي**، ولا يفتح منتقي ملفات أصلاً.
والأخطر: `_attachmentPaths` لم تكن تُستخدم في `_save()` إطلاقاً، فالمرفقات
تختفي بصمت عند حفظ الدعوى دون أي رسالة للمستخدم.

الإصلاح:
- `_addAttachment()` صار يفتح `FilePicker` ويقبل ملفات متعددة حقيقية.
- العرض يُظهر اسم الملف بدل المسار الكامل.
- بعد `createCase` تُحفظ المرفقات فعلياً عبر `DocumentRepository.addDocument`
  (تخزين نسخة على القرص + ربط بالدعوى)، مع تخطي أي ملف غير موجود.

#### ب. رفع المستند من شاشة تفاصيل الدعوى كان يضيع أيضاً

`_pickAndAddDocument` في `case_detail_screen.dart` كان ينتقي ملفاً حقيقياً
لكنه يضيفه إلى حالة الشاشة فقط عبر `addDocument` الخاص بالـ notifier،
ويخترع مساراً وهمياً عند عدم الاختيار:

```dart
filePath: file?.path ?? 'docs/cases/manual_...pdf',
fileSize: file?.size ?? 256 * 1024,
```

فيظهر المستند في الواجهة ثم يختفي عند إعادة فتح الدعوى.

الإصلاح: الحفظ الفعلي عبر `DocumentRepository.addDocument` مع `sourceFile`،
وإلغاء العملية إذا لم يُختر ملف، وعرض الخطأ عند الفشل، وتحديث
`uiDocumentsProvider`.

#### ج. «استخدام النموذج» في النماذج القانونية

كان يعرض «سيتم تفعيل... ضمن مرحلة النماذج القانونية الكاملة».
نُفّذ الآن كنسخة عمل: يُنسخ ملف القالب إلى `templates/generated` باسم مؤرخ
ثم يُفتح بـ `OpenFilex` للتحرير في Word، مع تسجيل في سجل المسؤولية.

**النموذج الأصلي لا يُمس، ولم يُضف أي محتوى قانوني** — هذا ربط ملفات فقط،
والمكتبة القانونية تبقى مؤجلة كما هو متفق.

#### اختبارات

`test/case_attachments_test.dart` — 3 اختبارات مع `PathProviderPlatform` مزيّف:
حفظ المرفق فعلياً على القرص وربطه بالدعوى، تعدد المرفقات لنفس الدعوى،
وعدم تسرب مرفقات دعوى إلى أخرى.

### حالة التحقق بعد الدفعة 9

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (67/67)
```

### دفعة 10 — مراجعة كل التصنيفات العابرة: ملف الدعوى كان يفقد كل شيء

#### سبب المراجعة

ثلاث مرات صُنِّف موضع بأنه «مؤجل» أو «تعليق عابر» دون فتح الكود، وثلاثتها
كانت أخطاء (زر الغد، مرفقات الويزارد، رفع المستند). لذلك جرت مراجعة منهجية.

#### الاكتشاف: `CaseDetailNotifier` لا يملك أي مستودع

```dart
CaseDetailNotifier(Case? caseItem, List<DocumentItem> allDocuments)
```

يستقبل بيانات جاهزة ويعدّل `state` فقط. كل الأزرار التي تمر عبره كانت
**تعدّل الذاكرة ولا تكتب في قاعدة البيانات**، ثم تعرض رسالة نجاح كاذبة.

المواضع المصلحة في `case_detail_screen.dart`:

| الزر | ما كان يحدث | الإصلاح |
|---|---|---|
| إضافة جلسة | تُضاف للذاكرة فقط | `caseRepository.addSession` (يولّد مهمة الموعد القادم ويغلق نقص `next_session_date`) |
| ربط عالمي | **يخترع مستنداً وهمياً** `linked_document.pdf` بحجم 384KB | منتقي مستندات حقيقي من الأرشيف + `linkExistingDocument` |
| حذف ربط مستند | يُحذف من الذاكرة | `unlinkDocument` (يفك الربط ويُبقي المستند في الأرشيف) |
| إضافة نقص | يُضاف للذاكرة | `taskRepository.addManualDeficiency` فيظهر في مكتب العمل والتقارير |
| نقل مرحلة | كائن `CasePhase` في الذاكرة | `transferToNextPhase` + اختيار محكمة حقيقية بدل حقل نصي |
| **إنهاء الدعوى** | يسجّل في سجل المسؤولية «تم الإنهاء» بينما الدعوى تبقى مفتوحة | `caseRepository.terminateCase` |

#### ثغرة إضافية في `CaseRepository.terminateCase`

كان يغلق الدعوى ونواقصها لكنه **لا يغلق ملف المكتب المرتبط**، فتبقى الدعوى
تظهر «جارية» في شاشة الملفات بعد إنهائها. أُضيف إغلاق `OfficeFile` ضمن
نفس المعاملة مع سبب الإغلاق والملخص.

#### دوال أُضيفت للطبقة السفلى

- `DocumentDao.unlinkDocument` و `DocumentRepository.linkExistingDocument` / `unlinkDocument`.
- `TaskRepository.addManualDeficiency`.

كانت `insertDeficiency` و `deleteDocument` موجودة في الـ DAO لكن غير مكشوفة.

#### اختبارات

`test/case_detail_persistence_test.dart` — 5 اختبارات: حفظ الجلسة، حفظ النقص
اليدوي، الربط وفك الربط دون حذف المستند، **إنهاء الدعوى يغلق الدعوى والنواقص
وملف المكتب معاً**، ونقل المرحلة.

#### قاعدة للمساعد التالي

`CaseDetailNotifier` للعرض فقط. أي إجراء يغيّر بيانات يجب أن يمر على المستودع
ثم `ref.invalidate` للمزودات المتأثرة. لا تكتفِ بتعديل `state`.

### حالة التحقق بعد الدفعة 10

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (72/72)
```

### دفعة 11 — مسح شامل لبقية الشاشات بنفس منهج الدفعة 10

#### المنهج

بعد اكتشاف نمط «notifier بلا مستودع» في ملف الدعوى، جرى مسح كل المشروع
بحثاً عن أي استدعاء كتابة يمر عبر notifier:

```bash
grep -rn "\.notifier)\.add\|\.notifier)\.delete\|\.notifier)\.link\|..."
```

#### النتيجة: 13 موضعاً، منها 8 كانت تضيع

**سليمة أصلاً** (تحفظ فعلاً): `FinanceNotifier` (اتفاق/دفعة/مصروف)،
`toggleFavorite` في المكتبة، إعدادات المكتب والأمان، وفلاتر البحث
(حالة عرض لا بيانات).

**كانت تضيع، وأُصلحت:**

| الموضع | الزر | الإصلاح |
|---|---|---|
| `person_detail_screen` | ربط وكالة بدعوى | `poaRepository.linkPoaToCase` + اختيار دعوى حقيقية بدل رقم نصي حر |
| `person_detail_screen` | ملاحظة على الخط الزمني | `personRepository.addTimelineNote` الجديدة |
| `poa_detail_screen` | ربط وكالة بدعوى | نفس الإصلاح مع قائمة دعاوى |
| `legal_library_models` | إضافة عنصر | `repo.addItem` |
| `legal_library_models` | تعليم كمبدأ | `repo.setPrinciple` |
| `legal_library_models` | ربط بكيان | `repo.linkToEntity` + محوّل `_entityTypeIndex` |
| `legal_library_models` | حذف ربط | `repo.removeLink` |
| `settings_models` | إضافة محكمة | `repo.addCourt` + `_reloadCourts` |

ملاحظة على المكتبة القانونية: هذا **ربط تقني بحت للأزرار بقاعدة البيانات**،
ولم يُضف أي محتوى قانوني، والمحتوى يبقى مؤجلاً كما هو متفق.

#### دوال أُضيفت

- `PersonRepository.addTimelineNote` — ملاحظة متابعة في `timeline_events`.
- `SettingsHubNotifier._reloadCourts` — إعادة قراءة المحاكم بعد التعديل.

#### حقول نصية حرة استُبدلت بقوائم حقيقية

«رقم الدعوى» في ربط الوكالة (موضعان) كان حقلاً نصياً حراً قد لا يقابل أي دعوى
موجودة. صار `DropdownButtonFormField` يقرأ من `allCasesProvider`.

#### اختبارات

- `test/persons_poa_persistence_test.dart` — 4 اختبارات: ربط الوكالة بدعوى،
  ربطها بعدة دعاوى، حفظ ملاحظة الخط الزمني، وعدم تسرب الملاحظات بين الأشخاص.
- `test/library_courts_persistence_test.dart` — 4 اختبارات: حفظ عنصر المكتبة،
  بقاء علامة المبدأ، الربط وفك الربط دون حذف العنصر، والمحكمة المضافة تصبح
  قابلة للاستخدام فعلياً في الدعاوى.

#### ما بقي في الذاكرة عن قصد

`updateCourt` و `deleteCourt` و `deleteLookup` و `setCourtActive` و
`markAsPrinciple` للقوائم المرجعية: لا توجد لها دوال في `SettingsRepository`
(المتوفر `addCourt` فقط)، وإضافتها تتطلب توسيع الـ DAO. مسجّلة كعمل قادم
ولم تُعلن مكتملة.

### حالة التحقق بعد الدفعة 11

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (80/80)
```

### دفعة 12 — مسح شامل بالأنماط: بيانات مُصطنعة في شاشات حقيقية

#### المنهج

بدل فحص شاشة شاشة، جرى البحث عن **أنماط الخلل** نفسها في كل المشروع:

```text
1. setState وحده داخل زر حفظ            => نظيف
2. catch فارغة تبتلع الأخطاء            => 4 مواضع، كلها في مسارات غير حرجة
3. DATE() على أعمدة تاريخ               => نظيف (تعليقات فقط)
4. strftime / julianday                 => غير مستخدمة
5. أحجام ومسارات ملفات مخترعة           => 3 مواضع (مخالفة)
6. أسماء أشخاص ثابتة في شاشات الإنتاج   => 3 مواضع (مخالفة)
```

#### المخالفات المكتشفة والمصلحة

**أ. اسم الطرف كان يظهر رقماً**

في `CaseDetailNotifier.fromRepository`:

```dart
name: p.personId.toString(),   // يعرض "7" بدل "أحمد الخطيب"
phone: '', address: '',
```

الأطراف تُقرأ الآن من `allPersonsProvider` عبر خريطة `personById`، مع الاسم
والهاتف والعنوان الحقيقية.

**ب. قوائم ثابتة في معالج إنشاء الدعوى**

- `_buildOpponentList` كانت `{'id': 1, 'name': 'محمد أحمد'}` … والمعرّف يُحفظ
  فعلياً كـ `opponentId`، أي **ربط الدعوى بشخص خاطئ في قاعدة البيانات**.
- `_buildPoaList` كانت `POA-2026-001` … والمعرّف يُحفظ كـ `poaId` لسند توكيل
  قد لا يكون موجوداً أصلاً.

كلاهما يقرأ الآن من `allPersonsProvider` و `allPoasProvider` (مزوّد جديد)،
مع رسالة واضحة عند فراغ الدليل بدل عرض أسماء وهمية.

**ج. مستندات مُصطنعة عن معرّفات**

`cases_screen` و `case_detail_screen` و `files_screen` كانت تولّد لكل معرّف
مستند بيانات مخترعة: `fileSize: 512 * 1024` و `filePath: 'docs/cases/...'`
و `uploadedBy: 'هادي البني'`. صارت تقرأ المستند الحقيقي من `uiDocumentsProvider`،
وفي `files_screen` يُعرض المستند المفقود صراحة كـ «مستند غير موجود» بحجم صفر
بدل اختلاق بياناته.

#### اختبار حارس دائم

`test/no_fabricated_data_test.dart` — 4 اختبارات تفحص **الشيفرة نفسها** لا
سلوك التطبيق، فتمنع عودة النمط:

- لا قوائم خصوم/وكالات ثابتة، والمصادر الحقيقية مستخدمة.
- لا `fileSize: 512 * 1024` ولا مسارات `docs/cases/` مخترعة.
- اسم الطرف يأتي من دليل الأشخاص لا من `personId.toString()`.
- لا `DATE()` على أعمدة التاريخ في أي ملف (يتجاهل التعليقات).

#### ملاحظة على البيانات التجريبية المشروعة

`_seedState()` في المكتبة والمالية والأشخاص يبقى كما هو: يُستدعى فقط عند غياب
المستودع (اختبارات)، ولا يظهر في الإنتاج.

### حالة التحقق بعد الدفعة 12

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (84/84)
```

### دفعة 13 — استكمال القوائم المرجعية (المتبقي من الدفعة 11)

#### أ. اكتشاف مهم: build_runner يعمل فعلاً

الـhandoff كان ينص على أن `build_runner` غير متاح، ولهذا بقيت جداول
`office_files` وغيرها SQL-managed. تم التحقق عملياً:

```text
dart run build_runner build --delete-conflicting-outputs
=> Built with build_runner/aot in 120s; wrote 279 outputs
```

يعني يمكن للمساعد التالي تعديل `schema.dart` وإعادة التوليد بأمان،
ولا داعي للالتفاف بـ SQL يدوي بعد الآن.

#### ب. عمليات المحاكم

أُضيفت إلى `SettingsDao` و `SettingsRepository`:

- `getAllCourtsIncludingInactive()`
- `updateCourt()` و `setCourtActive()`
- `countCasesUsingCourt()` و `deleteCourt()`

**حماية مرجعية:** حذف محكمة مرتبطة بدعاوى مرفوض، وتُعاد رسالة توضح العدد
وتقترح التعطيل بدل الحذف. الشاشة تعرض السبب بدل ابتلاعه.

**خلل جانبي أُصلح:** `_loadFromDb` و `_reloadCourts` كانتا تستخدمان
`getCourts()` التي تُرجع الفعّالة فقط، فأي محكمة تُعطَّل كانت تختفي من شاشة
القوائم المرجعية ولا يمكن إعادة تفعيلها. صارتا تستخدمان النسخة الشاملة،
بينما يبقى `getCourts()` للفعّالة فقط عند إنشاء الدعاوى.

#### ج. القوائم المرجعية

كانت ثابتة في الكود بلا تخزين إطلاقاً (لا DB ولا prefs)، فكل إضافة أو حذف
أو تعطيل يجريه المكتب يختفي عند إعادة التشغيل.

تُحفظ الآن كـ JSON في `app_settings` تحت `reference_lookups_json` عبر
`_persistLookups()`، وتُقرأ في `bootstrapDb()` عبر `_loadLookups()`،
مع البقاء على القوائم الافتراضية إن لم يوجد محفوظ أو فسدت البيانات.
أُضيفت `SettingsRepository.getSetting()` التي لم تكن مكشوفة.

#### اختبارات

- `test/courts_reference_test.dart` — 6 اختبارات: التعديل، التعطيل والإخفاء من
  القائمة الفعّالة مع بقائه مخزّناً، إعادة التفعيل، حذف غير المستخدمة،
  **رفض حذف محكمة مرتبطة بدعوى**، وتسجيل العمليات في سجل النشاط.
- `test/lookups_persistence_test.dart` — 4 اختبارات: دورة حفظ/قراءة، انعكاس
  الحذف، بقاء علامة التعطيل، وعدم الانهيار عند غياب الإعداد.

### حالة التحقق بعد الدفعة 13

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (94/94)
```

### دفعة 14 — تدقيق مقابل خارطة التنفيذ النهائية (لا مقابل قائمة الـhandoff)

#### سبب المراجعة

كل الدفعات السابقة عالجت البنود السبعة في قسم «ما لم يثبت بعد» من هذا الملف.
لكن المرجع الفعلي هو `docs/FINAL_IMPLEMENTATION_ROADMAP.md` وفيه **17 مرحلة**.
عند مقارنة المراحل بالكود ظهرت فجوات لم تكن مذكورة في قائمة الـhandoff.

#### المرحلة الرابعة — الإغلاق الإداري

الخطة تحدد 9 خطوات وأسباب إغلاق صريحة لكل نوع ملف. الموجود كان حواراً مبسطاً:
حقل سبب نصي حر + ملخص + ثلاثة مربعات اختيار يدوية، بلا فحص ولا تسجيل.

ما أُضيف:

- `kClosureReasonsByType` — أسباب معتمدة لكل نوع حرفياً كما في الخطة
  (دعوى: حكم قطعي/صلح/إسقاط/اعتزال/عزل/عدم متابعة، وهكذا للإجراء والعقد
  والشركة والوكالة)، مع خيار «سبب آخر» للحالات الاستثنائية.
- `_buildPreCloseChecks()` — فحص تلقائي قبل الإغلاق يعرض: أتعاب غير مقبوضة،
  أوامر عمل مفتوحة، مستندات/أصول ورقية ناقصة، ونواقص مفتوحة. هذا ينفذ
  الخطوات 3-6 التي كانت متروكة لتقدير المستخدم.
- تسجيل `audit` بمستوى `critical` عند الإغلاق (الخطوة 9) مع اسم من أغلق،
  و`ref.invalidate(uiFilesProvider)` لتحديث الشاشة فوراً.

#### المرحلة الرابعة عشرة — التقارير

الخطة تطلب 9 تقارير. الموجود كان 7، وأربعة منها خارج قائمة الخطة.
الناقص فعلياً: قائمة ملفات جارية، قائمة ملفات منتهية، تقرير أرشيف قديم.

ما أُضيف:

- `ReportKind.activeFiles` و `closedFiles` و `archiveQuality`.
- `officeFilesReportProvider` يقرأ من `office_files` الحقيقي ويحسب
  «ملاحظات الجودة» من المؤشرات (مالية معلقة، أصل ورقي ناقص، إجراءات لاحقة،
  ملف بلا عنوان).
- تقرير الملفات المنتهية يعرض سبب الإغلاق وتاريخه فعلياً.

#### اختبارات

`test/closure_and_file_reports_test.dart` — 6 اختبارات: وجود أسباب إغلاق لكل
نوع ملف، فصل الجارية عن المنتهية، عرض سبب/تاريخ الإغلاق، عزل الأرشيف القديم
مع رصد فجوات الجودة، إنتاج كل أنواع التقارير لعناوين صحيحة، وأن قاعدة فارغة
تعطي تقارير فارغة لا صفوفاً مخترعة.

#### ملاحظة منهجية للمساعد التالي

لا تعتمد قائمة «ما لم يثبت بعد» في هذا الملف كمرجع وحيد. المرجع هو
`FINAL_IMPLEMENTATION_ROADMAP.md` بمراحله الـ17، ويجب فحص كل مرحلة بالكود.

### حالة التحقق بعد الدفعة 14

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (100/100)
```

### دفعة 15 — المرحلة الثامنة: حقول الأصل الورقي الناقصة

#### الفجوة

الخطة تنص صراحة على حقول للأصل الورقي، وجدول `document_paper_metadata`
كان يغطي بعضها فقط. المفقود:

```text
مع الموكل؟
مبرز في المحكمة؟
نسخة رقمية فقط؟
محضر تسليم/استلام
```

#### ما نُفّذ

- أعمدة جديدة عبر `_ensureSqlColumn` (متوافق مع القرار التقني في الخطة
  بإبقاء الجدول SQL-managed): `with_client` و `court_exhibit` و
  `digital_only` و `handover_reference`.
- `DocumentRepository.addDocument` صار يستقبلها ويخزّنها.

#### تصحيح منطقي مهم

كان مؤشر «أصل ورقي معلق» يُحسب هكذا:

```dart
hasPendingPaperOriginal: !paperOriginalSaved
```

أي أن أي مستند بلا أصل محفوظ يُعدّ نقصاً، حتى لو كان:

- مبرزاً لدى المحكمة (وهذا وضع قانوني سليم)،
- أو بيد الموكل بمحضر تسليم،
- أو بلا أصل ورقي أصلاً (مراسلة إلكترونية).

صار الأصل يُعد معلقاً فقط عند غياب كل هذه الاستثناءات، فلا تظهر إنذارات
كاذبة على ملفات سليمة.

#### اختبارات

`test/paper_originals_test.dart` — 4 اختبارات: تخزين كل الحقول المطلوبة،
المستند الرقمي البحت لا يُعد نقصاً، غياب الأصل بلا استثناء يرفع المؤشر،
والأصل المبرز لدى المحكمة يُنزل المؤشر.

### حالة التحقق بعد الدفعة 15

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (104/104)
```

### دفعة 16 — المرحلة التاسعة: المؤشرات المالية وحماية الإغلاق

#### الفجوة

الخطة تنص على ستة مؤشرات مالية تظهر في شاشة الملفات، وعلى منع إغلاق ملف
عليه مالية مفتوحة إلا بتأكيد وصلاحية. لم يكن أي منهما موجوداً:
شاشة الملفات لا تعرض أي حالة مالية، والإغلاق يمر دون أي فحص مالي.

#### ما نُفّذ

**`FileFinanceStatus`** بالمؤشرات الستة حرفياً كما في الخطة:
لا مالية / أتعاب مفتوحة / مدفوع جزئياً / مدفوع بالكامل / مصاريف غير مسددة /
مالية تحتاج مراجعة. ولكل حالة `blocksClosure`.

**الحساب من بيانات حقيقية** في `uiFilesProvider`: تُقرأ الاتفاقيات والدفعات
والمصاريف مرة واحدة، ويُحسب المؤشر لكل ملف حسب كيانه المرتبط.
حالة `needsReview` ترصد الخلل: دفعات تتجاوز الاتفاق أو مبالغ سالبة.

**الحماية عند الإغلاق**: إن كان المؤشر مانعاً، يظهر تنبيه بالحالة المالية
ومربع تأكيد صريح. التأكيد متاح فقط لمن يملك `cases.close` **و** `finance.view`
معاً (والمالك دائماً)، وغيرهم يرى سبب المنع. التجاوز يُسجَّل في الـaudit
ضمن `financeOverride` و `financeStatus`.

**العرض**: بطاقة الملف تعرض المؤشر المالي بلون مميز.

#### اختبارات

`test/file_finance_status_test.dart` — 4 اختبارات: وجود المؤشرات الستة،
أن الحالات غير المسددة وحدها تمنع الإغلاق بينما «مدفوع بالكامل» لا يمنع،
والقيمة الافتراضية، وحمل المؤشر على الملف.

### حالة التحقق بعد الدفعة 16

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (108/108)
```

### دفعة 17 — ثلاثة أعطال رصدها المستخدم أثناء التشغيل الفعلي

#### 1) أنواع الوكالات لا تطابق الخطة

`FINAL_REFERENCE_LOOKUPS_PLAN.md` البند 56 يحدد: «سند توكيل عام / خاص /
خاص شرعي». الكود كان يكتب «وكالة عامة / خاصة»، وبتسميتين مختلفتين في
`PoaType` و `AgencyType`. كما كانت البنود 57 و58 غائبة كلياً.

أُضيف:
- تصحيح تسميات `PoaType` و `AgencyType.displayName`.
- `PoaUsage` — التصديقات الستة (صلحية، بدائية، جنائية، تنفيذية، شرعية، إدارية).
- `PoaStatus` — الحالات الإحدى عشرة، مع `isUsable` لتمييز الوكالة الصالحة
  للاستعمال عن المعزول عنها/المنتهية/الملغاة.

#### 2) زر «إضافة وكالة جديدة» في ويزارد الدعوى كان ميتاً

`_submitPoa` كان جسم `try` فيها **فارغاً تماماً**: تعرض «تم إضافة الوكالة»
ثم تغلق الحوار دون إنشاء أي سجل. وكان الحوار بلا حقل «الموكل» أصلاً، بينما
الشرط `_selectedClientId == null` يُنهي الدالة بصمت، فالزر لا يعمل إطلاقاً.

أُصلح:
- حقل الموكل من `allPersonsProvider`.
- قائمة النوع من `PoaType` وقائمة الاستعمال من `PoaUsage`.
- حفظ حقيقي عبر `poaRepository.createPoa` (يولّد رقم ملف مكتب `وكالة/سنة/تسلسل`).
- `ref.invalidate` للمزودات فتظهر الوكالة فوراً في قائمة الاختيار.
- رسالة خطأ واضحة بدل الصمت.

#### 3) حفظ دعوى في «الأرشيف الجاري» لا يتم

`_validateCurrentStep` الخطوة 7 تشترط تحديد موعد جلسة قادمة، مع استثناء
للأرشيف **المنتهي** فقط. أما الأرشيف **الجاري** فكان يُحبس، مع أن الدعوى
القديمة المستوردة قد لا يكون لها موعد محدد بعد.

صار الأرشيف الجاري يُقبل بلا موعد، و`DeficiencyService` يرصد
`next_session_date` تلقائياً فيظهر الملف في «يحتاج استكمال» بدل أن يتعذر حفظه.

#### اختبارات

`test/poa_types_and_wizard_test.dart` — 6 اختبارات: مطابقة التسميات للخطة،
اكتمال التصديقات الستة والحالات الإحدى عشرة، رفض الوكالة المعزول عنها
للاستعمال، حفظ الوكالة فعلياً مع رقم ملف مكتب، وقبول دعوى الأرشيف الجاري
بلا موعد.

### حالة التحقق بعد الدفعة 17

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (114/114)
```

### دفعة 18 — إكمال المراحل 6 و10 و13 و17 من خارطة التنفيذ

#### المرحلة السادسة — أوامر العمل

الأتمتة بعد الاعتماد كانت مكتملة فعلاً (مهمة متابعة عند `nextDate`، مصروف
عند نتيجة مالية، إغلاق النقص، Timeline/Audit) وكذلك سلوك واتساب.
الناقص الوحيد: **الربط المباشر بملف المكتب**.

أُضيف عمود `office_files.id` على `work_orders` عبر `officeFileId` في السكيما،
ويُملأ تلقائياً عند الإنشاء من ملف المكتب المرتبط بالكيان، مع بقاء الربط
بالكيان التفصيلي. أمر عمل بلا ملف مكتب يبقى صالحاً (`null`).

#### المرحلة العاشرة — تعارض المصالح

كانت غائبة كلياً (صفر نتائج بحث). أُضيف
`lib/data/services/conflict_of_interest_service.dart` بالحالات الثلاث
المنصوص عليها:

1. شخص كان خصماً في ملف سابق ويُسند الآن كموكل (والعكس) — تنبيه عالٍ.
2. وكالة معزول عنها/منتهية ما زالت مرتبطة بملف جارٍ — تنبيه عالٍ.
3. صفة متضاربة لنفس الشخص عبر الملفات (موكل وخصم معاً) — تنبيه متوسط.

يظهر كبانر في ويزارد الدعوى عند اختيار الموكل والخصم، مع ذكر أرقام الملفات
المرتبطة. **تنبيه لا منع**، حسب نص الخطة صراحة.

#### المرحلة الثالثة عشرة — النماذج

أُضيف `templateSource` (`ready` / `imported` / `generated`) و
`sourceOfficeFileId` إلى `ContractTemplates`. الاستيراد يسجّل `imported`،
والبطاقة تعرض المصدر. لم يُعالَج أي محتوى قانوني.

#### المرحلة السابعة عشرة — تنظيف الجودة

**`super.dispose()` كانت معطّلة في 21 ملفاً** — تسريب ذاكرة حقيقي في كل شاشة
تقريباً، إضافة إلى عشرات `controller.dispose()` المعلّقة.

أُعيد تفعيلها جميعاً. الأسماء الحقيقية مسبوقة بشرطة سفلية، فجرى التصحيح
بالاعتماد على مخرجات المحلل نفسه، وحُذفت الأسطر التي تشير إلى حقول غير
موجودة (بقايا نسخ من حوارات أخرى) بدل تخمينها.

#### اختبارات

- `test/roadmap_stages_6_10_13_17_test.dart` — 9 اختبارات: ربط أمر العمل
  بملف المكتب وبقاؤه صالحاً بدونه، حالات تعارض المصالح الأربع، الشخص النظيف
  بلا تنبيهات، ومصادر النماذج.
- `test/code_quality_guard_test.dart` — 3 حراس دائمة: لا `dispose` معلّقة،
  كل `dispose` تستدعي `super.dispose()`، ولا `print/debugPrint` في الإنتاج.

### حالة التحقق بعد الدفعة 18

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (126/126)
```

بهذا تكون مراحل خارطة التنفيذ الـ17 قد فُحصت بالكود جميعاً، عدا المؤجلات
المعلنة (المكتبة القانونية، الترخيص التجاري، الشبكة الداخلية، التصميم النهائي).

### دفعة 19 — إغلاق ملف المكتب لكل الأنواع لا الدعوى وحدها

#### الفجوة

المرحلة الرابعة تنص على أن الإغلاق يشمل الأنواع الخمسة: دعوى، إجراء، عقد،
شركة، وكالة. عند الفحص:

```text
case_repository.terminateCase      => يغلق OfficeFile  (أُصلح في الدفعة 10)
contract_repository                => لا يوجد إغلاق
company_repository                 => لا يوجد إغلاق
admin_procedure_repository         => لا يوجد إغلاق
poa_repository                     => لا يوجد إغلاق
```

النتيجة: عقد منتهٍ أو شركة انحلّت أو وكالة معزول عنها كانت تبقى «جارية» في
شاشة ملفات المكتب، وتُحتسب ضمن العمل القائم.

#### ما نُفّذ

أُضيفت `closeOfficeFileForEntity()` إلى المستودعات الأربعة، بنفس التوقيع:
سبب الإغلاق، الملخص، منفّذ الإغلاق، ومؤشرات المالية/الأصل الورقي/الإجراءات
اللاحقة.

خصائص مقصودة:

- **آمنة للتكرار**: إن كان الملف مغلقاً أصلاً تعود دون تعديل، فلا يُعاد كتابة
  سبب الإغلاق الأصلي.
- **لا تنهار** إن لم يوجد ملف مكتب مرتبط (كيان قديم قبل اعتماد OfficeFiles).
- **تحفظ المؤشرات المعلقة** كما هي عند الإغلاق.

ملاحظة: حوار الإغلاق في شاشة الملفات كان يغلق أي نوع بالفعل عبر
`getByLinkedEntity`. الدوال الجديدة تغطي الاستدعاء البرمجي من داخل
المستودعات (مثل إنهاء عقد أو حلّ شركة من شاشتها).

#### اختبارات

`test/all_entities_closure_test.dart` — 7 اختبارات: إغلاق العقد والشركة
والإجراء والوكالة، أمان الإغلاق المتكرر، عدم الانهيار بلا ملف مكتب،
وحفظ المؤشرات المعلقة.

### حالة التحقق بعد الدفعة 19

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (133/133)
```

### دفعة 20 — هيكل الوكالة الصحيح وحذف «نقض إداري»

بلاغات من الاختبار الفعلي، وجميعها كانت **موجودة في الخطة** ولم تُنفَّذ.

#### 1) «نقض إداري» غير موجود في القانون السوري

في `archive_intake_screen.dart` كانت قائمة المحاكم الإدارية تتضمن
«نقض إداري». المحكمة الإدارية العليا هي أعلى درجة في القضاء الإداري.
حُذف البند.

#### 2) هيكل الوكالة كان مسطّحاً ومخالفاً للخطة

`AGENCY_FILE_WORKFLOW_PLAN.md` البندان 3 و7 يحددان بنية هرمية:
تصنيف رئيسي ← تصنيف فرعي مختلف لكل نوع. الكود كان يعرض قائمة واحدة
مسطّحة من ثلاثة سندات فقط، ويخلط القضائية بالعدلية.

**البنية المعتمدة الآن** (`PoaCategory`):

```text
وكالة قضائية  => سند توكيل عام / خاص / خاص شرعي
وكالة عدلية   => وكالة عامة / خاصة / إدارية
وكالة خارجية / تفويض-تكليف / تصنيف آخر
```

مع «إضافة نوع جديد» في كل تصنيف.

**حقول التنظيم** أُضيفت إلى `PowersOfAttorney` (البند 7):

- `category` و `subType`
- `registryNumber` و `whiteNumber` — رقم الوكالة خانتان: سجل / أبيض
- `delegateName` و `delegatePhone` — مندوب رئيس فرع النقابة وهاتفه

`SyrianProvinces` — المحافظات الأربع عشرة كقائمة فروع النقابة.

**السلوك الشرطي**: بيانات فرع النقابة والمندوب تظهر للوكالة القضائية فقط
(`requiresBarBranch`)، واسم المندوب وهاتفه يظهران بعد اختيار الفرع.
والاستعمال/التصديق (صلحية، بدائية...) للقضائية فقط.
`sourceType` يُضبط تلقائياً: `delegate` للقضائية و`notary` للعدلية.

**رقم الوكالة**: يكفي أحد الرقمين (السجل أو الأبيض) لأن بعض الوكالات
تُسجَّل بالأبيض فقط.

#### ملاحظة تنفيذية

أُعيد بناء `AddPoaDialog` كاملاً بدل التعديل الجزئي، بعد أن تسبب استبدال
جزئي في ابتلاع نهاية الحوار وبداية `AddClientDialog`. تم اكتشاف ذلك
بالمحلل قبل الرفع، واستُرجع الملف من git ثم أُعيد البناء ضمن حدود الصنف.

#### اختبارات

`test/poa_structure_test.dart` — 8 اختبارات: التصنيفات الرئيسية، تصنيفات
القضائية والعدلية وعدم تداخلها، اشتراط فرع النقابة للقضائية فقط، المحافظات
الأربع عشرة، حفظ كل حقول التنظيم، حفظ العدلية بلا بيانات فرع،
وخلوّ قائمة المحاكم من «نقض إداري».

### حالة التحقق بعد الدفعة 20

```text
flutter analyze  =>  0 errors
flutter test     =>  All tests passed! (141/141)
```
