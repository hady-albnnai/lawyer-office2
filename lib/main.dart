import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'app.dart';
import 'core/constants/app_constants.dart';

/// نقطة انطلاق تطبيق إدارة وأرشفة مكتب المحاماة السوري (V6.2 Offline-First)
/// التحديث الماسي: Native Desktop Integration (Windows/Mac)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة الإضافات الخاصة بسطح المكتب فقط إذا كان التطبيق يعمل على الكمبيوتر
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    // 1. تهيئة الإشعارات الأصلية
    await localNotifier.setup(appName: AppConstants.appDisplayName, shortcutPolicy: ShortcutPolicy.requireCreate);
    
    // 2. تهيئة نافذة التطبيق الأساسية
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(1024, 768),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: AppConstants.appWindowTitle,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      
      // إرسال إشعار ترحيبي عبر النظام الأصلي
      LocalNotification notification = LocalNotification(
        title: AppConstants.appDisplayName,
        body: 'أهلاً بك، المنصة الرقمية للمحامي جاهزة للعمل.',
      );
      notification.show();
    });
  }

  // تشغيل التطبيق مغلفاً بمزود الحالة Riverpod ProviderScope
  runApp(
    const ProviderScope(
      child: LawyerOfficeApp(),
    ),
  );
}
