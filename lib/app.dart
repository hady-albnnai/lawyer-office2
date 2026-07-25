import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/services/desktop_integration_service.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/providers/ui_data_providers.dart';
import 'presentation/theme/app_theme.dart';

class LawyerOfficeApp extends ConsumerStatefulWidget {
  const LawyerOfficeApp({super.key});

  @override
  ConsumerState<LawyerOfficeApp> createState() => _LawyerOfficeAppState();
}

class _LawyerOfficeAppState extends ConsumerState<LawyerOfficeApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final demo = prefs.getBool('demo_seed_enabled') ?? false;
      ref.read(allowDemoSeedProvider.notifier).state = demo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return DesktopIntegrationWrapper(
      child: MaterialApp.router(
        title: AppConstants.appWindowTitle,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'SY'),
        supportedLocales: const [Locale('ar', 'SY'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
