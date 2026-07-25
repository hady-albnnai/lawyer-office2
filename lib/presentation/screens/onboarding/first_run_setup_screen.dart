/// معالج أول تشغيل — مكتب فاضي + بيانات الزبون + كلمة مرور.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/crypto_utils.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/office_settings_provider.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';

const kFirstRunDoneKey = 'first_run_completed_v1';

final firstRunCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kFirstRunDoneKey) ?? false;
});

class FirstRunSetupScreen extends ConsumerStatefulWidget {
  const FirstRunSetupScreen({super.key});

  @override
  ConsumerState<FirstRunSetupScreen> createState() => _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends ConsumerState<FirstRunSetupScreen> {
  final _title = TextEditingController(text: AppConstants.defaultOfficeTitle);
  final _lawyer = TextEditingController(text: AppConstants.defaultLawyerName);
  final _address = TextEditingController(text: AppConstants.defaultAddress);
  final _phone = TextEditingController();
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _question = TextEditingController(text: 'ما اسم مدينتك؟');
  final _answer = TextEditingController();
  bool _saving = false;
  bool _seedDemo = false;

  @override
  void dispose() {
    _title.dispose();
    _lawyer.dispose();
    _address.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('إعداد المكتب لأول مرة', style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy)),
                        const SizedBox(height: 8),
                        Text(
                          'هذه الشاشة تظهر مرة واحدة. أدخل بيانات مكتبك وكلمة مرور حماية محلية.',
                          style: AppTextStyles.bodyMediumSecondary,
                        ),
                        const Divider(height: 28),
                        TextField(controller: _title, decoration: const InputDecoration(labelText: 'اسم المكتب *')),
                        const SizedBox(height: 10),
                        TextField(controller: _lawyer, decoration: const InputDecoration(labelText: 'اسم المحامي الأستاذ *')),
                        const SizedBox(height: 10),
                        TextField(controller: _address, decoration: const InputDecoration(labelText: 'العنوان')),
                        const SizedBox(height: 10),
                        TextField(controller: _phone, decoration: const InputDecoration(labelText: 'الهاتف')),
                        const SizedBox(height: 10),
                        TextField(controller: _username, decoration: const InputDecoration(labelText: 'اسم دخول المدير *')),
                        const SizedBox(height: 10),
                        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة مرور الحماية *')),
                        const SizedBox(height: 10),
                        TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور *')),
                        const SizedBox(height: 10),
                        TextField(controller: _question, decoration: const InputDecoration(labelText: 'سؤال الأمان *')),
                        const SizedBox(height: 10),
                        TextField(controller: _answer, decoration: const InputDecoration(labelText: 'إجابة سؤال الأمان *')),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تحميل بيانات تجريبية للتجربة'),
                          subtitle: const Text('اتركها مغلقة لمكتب فاضي جاهز للعمل الحقيقي'),
                          value: _seedDemo,
                          onChanged: (v) => setState(() => _seedDemo = v),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _finish,
                          icon: const Icon(Icons.check),
                          label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ وبدء العمل'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    if (_title.text.trim().isEmpty || _lawyer.text.trim().isEmpty) {
      _err('اسم المكتب واسم المحامي إلزاميان');
      return;
    }
    if (_username.text.trim().isEmpty) {
      _err('اسم دخول المدير إلزامي');
      return;
    }
    if (_password.text.length < 6) {
      _err('كلمة المرور يجب ألا تقل عن 6 أحرف');
      return;
    }
    if (_password.text != _confirm.text) {
      _err('تأكيد كلمة المرور غير مطابق');
      return;
    }
    if (_question.text.trim().isEmpty || _answer.text.trim().isEmpty) {
      _err('سؤال الأمان وإجابته إلزاميان');
      return;
    }

    setState(() => _saving = true);
    try {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      await settingsRepo.ensureDefaults();
      await settingsRepo.saveOfficeSettings(
        title: _title.text.trim(),
        lawyer: _lawyer.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        userRef: _lawyer.text.trim(),
      );
      await settingsRepo.setSecurityDirect(
        password: _password.text,
        securityQuestion: _question.text.trim(),
        securityAnswer: _answer.text.trim(),
        lockTimeoutMinutes: 10,
        userRef: _lawyer.text.trim(),
      );

      if (!await ref.read(authRepositoryProvider).ownerExists()) {
        await ref.read(authRepositoryProvider).createOwner(
              fullName: _lawyer.text.trim(),
              username: _username.text.trim(),
              password: _password.text,
            );
      }

      await ref.read(officeSettingsProvider.notifier).updateSettings(
            newTitle: _title.text.trim(),
            newLawyerName: _lawyer.text.trim(),
            newAddress: _address.text.trim(),
            newPhone: _phone.text.trim(),
          );

      if (_seedDemo) {
        ref.read(allowDemoSeedProvider.notifier).state = true;
        await ref.read(personRepositoryProvider).seedDemoIfEmpty();
        await ref.read(caseRepositoryProvider).seedDemoIfEmpty();
        await ref.read(documentRepositoryProvider).seedDemoIfEmpty();
        await ref.read(workOrderRepositoryProvider).seedDemoIfEmpty();
        await ref.read(financeRepositoryProvider).seedDemoIfEmpty();
        await ref.read(legalLibraryRepositoryProvider).seedDemoIfEmpty();
      } else {
        ref.read(allowDemoSeedProvider.notifier).state = false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kFirstRunDoneKey, true);
      await prefs.setBool('demo_seed_enabled', _seedDemo);
      await prefs.setBool('show_archive_start_after_setup', true);
      await prefs.setString('security_password_hash_hint', CryptoUtils.hashPassword(_password.text).substring(0, 8));

      ref.invalidate(firstRunCompletedProvider);
      await ref.read(authControllerProvider.notifier).markOwnerCreated();
      if (mounted) context.go('/login');
    } catch (e) {
      _err('فشل الإعداد: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error));
  }
}
