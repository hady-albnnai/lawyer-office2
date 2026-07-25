# F8 — قائمة التسليم النهائي (Release Checklist)

**المشروع:** ميزان — المنصة الرقمية للمحامي (V6.2)  
**التاريخ:** 2026-07-24  
**الحالة:** جاهز للبناء والتسليم

---

## 1. فحص الجودة (يُنفذ على Windows)

- [ ] `flutter analyze` — بدون أخطاء
- [ ] `flutter test` — جميع الاختبارات ناجحة
- [ ] Windows CI أخضر (GitHub Actions)
- [ ] لا يوجد `print` أو `debugPrint` في الكود النهائي

## 2. البناء (Build)

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

- [ ] تم بناء `build/windows/x64/runner/Release/`
- [ ] حجم المجلد معقول (< 150 MB)

## 3. التغليف (Packaging)

### الخيار الموصى به: ZIP

```powershell
Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "LawyerOffice-v1.0.0.zip"
```

### الخيار المتقدم: Setup.exe (Inno Setup)

- [ ] تم إنشاء `installer/lawyer_office_setup.iss`
- [ ] تم توليد `LawyerOffice-Setup-v1.0.0.exe`

## 4. الاختبار النهائي (Smoke Test)

- [ ] التطبيق يعمل على جهاز Windows نظيف (بدون Flutter)
- [ ] أول تشغيل يعمل (`/setup`)
- [ ] إنشاء دعوى + جلسة + نتيجة يعمل
- [ ] الإغلاق الإداري يعمل
- [ ] البحث الشامل يعمل
- [ ] النسخ الاحتياطي يعمل

## 5. التوثيق النهائي

- [ ] `RELEASE_NOTES_v1.0.md` محدث
- [ ] `CLIENT_RUNBOOK.md` محدث
- [ ] `BUILD_RELEASE.md` محدث
- [ ] `MANUAL_E2E_DAY_IN_THE_LIFE.md` جاهز

## 6. الإصدار (Release)

- [ ] Tag: `v1.0.0`
- [ ] Push Tag إلى GitHub
- [ ] إنشاء Release على GitHub مع:
  - `LawyerOffice-v1.0.0.zip`
  - (اختياري) `LawyerOffice-Setup-v1.0.0.exe`
  - `RELEASE_NOTES_v1.0.md`

## 7. التسليم للعميل

- [ ] إرسال الرابط أو الملفات
- [ ] إرسال `CLIENT_RUNBOOK.md`
- [ ] تدريب سريع (إن أمكن)

---

**ملاحظة هامة:**  
بعد تنفيذ هذه القائمة على Windows، يُعتبر المشروع **مُسلّم 100%**.