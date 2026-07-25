/// ألوان الثيم الفاخر لتطبيق مكتب المحامي
/// 
/// هذا الملف يحدد نظام الألوان الرسمي للتطبيق حسب مواصفات
/// PRODUCT_REDESIGN_MASTER_PLAN.md - القسم 2.1
/// 
/// آخر تحديث: 2026-07-09

import 'package:flutter/material.dart';

class AppColors {
  // ===========================================================================
  // الألوان الأساسية (Primary Colors)
  // ===========================================================================
  
  /// خلفية فاتحة مريحة للعمل الطويل
  static const Color backgroundLight = Color(0xFFF8F9FA);
  
  /// كحلي قانوني هادئ وليس قاتماً جداً
  static const Color primaryNavy = Color(0xFF2C3E50);
  
  /// ذهبي رسمي للتأكيدات والعناصر المهمة
  static const Color secondaryGold = Color(0xFFD4AF37);
  
  /// أبيض نقي للبطاقات
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  // ===========================================================================
  // الألوان الثانوية (Secondary Colors)
  // ===========================================================================
  
  /// حدود ناعمة للبطاقات
  static const Color cardBorder = Color(0xFFE0E0E0);
  
  /// ظلال خفيفة
  static const Color shadowLight = Color(0x1A000000); // 10% black
  static const Color shadowMedium = Color(0x29000000); // 16% black
  static const Color shadowHeavy = Color(0x3D000000); // 24% black
  
  // ===========================================================================
  // ألوان النصوص (Text Colors)
  // ===========================================================================
  
  /// نص رئيسي (عناوين، نص رئيسي)
  static const Color textPrimary = Color(0xFF2C3E50);
  
  /// نص ثانوي (وصف، نص مساعد)
  static const Color textSecondary = Color(0xFF6C757D);
  
  /// نص على خلفية فاتحة
  static const Color textOnLight = Color(0xFFFFFFFF);
  
  /// نص على خلفية داكنة
  static const Color textOnDark = Color(0xFF2C3E50);
  
  // ===========================================================================
  // ألوان الحالة (Status Colors)
  // ===========================================================================
  
  /// نجاح (مكتمل، نشط)
  static const Color success = Color(0xFF28A745);
  static const Color successLight = Color(0xFFD4EDDA);
  static const Color successDark = Color(0xFF155724);
  
  /// تنبيه (مهم، يحتاج اهتمام)
  static const Color warning = Color(0xFFFFC107);
  static const Color warningLight = Color(0xFFFFF3CD);
  static const Color warningDark = Color(0xFF856404);
  
  /// خطأ (نقص، خطأ)
  static const Color error = Color(0xFFDC3545);
  static const Color errorLight = Color(0xFFF8D7DA);
  static const Color errorDark = Color(0xFF721C24);
  
  /// معلومات (معلومات عامة)
  static const Color info = Color(0xFF17A2B8);
  static const Color infoLight = Color(0xFFD1ECF1);
  static const Color infoDark = Color(0xFF0C5460);
  
  // ===========================================================================
  // ألوان SideBar
  // ===========================================================================
  
  /// خلفية SideBar
  static const Color sidebarBackground = backgroundLight;
  
  /// خلفية عنصر SideBar عند التمرير عليه
  static const Color sidebarHover = Color(0xFFE9ECEF);
  
  /// خلفية عنصر SideBar المختار
  static const Color sidebarSelected = primaryNavy;
  
  /// لون نص عنصر SideBar
  static const Color sidebarText = textPrimary;
  
  /// لون نص عنصر SideBar المختار
  static const Color sidebarTextSelected = textOnLight;
  
  /// لون أيقونة SideBar
  static const Color sidebarIcon = textSecondary;
  
  /// لون أيقونة SideBar المختارة
  static const Color sidebarIconSelected = secondaryGold;
  
  // ===========================================================================
  // ألوان Badges
  // ===========================================================================
  
  /// خلفية Badge لحالة عادية
  static const Color badgeBackground = error;
  
  /// خلفية Badge لحالة تنبيه
  static const Color badgeWarningBackground = warning;
  
  /// خلفية Badge لحالة نجاح
  static const Color badgeSuccessBackground = success;
  
  /// لون نص Badge
  static const Color badgeText = textOnLight;
  
  // ===========================================================================
  // ألوان الأزرار (Buttons)
  // ===========================================================================
  
  /// زر رئيسي (Primary Button)
  static const Color buttonPrimary = primaryNavy;
  static const Color buttonPrimaryText = textOnLight;
  
  /// زر ثانوي (Secondary Button)
  static const Color buttonSecondary = Color(0xFF6C757D);
  static const Color buttonSecondaryText = textOnLight;
  
  /// زر خلفي (Outlined Button)
  static const Color buttonOutlined = primaryNavy;
  static const Color buttonOutlinedText = primaryNavy;
  static const Color buttonOutlinedBorder = primaryNavy;
  
  /// زر نصي (Text Button)
  static const Color buttonText = primaryNavy;
  
  // ===========================================================================
  // ألوان حقول الإدخال (Input Fields)
  // ===========================================================================
  
  /// خلفية حقل الإدخال
  static const Color inputBackground = cardBackground;
  
  /// حدود حقل الإدخال
  static const Color inputBorder = cardBorder;
  
  /// حدود حقل الإدخال عند التركيز
  static const Color inputBorderFocused = primaryNavy;
  
  /// حدود حقل الإدخال عند خطأ
  static const Color inputBorderError = error;
  
  /// خلفية حقل الإدخال عند التعطيل
  static const Color inputBackgroundDisabled = Color(0xFFF8F9FA);
  
  // ===========================================================================
  // ألوان الجداول (Tables)
  // ===========================================================================
  
  /// خلفية صف الجدول عند التمرير
  static const Color tableRowHover = Color(0xFFF8F9FA);
  
  /// خلفية صف الجدول المختار
  static const Color tableRowSelected = Color(0xFFE9ECEF);
  
  /// حدود خلايا الجدول
  static const Color tableBorder = cardBorder;
  
  // ===========================================================================
  /// الحصول على ColorScheme كامل للتطبيق
  // ===========================================================================
  
  static ColorScheme get colorScheme {
    return const ColorScheme.light(
      primary: primaryNavy,
      primaryContainer: primaryNavy,
      secondary: secondaryGold,
      secondaryContainer: Color(0xFFFFF5E6),
      surface: cardBackground,
      background: backgroundLight,
      error: error,
      errorContainer: errorLight,
      onPrimary: textOnLight,
      onSecondary: textPrimary,
      onSurface: textPrimary,
      onBackground: textPrimary,
      onError: textOnLight,
      brightness: Brightness.light,
    );
  }
  
  // ===========================================================================
  /// الحصول على ThemeData كامل للتطبيق
  // ===========================================================================
  
  static ThemeData get themeData {
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: textOnLight,
        elevation: 4,
        shadowColor: shadowMedium,
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        surfaceTintColor: cardBackground,
        elevation: 2,
        shadowColor: shadowMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: cardBorder, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorderFocused, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorderError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorderError, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cardBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonPrimary,
          foregroundColor: buttonPrimaryText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
          shadowColor: shadowMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonOutlinedText,
          side: const BorderSide(color: buttonOutlinedBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: buttonText,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: cardBackground,
        selectedTileColor: tableRowSelected,
        selectedColor: primaryNavy,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryNavy,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryNavy,
        foregroundColor: textOnLight,
        elevation: 4,
        shape: CircleBorder(),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: cardBackground,
        surfaceTintColor: cardBackground,
        elevation: 8,
        shadowColor: shadowMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      // دعم RTL
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Cairo'),
        displayMedium: TextStyle(fontFamily: 'Cairo'),
        displaySmall: TextStyle(fontFamily: 'Cairo'),
        headlineLarge: TextStyle(fontFamily: 'Cairo'),
        headlineMedium: TextStyle(fontFamily: 'Cairo'),
        headlineSmall: TextStyle(fontFamily: 'Cairo'),
        titleLarge: TextStyle(fontFamily: 'Cairo'),
        titleMedium: TextStyle(fontFamily: 'Cairo'),
        titleSmall: TextStyle(fontFamily: 'Cairo'),
        bodyLarge: TextStyle(fontFamily: 'Cairo'),
        bodyMedium: TextStyle(fontFamily: 'Cairo'),
        bodySmall: TextStyle(fontFamily: 'Cairo'),
        labelLarge: TextStyle(fontFamily: 'Cairo'),
        labelMedium: TextStyle(fontFamily: 'Cairo'),
        labelSmall: TextStyle(fontFamily: 'Cairo'),
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}
