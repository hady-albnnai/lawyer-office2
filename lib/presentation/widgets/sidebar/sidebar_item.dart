/// عنصر SideBar (NavItem) لتطبيق مكتب المحامي
/// 
/// هذا الملف ينفذ عناصر SideBar حسب مواصفات
/// PRODUCT_REDESIGN_MASTER_PLAN.md - القسم 3.2
/// 
/// آخر تحديث: 2026-07-14
library;

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'badge_widget.dart';

/// نموذج بيانات لعنصر SideBar
class SidebarItemModel {
  /// المعرف الفريد
  final String id;
  
  /// الاسم الذي يظهر في SideBar
  final String label;
  
  /// الأيقونة
  final IconData icon;
  
  /// المسار (Route)
  final String route;
  
  /// عدد Badge (0 يعني لا يظهر)
  final int badgeCount;
  
  /// نوع Badge
  final BadgeType badgeType;
  
  /// هل هذا العنصر مخفي
  final bool isHidden;
  
  /// هل هذا العنصر معطل
  final bool isDisabled;
  
  /// أداة مساعدة (Tooltip)
  final String? tooltip;
  
  /// العنصر الفرعي (إذا كان هناك قائمة منبثقة)
  final List<SidebarItemModel>? children;

  /// نوع الشارة الخاصة (للـ Office Files)
  final String? badge; // 'active', 'closed', 'needs'

  /// لون مميّز للقسم الرئيسي.
  final Color? accentColor;

  /// هل هذا عنصر بارز (مثل "عمل جديد") — يُرسم كزر مميز
  final bool isProminent;

  const SidebarItemModel({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    this.badgeCount = 0,
    this.badgeType = BadgeType.normal,
    this.isHidden = false,
    this.isDisabled = false,
    this.tooltip,
    this.children,
    this.badge,
    this.accentColor,
    this.isProminent = false,
  });
  
  /// نسخة بلون قسم موروث.
  SidebarItemModel copyWithAccent(Color color) => SidebarItemModel(
        id: id,
        label: label,
        icon: icon,
        route: route,
        badgeCount: badgeCount,
        badgeType: badgeType,
        isHidden: isHidden,
        isDisabled: isDisabled,
        tooltip: tooltip,
        children: children,
        badge: badge,
        accentColor: color,
        isProminent: isProminent,
      );

  /// تحويل إلى widget
  Widget toWidget({
    required BuildContext context,
    required bool isExpanded,
    required String? selectedRoute,
    required void Function(SidebarItemModel) onItemSelected,
  }) {
    return SidebarItem(
      item: this,
      isExpanded: isExpanded,
      selectedRoute: selectedRoute,
      onSelected: onItemSelected,
    );
  }
}

/// widget لعنصر SideBar واحد
class SidebarItem extends StatelessWidget {
  /// نموذج البيانات
  final SidebarItemModel item;
  
  /// هل SideBar موسع
  final bool isExpanded;
  
  /// المسار المختار حاليا
  final String? selectedRoute;
  
  /// دالة عند اختيار العنصر
  final void Function(SidebarItemModel) onSelected;
  
  const SidebarItem({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.selectedRoute,
    required this.onSelected,
  });
  
  @override
  Widget build(BuildContext context) {
    if (item.isHidden) return const SizedBox.shrink();

    final isSelected = selectedRoute == item.route;
    final accent = item.accentColor;

    // ── خلفية العنصر ──
    // عند الاختيار: خلفية ملوّنة خفيفة بلون القسم
    // بدون اختيار: خلفية شفافة
    Color backgroundColor;
    if (isSelected && accent != null) {
      backgroundColor = accent.withValues(alpha: 0.12);
    } else if (isSelected) {
      backgroundColor = AppColors.sidebarHover;
    } else {
      backgroundColor = Colors.transparent;
    }

    // ── لون الأيقونة ──
    // المختار بلون القسم، العادي رمادي هادئ
    Color iconColor;
    if (isSelected && accent != null) {
      iconColor = accent;
    } else if (isSelected) {
      iconColor = AppColors.primaryNavy;
    } else {
      iconColor = AppColors.sidebarIcon;
    }

    // ── لون النص ──
    // المختار بلون القسم (داكن على خلفية فاتحة = مقروء)
    // العادي بلون النص الافتراضي
    TextStyle textStyle;
    if (isSelected && accent != null) {
      textStyle = AppTextStyles.sidebarItem.copyWith(
        color: accent,
        fontWeight: FontWeight.bold,
      );
    } else if (isSelected) {
      textStyle = AppTextStyles.sidebarItem.copyWith(
        color: AppColors.primaryNavy,
        fontWeight: FontWeight.bold,
      );
    } else {
      textStyle = AppTextStyles.sidebarItem;
    }

    final double itemHeight = 48.0;
    final effectiveBadgeCount = item.badgeCount > 0 ? item.badgeCount : 0;

    return Tooltip(
      message: item.tooltip ?? item.label,
      child: InkWell(
        onTap: item.isDisabled ? null : () => onSelected(item),
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.sidebarHover,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: itemHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            // خط جانبي ملوّن عند الاختيار
            border: isSelected && accent != null
                ? Border(right: BorderSide(color: accent, width: 3))
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(item.icon, key: ValueKey(isSelected), color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              if (isExpanded) ...[
                Expanded(
                  child: Text(
                    item.label,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (effectiveBadgeCount > 0) ...[
                  const SizedBox(width: 8),
                  BadgeWidget(count: effectiveBadgeCount, type: item.badgeType, size: 20),
                ],
              ] else ...[
                if (effectiveBadgeCount > 0) ...[
                  const SizedBox(width: 4),
                  BadgeWidget(count: effectiveBadgeCount, type: item.badgeType, size: 18),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// قائمة من عناصر SideBar
class SidebarItemList extends StatelessWidget {
  final List<SidebarItemModel> items;
  final bool isExpanded;
  final String? selectedRoute;
  final void Function(SidebarItemModel) onItemSelected;
  
  const SidebarItemList({
    super.key,
    required this.items,
    required this.isExpanded,
    required this.selectedRoute,
    required this.onItemSelected,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        if (item.children != null && item.children!.isNotEmpty) {
          return _buildExpandableItem(context, item);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: item.toWidget(
            context: context,
            isExpanded: isExpanded,
            selectedRoute: selectedRoute,
            onItemSelected: onItemSelected,
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildExpandableItem(BuildContext context, SidebarItemModel parent) {
    if (!isExpanded) {
      // إذا كان مطوياً، نعرض العنصر الرئيسي كأيقونة فقط (بدون ExpansionTile)
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: parent.toWidget(
          context: context,
          isExpanded: isExpanded,
          selectedRoute: selectedRoute,
          onItemSelected: (item) {
            // نأخذ المستخدم لأول ابن بشكل افتراضي لتسهيل الوصول عند الطي
            if (parent.children!.isNotEmpty) {
              onItemSelected(parent.children!.first);
            } else {
              onItemSelected(parent);
            }
          },
        ),
      );
    }

    final hasSelectedChild = parent.children!.any((c) => selectedRoute == c.route) || selectedRoute == parent.route;
    final accent = parent.accentColor;

    // نفس منطق العناصر العادية: لون القسم عند التفعيل
    final tileIconColor = hasSelectedChild && accent != null
        ? accent
        : (hasSelectedChild ? AppColors.primaryNavy : AppColors.sidebarIcon);

    final tileTextStyle = hasSelectedChild && accent != null
        ? AppTextStyles.sidebarItem.copyWith(color: accent, fontWeight: FontWeight.bold)
        : (hasSelectedChild
            ? AppTextStyles.sidebarItem.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)
            : AppTextStyles.sidebarItem);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: hasSelectedChild,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: hasSelectedChild && accent != null
            ? accent.withValues(alpha: 0.06)
            : Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        leading: Icon(parent.icon, color: tileIconColor, size: 22),
        title: Text(parent.label, style: tileTextStyle),
        children: parent.children!.map((child) {
          final tinted = child.accentColor == null && accent != null
              ? child.copyWithAccent(accent)
              : child;
          return Padding(
            padding: const EdgeInsets.only(right: 16.0, bottom: 4.0),
            child: tinted.toWidget(
              context: context,
              isExpanded: isExpanded,
              selectedRoute: selectedRoute,
              onItemSelected: onItemSelected,
            ),
          );
        }).toList(),
      ),
    );
  }
}
