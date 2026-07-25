# حالة طبقة البيانات الحقيقية (Drift / SQLite)

> آخر تحديث: 2026-07-10

## الهدف
التطبيق يخزّن ويسترجع من SQLite، وليس من قوائم seed في الذاكرة فقط.

## ما هو مربوط الآن بـ SQLite

| الوحدة | المصدر | ملاحظات |
|---|---|---|
| المالية | `FinanceRepository` | seed أول تشغيل إن فارغ |
| المكتبة القانونية | `LegalLibraryRepository` + جداول v2 | |
| الإعدادات/الأمان/النسخ/السجل/المحاكم | `SettingsRepository` | + BackupService |
| الأشخاص والوكالات | `PersonRepository` + hydrate للواجهة | |
| الدعاوى | `CaseRepository` + `uiCasesProvider` | |
| المستندات | `DocumentRepository` + `documentsProvider` | |
| الملفات (أرشيف) | مشتق من الدعاوى+المستندات | |
| أوامر العمل | جدول `work_orders` v3 + `WorkOrderRepository` | |

## schemaVersion
**3** (مكتبة قانونية + أوامر العمل)

## اختبارات
- `test/stage11_data_layer_test.dart`
- `test/stage12_remaining_modules_test.dart`

## ملاحظة
بعض شاشات wizard/تفاصيل قد ما زالت تستخدم حقولاً محلية مؤقتة أثناء الإدخال، لكن القوائم الرئيسية تُقرأ من DB بعد البذر/التشغيل.
