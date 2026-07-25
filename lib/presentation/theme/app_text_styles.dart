/// أنماط النصوص الثيم الفاخر لتطبيق مكتب المحامي
/// 
/// هذا الملف يحدد نظام أنماط النصوص الرسمي للتطبيق حسب مواصفات
/// PRODUCT_REDESIGN_MASTER_PLAN.md - القسم 2.1
/// 
/// آخر تحديث: 2026-07-09

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // ===========================================================================
  // خطوط Cairo للواجهة (UI)
  // ===========================================================================
  
  /// عائلة الخطوط الرئيسية للواجهة
  static const String uiFontFamily = 'Cairo';
  
  // ===========================================================================
  // خطوط Amiri للطباعة القانونية (Legal Printing)
  // ===========================================================================
  
  /// عائلة الخطوط الرئيسية للطباعة
  static const String legalFontFamily = 'Amiri';
  
  // ===========================================================================
  // أنماط العناوين (Headlines)
  // ===========================================================================
  
  /// عنوان رئيسي كبير (استخدام في لوحات التحكم)
  static const TextStyle headline1 = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// عنوان رئيسي متوسط
  static const TextStyle headline2 = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// عنوان رئيسي صغير
  static const TextStyle headline3 = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// عنوان فرعي
  static const TextStyle headline4 = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// عنوان فرعي صغير
  static const TextStyle headline5 = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// عنوان فرعي جدا صغير
  static const TextStyle headline6 = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  // ===========================================================================
  // أنماط النص الرئيسي (Body)
  // ===========================================================================
  
  /// نص رئيسي كبير
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  /// نص رئيسي متوسط
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  /// نص رئيسي صغير
  static const TextStyle bodySmall = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  // ===========================================================================
  // أنماط التسميات (Labels)
  // ===========================================================================
  
  /// تسمية كبيرة (استخدام في الأزرار)
  static const TextStyle labelLarge = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// تسمية متوسطة
  static const TextStyle labelMedium = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// تسمية صغيرة
  static const TextStyle labelSmall = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.3,
  );
  
  // ===========================================================================
  // أنماط النصوص الثانوية (Secondary)
  // ===========================================================================
  
  /// نص ثانوي كبير
  static const TextStyle bodyLargeSecondary = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
  );
  
  /// نص ثانوي متوسط
  static const TextStyle bodyMediumSecondary = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
  );
  
  /// نص ثانوي صغير
  static const TextStyle bodySmallSecondary = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
  );
  
  // ===========================================================================
  // أنماط النصوص للأزرار
  // ===========================================================================
  
  /// نص زر رئيسي
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.buttonPrimaryText,
    height: 1.3,
  );
  
  /// نص زر ثانوي
  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.buttonSecondaryText,
    height: 1.3,
  );
  
  /// نص زر نصي
  static const TextStyle buttonText = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.buttonText,
    height: 1.3,
  );
  
  // ===========================================================================
  // أنماط النصوص للـ SideBar
  // ===========================================================================
  
  /// نص عنصر SideBar
  static const TextStyle sidebarItem = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.sidebarText,
    height: 1.3,
  );
  
  /// نص عنصر SideBar المختار
  static const TextStyle sidebarItemSelected = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.sidebarTextSelected,
    height: 1.3,
  );
  
  /// نص عنصر SideBar عند التمرير
  static const TextStyle sidebarItemHover = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryNavy,
    height: 1.3,
  );
  
  // ===========================================================================
  // أنماط النصوص للبطاقات (Cards)
  // ===========================================================================
  
  /// عنوان بطاقة
  static const TextStyle cardTitle = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// نص بطاقة
  static const TextStyle cardText = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  /// نص بطاقة ثانوي
  static const TextStyle cardTextSecondary = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  // ===========================================================================
  // أنماط النصوص للجداول (Tables)
  // ===========================================================================
  
  /// عنوان عمود جدول
  static const TextStyle tableHeader = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// نص خلية جدول
  static const TextStyle tableCell = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  /// نص خلية جدول ثانوي
  static const TextStyle tableCellSecondary = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  // ===========================================================================
  // أنماط النصوص للـ Badges
  // ===========================================================================
  
  /// نص Badge
  static const TextStyle badgeText = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: AppColors.badgeText,
    height: 1.2,
  );
  
  /// نص Badge صغير
  static const TextStyle badgeTextSmall = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: AppColors.badgeText,
    height: 1.2,
  );
  
  // ===========================================================================
  // أنماط النصوص لحقول الإدخال (Input Fields)
  // ===========================================================================
  
  /// عنوان حقل إدخال
  static const TextStyle inputLabel = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// نص حقل إدخال
  static const TextStyle inputText = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  /// نص حقل إدخال ثانوي (placeholder)
  static const TextStyle inputHint = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  /// نص حقل إدخال خطأ
  static const TextStyle inputError = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.error,
    height: 1.3,
  );
  
  // ===========================================================================
  // أنماط النصوص للطباعة القانونية (Legal Printing)
  // ===========================================================================
  
  /// عنوان قانوني كبير (للطباعة)
  static const TextStyle legalTitleLarge = TextStyle(
    fontFamily: legalFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  /// عنوان قانوني متوسط
  static const TextStyle legalTitleMedium = TextStyle(
    fontFamily: legalFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  /// نص قانوني (للطباعة)
  static const TextStyle legalBody = TextStyle(
    fontFamily: legalFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.6,
  );
  
  /// نص قانوني صغير
  static const TextStyle legalBodySmall = TextStyle(
    fontFamily: legalFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  /// ترويسة قانونية (Header)
  static const TextStyle legalHeader = TextStyle(
    fontFamily: legalFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  /// تذييل قانوني (Footer)
  static const TextStyle legalFooter = TextStyle(
    fontFamily: legalFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  // ===========================================================================
  // أنماط النصوص الخاصة
  // ===========================================================================
  
  /// نص لتاريخ
  static const TextStyle dateText = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  /// نص للأرقام (مثل الأرقام المالية)
  static const TextStyle numberText = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// نص للـ ToolTips
  static const TextStyle tooltipText = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textOnLight,
    height: 1.3,
  );
  
  // ===========================================================================
  /// الحصول على TextTheme كامل للتطبيق
  // ===========================================================================
  
  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: headline1,
      displayMedium: headline2,
      displaySmall: headline3,
      headlineLarge: headline4,
      headlineMedium: headline5,
      headlineSmall: headline6,
      titleLarge: headline5.copyWith(fontSize: 22),
      titleMedium: headline5,
      titleSmall: headline6,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }
}
