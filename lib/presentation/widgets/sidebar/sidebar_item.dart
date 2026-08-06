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

    // ── الألوان موحدة: كحلي + ذهبي فقط ──
    // عادي: أيقونة رمادية + نص رمادي
    // مختار: أيقونة ذهبية + نص كحلي غامق + خلفية كحلي خفيف + خط ذهبي يمين
    final Color backgroundColor = isSelected
        ? AppColors.primaryNavy.withValues(alpha: 0.08)
        : Colors.transparent;

    final Color iconColor = isSelected
        ? AppColors.secondaryGold
        : AppColors.sidebarIcon;

    final TextStyle textStyle = isSelected
        ? AppTextStyles.sidebarItem.copyWith(
            color: AppColors.primaryNavy,
            fontWeight: FontWeight.bold,
          )
        : AppTextStyles.sidebarItem;

    final double itemHeight = 44.0;
    final effectiveBadgeCount = item.badgeCount > 0 ? item.badgeCount : 0;

    return Tooltip(
      message: item.tooltip ?? item.label,
      child: InkWell(
        onTap: item.isDisabled ? null : () => onSelected(item),
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.primaryNavy.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: itemHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border(right: BorderSide(color: AppColors.secondaryGold, width: 3))
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(item.icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
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
                  const SizedBox(width: 6),
                  BadgeWidget(count: effectiveBadgeCount, type: item.badgeType, size: 18),
                ],
              ] else ...[
                if (effectiveBadgeCount > 0) ...[
                  const SizedBox(width: 2),
                  BadgeWidget(count: effectiveBadgeCount, type: item.badgeType, size: 16),
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

    // ألوان موحدة: كحلي + ذهبي
    final tileIconColor = hasSelectedChild ? AppColors.secondaryGold : AppColors.sidebarIcon;
    final tileTextStyle = hasSelectedChild
        ? AppTextStyles.sidebarItem.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)
        : AppTextStyles.sidebarItem;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: hasSelectedChild,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.04),
        collapsedBackgroundColor: Colors.transparent,
        leading: Icon(parent.icon, color: tileIconColor, size: 20),
        title: Text(parent.label, style: tileTextStyle),
        children: parent.children!.map((child) {
          return Padding(
            padding: const EdgeInsets.only(right: 16.0, bottom: 2.0),
            child: child.toWidget(
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
