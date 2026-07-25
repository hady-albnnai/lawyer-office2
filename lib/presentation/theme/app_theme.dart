/// الثيم الرئيسي لتطبيق مكتب المحامي
/// 
/// هذا الملف يحدد الثيم الرسمي الكامل للتطبيق حسب مواصفات
/// PRODUCT_REDESIGN_MASTER_PLAN.md - القسم 2.1
/// 
/// آخر تحديث: 2026-07-09

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  // ===========================================================================
  /// الثيم الرئيسي للتطبيق (Light Theme)
  // ===========================================================================
  
  static ThemeData get lightTheme {
    return ThemeData(
      // =========================================================================
      // إعدادات عامة
      // =========================================================================
      useMaterial3: true,
      brightness: Brightness.light,
      
      // =========================================================================
      // ColorScheme
      // =========================================================================
      colorScheme: AppColors.colorScheme,
      
      // =========================================================================
      // Scaffold Background
      // =========================================================================
      scaffoldBackgroundColor: AppColors.cardBackground,
      
      // =========================================================================
      // AppBar Theme
      // =========================================================================
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: AppColors.textOnLight,
        elevation: 4,
        shadowColor: AppColors.shadowMedium,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textOnLight,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textOnLight,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.textOnLight,
        ),
      ),
      
      // =========================================================================
      // Card Theme
      // =========================================================================
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        surfaceTintColor: AppColors.cardBackground,
        elevation: 2,
        shadowColor: AppColors.shadowMedium,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      
      // =========================================================================
      // Input Decoration Theme
      // =========================================================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inputBorderFocused, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inputBorderError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inputBorderError, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        hintStyle: AppTextStyles.inputHint,
        errorStyle: AppTextStyles.inputError,
        labelStyle: AppTextStyles.inputLabel,
      ),
      
      // =========================================================================
      // Button Themes
      // =========================================================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          foregroundColor: AppColors.buttonPrimaryText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
          shadowColor: AppColors.shadowMedium,
          textStyle: AppTextStyles.buttonPrimary,
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.buttonOutlinedText,
          side: const BorderSide(color: AppColors.buttonOutlinedBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: AppTextStyles.buttonText,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.buttonText,
          textStyle: AppTextStyles.buttonText,
        ),
      ),
      
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // =========================================================================
      // Floating Action Button Theme
      // =========================================================================
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: AppColors.textOnLight,
        elevation: 4,
        shape: CircleBorder(),
      ),
      
      // =========================================================================
      /// Divider Theme
      // =========================================================================
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder,
        thickness: 0.5,
        space: 0,
      ),
      
      // =========================================================================
      // List Tile Theme
      // =========================================================================
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: AppColors.cardBackground,
        selectedTileColor: AppColors.tableRowSelected,
        selectedColor: AppColors.primaryNavy,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: AppTextStyles.bodyMedium,
        subtitleTextStyle: AppTextStyles.bodySmallSecondary,
      ),
      
      // =========================================================================
      // Bottom Navigation Bar Theme
      // =========================================================================
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardBackground,
        selectedItemColor: AppColors.primaryNavy,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),
      
      // =========================================================================
      // Dialog Theme
      // =========================================================================
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: AppColors.cardBackground,
        elevation: 8,
        shadowColor: AppColors.shadowMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
      ),
      
      // =========================================================================
      // SnackBar Theme
      // =========================================================================
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.primaryNavy,
        actionTextColor: AppColors.secondaryGold,
        contentTextStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 14,
          color: AppColors.textOnLight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      
      // =========================================================================
      // Tab Bar Theme
      // =========================================================================
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primaryNavy,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: AppColors.primaryNavy,
            width: 2,
          ),
        ),
        labelStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),
      
      // =========================================================================
      // Chip Theme
      // =========================================================================
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.cardBackground,
        labelStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: AppColors.textOnLight,
        ),
        brightness: Brightness.light,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: StadiumBorder(),
      ),
      
      // =========================================================================
      // Text Theme (دعم RTL)
      // =========================================================================
      textTheme: AppTextStyles.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      
      // =========================================================================
      // Icon Theme
      // =========================================================================
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 24,
        fill: 0.0,
        weight: 400,
        grade: 0,
        opticalSize: 48,
      ),
      
      // =========================================================================
      // Primary Icon Theme
      // =========================================================================
      primaryIconTheme: const IconThemeData(
        color: AppColors.primaryNavy,
        size: 24,
      ),
      
      // =========================================================================
      // ToolTip Theme
      // =========================================================================
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primaryNavy,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: AppTextStyles.tooltipText,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: EdgeInsets.all(8),
        height: 32,
        waitDuration: Duration(milliseconds: 500),
        showDuration: Duration(seconds: 3),
      ),
      
      // =========================================================================
      // Data Table Theme
      // =========================================================================
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        dataTextStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        columnSpacing: 16,
        horizontalMargin: 16,
        dividerThickness: 0.5,
      ),
      
      // =========================================================================
      // Bottom Sheet Theme
      // =========================================================================
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: AppColors.cardBackground,
        elevation: 8,
        shadowColor: AppColors.shadowMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      
      // =========================================================================
      // Popup Menu Theme
      // =========================================================================
      popupMenuTheme: const PopupMenuThemeData(
        textStyle: TextStyle(
          fontFamily: AppTextStyles.uiFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        elevation: 8,
        shadowColor: AppColors.shadowMedium,
      ),
      
      // =========================================================================
      // Switch Theme
      // =========================================================================
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.secondaryGold;
          }
          return AppColors.cardBorder;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.secondaryGold.withOpacity(0.5);
          }
          return AppColors.cardBorder;
        }),
        overlayColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.secondaryGold.withOpacity(0.2);
          }
          return AppColors.cardBorder.withOpacity(0.2);
        }),
      ),
      
      // =========================================================================
      // Checkbox Theme
      // =========================================================================
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primaryNavy;
          }
          return AppColors.cardBackground;
        }),
        checkColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.textOnLight;
          }
          return AppColors.textPrimary;
        }),
        overlayColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primaryNavy.withOpacity(0.2);
          }
          return AppColors.cardBorder.withOpacity(0.2);
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: const BorderSide(
          color: AppColors.cardBorder,
          width: 1,
        ),
      ),
      
      // =========================================================================
      // Radio Theme
      // =========================================================================
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primaryNavy;
          }
          return AppColors.cardBackground;
        }),
        overlayColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primaryNavy.withOpacity(0.2);
          }
          return AppColors.cardBorder.withOpacity(0.2);
        }),
      ),
    );
  }
  
  // ===========================================================================
  /// الثيم الداكن للتطبيق (Dark Theme) - للتشغيل المستقبل
  // ===========================================================================
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.secondaryGold,
        secondary: AppColors.primaryNavy,
        surface: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
        error: AppColors.error,
        onPrimary: AppColors.textPrimary,
        onSecondary: AppColors.textOnLight,
        onSurface: AppColors.textOnLight,
        onBackground: AppColors.textOnLight,
        onError: AppColors.textOnLight,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: AppColors.textOnLight,
        elevation: 4,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        surfaceTintColor: const Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF424242), width: 0.5),
        ),
      ),
      textTheme: AppTextStyles.textTheme.apply(
        bodyColor: AppColors.textOnLight,
        displayColor: AppColors.textOnLight,
      ),
    );
  }
  
  // ===========================================================================
  /// الحصول على الثيم حسب الإعدادات
  // ===========================================================================
  
  static ThemeData getThemeByBrightness(Brightness brightness) {
    switch (brightness) {
      case Brightness.light:
        return lightTheme;
      case Brightness.dark:
        return darkTheme;
      default:
        return lightTheme;
    }
  }
}
