/// Glassmorphism + Neumorphism Design Helpers
/// 
/// هذا الملف يحتوي على دوال مساعدة لتصميم Glassmorphism و Neumorphism
/// للتطبيق مع الحفاظ على الألوان الكحلي والذهبي والأسود
/// 
/// آخر تحديث: 2026-08-06
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Glassmorphism Container
/// تأثير الزجاج الضبابي مع شفافية وطبقات
class GlassmorphismContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final double blurSigma;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final BoxShadow? boxShadow;

  const GlassmorphismContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.backgroundColor,
    this.blurSigma = 10,
    this.opacity = 0.15,
    this.padding,
    this.margin,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground.withOpacity(opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(
          color: AppColors.cardBackground.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: boxShadow != null
            ? [boxShadow!]
            : [
                BoxShadow(
                  color: AppColors.primaryNavy.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Neumorphic Container
/// تأثير Neumorphism مع ظلال ناعمة
class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isPressed;
  final double shadowDistance;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.isPressed = false,
    this.shadowDistance = 8,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.backgroundLight;
    
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  offset: Offset(-shadowDistance, -shadowDistance),
                  blurRadius: shadowDistance * 1.5,
                ),
                BoxShadow(
                  color: AppColors.primaryNavy.withOpacity(0.15),
                  offset: Offset(shadowDistance, shadowDistance),
                  blurRadius: shadowDistance * 1.5,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  offset: Offset(-shadowDistance, -shadowDistance),
                  blurRadius: shadowDistance * 2,
                ),
                BoxShadow(
                  color: AppColors.primaryNavy.withOpacity(0.1),
                  offset: Offset(shadowDistance, shadowDistance),
                  blurRadius: shadowDistance * 2,
                ),
              ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// Glassmorphic Button
/// زر بتأثير الزجاج الضبابي
class GlassmorphicButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool isPrimary;

  const GlassmorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.borderRadius = 16,
    this.padding,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? 
        (isPrimary 
            ? AppColors.primaryNavy.withOpacity(0.85) 
            : AppColors.cardBackground.withOpacity(0.2));
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isPrimary 
                  ? AppColors.secondaryGold.withOpacity(0.5) 
                  : AppColors.cardBackground.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary 
                    ? AppColors.primaryNavy.withOpacity(0.3) 
                    : AppColors.primaryNavy.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Neumorphic Input Field
/// حقل إدخال بتأثير Neumorphism
class NeumorphicInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? maxLines;
  final double borderRadius;

  const NeumorphicInputField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            offset: const Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.1),
            offset: const Offset(6, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: AppColors.secondaryGold,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: AppColors.error,
              width: 1.5,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: AppColors.error,
              width: 2,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

/// Glassmorphic Card
/// بطاقة بتأثير الزجاج الضبابي
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double opacity;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphismContainer(
      borderRadius: borderRadius,
      padding: padding ?? const EdgeInsets.all(20),
      margin: margin ?? const EdgeInsets.all(8),
      backgroundColor: backgroundColor,
      opacity: opacity,
      child: child,
    );
  }
}

/// Glassmorphic AppBar
/// AppBar بتأثير الزجاج الضبابي
class GlassmorphicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double appBarHeight;

  const GlassmorphicAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.appBarHeight = 56,
  });

  @override
  Size get preferredSize => Size.fromHeight(appBarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withOpacity(0.85),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AppBar(
            title: Text(
              title,
              style: const TextStyle(
                color: AppColors.textOnLight,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: leading,
            automaticallyImplyLeading: automaticallyImplyLeading,
            actions: actions,
            iconTheme: const IconThemeData(color: AppColors.textOnLight),
          ),
        ),
      ),
    );
  }
}

/// Neumorphic Bottom Navigation Bar
/// Bottom Navigation Bar بتأثير Neumorphism
class NeumorphicBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  const NeumorphicBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            offset: const Offset(0, -8),
            blurRadius: 16,
          ),
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.1),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: items,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primaryNavy,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Glassmorphic Stepper
/// Stepper بتأثير الزجاج الضبابي
class GlassmorphicStepper extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;
  final List<IconData> stepIcons;

  const GlassmorphicStepper({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
    required this.stepIcons,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphismContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;
          final isLast = index == totalSteps - 1;

          return Expanded(
            child: Row(
              children: [
                // الدائرة مع الأيقونة
                Expanded(
                  flex: 0,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isCompleted
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.success,
                                    AppColors.success,
                                  ],
                                )
                              : isCurrent
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.primaryNavy,
                                        AppColors.secondaryGold,
                                      ],
                                    )
                                  : null,
                          color: isCompleted || isCurrent
                              ? null
                              : AppColors.cardBackground.withOpacity(0.3),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AppColors.secondaryGold.withOpacity(0.5),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: AppColors.primaryNavy.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                          border: Border.all(
                            color: isCompleted
                                ? AppColors.success.withOpacity(0.5)
                                : isCurrent
                                    ? AppColors.secondaryGold.withOpacity(0.5)
                                    : AppColors.cardBackground.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 28)
                              : Icon(
                                  stepIcons[index],
                                  color: isCurrent ? Colors.white : AppColors.textSecondary,
                                  size: 28,
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stepLabels[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCompleted || isCurrent
                              ? AppColors.primaryNavy
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // الخط الواصل
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: isCompleted
                            ? const LinearGradient(
                                colors: [
                                  AppColors.success,
                                  AppColors.success,
                                ],
                              )
                            : null,
                        color: isCompleted ? null : AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isCompleted
                            ? [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
