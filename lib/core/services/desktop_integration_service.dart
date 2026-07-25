import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

/// خدمة التكامل العميق مع سطح المكتب (Windows/Mac)
/// مسؤولية هذا الـ Widget هي تغليف التطبيق للتنصت على أحداث الإغلاق
/// وإرسال التطبيق إلى الـ System Tray (بجوار الساعة) بدلاً من إغلاقه بالكامل.
class DesktopIntegrationWrapper extends StatefulWidget {
  final Widget child;
  const DesktopIntegrationWrapper({super.key, required this.child});

  @override
  State<DesktopIntegrationWrapper> createState() => _DesktopIntegrationWrapperState();
}

class _DesktopIntegrationWrapperState extends State<DesktopIntegrationWrapper> with WindowListener, TrayListener {
  
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      _initSystemTray();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    // إعداد قائمة الـ System Tray
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show_app',
            label: 'إظهار التطبيق',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'إغلاق النظام تماماً',
          ),
        ],
      ),
    );
    // ضبط أيقونة الـ Tray (سيحتاج ملف أيقونة حقيقي لاحقاً، حالياً سنتركها افتراضية أو مسار رمزي)
    // await trayManager.setIcon(Platform.isWindows ? 'assets/icons/app_icon.ico' : 'assets/icons/app_icon.png');
  }

  // ---------------------------------------------------------------------------
  // Window Events (إدارة النافذة)
  // ---------------------------------------------------------------------------

  @override
  void onWindowClose() async {
    // بدلاً من إغلاق التطبيق، نقوم بإخفائه ليبقى يعمل في الخلفية (Background Daemon)
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }

  // ---------------------------------------------------------------------------
  // Tray Events (إدارة شريط المهام)
  // ---------------------------------------------------------------------------

  @override
  void onTrayIconMouseDown() async {
    // إظهار التطبيق عند النقر المزدوج أو النقر على الأيقونة
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_app') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      await windowManager.destroy(); // إغلاق التطبيق النهائي
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
