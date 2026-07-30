# أدوات التدقيق الساكن

أدوات تحليل شجرة الكود (AST) تلتقط أصنافاً من العيوب لا يلتقطها
`flutter analyze` وحده. **لا تُغني عن `flutter analyze`** بل تسبقه.

## التشغيل

```bash
cd tool/audit
dart pub get

# فحص نحوي سريع
dart run parse.dart ../../lib/**/*.dart

# الأعضاء والمزودات (يلتقط أخطاء الأنواع الشائعة)
dart run audit_members.dart ../../lib/**/*.dart

# معالجات الأزرار (يلتقط النجاح الوهمي)
dart run audit_handlers.dart ../../lib/presentation/**/*.dart

# الكتابات (يلتقط الحفظ دون تحديث أو معالجة خطأ)
dart run audit_writes.dart ../../lib/presentation/**/*.dart
```

## ما تلتقطه كل أداة

| الأداة | الفئة | مثال حقيقي وقع في المشروع |
|---|---|---|
| `parse` | أخطاء نحوية | — |
| `audit_members` | `DUPLICATE_TOP_LEVEL` | `activeCourtsProvider` عُرِّف مرتين |
| | `UNDEFINED_MEMBER` | كتلة تحقّق نُقلت إلى الحوار الخطأ |
| | `FAMILY_MISUSE` | `watch(provider)` لمزوّد `family` |
| `audit_handlers` | `FAKE_SUCCESS` | زر «استعادة» يعرض نجاحاً دون استعادة |
| | `EMPTY_HANDLER` | `onPressed: () { /* إتمام المرحلة */ }` |
| `audit_writes` | `WRITE_NO_REFRESH` | حفظ لا ينعكس على الشاشة |
| | `SUCCESS_BEFORE_AWAIT` | رسالة نجاح قبل انتهاء العملية |

## حدودها

- **لا تفحص الأنواع بالكامل.** `flutter analyze` وحده يفعل ذلك.
- تُنتج إيجابيات كاذبة، خصوصاً `UNDEFINED_MEMBER` مع الصفوف
  العلوية المُشار إليها من صفوف `State`. راجع كل نتيجة قبل التعديل.
- `audit_handlers` يعتبر استدعاء تابع محلي «عملاً حقيقياً» دون
  فحص محتواه.
