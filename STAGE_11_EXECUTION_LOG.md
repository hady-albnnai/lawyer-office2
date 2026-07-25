# سجل المرحلة 11: ربط طبقة البيانات الحقيقية

> الحالة: منفّذة  
> التاريخ: 2026-07-10

## المنجز

- توسيع `FinanceDao` / `FinanceRepository` (watch/get all + seed + activity/timeline).
- جداول المكتبة القانونية + `LegalLibraryDao` / `LegalLibraryRepository`.
- `SettingsDao` / `SettingsRepository` (settings, security, backups log, activity, courts).
- ربط `FinanceNotifier` و`LegalLibraryNotifier` و`SettingsHubNotifier` بالمستودعات.
- schemaVersion 2 + build_runner.
- اختبارات stage11 على قاعدة ذاكرة.

## النتيجة

المستخدم يطلب تطبيقاً جاهزاً 100% وليس إغلاقاً شكلياً للخطة.  
هذه المرحلة تعالج جذر "seed vs Drift" للمالية/المكتبة/الإعدادات.
