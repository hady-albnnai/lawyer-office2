# 📋 خطة تنفيذ المرحلة 1: التصميم والهيكل العام

> **مرجع:** [PRODUCT_REDESIGN_MASTER_PLAN.md](../docs/PRODUCT_REDESIGN_MASTER_PLAN.md) - القسم 15.1
> **التاريخ:** 2026-07-09
> **المسؤول:** وكيل الذكي (Agent)
> **الحالة:** جاري التنفيذ ⏳

---

## 🎯 أهداف المرحلة 1

تنفيذ التصميم الفاخر الجديد والهيكلة العامة للتطبيق بما يتوافق مع:
1. **الثيم الفاخر** - ألوان، خطوط، أيقونات قانونية
2. **Sidebar الجديد** - قابل للطي، يدعم RTL، يعرض Badges
3. **التبويبات الرئيسية** - 11 تبويب حسب الخطة
4. **إزالة التبعيات القديمة** - تنظيف الكود غير المستخدم

---

## 📋 مهام المرحلة 1 (بترتيب التنفيذ)

### 🔴 المهام الحرجة (Priority: Critical)

#### 1.1 بناء نظام الثيم الفاخر
- [ ] **1.1.1** إنشاء ملف `lib/presentation/theme/app_theme.dart` 
  - تعريف ألوان الثيم: خلفية فاتحة، كحلي قانوني، ذهبي رسمي
  - تعريف أنماط البطاقات: حدود ناعمة، ظلال خفيفة
  - دعم RTL الكامل
- [ ] **1.1.2** تضمين خطوط Cairo (للواجهة) و Amiri (للطباعة)
  - تحميل الخطوط في `pubspec.yaml`
  - تعريف `TextTheme` المناسب
- [ ] **1.1.3** تعريف أيقونات قانونية متناسقة
  - استخدام `CustomIcons` أو `FontAwesome` مع أيقونات مخصصة
  - أيقونات ل:
    - لوحة اليوم
    - الأجندة
    - عمل جديد
    - الملفات
    - الأشخاص والجهات
    - أوامر العمل
    - المالية
    - المستندات
    - المكتبة القانونية
    - البحث والتقارير
    - الإعدادات

#### 1.2 بناء Sidebar الجديد
- [ ] **1.2.1** إنشاء `lib/presentation/widgets/sidebar/nav_sidebar.dart`
  - Sidebar قابل للطي (Expandable/Collapsible)
  - دعم RTL (العربية)
  - عرض اسم التبويب + Badges عند التوسعة
  - عرض الأيقونات فقط عند الطي
- [ ] **1.2.2** تنفيذ نظام Badges
  - Badge لمهام اليوم
  - Badge للمتأخرات
  - Badge للنواقص
  - Badge لنتائج المعقب بانتظار الاعتماد
  - Badge لمستندات ناقصة
  - Badge لنسخ احتياطي متأخر
- [ ] **1.2.3** ربط Sidebar مع GoRouter
  - التنقل بين التبويبات الرئيسية
  - الحفاظ على الحالة (مفتوح/مطوي)

#### 1.3 تعريف التبويبات الرئيسية (11 تبويب)
- [ ] **1.3.1** تحديث `lib/presentation/navigation/app_router.dart`
  - تعريف 11 route رئيسة
  - الربط مع Sidebar
- [ ] **1.3.2** إنشاء شاشات Placeholder لكل تبويب
  - `TodayDashboardScreen` (لوحة اليوم)
  - `AgendaScreen` (الأجندة)
  - `NewWorkScreen` (عمل جديد)
  - `FilesScreen` (الملفات)
  - `PersonsScreen` (الأشخاص والجهات)
  - `WorkOrdersScreen` (أوامر العمل للمعقب)
  - `FinanceScreen` (المالية)
  - `DocumentsScreen` (المستندات)
  - `LegalLibraryScreen` (المكتبة القانونية السورية)
  - `SearchReportsScreen` (البحث والتقارير)
  - `SettingsScreen` (الإعدادات)

#### 1.4 تنظيف الكود القديم
- [ ] **1.4.1** تحديد وحذف التبويبات القديمة غير المستخدمة
- [ ] **1.4.2** تنظيف ملفات الثيم القديمة
- [ ] **1.4.3** تحديث `pubspec.yaml` إذا لزم الأمر

---

## 📁 هيكل الملفات الجديد للمرحلة 1

```
lib/
├── presentation/
│   ├── theme/
│   │   ├── app_theme.dart          # الثيم الرئيسي
│   │   ├── app_colors.dart         # ألوان الثيم
│   │   ├── app_text_styles.dart    # أنماط النصوص
│   │   └── custom_icons.dart        # أيقونات مخصصة
│   ├── widgets/
│   │   └── sidebar/
│   │       ├── nav_sidebar.dart     # Sidebar الرئيسي
│   │       ├── sidebar_item.dart   # عنصر Sidebar
│   │       └── badge_widget.dart    # widget Badge
│   ├── navigation/
│   │   └── app_router.dart          # GoRouter محدث
│   └── screens/
│       ├── dashboard/
│       │   └── today_dashboard_screen.dart
│       ├── agenda/
│       │   └── agenda_screen.dart
│       ├── new_work/
│       │   └── new_work_screen.dart
│       ├── files/
│       │   └── files_screen.dart
│       ├── persons/
│       │   └── persons_screen.dart
│       ├── work_orders/
│       │   └── work_orders_screen.dart
│       ├── finance/
│       │   └── finance_screen.dart
│       ├── documents/
│       │   └── documents_screen.dart
│       ├── legal_library/
│       │   └── legal_library_screen.dart
│       ├── search_reports/
│       │   └── search_reports_screen.dart
│       └── settings/
│           └── settings_screen.dart
```

---

## 🎨 مواصفات التصميم التفصيلية

### الألوان (App Colors)
```dart
// ألوان الثيم الفاخر
const Color backgroundLight = Color(0xFFF8F9FA);  // خلفية فاتحة
const Color primaryNavy = Color(0xFF2C3E50);       // كحلي قانوني
const Color secondaryGold = Color(0xFFD4AF37);     // ذهبي رسمي
const Color cardBackground = Color(0xFFFFFFFF);    // بطاقات بيضاء
const Color cardBorder = Color(0xFFE0E0E0);        // حدود ناعمة
const Color textPrimary = Color(0xFF2C3E50);       // نص رئيسي
const Color textSecondary = Color(0xFF6C757D);     // نص ثانوي
const Color successGreen = Color(0xFF28A745);      // نجاح
const Color warningAmber = Color(0xFFFFC107);      // تنبيه
const Color errorRed = Color(0xFFDC3545);           // خطأ
const Color infoBlue = Color(0xFF17A2B8);          // معلومات
```

### الخطوط (Typography)
```dart
// خطوط Cairo للواجهة
TextStyle get headline1 => TextStyle(
  fontFamily: 'Cairo',
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: textPrimary,
);

// خطوط Amiri للطباعة القانونية
TextStyle get legalText => TextStyle(
  fontFamily: 'Amiri',
  fontSize: 16,
  color: textPrimary,
);
```

### SideBar specifications
- **العرض:** 280px عند التوسعة، 70px عند الطي
- **الألوان:** خلفية SideBar = backgroundLight
- **الظلال:** ظل خفيف على الجانب الأيمن
- **التبويبات:** 11 تبويب رئيسة
- **Badges:** دوائر صغيرة بالأحمر/الأصفر/الأخضر حسب الأولوية

### الأيقونات
- استخدام `FontAwesome` أو `Material Icons` مع أيقونات قانونية
- مثال:
  - لوحة اليوم: `Icons.dashboard`
  - الأجندة: `Icons.calendar_today`
  - عمل جديد: `Icons.add_circle`
  - الملفات: `Icons.folder`
  - الأشخاص: `Icons.people`
  - أوامر العمل: `Icons.assignment`
  - المالية: `Icons.attach_money`
  - المستندات: `Icons.description`
  - المكتبة: `Icons.library_books`
  - البحث: `Icons.search`
  - الإعدادات: `Icons.settings`

---

## ⚙️ المتطلبات الفنية

### 1. تحديث `pubspec.yaml`
```yaml
flutter:
  fonts:
    - family: Cairo
      fonts:
        - asset: assets/fonts/Cairo-Regular.ttf
        - asset: assets/fonts/Cairo-Bold.ttf
          weight: 700
    - family: Amiri
      fonts:
        - asset: assets/fonts/Amiri-Regular.ttf
        - asset: assets/fonts/Amiri-Bold.ttf
          weight: 700

dependencies:
  flutter:
    sdk: flutter
  go_router: ^13.0.0
  flutter_riverpod: ^2.4.9
  font_awesome_flutter: ^10.6.0
```

### 2. إنشاء مجلدات الأصول
```
assets/
├── fonts/
│   ├── Cairo-Regular.ttf
│   ├── Cairo-Bold.ttf
│   ├── Amiri-Regular.ttf
│   └── Amiri-Bold.ttf
└── icons/
    └── custom_icons.ttf (إذا لزم الأمر)
```

---

## ✅ معايير قبول المرحلة 1

تعتبر المرحلة 1 مكتملة عندما:

1. ✅ يتم عرض الثيم الفاخر بشكل صحيح في جميع الشاشات
2. ✅ يعمل Sidebar بشكل سلس (الطي/التوسعة)
3. ✅ تظهر جميع التبويبات الرئيسية (11 تبويب)
4. ✅ تعمل Badges بشكل صحيح (عدادات ديناميكية)
5. ✅ يدعم التطبيق RTL بشكل كامل
6. ✅ يتم التنقل بين التبويبات بدون أخطاء
7. ✅ يتم تنظيف الكود القديم غير المستخدم
8. ✅ يتم رفع جميع التغييرات إلى GitHub
9. ✅ يتم تحديث التوثيق (EXECUTION_PLAN.md)
10. ✅ يتم اختبار التشغيل على Windows

---

## 📝 سجل التقدم

| المهمة | الحالة | التاريخ | ملاحظات |
|--------|--------|----------|----------|
| 1.1.1 إنشاء app_theme.dart | ⏳ | - | جاري |
| 1.1.2 تضمين الخطوط | ⏳ | - | في انتظار |
| 1.1.3 تعريف الأيقونات | ⏳ | - | في انتظار |
| 1.2.1 إنشاء nav_sidebar.dart | ⏳ | - | في انتظار |
| 1.2.2 نظام Badges | ⏳ | - | في انتظار |
| 1.2.3 ربط مع GoRouter | ⏳ | - | في انتظار |
| 1.3.1 تحديث app_router.dart | ⏳ | - | في انتظار |
| 1.3.2 إنشاء شاشات Placeholder | ⏳ | - | في انتظار |
| 1.4.1 حذف التبويبات القديمة | ⏳ | - | في انتظار |
| 1.4.2 تنظيف ملفات الثيم | ⏳ | - | في انتظار |

---

## 🚀 الخطوات التالية

1. **بدء التنفيذ:** إنشاء ملفات الثيم أولاً
2. **الاختبار:** اختبار كل مكون على حدة
3. **الرفع:** رفع التغيرات إلى GitHub بعد كل ميزة
4. **التوثيق:** تحديث EXECUTION_PLAN.md

---

**ملاحظة:** يجب الالتزام بدستور التطوير (DEVELOPMENT_GUIDELINES.md):
- لا宣布 اكتمال المرحلة إلا بعد استكمال جميع المتطلبات
- يجب رفع الكود إلى GitHub بعد كل ميزة
- يجب تحديث التوثيق باستمرار
