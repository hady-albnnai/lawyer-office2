/// الهيكل الرئيسي الموحّد: SideBar + ShellRoutes.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/permission_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../providers/auth_providers.dart';
import '../providers/office_settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/sidebar/nav_sidebar.dart';
import '../widgets/sidebar/sidebar_item.dart';
import 'search_reports/search_report_models.dart';

/// غلاف التطبيق مع الشريط الجانبي الموحد.
class MainShellScreen extends ConsumerWidget {
  final Widget child;
  const MainShellScreen({super.key, required this.child});

  static const _shellRoutes = <String>{
    '/today',
    '/agenda',
    '/files',
    '/persons',
    '/work-orders',
    '/finance',
    '/documents',
    '/legal-library',
    '/search-reports',
    '/settings',
    '/cases',
    '/companies',
    '/contracts',
    '/procedures',
    '/tasks',
    '/printing',
    '/archive',
    '/archive-intake',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(officeSettingsProvider);
    final currentUri = GoRouterState.of(context).uri;
    final location = currentUri.path;
    
    // نحدد المسار للـ Sidebar بناءً على بداية الرابط مع احترام تبويبي ملفات المكتب الجاري/المنتهي.
    String selectedRoute = '/today';
    if (location.startsWith('/templates') || location.startsWith('/contracts/templates')) selectedRoute = '/templates';
    else if (location == '/files' && currentUri.queryParameters['status'] == 'completed') selectedRoute = '/files?status=completed';
    else if (location == '/files') selectedRoute = '/files?status=active';
    else if (location.startsWith('/archive-intake')) selectedRoute = '/archive-intake';
    else if (location.startsWith('/cases') || location.startsWith('/companies') || location.startsWith('/contracts') || location.startsWith('/procedures') || location.startsWith('/poa') || location.startsWith('/persons') || location.startsWith('/archive')) selectedRoute = '/files';
    else if (location.startsWith('/work-orders') || location.startsWith('/tasks')) selectedRoute = '/work-orders';
    else if (location.startsWith('/agenda')) selectedRoute = '/agenda';
    else if (location.startsWith('/finance')) selectedRoute = '/finance';
    else if (location.startsWith('/legal-library')) selectedRoute = '/legal-library';
    else if (location.startsWith('/printing') || location.startsWith('/search-reports')) selectedRoute = '/search-reports';
    else if (location.startsWith('/settings')) selectedRoute = '/settings';

    final officeName = settingsAsync.maybeWhen(
      data: (s) => s.officeTitle,
      orElse: () => AppConstants.defaultOfficeTitle,
    );
    final lawyerName = settingsAsync.maybeWhen(
      data: (s) => s.lawyerName,
      orElse: () => AppConstants.defaultLawyerName,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            AppSidebar(
              items: _filterSidebarItems(getDefaultSidebarItems(), ref),
              officeName: officeName,
              lawyerName: lawyerName,
              logo: SizedBox(
                width: 52,
                height: 52,
                child: Image.asset(
                  AppConstants.appIconAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.verified_user, color: AppConstants.accentGold),
                ),
              ),
              version: '6.2.0',
            ),
            // Force selected route highlight via provider sync
            _SidebarRouteSync(selectedRoute: selectedRoute),
            const _SessionHeartbeat(),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.cardBorder),
            Expanded(
              child: Column(
                children: [
                  _TopBar(officeName: officeName, lawyerName: lawyerName),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SessionHeartbeat extends ConsumerStatefulWidget {
  const _SessionHeartbeat();

  @override
  ConsumerState<_SessionHeartbeat> createState() => _SessionHeartbeatState();
}

class _SessionHeartbeatState extends ConsumerState<_SessionHeartbeat> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).touchActivity();
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.read(authControllerProvider.notifier).touchActivity();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SidebarRouteSync extends ConsumerWidget {
  final String selectedRoute;
  const _SidebarRouteSync({required this.selectedRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(sidebarStateProvider);
      if (state.selectedRoute != selectedRoute) {
        ref.read(sidebarStateProvider.notifier).state =
            state.copyWith(selectedRoute: selectedRoute);
      }
    });
    return const SizedBox.shrink();
  }
}

class _TopBar extends ConsumerWidget {
  final String officeName;
  final String lawyerName;
  const _TopBar({required this.officeName, required this.lawyerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    return Material(
      color: AppConstants.primaryNavy,
      elevation: 1,
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: Image.asset(
                  AppConstants.appIconAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.verified_user, color: AppConstants.accentGold),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.appDisplayName,
                    style: AppTextStyles.headline6.copyWith(
                      color: Colors.white,
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    AppConstants.appTagline,
                    style: AppTextStyles.bodySmall.copyWith(color: AppConstants.accentGold, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Text(
                '$officeName • $lawyerName',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withOpacity(0.76)),
              ),
              
              const SizedBox(width: 32),
              
              // محرك البحث الشامل والذكاء (The Command Palette / Omnibar)
              Expanded(
                child: Container(
                  height: 40,
                  constraints: const BoxConstraints(maxWidth: 500),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.accentGold.withOpacity(0.3)),
                  ),
                  child: InkWell(
                    onTap: () => _showOmnibarSearch(context, ref),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppConstants.accentGold, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "بحث شامل أو أمر سريع (Ctrl+K)...",
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 24),
              
              // إنشاء الملفات الجديدة يتم حصراً من مكتب العمل عبر زر "إنشاء جديد".
                            if (permissions.can(PermissionKeys.settingsView))
                IconButton(
                  tooltip: "الإعدادات",
                  onPressed: () => context.go("/settings"),
                  icon: const Icon(Icons.settings_outlined, color: AppConstants.accentGold),
                ),
              IconButton(
                tooltip: "تسجيل الخروج",
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout, color: AppConstants.accentGold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOmnibarSearch(BuildContext context, WidgetRef ref) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Omnibar",
      barrierColor: Colors.black.withOpacity(0.5),
      pageBuilder: (ctx, anim1, anim2) {
        return const Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 100),
            child: Material(
              color: Colors.transparent,
              child: _OmnibarPopup(),
            ),
          ),
        );
      },
    );
  }
}

class _OmnibarPopup extends ConsumerStatefulWidget {
  const _OmnibarPopup();
  @override
  ConsumerState<_OmnibarPopup> createState() => _OmnibarPopupState();
}

class _OmnibarPopupState extends ConsumerState<_OmnibarPopup> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<dynamic> _hits = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _normalizeCommand(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه');
  }

  bool _commandMatches(String command, String query) {
    final normalizedCommand = _normalizeCommand(command);
    final normalizedQuery = _normalizeCommand(query);
    return normalizedCommand.contains(normalizedQuery);
  }

  void _search(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // الأوامر السريعة لا تحتاج تأخير زمني لأنها تعمل بالذاكرة فورا
    if (query.startsWith("/")) {
      final commands = [
        {"title": "فتح الملفات الجارية", "cmd": "/ملفات جارية", "route": "files_running", "subtitle": "عرض الملفات الحية"},
        {"title": "فتح الملفات المنتهية", "cmd": "/ملفات منتهية", "route": "files_closed", "subtitle": "عرض ملفات الأرشيف المنتهي"},
      ];
      setState(() {
        _hits = commands.where((c) => _commandMatches(c["cmd"]!, query)).toList();
      });
      return;
    }

    // تأخير البحث العميق بمقدار 300 ملي ثانية (Quantum Debouncing)
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        setState(() => _hits = []);
        return;
      }
      
      final engine = ref.read(searchReportEngineProvider); 
      final results = engine.search(query).take(5).toList(); 

      setState(() {
        _hits = results.map((hit) => {
          "title": hit.title,
          "subtitle": hit.subtitle,
          "route": hit.routeHint
        }).toList();
        
        if (_hits.isEmpty) {
          _hits.add({
            "title": "لا يوجد نتائج سريعة لـ: $query",
            "subtitle": "اضغط هنا للبحث المتقدم في السجلات",
            "route": "/search-reports",
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _search,
              style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy),
              decoration: InputDecoration(
                hintText: "ما الذي تبحث عنه؟ (اكتب / للأوامر السريعة)",
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryNavy),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_hits.isNotEmpty) const Divider(height: 1, thickness: 1),
          if (_hits.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _hits.length,
                itemBuilder: (ctx, i) {
                  final hit = _hits[i];
                  return ListTile(
                    leading: const Icon(Icons.arrow_forward_ios, size: 16),
                    title: Text(hit["title"] ?? "", style: AppTextStyles.labelLarge),
                    subtitle: hit["subtitle"] != null ? Text(hit["subtitle"]!) : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (hit["route"] == "/search-reports") {
                        context.go("/search-reports");
                      } else if (hit["route"] == "files_running") {
                        context.go("/files?status=active");
                      } else if (hit["route"] == "files_closed") {
                        context.go("/files?status=completed");
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class MainLayoutScreen extends StatelessWidget {

  const MainLayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainShellScreen(child: SizedBox.shrink());
  }
}

List<SidebarItemModel> _filterSidebarItems(List<SidebarItemModel> items, WidgetRef ref) {
  final perms = ref.watch(permissionServiceProvider);
  bool allowed(String route) {
    if (route.startsWith('/today')) return true;
    if (route.startsWith('/agenda') || route.startsWith('/tasks')) return perms.can(PermissionKeys.casesView);
    if (route.startsWith('/work-orders')) return perms.can(PermissionKeys.workOrdersView);
    if (route.startsWith('/finance')) return perms.can(PermissionKeys.financeView);
    if (route.startsWith('/archive-intake')) return perms.can(PermissionKeys.archiveIntakeView);
    if (route.startsWith('/files')) return perms.canAny(const [PermissionKeys.casesView, PermissionKeys.proceduresView, PermissionKeys.contractsView, PermissionKeys.companiesView, PermissionKeys.poaView]);
    if (route.startsWith('/documents')) return perms.can(PermissionKeys.documentsView);
    if (route.startsWith('/legal-library')) return perms.can(PermissionKeys.libraryView);
    if (route.startsWith('/search-reports')) return perms.can(PermissionKeys.searchView);
    if (route.startsWith('/settings')) return perms.can(PermissionKeys.settingsView);
    if (route.startsWith('/cases')) return perms.can(PermissionKeys.casesView);
    if (route.startsWith('/companies')) return perms.can(PermissionKeys.companiesView);
    if (route.startsWith('/templates')) return perms.can(PermissionKeys.templatesView);
    if (route.startsWith('/contracts/templates')) return perms.can(PermissionKeys.templatesView);
    if (route.startsWith('/contracts')) return perms.can(PermissionKeys.contractsView);
    if (route.startsWith('/procedures')) return perms.can(PermissionKeys.proceduresView);
    if (route.startsWith('/poa')) return perms.can(PermissionKeys.poaView);
    if (route.startsWith('/persons') || route.startsWith('/archive')) return perms.can(PermissionKeys.personsView);
    if (route.startsWith('/printing')) return perms.can(PermissionKeys.reportsView);
    return true;
  }

  SidebarItemModel? filterOne(SidebarItemModel item) {
    final children = item.children?.map(filterOne).whereType<SidebarItemModel>().toList();
    if ((children != null && children.isNotEmpty) || allowed(item.route)) {
      return SidebarItemModel(
        id: item.id,
        label: item.label,
        icon: item.icon,
        route: item.route,
        badgeCount: item.badgeCount,
        badgeType: item.badgeType,
        isHidden: item.isHidden,
        isDisabled: item.isDisabled,
        tooltip: item.tooltip,
        children: children,
      );
    }
    return null;
  }

  return items.map(filterOne).whereType<SidebarItemModel>().toList();
}
