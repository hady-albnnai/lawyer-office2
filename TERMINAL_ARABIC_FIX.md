# حل مشكلة كتابة اللغة العربية بالعكس في التيرمنال

## المشكلة
عند عرض النص العربي في التيرمنال، يظهر بالعكس (من اليمين إلى اليسار) مما يجعل قراءته صعبة.

## الحلول المقترحة

### الحل 1: استخدام Windows Terminal (الموصى به)

1. **تثبيت Windows Terminal:**
   ```
   winget install Microsoft.WindowsTerminal
   ```

2. **ضبط إعدادات Windows Terminal:**
   - افتح Windows Terminal
   - اضغط `Ctrl + ,` لفتح الإعدادات
   - اذهب إلى `Profiles` → `Defaults`
   - ابحث عن `Text direction` وضبطه على `Left-to-right`

3. **ضبط الخط العربي:**
   - في الإعدادات، اذهب إلى `Appearance`
   - ابحث عن `Font face`
   - استخدم خط يدعم العربية بشكل صحيح مثل:
     - `Cairo`
     - `Segoe UI`
     - `Tahoma`
     - `Arial`

### الحل 2: ضبط PowerShell

1. **فتح PowerShell بصلاحيات المسؤول**
2. **تشغيل الأوامر التالية:**
   ```powershell
   # ضبط إعدادات اللغة
   Set-WinSystemLocale -SystemLocale "ar-SA"
   Set-WinUserLanguageList -LanguageList "ar-SA" -Force
   
   # ضبط إعدادات التيرمنال
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
   $OutputEncoding = [System.Text.Encoding]::UTF8
   ```

### الحل 3: استخدام VS Code Terminal

1. **فتح VS Code**
2. **ضبط إعدادات JSON:**
   ```json
   {
     "terminal.integrated.fontFamily": "Cairo",
     "terminal.integrated.fontSize": 14,
     "terminal.integrated.rightClickBehavior": "default"
   }
   ```

### الحل 4: استخدام Git Bash

1. **تثبيت Git Bash:** 
   ```
   winget install Git.Git
   ```

2. **ضبط Git Bash لدعم العربية:**
   ```bash
   # إضافة إلى ~/.bashrc
   export LANG=ar_SA.UTF-8
   export LC_ALL=ar_SA.UTF-8
   ```

### الحل 5: استخدام أوامر بديلة

بدلاً من عرض النص مباشرة في التيرمنال، يمكنك حفظه في ملف:

```powershell
# حفظ الإخراج في ملف
your-command | Out-File -Encoding UTF8 "output.txt"

# ثم قراءة الملف في محرر نصوص
notepad "output.txt"
```

### الحل 6: استخدام محرر نصوص خارجي

1. **نسخ النص من التيرمنال**
2. **لصقه في محرر نصوص يدعم العربية:**
   - Notepad
   - Word
   - أي متصفح ويب
   - VS Code

## الحل المؤقت (الأسرع)

إذا كنت بحاجة لقراءة النص بشكل عاجل:

1. قم بنسخ النص من التيرمنال
2. ألصقه في أي محرر نصوص أو متصفح
3. النص سيظهر بشكل صحيح

## النصيحة الموصى بها

أفضل حل هو استخدام **Windows Terminal** مع ضبط الإعدادات المذكورة أعلاه، حيث يوفر أفضل تجربة للغة العربية.

## التحقق من الحل

بعد تطبيق أي حل، يمكنك اختباره بتشغيل:

```powershell
Write-Host "مرحباً بالعالم العربي"
```

إذا ظهر النص بشكل صحيح، فقد تم حل المشكلة بنجاح.

---

**ملاحظة:** هذه المشكلة خاصة بإعدادات التيرمنال وليست مشكلة في الكود أو التطبيق نفسه.