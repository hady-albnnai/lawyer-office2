# ملخص تسليم للمحادثة القادمة — مشروع «ميزان»

تاريخ التلخيص: 2026-07-21  
المستودع: `https://github.com/hady-albnnai/lawyer-office`  
المسار المحلي في بيئة العمل: `/home/user/lawyer-office`  
الفرع المعتمد: `main`

---

## 1. حالة Git والمستودع الحالية

الحالة المعتمدة بعد التحقق:

```text
local main = origin/main = 5403c7c
```

آخر commits مهمة:

```text
5403c7c docs(plan): audit roadmap coverage against partial plans
5ba7af7 docs(plan): add final restructuring implementation roadmap
0fbc417 docs(plan): reassess technical requirements after branch unification
e722ee6 docs(status): record current project progress
d35d7d7 feat(legal-library): load real Syrian legal files from content/ (last core point)
```

الفرع الوحيد على GitHub:

```text
refs/heads/main
```

تمت ملاحظة أن بيئة العمل أحياناً تعود لحالة محلية قديمة/متسخة بسبب snapshots، لذلك في بداية المحادثة القادمة يجب تنفيذ:

```bash
cd /home/user/lawyer-office
git remote add origin https://github.com/hady-albnnai/lawyer-office.git 2>/dev/null || git remote set-url origin https://github.com/hady-albnnai/lawyer-office.git
git fetch origin --prune
git status --short
git log --oneline -5
```

إذا كانت الحالة ليست على `5403c7c` أو أعلى، يجب عدم البرمجة قبل إعادة الضبط إلى `origin/main` بعد حفظ أي تغييرات محلية غير مقصودة في stash.

يوجد stash احتياطي حديث من حالة محلية قديمة غير معتمدة:

```text
stash@{0}: pre-handoff-local-stale-state-2026-07-21
```

وقبله stashes محتملة من مراحل سابقة. لا تطبق أي stash إلا لسبب واضح، لأن بعضها يحتوي تعديلات محتوى مكتبة قانونية مؤجلة أو حالة محلية قديمة.

---

## 2. قرارات المستخدم المهمة

- المستخدم يريد تطبيق «صنديد»: قوي، عملي، خاص بمكتب محاماة سوري، وليس CRUD عام.
- المستخدم يريد نقاش عميق قبل البرمجة، وخصوصاً قبل أي شاشة أو مرحلة.
- لا تغيير أي شيء خارج المطلوب.
- لا تنفيذ جزئي للميزات الكبيرة.
- لا إعلان إنجاز إلا بعد كود + توثيق + commit + push + تحقق قدر الإمكان.
- Flutter/Dart غير مثبتين في بيئة المساعد؛ المستخدم يشغل البناء على Windows ويرسل الأخطاء.
- كل بيانات التطبيق الحالية تجريبية، ولا مشكلة بحذفها/عمل Reset لها أثناء إعادة الهيكلة.
- محتوى المكتبة القانونية مؤجل بالكامل حالياً، وسيعود المستخدم لتنقيحه لاحقاً بعد اكتمال البرمجة الأساسية.
- لا حذف للدستور أو أي محتوى قانوني الآن؛ أمر الحذف السابق تم تجاوزه.
- التصميم الشكلي النهائي للواجهات مؤجل لما بعد اكتمال البرمجة الأساسية.
- المستودع يجب أن يبقى فرعاً واحداً: `main`.

---

## 3. ما تم إنجازه تخطيطياً

تمت كتابة واعتماد خطط تفصيلية كثيرة، أهمها:

### ملفات المكتب والدعاوى

```text
docs/ACTIVE_CASE_WORKSPACE_PLAN.md
docs/NEW_CASE_FOLLOWUP_WIZARD_PLAN.md
docs/OLD_CASE_ARCHIVE_WIZARD_PLAN.md
docs/OFFICE_FILES_ACTIVE_CLOSED_SCREEN_PLAN.md
docs/OFFICE_FILE_NUMBERING_AND_LINKING_RULES.md
docs/SYRIAN_LAW_OFFICE_SUPPORTING_RULES.md
```

### الإجراءات والعقود والشركات والوكالات

```text
docs/ADMIN_PROCEDURE_FILE_WORKFLOW_PLAN.md
docs/CONTRACT_FILE_WORKFLOW_PLAN.md
docs/COMPANY_FILE_WORKFLOW_PLAN.md
docs/AGENCY_FILE_WORKFLOW_PLAN.md
```

### مركز العمل

```text
docs/DEFAULT_ROLES_AND_WORK_ASSIGNMENT_PLAN.md
docs/TOMORROW_WORK_SCREEN_PLAN.md
docs/TODAY_WORK_SCREEN_PLAN.md
docs/WORK_ORDER_LIFECYCLE_PLAN.md
docs/WORK_CALENDAR_SCREEN_PLAN.md
docs/NEW_WORK_CREATION_SCREEN_PLAN.md
```

### المالية والمستندات والقوائم والتقارير

```text
docs/FINANCE_CASHBOX_WORKFLOW_PLAN.md
docs/DOCUMENTS_AND_PAPER_ORIGINALS_PLAN.md
docs/FINAL_REFERENCE_LOOKUPS_PLAN.md
docs/REPORTS_AND_EXPORTS_PLAN.md
```

### النماذج والمكتبة والصلاحيات والتجاري والشبكة

```text
docs/LEGAL_TEMPLATES_USAGE_PLAN.md
docs/LEGAL_LIBRARY_PLAN.md
docs/LEGAL_CONTENT_COLLECTION_TASKS.md
docs/FINAL_PERMISSIONS_AND_ROLE_HIERARCHY_PLAN.md
docs/COMMERCIAL_LICENSING_AND_ACTIVATION_PLAN.md
docs/INTERNAL_NETWORK_DEPLOYMENT_PLAN.md
```

### تقارير الحالة النهائية قبل التنفيذ

```text
docs/CURRENT_PROJECT_STATUS_AND_NEXT_STEPS.md
docs/UPDATED_TECHNICAL_UPDATE_REQUIREMENTS.md
docs/FINAL_IMPLEMENTATION_ROADMAP.md
docs/FINAL_ROADMAP_COVERAGE_AUDIT.md
```

أهم وثيقتين يجب قراءتهما قبل بدء التنفيذ:

```text
docs/FINAL_IMPLEMENTATION_ROADMAP.md
docs/FINAL_ROADMAP_COVERAGE_AUDIT.md
```

---

## 4. النتيجة النهائية للتدقيق

تم تدقيق خارطة التنفيذ النهائية مقابل الخطط الجزئية. النتيجة:

```text
الخطة النهائية الآن شاملة لكامل نطاق إعادة الهيكلة المتفق عليه.
```

أثناء التدقيق أضيف قسم جديد إلى `FINAL_IMPLEMENTATION_ROADMAP.md`:

```text
26. استدراكات تدقيق المطابقة مع الخطط الجزئية
```

كما أضيف تقرير مستقل:

```text
docs/FINAL_ROADMAP_COVERAGE_AUDIT.md
```

هذا التقرير يطابق كل خطة جزئية مع مكان تغطيتها في الخارطة النهائية.

---

## 5. قلب النسخة الجديدة المتفق عليه

النسخة الجديدة يجب أن تتمحور حول:

```text
OfficeFiles + OfficeFileSequences
```

أي:

- جدول موحد لكل ملفات المكتب.
- ترقيم داخلي عربي حسب نوع الملف.
- ربط كل دعوى/إجراء/عقد/شركة/وكالة بهذا الملف الموحد.

### صيغ أرقام الملفات المعتمدة

```text
دعوى/2026/0001
إجراء/2026/0001
عقد/2026/0001
شركة/2026/0001
وكالة/2026/0001
```

### قواعد الرقم

- يولد تلقائياً.
- لا يعدل بعد الحفظ حتى للمالك.
- منفصل عن رقم أساس الدعوى أو رقم المعاملة أو رقم السجل أو رقم سند الوكالة.
- يولد داخل Transaction.

---

## 6. الفصل الوظيفي الأساسي

يجب أن يميز التطبيق بين:

```text
العمل الجديد بعد نزول التطبيق
الأرشيف القديم
الملفات الجارية
الملفات المنتهية
```

القواعد:

- إنشاء جديد فقط من مكتب العمل.
- إدخال الأرشيف القديم فقط من شاشة إدخال الأرشيف القديم.
- الملفات الجارية والمنتهية للبحث والفتح والتعديل/الطباعة حسب الصلاحية، وليست لإنشاء جديد.
- الأرشيف القديم مصدر إدخال، وليس حالة عادية للملف.

---

## 7. نطاق إعادة الهيكلة المشمول

الخطة النهائية تشمل:

1. ملف مكتب موحد.
2. ترقيم عربي حسب نوع الملف.
3. إنشاء جديد من مكتب العمل فقط.
4. شاشة ملفات جارية ومنتهية.
5. إدخال أرشيف قديم منفصل.
6. دعوى جديدة ودعوى متابعة.
7. شاشة دعوى جارية ومنتهية.
8. مراحل وجلسات ونتائج جلسات.
9. ويزارد إنهاء/إغلاق مرحلة.
10. إغلاق إداري للملف.
11. إعادة فتح ملف منتهٍ بصلاحية.
12. كتاب لا مانع عند التخلي/التسليم.
13. استئناف/نقض/مخاصمة/تنفيذ بعد الحكم حسب الحالة.
14. دعوى جديدة مرتبطة بعد رد شكلي.
15. إجراء إداري كملف مستقل.
16. ربط الإجراء بدعوى/عقد/شركة/وكالة دون دمج.
17. عقود كغلاف فقط وتفاصيلها داخل Word/النموذج.
18. شركات: شركاء، مديرون، مراحل تأسيس، ما بعد التأسيس، انحلال.
19. وكالات كملفات مستقلة مع ارتباطات وحالات انتهاء/عزل/اعتزال.
20. مركز عمل اليوم والغد وغير المكتمل.
21. أوامر عمل وحالات مبسطة وواتساب مضبوط.
22. مستندات وأصول ورقية ومحاضر تسليم.
23. مالية مرتبطة بالملف وتمييز أتعاب/مصاريف/مبالغ لحساب الموكل.
24. أشخاص وجهات وتعارض مصالح.
25. قوائم مرجعية سورية قابلة للتوسع، ومنها القضاء الإداري.
26. أدوار وصلاحيات هرمية: مالك المكتب، مدير المكتب، محامي أستاذ.
27. منع التصعيد وحماية آخر مالك والصلاحيات المالية الحساسة.
28. نماذج قانونية: جاهزة/مستوردة/مستند جديد.
29. تقارير وطباعة PDF.
30. تأجيل المكتبة القانونية والتصميم النهائي والترخيص والشبكة لوقتها.

---

## 8. المرحلة البرمجية القادمة المقترحة

أول مرحلة كود يجب أن تكون:

```text
المرحلة 0 + بداية المرحلة 1 من FINAL_IMPLEMENTATION_ROADMAP.md
```

أي:

1. تنظيف فهارس Drift المكررة في `schema.dart`:
   - `idx_case_parties_case`
   - `idx_case_phases_case`
   - `idx_case_sessions_case`
   - `idx_tasks_date`
2. إضافة enums/constants لأنواع OfficeFile وحالاته ومصادره.
3. إضافة جداول Drift:
   - `OfficeFiles`
   - `OfficeFileSequences`
4. رفع `schemaVersion`.
5. إضافة خدمة توليد رقم ملف المكتب.
6. إضافة `OfficeFileRepository`.
7. عدم ربط كل الشاشات دفعة واحدة في هذه المرحلة.
8. بعد ذلك يشغل المستخدم على Windows:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter run -d windows
```

ثم يرسل أي خطأ فوراً ليتم إصلاحه.

---

## 9. ملفات الكود المهمة الحالية

قاعدة البيانات:

```text
lib/data/database/schema.dart
lib/data/database/database.dart
lib/data/database/database.g.dart
```

الخدمات:

```text
lib/data/services/sequence_service.dart
lib/data/services/task_sync_service.dart
lib/data/services/deficiency_service.dart
lib/data/services/audit_service.dart
lib/data/services/permission_service.dart
```

Repositories:

```text
lib/data/repositories/case_repository.dart
lib/data/repositories/admin_procedure_repository.dart
lib/data/repositories/contract_repository.dart
lib/data/repositories/company_repository.dart
lib/data/repositories/poa_repository.dart
lib/data/repositories/work_order_repository.dart
lib/data/repositories/finance_repository.dart
lib/data/repositories/document_repository.dart
lib/data/repositories/auth_repository.dart
```

Providers:

```text
lib/presentation/providers/app_providers.dart
lib/presentation/providers/ui_data_providers.dart
lib/presentation/providers/auth_providers.dart
```

الشاشات الأهم:

```text
lib/presentation/screens/files/files_screen.dart
lib/presentation/screens/new_work/new_work_screen.dart
lib/presentation/screens/work_center/daily_work_center_screen.dart
lib/presentation/screens/work_orders/work_orders_screen.dart
lib/presentation/screens/cases/create_case_wizard.dart
lib/presentation/screens/cases/case_detail_screen.dart
lib/presentation/screens/archive_intake/archive_intake_screen.dart
lib/presentation/screens/settings/settings_screen.dart
```

---

## 10. ملاحظات تقنية حالية

- `schemaVersion` الحالي قبل التنفيذ: `3`.
- `SequenceService` الحالي يولد أرقاماً عامة مثل `2026/001` ويجب استبداله/توسيعه.
- `YearlySequences` الحالي يستخدم `year` فقط كفريد؛ لا يكفي للترقيم حسب نوع الملف.
- يوجد تكرار فهارس في `schema.dart` يجب إصلاحه أولاً.
- لا توجد بيئة Flutter/Dart في المساعد؛ البناء عند المستخدم.
- يوجد نظام مستخدمين وصلاحيات SQL-managed عبر `ensureAuthTables()`.
- يوجد نظام أرشيف SQL-managed عبر `ensureArchiveTables()`.
- لا تنقل SQL-managed tables إلى Drift الآن دون خطة منفصلة.

---

## 11. ما لا يجب فعله في بداية المحادثة القادمة

- لا تبدأ بتنفيذ كل الخطة دفعة واحدة.
- لا تجمع محتوى مكتبة قانونية.
- لا تحذف الدستور.
- لا تبدأ بالتصميم الشكلي النهائي.
- لا تبدأ بالترخيص التجاري أو الشبكة.
- لا تطبق stashes قديمة.
- لا تعمل Migration معقدة لحفظ بيانات تجريبية.
- لا تغير وظائف خارج المرحلة المتفق عليها.

---

## 12. طريقة متابعة المحادثة القادمة

ابدأ المحادثة القادمة بهذه العبارة تقريباً:

```text
نحن في مشروع ميزان lawyer-office. اقرأ docs/NEXT_CONVERSATION_HANDOFF.md ثم docs/FINAL_IMPLEMENTATION_ROADMAP.md و docs/FINAL_ROADMAP_COVERAGE_AUDIT.md. المستودع يجب أن يكون على main عند commit 5403c7c أو أحدث. كل بيانات التطبيق تجريبية ومسموح reset لها. محتوى المكتبة والتصميم النهائي والترخيص والشبكة مؤجلة. المرحلة التالية هي المرحلة 0 + بداية المرحلة 1: تنظيف فهارس Drift المكررة ثم إضافة OfficeFiles و OfficeFileSequences وخدمة ترقيم رقم ملف المكتب. لا تبدأ بالكود قبل أن تناقش معي تفاصيل المرحلة وتحدد الملفات والجداول المتأثرة.
```

---

## 13. خلاصة قصيرة جداً

وصلنا إلى نهاية التخطيط والتدقيق. الخطة النهائية شاملة وتم تدقيقها مقابل الخطط الجزئية. لم نبدأ بعد تنفيذ إعادة الهيكلة البرمجية. أول تنفيذ قادم هو تأسيس قلب النظام: `OfficeFiles` و `OfficeFileSequences` بعد تنظيف Drift، ثم البناء على Windows وإصلاح أي أخطاء.
