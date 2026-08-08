/// SideBar الرئيسي لتطبيق مكتب المحامي — التصميم المعاد
///
/// الفلسفة: 4 مجموعات تعكس يوم المحامي السوري
/// 1. العمل اليومي — ما يستخدمه كل صباح
/// 2. الملفات والأشخاص — إدارة المحتوى
/// 3. الأدوات والمرجع — بحث ومكتبة ومالية
/// 4. الإدارة — أرشيف وإعدادات + AI مستقبلاً
///
/// جاهز للذكاء الاصطناعي: مكان محجوز للمساعد الذكي
///
/// آخر تحديث: 2026-08-06
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/custom_icons.dart';
import 'sidebar_item.dart';

/// حالة SideBar (موسع/طوي)
class SidebarState {
  final bool isExpanded;
  final String? selectedRoute;

  const SidebarState({
    this.isExpanded = true,
    this.selectedRoute,
  });

  SidebarState copyWith({
    bool? isExpanded,
    String? selectedRoute,
  }) {
    return SidebarState(
      isExpanded: isExpanded ?? this.isExpanded,
      selectedRoute: selectedRoute ?? this.selectedRoute,
    );
  }
}

/// Provider لحالة SideBar
final sidebarStateProvider = StateProvider<SidebarState>((ref) {
  return const SidebarState(isExpanded: true);
});

/// SideBar الرئيسي
class NavSidebar extends ConsumerWidget {
  final List<SidebarGroupModel> groups;
  final Widget? header;
  final Widget? footer;
  final double expandedWidth;
  final double collapsedWidth;
  final Color backgroundColor;
  final Color shadowColor;
  final void Function(bool isExpanded)? onExpandedChanged;

  const NavSidebar({
    super.key,
    required this.groups,
    this.header,
    this.footer,
    this.expandedWidth = 280,
    this.collapsedWidth = 70,
    this.backgroundColor = AppColors.sidebarBackground,
    this.shadowColor = AppColors.shadowMedium,
    this.onExpandedChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sidebarStateProvider);
    final isExpanded = state.isExpanded;
    final selectedRoute =
        state.selectedRoute ?? GoRouterState.of(context).uri.toString();

    return Container(
      width: isExpanded ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          if (header != null) ...[
            Container(
              height: isExpanded ? 104 : 72,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.center,
              child: header,
            ),
            const Divider(color: AppColors.cardBorder, height: 1, thickness: 0.5),
          ],

          // قائمة المجموعات
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int g = 0; g < groups.length; g++) ...[
                    if (g > 0) const SizedBox(height: 4),
                    _buildGroupLabel(groups[g], isExpanded),
                    const SizedBox(height: 4),
                    ...groups[g].items.map((item) {
                      // العنصر المميز "عمل جديد"
                      if (item.isProminent) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildProminentButton(
                              context, ref, item, isExpanded, selectedRoute),
                        );
                      }
                      // عنصر عادي أو قابل للتوسيع
                      if (item.children != null && item.children!.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: _buildExpandableItem(
                              context, ref, item, isExpanded, selectedRoute),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: item.toWidget(
                          context: context,
                          isExpanded: isExpanded,
                          selectedRoute: selectedRoute,
                          onItemSelected: (i) => _navigate(ref, state, context, i),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          // Footer
          if (footer != null) ...[
            const Divider(color: AppColors.cardBorder, height: 1, thickness: 0.5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: footer,
            ),
          ],

          // زر طي/توسعة
          Container(
            height: 48,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: IconButton(
              icon: Icon(
                isExpanded ? Icons.chevron_left : Icons.chevron_right,
                color: AppColors.textPrimary,
                size: 24,
              ),
              tooltip: isExpanded ? 'طي القائمة' : 'توسيع القائمة',
              onPressed: () {
                final newState = !isExpanded;
                ref.read(sidebarStateProvider.notifier).state =
                    state.copyWith(isExpanded: newState);
                onExpandedChanged?.call(newState);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// عنوان المجموعة (يظهر فقط عند التوسيع)
  Widget _buildGroupLabel(SidebarGroupModel group, bool isExpanded) {
    if (!isExpanded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 10, bottom: 2),
      child: Text(
        group.label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.secondaryGold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// زر "عمل جديد" المميز
  Widget _buildProminentButton(BuildContext context, WidgetRef ref,
      SidebarItemModel item, bool isExpanded, String? selectedRoute) {
    final isSelected = selectedRoute == item.route;

    if (!isExpanded) {
      return Tooltip(
        message: item.label,
        child: InkWell(
          onTap: () => _navigate(ref, ref.read(sidebarStateProvider), context, item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryNavy,
                  AppColors.primaryNavy.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.add_circle, color: AppColors.secondaryGold, size: 26),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _navigate(ref, ref.read(sidebarStateProvider), context, item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryNavy,
              AppColors.primaryNavy.withOpacity(0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.secondaryGold, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryNavy.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.secondaryGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_circle_outline,
                  color: AppColors.secondaryGold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  /// عنصر قابل للتوسيع
  Widget _buildExpandableItem(BuildContext context, WidgetRef ref,
      SidebarItemModel parent, bool isExpanded, String? selectedRoute) {
    if (!isExpanded) {
      return parent.toWidget(
        context: context,
        isExpanded: isExpanded,
        selectedRoute: selectedRoute,
        onItemSelected: (item) {
          if (parent.children!.isNotEmpty) {
            _navigate(ref, ref.read(sidebarStateProvider), context,
                parent.children!.first);
          }
        },
      );
    }

    final hasSelectedChild = parent.children!
            .any((c) => selectedRoute == c.route) ||
        selectedRoute == parent.route;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: hasSelectedChild,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(right: 8),
        // النقر على العنوان ينقل مباشرة إلى صفحة الأب (مثلاً "النماذج
        // القانونية")، فلا يحتاج المستخدم للضغط مرتين للدخول، بينما يبقى
        // سهم التوسيع يمكّن فتح/طيّ الفروع.
        onTap: () {
          if (parent.route.isNotEmpty) {
            _navigate(ref, ref.read(sidebarStateProvider), context, parent);
          }
        },
        leading: Icon(
          parent.icon,
          color: parent.accentColor ??
              (hasSelectedChild ? AppColors.primaryNavy : AppColors.sidebarIcon),
          size: 22,
        ),
        title: Text(
          parent.label,
          style: hasSelectedChild
              ? AppTextStyles.sidebarItem.copyWith(
                  color: parent.accentColor ?? AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                )
              : AppTextStyles.sidebarItem,
        ),
        children: parent.children!.map((child) {
          final tinted =
              child.accentColor == null && parent.accentColor != null
                  ? child.copyWithAccent(parent.accentColor!)
                  : child;
          return Padding(
            padding: const EdgeInsets.only(right: 16.0, bottom: 4.0),
            child: tinted.toWidget(
              context: context,
              isExpanded: isExpanded,
              selectedRoute: selectedRoute,
              onItemSelected: (i) =>
                  _navigate(ref, ref.read(sidebarStateProvider), context, i),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _navigate(
      WidgetRef ref, SidebarState state, BuildContext context, SidebarItemModel item) {
    ref.read(sidebarStateProvider.notifier).state =
        state.copyWith(selectedRoute: item.route);
    context.go(item.route);
  }
}

// =============================================================================
// نموذج مجموعة عناصر (Group)
// =============================================================================

class SidebarGroupModel {
  final String label;
  final List<SidebarItemModel> items;
  final Color? accentColor;

  const SidebarGroupModel({
    required this.label,
    required this.items,
    this.accentColor,
  });
}

// =============================================================================
// AppSidebar — السايدبار الرئيسي مع رأس وتذييل
// =============================================================================

extension SidebarItemModelExtension on SidebarItemModel {
  SidebarItemModel copyWith({int? badgeCount}) {
    return SidebarItemModel(
      id: id,
      label: label,
      icon: icon,
      route: route,
      children: children,
      badge: badge,
      isProminent: isProminent,
      accentColor: accentColor,
      badgeCount: badgeCount ?? this.badgeCount,
    );
  }
}

class AppSidebar extends NavSidebar {
  final String officeName;
  final String lawyerName;
  final Widget? logo;
  final String version;

  const AppSidebar({
    super.key,
    required List<SidebarGroupModel> groups,
    this.officeName = 'مكتب المحامي',
    this.lawyerName = 'هادي فيصل البني',
    this.logo,
    this.version = '6.2.0',
    super.expandedWidth = 280,
    super.collapsedWidth = 70,
  }) : super(groups: groups);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavSidebar(
      groups: groups,
      header: _buildHeader(context, ref),
      footer: _buildFooter(context, ref),
      expandedWidth: expandedWidth,
      collapsedWidth: collapsedWidth,
      onExpandedChanged: onExpandedChanged,
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(sidebarStateProvider).isExpanded;

    final logoWidget = logo ??
        Image.asset(
          AppConstants.appIconAsset,
          width: isExpanded ? 52 : 42,
          height: isExpanded ? 52 : 42,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.verified_user,
            color: AppColors.primaryNavy,
            size: isExpanded ? 42 : 34,
          ),
        );

    if (!isExpanded) return logoWidget;

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        logoWidget,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appDisplayName,
                style: AppTextStyles.headline6.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                AppConstants.appTagline,
                style: AppTextStyles.bodySmallSecondary.copyWith(
                  color: AppConstants.accentGoldDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                officeName,
                style: AppTextStyles.bodySmallSecondary.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(sidebarStateProvider).isExpanded;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, color: AppColors.textSecondary, size: 16),
        if (isExpanded) ...[
          const SizedBox(width: 8),
          Text('الإصدار $version', style: AppTextStyles.bodySmallSecondary),
        ],
      ],
    );
  }
}

// =============================================================================
// ألوان القائمة الجانبية — كحلي + ذهبي فقط (هوية التطبيق)
// =============================================================================

class SidebarPalette {
  const SidebarPalette._();

  /// اللون الأساسي للأيقونات والنصوص = كحلي التطبيق
  static const Color primary = AppColors.primaryNavy;

  /// لون التمييز = ذهبي التطبيق
  static const Color accent = AppColors.secondaryGold;

  /// خلفية العنصر المختار
  static const Color selected = Color(0xFF1A2332); // كحلي داكن
}

// =============================================================================
// التعريف الجديد: 4 مجموعات / كلها قوائم منسدلة / ألوان موحدة
// =============================================================================

List<SidebarGroupModel> getDefaultSidebarGroups() {
  return [
    // ── المجموعة 1: العمل اليومي ──
    const SidebarGroupModel(
      label: 'العمل اليومي',
      items: [
        SidebarItemModel(
          id: 'daily_workspace',
          label: 'العمل اليومي',
          icon: Icons.dashboard_outlined,
          route: '/today',
          children: [
            SidebarItemModel(id: 'ws_today', label: 'لوحة اليوم', icon: Icons.today_outlined, route: '/today'),
            SidebarItemModel(id: 'ws_agenda', label: 'الأجندة', icon: Icons.calendar_month_outlined, route: '/agenda'),
            SidebarItemModel(id: 'ws_new', label: 'عمل جديد', icon: Icons.add_circle_outline, route: '/new-work', isProminent: true),
            SidebarItemModel(id: 'ws_wo', label: 'أوامر العمل', icon: Icons.assignment_ind_outlined, route: '/work-orders'),
          ],
        ),
      ],
    ),

    // ── المجموعة 2: الملفات والأشخاص ──
    const SidebarGroupModel(
      label: 'الملفات والأشخاص',
      items: [
        SidebarItemModel(
          id: 'office_files',
          label: 'ملفات المكتب',
          icon: Icons.folder_special_outlined,
          route: '/files',
          children: [
            SidebarItemModel(id: 'of_active', label: 'الملفات الجارية', icon: Icons.pending_actions, route: '/files?status=active'),
            SidebarItemModel(id: 'of_completed', label: 'الملفات المنتهية', icon: Icons.inventory_2_outlined, route: '/files?status=completed'),
            SidebarItemModel(id: 'of_agencies', label: 'ملفات الوكالات', icon: Icons.verified_user_outlined, route: '/files/agencies'),
          ],
        ),
        SidebarItemModel(
          id: 'persons',
          label: 'الأشخاص والجهات',
          icon: Icons.people_alt_outlined,
          route: '/persons',
          children: [
            SidebarItemModel(id: 'p_all', label: 'كل الأشخاص', icon: Icons.people_outline, route: '/persons'),
            SidebarItemModel(id: 'p_clients', label: 'الموكلون', icon: Icons.person_outline, route: '/persons?role=client'),
            SidebarItemModel(id: 'p_opponents', label: 'الخصوم', icon: Icons.person_off_outlined, route: '/persons?role=opponent'),
            SidebarItemModel(id: 'p_lawyers', label: 'محامو الخصوم', icon: Icons.gavel_outlined, route: '/persons?role=opponentLawyer'),
            SidebarItemModel(id: 'p_companies', label: 'الشركات والجهات', icon: Icons.business_outlined, route: '/persons?role=legalEntity'),
          ],
        ),
      ],
    ),

    // ── المجموعة 3: الأدوات والمرجع ──
    const SidebarGroupModel(
      label: 'الأدوات والمرجع',
      items: [
        SidebarItemModel(
          id: 'finance',
          label: 'المالية والصندوق',
          icon: Icons.account_balance_wallet_outlined,
          route: '/finance',
          children: [
            SidebarItemModel(id: 'f_dashboard', label: 'لوحة مالية', icon: Icons.dashboard_outlined, route: '/finance'),
            SidebarItemModel(id: 'f_agreements', label: 'اتفاقيات الأتعاب', icon: Icons.handshake_outlined, route: '/finance?tab=agreements'),
            SidebarItemModel(id: 'f_payments', label: 'الدفعات وسندات القبض', icon: Icons.payments_outlined, route: '/finance?tab=payments'),
            SidebarItemModel(id: 'f_expenses', label: 'المصاريف', icon: Icons.receipt_long_outlined, route: '/finance?tab=expenses'),
            SidebarItemModel(id: 'f_cashbox', label: 'الصندوق', icon: Icons.savings_outlined, route: '/finance?tab=cashbox'),
          ],
        ),
        SidebarItemModel(
          id: 'legal_templates',
          label: 'النماذج القانونية',
          icon: Icons.article_outlined,
          route: '/templates',
          children: [
            SidebarItemModel(id: 't_all', label: 'كل النماذج', icon: Icons.folder_outlined, route: '/templates'),
            SidebarItemModel(id: 't_contracts', label: 'قوالب العقود', icon: Icons.description_outlined, route: '/templates?category=عقد'),
            SidebarItemModel(id: 't_courts', label: 'قوالب الدعاوى', icon: Icons.gavel_outlined, route: '/templates?category=لائحة دعوى'),
            SidebarItemModel(id: 't_memos', label: 'المذكرات', icon: Icons.note_outlined, route: '/templates?category=مذكرة'),
            SidebarItemModel(id: 't_admin', label: 'قوالب الإجراءات', icon: Icons.assignment_outlined, route: '/templates?category=طلب إداري'),
          ],
        ),
        SidebarItemModel(
          id: 'search_reports',
          label: 'البحث والتقارير',
          icon: Icons.search_outlined,
          route: '/search-reports',
          children: [
            SidebarItemModel(id: 'r_search', label: 'البحث الشامل', icon: Icons.manage_search, route: '/search-reports'),
            SidebarItemModel(id: 'r_print', label: 'الطباعة والتصدير', icon: Icons.print_outlined, route: '/printing'),
          ],
        ),
        SidebarItemModel(
          id: 'legal_library',
          label: 'المكتبة القانونية',
          icon: Icons.local_library_outlined,
          route: '/legal-library',
          children: [
            SidebarItemModel(id: 'l_all', label: 'كل المكتبة', icon: Icons.local_library_outlined, route: '/legal-library'),
            SidebarItemModel(id: 'l_laws', label: 'القوانين السورية', icon: Icons.menu_book_outlined, route: '/legal-library?section=laws'),
            SidebarItemModel(id: 'l_precedents', label: 'الاجتهادات', icon: Icons.balance_outlined, route: '/legal-library?section=precedents'),
            SidebarItemModel(id: 'l_favorites', label: 'المفضلة', icon: Icons.bookmark_outline, route: '/legal-library?section=favorites'),
          ],
        ),
      ],
    ),

    // ── المجموعة 4: الإدارة ──
    const SidebarGroupModel(
      label: 'الإدارة',
      items: [
        SidebarItemModel(
          id: 'admin',
          label: 'إدارة المكتب',
          icon: Icons.admin_panel_settings_outlined,
          route: '/archive-intake',
          children: [
            SidebarItemModel(id: 'a_archive', label: 'إدخال الأرشيف', icon: Icons.archive_outlined, route: '/archive-intake'),
            SidebarItemModel(id: 'a_settings', label: 'الإعدادات', icon: Icons.settings_outlined, route: '/settings'),
          ],
        ),
      ],
    ),
  ];
}
