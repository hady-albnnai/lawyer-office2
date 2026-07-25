import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  Future<void> _login() async {
    final ok = await ref.read(authControllerProvider.notifier).login(
          _username.text.trim(),
          _password.text,
        );
    if (ok && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final showArchiveStart = prefs.getBool('show_archive_start_after_setup') ?? false;
      if (showArchiveStart) {
        await prefs.setBool('show_archive_start_after_setup', false);
        if (mounted) context.go('/archive-intake');
      } else {
        if (mounted) context.go('/today');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.primaryNavy,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(AppConstants.appIconAsset, height: 92, fit: BoxFit.contain),
                    const SizedBox(height: 16),
                    Text(
                      AppConstants.appDisplayName,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline4.copyWith(
                        color: AppColors.primaryNavy,
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppConstants.appTagline,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppConstants.accentGoldDark),
                    ),
                    const Divider(height: 32),
                    TextField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'اسم الدخول', prefixIcon: Icon(Icons.person)),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock)),
                      onSubmitted: (_) => _login(),
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      Text(auth.error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: auth.isLoading ? null : _login,
                      icon: auth.isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login),
                      label: Text(auth.isLoading ? 'جارٍ الدخول...' : 'دخول'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.primaryNavy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppConstants.appBrandLockupAsset, width: 360, fit: BoxFit.contain),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: AppConstants.accentGold),
              const SizedBox(height: 12),
              const Text('جارٍ تهيئة قاعدة البيانات المحلية...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
