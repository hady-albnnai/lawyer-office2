/// Widget للـ Badge (العلامة الدائرية) في SideBar
/// 
/// هذا الملف ينفذ نظام Badges حسب مواصفات
/// PRODUCT_REDESIGN_MASTER_PLAN.md - القسم 3.2
/// 
/// آخر تحديث: 2026-07-09

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// أنواع Badges حسب الأولوية
enum BadgeType {
  /// حالة عادية (أحمر)
  normal,
  
  /// حالة تنبيه (أصفر)
  warning,
  
  /// حالة نجاح (أخضر)
  success,
  
  /// حالة معلومات (أزرق)
  info,
}

/// widget Badge يعرض عدداً في دائرة ملونة
class BadgeWidget extends StatelessWidget {
  /// العدد الذي سيظهر في Badge
  final int count;
  
  /// نوع Badge (يحدد اللون)
  final BadgeType type;
  
  /// حجم Badge
  final double size;
  
  /// هل يظهر Badge إذا كان count = 0
  final bool showWhenZero;
  
  /// نمط النص
  final TextStyle? textStyle;
  
  const BadgeWidget({
    super.key,
    required this.count,
    this.type = BadgeType.normal,
    this.size = 18,
    this.showWhenZero = false,
    this.textStyle,
  });
  
  @override
  Widget build(BuildContext context) {
    // إذا كان count = 0 ولا نريد عرض Badge
    if (count <= 0 && !showWhenZero) {
      return const SizedBox.shrink();
    }
    
    // تحديد اللون حسب النوع
    Color backgroundColor;
    switch (type) {
      case BadgeType.warning:
        backgroundColor = AppColors.warning;
        break;
      case BadgeType.success:
        backgroundColor = AppColors.success;
        break;
      case BadgeType.info:
        backgroundColor = AppColors.info;
        break;
      case BadgeType.normal:
      default:
        backgroundColor = AppColors.error;
        break;
    }
    
    // تحديد حجم النص حسب العدد
    String displayText = count > 99 ? '99+' : count.toString();
    double fontSize = size * 0.7;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.cardBackground,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        displayText,
        style: textStyle ?? AppTextStyles.badgeText.copyWith(
          fontSize: fontSize,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// امتداد لـ BadgeWidget لإضافة Badge إلى أي widget
class Badge extends StatelessWidget {
  /// widget الأصل الذي سيظهر معه Badge
  final Widget child;
  
  /// عدد Badge
  final int count;
  
  /// نوع Badge
  final BadgeType type;
  
  /// موقع Badge بالنسبة للـ child
  final Alignment alignment;
  
  /// مسافة Badge عن حافة child
  final EdgeInsets padding;
  
  /// حجم Badge
  final double size;
  
  const Badge({
    super.key,
    required this.child,
    required this.count,
    this.type = BadgeType.normal,
    this.alignment = Alignment.topRight,
    this.padding = const EdgeInsets.all(4),
    this.size = 18,
  });
  
  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return child;
    }
    
    return Stack(
      alignment: alignment,
      children: [
        child,
        Padding(
          padding: padding,
          child: BadgeWidget(
            count: count,
            type: type,
            size: size,
          ),
        ),
      ],
    );
  }
}
