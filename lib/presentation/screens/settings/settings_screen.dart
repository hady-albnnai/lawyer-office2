/// شاشة الإعدادات والأمان والنسخ - المرحلة 10.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/archive_intake_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/app_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import 'settings_models.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsHubProvider);

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إدارة المكتب'),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              indicatorColor: AppColors.secondaryGold,
              labelColor: AppColors.secondaryGold,
              unselectedLabelColor: AppColors.textOnLight.withOpacity(0.75),
              labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'بيانات المكتب'),
                Tab(text: 'الأمان'),
                Tab(text: 'المستخدمون والصلاحيات'),
                Tab(text: 'سجل المسؤولية'),
                Tab(text: 'النسخ الاحتياطي'),
                Tab(text: 'القوائم المرجعية'),
              ],
            ),
          ),
          body: Column(
            children: [
              if (state.lastMessage != null)
                MaterialBanner(
                  content: Text(state.lastMessage!),
                  actions: [
                    TextButton(
                      onPressed: () => ref.read(settingsHubProvider.notifier).clearMessage(),
                      child: const Text('إخفاء'),
                    ),
                  ],
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _OfficeTab(),
                    _SecurityTab(),
                    _UsersRolesTab(),
                    _AuditTab(),
                    _BackupTab(),
                    _LookupsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficeTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_OfficeTab> createState() => _OfficeTabState();
}

class _OfficeTabState extends ConsumerState<_OfficeTab> {
  late final TextEditingController _title;
  late final TextEditingController _lawyer;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _logo;
  late final TextEditingController _signature;
  late String _uiFont;
  late String _printFont;
  late int _woPriority;
  late bool _libFav;

  @override
  void initState() {
    super.initState();
    final p = ref.read(settingsHubProvider).preferences;
    _title = TextEditingController(text: p.officeTitle);
    _lawyer = TextEditingController(text: p.lawyerName);
    _address = TextEditingController(text: p.officeAddress);
    _phone = TextEditingController(text: p.officePhone);
    _email = TextEditingController(text: p.officeEmail);
    _logo = TextEditingController(text: p.logoPath);
    _signature = TextEditingController(text: p.signaturePath);
    _uiFont = p.uiFont;
    _printFont = p.printFont;
    _woPriority = p.workOrderDefaultPriority;
    _libFav = p.libraryAutoFavoritePrinciples;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('بيانات المكتب والترويسة', style: AppTextStyles.headline5.copyWith(color: AppColors.primaryNavy)),
                const SizedBox(height: 8),
                Text('تظهر في الشاشات وتقارير PDF.', style: AppTextStyles.bodySmallSecondary),
                const Divider(height: 28),
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'اسم المكتب *', prefixIcon: Icon(Icons.business))),
                const SizedBox(height: 12),
                TextField(controller: _lawyer, decoration: const InputDecoration(labelText: 'اسم المحامي الأستاذ *', prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 12),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'العنوان', prefixIcon: Icon(Icons.location_on))),
                const SizedBox(height: 12),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'الهاتف / واتساب', prefixIcon: Icon(Icons.phone))),
                const SizedBox(height: 12),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email))),
                const SizedBox(height: 12),
                TextField(controller: _logo, decoration: const InputDecoration(labelText: 'مسار الشعار (محلي)', prefixIcon: Icon(Icons.image))),
                const SizedBox(height: 12),
                TextField(controller: _signature, decoration: const InputDecoration(labelText: 'مسار التوقيع (محلي)', prefixIcon: Icon(Icons.draw))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _uiFont,
                        decoration: const InputDecoration(labelText: 'خط الواجهة'),
                        items: const [
                          DropdownMenuItem(value: 'Cairo', child: Text('Cairo')),
                          DropdownMenuItem(value: 'Amiri', child: Text('Amiri')),
                        ],
                        onChanged: (v) => setState(() => _uiFont = v ?? _uiFont),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _printFont,
                        decoration: const InputDecoration(labelText: 'خط الطباعة القانونية'),
                        items: const [
                          DropdownMenuItem(value: 'Amiri', child: Text('Amiri')),
                          DropdownMenuItem(value: 'Cairo', child: Text('Cairo')),
                        ],
                        onChanged: (v) => setState(() => _printFont = v ?? _printFont),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _woPriority,
                  decoration: const InputDecoration(labelText: 'أولوية أمر العمل الافتراضية'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('منخفضة')),
                    DropdownMenuItem(value: 1, child: Text('متوسطة')),
                    DropdownMenuItem(value: 2, child: Text('عالية')),
                  ],
                  onChanged: (v) => setState(() => _woPriority = v ?? _woPriority),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تعيين المبادئ القانونية تلقائياً كمفضلة في المكتبة'),
                  value: _libFav,
                  onChanged: (v) => setState(() => _libFav = v),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ إعدادات المكتب'),
                  onPressed: () async {
                    if (_title.text.trim().isEmpty || _lawyer.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('اسم المكتب واسم المحامي إلزاميان'), backgroundColor: AppColors.error),
                      );
                      return;
                    }
                    final current = ref.read(settingsHubProvider).preferences;
                    await ref.read(settingsHubProvider.notifier).saveOfficePreferences(
                          current.copyWith(
                            officeTitle: _title.text.trim(),
                            lawyerName: _lawyer.text.trim(),
                            officeAddress: _address.text.trim(),
                            officePhone: _phone.text.trim(),
                            officeEmail: _email.text.trim(),
                            logoPath: _logo.text.trim(),
                            signaturePath: _signature.text.trim(),
                            uiFont: _uiFont,
                            printFont: _printFont,
                            workOrderDefaultPriority: _woPriority,
                            libraryAutoFavoritePrinciples: _libFav,
                          ),
                        );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends ConsumerState<_SecurityTab> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _question = TextEditingController();
  final _answer = TextEditingController();
  int _timeout = 10;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsHubProvider).security;
    _question.text = s.securityQuestion;
    _timeout = s.lockTimeoutMinutes;
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(settingsHubProvider).security;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Card(
              color: AppColors.primaryNavy,
              child: ListTile(
                leading: const Icon(Icons.verified_user, color: AppColors.secondaryGold, size: 40),
                title: Text(
                  security.isConfigured ? 'الحماية المحلية مفعّلة' : 'الحماية غير مهيأة',
                  style: AppTextStyles.headline6.copyWith(color: Colors.white),
                ),
                subtitle: Text(
                  'تشفير محلي لكلمة المرور (SHA-256) • مهلة القفل: ${security.lockTimeoutMinutes} دقيقة',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
                  child: const Text('محمي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('تغيير كلمة المرور وسؤال الأمان', style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
                    const SizedBox(height: 12),
                    TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية', prefixIcon: Icon(Icons.lock_outline))),
                    const SizedBox(height: 12),
                    TextField(controller: _next, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', prefixIcon: Icon(Icons.lock))),
                    const SizedBox(height: 12),
                    TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور', prefixIcon: Icon(Icons.lock))),
                    const SizedBox(height: 12),
                    TextField(controller: _question, decoration: const InputDecoration(labelText: 'سؤال الأمان', prefixIcon: Icon(Icons.question_answer))),
                    const SizedBox(height: 12),
                    TextField(controller: _answer, decoration: const InputDecoration(labelText: 'إجابة سؤال الأمان', prefixIcon: Icon(Icons.check))),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _timeout,
                      decoration: const InputDecoration(labelText: 'مهلة القفل التلقائي (دقيقة)'),
                      items: const [5, 10, 15, 30, 60]
                          .map((m) => DropdownMenuItem(value: m, child: Text('$m دقيقة')))
                          .toList(),
                      onChanged: (v) => setState(() => _timeout = v ?? _timeout),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.security),
                      label: const Text('تحديث بيانات الحماية'),
                      onPressed: () async {
                        final err = await ref.read(settingsHubProvider.notifier).updateSecurity(
                              currentPassword: _current.text,
                              newPassword: _next.text,
                              confirmPassword: _confirm.text,
                              securityQuestion: _question.text,
                              securityAnswer: _answer.text,
                              lockTimeoutMinutes: _timeout,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(err ?? 'تم تحديث بيانات الأمان بنجاح'),
                            backgroundColor: err == null ? AppColors.success : AppColors.error,
                          ),
                        );
                        if (err == null) {
                          _current.clear();
                          _next.clear();
                          _confirm.clear();
                          _answer.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsHubProvider);
    final notifier = ref.read(settingsHubProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Card(
              color: const Color(0xFF117A65),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done, size: 48, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'النسخ الاحتياطي الذكي (Offline)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.needsWeeklyBackup
                                ? 'تنبيه: مر أسبوع أو أكثر — يُفضّل إنشاء نسخة الآن.'
                                : 'آخر نسخة: ${state.preferences.lastBackupAt?.toString().substring(0, 16) ?? '—'}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF117A65)),
                      onPressed: state.isBusy
                          ? null
                          : () async {
                              final rec = await notifier.createBackup(includeAttachments: true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('تم إنشاء: ${rec.path}'), backgroundColor: AppColors.success),
                                );
                              }
                            },
                      icon: const Icon(Icons.backup),
                      label: Text(state.isBusy ? 'جارٍ...' : 'نسخ الآن'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.error.withOpacity(0.04),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cleaning_services, color: AppColors.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'بدء مكتب حقيقي بقاعدة نظيفة',
                            style: AppTextStyles.headline6.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يمسح الدعاوى والأشخاص والعقود والشركات والمستندات والمالية وأوامر العمل والبيانات التجريبية، مع الإبقاء على بيانات المكتب وكلمة المرور والقوائم المرجعية السورية.',
                      style: AppTextStyles.bodySmallSecondary,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('مسح البيانات التجريبية وبدء مكتب نظيف'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: state.isBusy ? null : () => _confirmCleanStart(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('النسخ السابقة', style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
                        const Spacer(),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open),
                          label: const Text('مسار خارجي'),
                          onPressed: () async {
                            final controller = TextEditingController(text: state.preferences.externalBackupPath);
                            final path = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('مسار النسخ الخارجي / USB'),
                                content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'D:/Backups أو /media/usb')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('حفظ')),
                                ],
                              ),
                            );
                            if (path != null && path.isNotEmpty) {
                              notifier.setExternalBackupPath(path);
                            }
                          },
                        ),
                      ],
                    ),
                    if (state.preferences.externalBackupPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('المسار الخارجي: ${state.preferences.externalBackupPath}', style: AppTextStyles.bodySmallSecondary),
                      ),
                    const Divider(height: 24),
                    if (state.backups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('لا توجد نسخ سابقة')),
                      )
                    else
                      ...state.backups.map(
                        (b) => Card(
                          child: ListTile(
                            leading: Icon(Icons.archive, color: AppColors.secondaryGold),
                            title: Text(b.path.split('/').last, style: AppTextStyles.labelLarge),
                            subtitle: Text(
                              '${b.type} • ${b.sizeMb.toStringAsFixed(1)} MB • ${b.createdAt.toString().substring(0, 16)}${b.includesAttachments ? ' • مع مرفقات' : ''}',
                              style: AppTextStyles.bodySmallSecondary,
                            ),
                            trailing: ElevatedButton.icon(
                              icon: const Icon(Icons.restore, size: 16),
                              label: const Text('استعادة'),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('تأكيد الاستعادة'),
                                        content: const Text('سيتم اعتماد هذه النسخة كمرجع استعادة. هل تريد المتابعة؟'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('استعادة'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                                if (!ok) return;
                                final success = await notifier.restoreBackup(b.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success ? 'تمت الاستعادة' : 'فشلت الاستعادة'),
                                      backgroundColor: success ? AppColors.success : AppColors.error,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCleanStart(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تأكيد مسح البيانات التجريبية'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سيتم مسح كل بيانات التشغيل الحالية وفتح المكتب كأنه جديد. لا يؤثر ذلك على بيانات المكتب وكلمة المرور والقوائم المرجعية.'),
                const SizedBox(height: 12),
                const Text('للتأكيد اكتب: مسح'),
                const SizedBox(height: 8),
                TextField(controller: controller, autofocus: true),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, controller.text.trim() == 'مسح'),
                child: const Text('مسح وبدء مكتب نظيف'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('demo_seed_enabled', false);
    ref.read(allowDemoSeedProvider.notifier).state = false;
    await ref.read(databaseProvider).clearOperationalData();

    ref.invalidate(coreDataBootstrapProvider);
    ref.invalidate(uiWorkOrdersProvider);
    ref.invalidate(uiPersonsDirectoryProvider);
    ref.invalidate(allCasesProvider);
    ref.invalidate(allPersonsProvider);
    ref.invalidate(allCompaniesProvider);
    ref.invalidate(allContractsProvider);
    ref.invalidate(allProceduresProvider);
    ref.invalidate(tasksByDateProvider);
    ref.invalidate(openDeficienciesProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم مسح البيانات التجريبية. أصبح المكتب جاهزاً لإدخال الملفات الحقيقية.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

class _LookupsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LookupsTab> createState() => _LookupsTabState();
}

class _LookupsTabState extends ConsumerState<_LookupsTab> {
  String _selected = 'courts';
  String _query = '';

  static const _labels = {
    'courts': 'المحاكم',
    'case_types': 'أنواع الدعاوى',
    'party_roles': 'صفات الأطراف',
    'contract_types': 'أنواع العقود',
    'company_types': 'أنواع الشركات',
    'procedure_types': 'أنواع الإجراءات',
    'bar_branches': 'فروع النقابة',
    'agency_delegates': 'مندوبو الوكالات',
    'expense_types': 'أنواع المصاريف',
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsHubProvider);
    final canManage = ref.watch(permissionServiceProvider).can(PermissionKeys.settingsLookupsManage);
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Container(
            color: AppColors.cardBackground,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: _labels.entries.map((entry) {
                final selected = _selected == entry.key;
                return Card(
                  color: selected ? AppColors.primaryNavy.withOpacity(0.08) : null,
                  child: ListTile(
                    selected: selected,
                    leading: Icon(entry.key == 'courts' ? Icons.account_balance : Icons.list_alt, color: selected ? AppColors.primaryNavy : AppColors.textSecondary),
                    title: Text(entry.value),
                    onTap: () => setState(() {
                      _selected = entry.key;
                      _query = '';
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'بحث في ${_labels[_selected]}',
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (canManage)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(_selected == 'courts' ? 'إضافة محكمة' : 'إضافة عنصر'),
                        onPressed: () => _selected == 'courts'
                            ? _showCourtDialog(context, ref)
                            : _selected == 'agency_delegates'
                                ? _showAgencyDelegateDialog(context, ref)
                                : _showLookupDialog(context, ref, _selected),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _selected == 'courts'
                    ? _courtsList(state.courts, canManage)
                    : _selected == 'agency_delegates'
                        ? _agencyDelegatesList(canManage)
                        : _lookupList(_selected, state.referenceLists[_selected] ?? const [], canManage),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _courtsList(List<SettingsCourtItem> courts, bool canManage) {
    final list = courts.where((c) => _query.isEmpty || c.name.toLowerCase().contains(_query) || c.type.toLowerCase().contains(_query) || c.city.toLowerCase().contains(_query)).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final c = list[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.primaryNavy, child: Icon(Icons.account_balance, color: AppColors.secondaryGold)),
            title: Text(c.name, style: AppTextStyles.labelLarge),
            subtitle: Text('${c.type} • ${c.city} • ${c.isActive ? 'فعال' : 'معطل'}', style: AppTextStyles.bodySmallSecondary),
            trailing: canManage
                ? Wrap(
                    spacing: 6,
                    children: [
                      IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit), onPressed: () => _showCourtDialog(context, ref, court: c)),
                      Switch(value: c.isActive, onChanged: (v) => ref.read(settingsHubProvider.notifier).setCourtActive(c.id, v)),
                      IconButton(tooltip: 'حذف آمن', icon: Icon(Icons.delete_outline, color: AppColors.error), onPressed: () => _confirmDeleteCourt(context, ref, c)),
                    ],
                  )
                : Icon(Icons.check_circle, color: c.isActive ? AppColors.success : AppColors.textSecondary),
          ),
        );
      },
    );
  }

  Widget _agencyDelegatesList(bool canManage) {
    return FutureBuilder<List<AgencyDelegateRecord>>(
      future: ref.watch(archiveIntakeRepositoryProvider).getAgencyDelegates(query: _query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return Center(child: Text('لا توجد مندوبو وكالات', style: AppTextStyles.bodyMediumSecondary));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: (item.isActive ? AppColors.primaryNavy : AppColors.textSecondary).withOpacity(0.12), child: Icon(Icons.person_pin, color: item.isActive ? AppColors.primaryNavy : AppColors.textSecondary)),
                title: Text(item.fullName, style: AppTextStyles.labelLarge),
                subtitle: Text([
                  if (item.phone.isNotEmpty) item.phone,
                  if (item.barBranch.isNotEmpty) 'فرع ${item.barBranch}',
                  if (item.notes.isNotEmpty) item.notes,
                  item.isActive ? 'فعال' : 'معطل',
                ].join(' • '), style: AppTextStyles.bodySmallSecondary),
                trailing: canManage
                    ? Wrap(
                        spacing: 6,
                        children: [
                          IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit), onPressed: () => _showAgencyDelegateDialog(context, ref, item: item)),
                          Switch(value: item.isActive, onChanged: (v) => _setAgencyDelegateActive(ref, item, v)),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _setAgencyDelegateActive(WidgetRef ref, AgencyDelegateRecord item, bool active) async {
    await ref.read(archiveIntakeRepositoryProvider).setAgencyDelegateActive(item.id, active);
    await ref.read(auditServiceProvider).log(action: active ? 'enable' : 'disable', category: 'lookups', entityType: 'agency_delegate', entityId: '${item.id}', entityTitle: item.fullName, description: active ? 'إعادة تفعيل مندوب وكالات' : 'تعطيل مندوب وكالات', severity: active ? 'info' : 'warning');
    setState(() {});
  }

  Widget _lookupList(String key, List<SettingsLookupItem> items, bool canManage) {
    final list = items.where((i) => _query.isEmpty || i.name.toLowerCase().contains(_query) || i.category.toLowerCase().contains(_query) || i.notes.toLowerCase().contains(_query)).toList();
    if (list.isEmpty) {
      return Center(child: Text('لا توجد عناصر في ${_labels[key]}', style: AppTextStyles.bodyMediumSecondary));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: (item.isActive ? AppColors.primaryNavy : AppColors.textSecondary).withOpacity(0.12), child: Icon(Icons.label, color: item.isActive ? AppColors.primaryNavy : AppColors.textSecondary)),
            title: Text(item.name, style: AppTextStyles.labelLarge),
            subtitle: Text([if (item.category.isNotEmpty) item.category, if (item.notes.isNotEmpty) item.notes, item.isActive ? 'فعال' : 'معطل'].join(' • '), style: AppTextStyles.bodySmallSecondary),
            trailing: canManage
                ? Wrap(
                    spacing: 6,
                    children: [
                      IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit), onPressed: () => _showLookupDialog(context, ref, key, item: item)),
                      Switch(value: item.isActive, onChanged: (v) => ref.read(settingsHubProvider.notifier).setLookupActive(key, item.id, v)),
                      IconButton(tooltip: 'حذف آمن', icon: Icon(Icons.delete_outline, color: AppColors.error), onPressed: () => _confirmDeleteLookup(context, ref, key, item)),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showAgencyDelegateDialog(BuildContext context, WidgetRef ref, {AgencyDelegateRecord? item}) {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.settingsLookupsManage)) return;
    final name = TextEditingController(text: item?.fullName ?? '');
    final phone = TextEditingController(text: item?.phone ?? '');
    final notes = TextEditingController(text: item?.notes ?? '');
    final branches = ref.read(settingsHubProvider).referenceLists['bar_branches'] ?? const <SettingsLookupItem>[];
    String branch = item?.barBranch ?? (branches.isNotEmpty ? branches.first.name : 'دمشق');
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(item == null ? 'إضافة مندوب وكالات' : 'تعديل مندوب وكالات'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المندوب *')),
                const SizedBox(height: 12),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: branch,
                  decoration: const InputDecoration(labelText: 'فرع النقابة'),
                  items: [
                    ...branches.where((b) => b.isActive).map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))),
                    if (branches.where((b) => b.isActive).every((b) => b.name != branch)) DropdownMenuItem(value: branch, child: Text(branch)),
                  ],
                  onChanged: (v) => setDialog(() => branch = v ?? branch),
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final id = await ref.read(archiveIntakeRepositoryProvider).upsertAgencyDelegate(
                      id: item?.id,
                      fullName: name.text.trim(),
                      phone: phone.text.trim(),
                      barBranch: branch,
                      notes: notes.text.trim(),
                      isActive: item?.isActive ?? true,
                    );
                await ref.read(auditServiceProvider).log(action: item == null ? 'create' : 'update', category: 'lookups', entityType: 'agency_delegate', entityId: '$id', entityTitle: name.text.trim(), description: item == null ? 'إضافة مندوب وكالات' : 'تعديل مندوب وكالات', severity: 'warning');
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLookupDialog(BuildContext context, WidgetRef ref, String key, {SettingsLookupItem? item}) {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.settingsLookupsManage)) return;
    final name = TextEditingController(text: item?.name ?? '');
    final category = TextEditingController(text: item?.category ?? '');
    final notes = TextEditingController(text: item?.notes ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'إضافة عنصر مرجعي' : 'تعديل عنصر مرجعي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم *')),
            const SizedBox(height: 12),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'تصنيف فرعي / مجموعة')),
            const SizedBox(height: 12),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final next = SettingsLookupItem(
                id: item?.id ?? '${key}_${DateTime.now().microsecondsSinceEpoch}',
                name: name.text.trim(),
                category: category.text.trim(),
                notes: notes.text.trim(),
                isActive: item?.isActive ?? true,
              );
              ref.read(settingsHubProvider.notifier).upsertLookup(key, next);
              await ref.read(auditServiceProvider).log(action: item == null ? 'create' : 'update', category: 'lookups', entityType: key, entityId: next.id, entityTitle: next.name, description: '${item == null ? 'إضافة' : 'تعديل'} عنصر في ${_labels[key]}', severity: 'warning');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLookup(BuildContext context, WidgetRef ref, String key, SettingsLookupItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف عنصر مرجعي'),
        content: const Text('استخدم الحذف فقط إذا كان العنصر غير مستخدم. إذا كان مستخدماً في ملفات سابقة، عطّله بدلاً من حذفه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              ref.read(settingsHubProvider.notifier).deleteLookup(key, item.id);
              await ref.read(auditServiceProvider).log(action: 'delete', category: 'lookups', entityType: key, entityId: item.id, entityTitle: item.name, description: 'حذف عنصر مرجعي من ${_labels[key]}', severity: 'critical');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showCourtDialog(BuildContext context, WidgetRef ref, {SettingsCourtItem? court}) {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.settingsLookupsManage)) return;
    final name = TextEditingController(text: court?.name ?? '');
    String type = court?.type ?? 'بداية';
    String city = court?.city ?? 'السويداء';
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(court == null ? 'إضافة محكمة' : 'تعديل محكمة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المحكمة *')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: ['صلح', 'بداية', 'استئناف', 'نقض', 'شرعية', 'تجارية']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setDialog(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: city,
                decoration: const InputDecoration(labelText: 'المحافظة'),
                items: ['دمشق', 'السويداء', 'ريف دمشق', 'حلب', 'حمص', 'اللاذقية', 'درعا']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialog(() => city = v ?? city),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final item = SettingsCourtItem(
                  id: court?.id ?? 'court_${DateTime.now().microsecondsSinceEpoch}',
                  name: name.text.trim(),
                  type: type,
                  city: city,
                  isActive: court?.isActive ?? true,
                );
                if (court == null) {
                  ref.read(settingsHubProvider.notifier).addCourt(item);
                  await ref.read(auditServiceProvider).log(action: 'create', category: 'lookups', entityType: 'court', entityId: item.id, entityTitle: item.name, description: 'إضافة محكمة مرجعية', severity: 'warning');
                } else {
                  ref.read(settingsHubProvider.notifier).updateCourt(item);
                  await ref.read(auditServiceProvider).log(action: 'update', category: 'lookups', entityType: 'court', entityId: item.id, entityTitle: item.name, description: 'تعديل محكمة مرجعية', after: {'name': item.name, 'type': item.type, 'city': item.city}, severity: 'warning');
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCourt(BuildContext context, WidgetRef ref, SettingsCourtItem court) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف محكمة من القوائم المرجعية'),
        content: const Text('يجب استخدام الحذف فقط للعناصر غير المستخدمة. إذا كانت المحكمة مستخدمة في ملفات سابقة فالأفضل تعطيلها فقط.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              // الحذف قد يُرفض إذا كانت المحكمة مستخدمة في دعاوى؛ يُعرض السبب.
              final error = await ref.read(settingsHubProvider.notifier).deleteCourt(court.id);
              if (error != null) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error), backgroundColor: AppColors.error),
                  );
                  Navigator.pop(ctx);
                }
                return;
              }
              await ref.read(auditServiceProvider).log(action: 'delete', category: 'lookups', entityType: 'court', entityId: court.id, entityTitle: court.name, description: 'حذف محكمة مرجعية من الواجهة', severity: 'critical');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsHubProvider);
    final logs = state.filteredActivity;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'بحث في سجل النشاط...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => ref.read(settingsHubProvider.notifier).setActivityFilter(v),
          ),
        ),
        Expanded(
          child: logs.isEmpty
              ? Center(child: Text('لا أحداث', style: AppTextStyles.bodyMediumSecondary))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final e = logs[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryNavy.withOpacity(0.1),
                          child: Icon(_iconFor(e.action), color: AppColors.primaryNavy),
                        ),
                        title: Text('${e.action} • ${e.tableName}', style: AppTextStyles.labelLarge),
                        subtitle: Text(
                          '${e.details}\n${e.userRef} • ${e.timestamp.toString().substring(0, 16)}',
                          style: AppTextStyles.bodySmallSecondary,
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'login':
        return Icons.login;
      case 'export':
        return Icons.backup;
      case 'import':
        return Icons.restore;
      case 'insert':
        return Icons.add_circle_outline;
      default:
        return Icons.edit;
    }
  }
}

class _UsersRolesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(authRepositoryProvider);
    final current = ref.watch(authControllerProvider).user;
    final permissions = ref.watch(permissionServiceProvider);
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([repo.getUsers(), repo.getRoles()]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data![0] as List;
        final roles = snapshot.data![1] as List;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('المستخدمون والصلاحيات', style: AppTextStyles.headline5.copyWith(color: AppColors.primaryNavy))),
                  if (permissions.can(PermissionKeys.settingsUsersManage)) ...[
                    ElevatedButton.icon(onPressed: () => _showRoleDialog(context, ref), icon: const Icon(Icons.security), label: const Text('دور جديد')),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(onPressed: () => _showUserDialog(context, ref, roles), icon: const Icon(Icons.person_add), label: const Text('مستخدم جديد')),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(title: Text('المستخدمون', style: AppTextStyles.headline6)),
                    ...users.map((dynamic u) => ListTile(
                          leading: Icon(u.isOwner ? Icons.workspace_premium : Icons.person, color: u.isActive ? AppColors.primaryNavy : AppColors.textSecondary),
                          title: Text(u.fullName),
                          subtitle: Text('${u.username} • ${u.roleName} (مستوى ${u.effectiveLevel}) • ${u.isActive ? 'فعال' : 'معطل'}'),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              if (u.isOwner) const Chip(label: Text('Owner')),
                              if (permissions.can(PermissionKeys.settingsUsersManage)) ...[
                                IconButton(
                                  tooltip: 'تعديل المستخدم',
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showUserDialog(context, ref, roles, user: u),
                                ),
                                IconButton(
                                  tooltip: 'تغيير كلمة المرور',
                                  icon: const Icon(Icons.password),
                                  onPressed: () => _showPasswordDialog(context, ref, user: u),
                                ),
                                if (!u.isOwner)
                                  Switch(value: u.isActive, onChanged: (v) async {
                                    try { await repo.setUserActive(u.id, v, actor: current); }
                                    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Bad state: ', '')), backgroundColor: AppColors.error)); }
                                  }),
                              ],
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(title: Text('الأدوار', style: AppTextStyles.headline6)),
                    ...roles.map((dynamic r) => ListTile(
                          leading: Icon(r.isSystemRole ? Icons.admin_panel_settings : Icons.badge, color: AppConstants.accentGold),
                          title: Text(r.name),
                          subtitle: Text('مستوى: ${r.hierarchyLevel} • مستخدمون: ${r.userCount} • صلاحيات: ${r.permissionCount}${r.description.isNotEmpty ? ' • ${r.description}' : ''}'),
                          trailing: permissions.can(PermissionKeys.settingsUsersManage)
                              ? Wrap(
                                  spacing: 6,
                                  children: [
                                    TextButton.icon(onPressed: () => _showRoleDialog(context, ref, role: r), icon: const Icon(Icons.edit), label: const Text('تعديل')),
                                    TextButton.icon(onPressed: () => _showCopyRoleDialog(context, ref, role: r), icon: const Icon(Icons.copy), label: const Text('نسخ')),
                                    if (!r.isSystemRole)
                                      Switch(value: r.isActive, onChanged: (v) async {
                                        try { await ref.read(authRepositoryProvider).setRoleActive(r.id, v, actor: ref.read(authControllerProvider).user); }
                                        catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error)); }
                                      }),
                                  ],
                                )
                              : null,
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUserDialog(BuildContext context, WidgetRef ref, List roles, {dynamic user}) {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.settingsUsersManage)) return;
    final actorUser = ref.read(authControllerProvider).user;
    final actorLevel = actorUser == null ? 0 : actorUser.effectiveLevel;
    final isOwnerActor = actorUser?.isOwner ?? false;
    // لا يجوز تعديل مستخدم يساوي مستوى المنفّذ أو يعلوه (عدا حسابه الشخصي).
    if (user != null && !isOwnerActor && user.id != actorUser?.id) {
      final targetLevel = (user.isOwner as bool) ? AuthRepository.ownerLevel : (user.hierarchyLevel as int);
      if (targetLevel >= actorLevel) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('لا يمكنك تعديل مستخدم بمستوى صلاحيات يساوي مستواك أو يعلوه'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }
    // الأدوار المتاحة للإسناد: الأدنى من مستوى المنفّذ فقط.
    final assignableRoles = isOwnerActor
        ? roles
        : roles.where((dynamic r) => (r.hierarchyLevel as int) < actorLevel).toList();
    if (assignableRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('لا توجد أدوار بمستوى أدنى من مستواك لإسنادها'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    final name = TextEditingController(text: user?.fullName ?? '');
    final username = TextEditingController(text: user?.username ?? '');
    final phone = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    int? roleId = user?.roleId ?? (assignableRoles.isNotEmpty ? assignableRoles.first.id as int : null);
    final isEdit = user != null;
    showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(isEdit ? 'تعديل مستخدم' : 'إضافة مستخدم'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم الكامل *')),
        const SizedBox(height: 8),
        TextField(controller: username, decoration: const InputDecoration(labelText: 'اسم الدخول *')),
        if (!isEdit) ...[
          const SizedBox(height: 8),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور المؤقتة *')),
        ],
        const SizedBox(height: 8),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
        const SizedBox(height: 8),
        TextField(controller: email, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(value: assignableRoles.any((dynamic r) => r.id == roleId) ? roleId : null, decoration: const InputDecoration(labelText: 'الدور'), items: assignableRoles.map<DropdownMenuItem<int>>((dynamic r) => DropdownMenuItem<int>(value: r.id as int, child: Text('${r.name} (مستوى ${r.hierarchyLevel})'))).toList(), onChanged: (v) => setDialog(() => roleId = v)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(onPressed: () async {
        if (name.text.trim().isEmpty || username.text.trim().isEmpty || roleId == null) return;
        final repo = ref.read(authRepositoryProvider);
        final actor = ref.read(authControllerProvider).user;
        try {
          if (isEdit) {
            await repo.updateUser(id: user.id, fullName: name.text.trim(), username: username.text.trim(), roleId: roleId!, phone: phone.text.trim(), email: email.text.trim(), actor: actor);
          } else {
            if (password.text.length < 6) return;
            await repo.createUser(fullName: name.text.trim(), username: username.text.trim(), password: password.text, roleId: roleId!, phone: phone.text.trim(), email: email.text.trim(), actor: actor);
          }
        } catch (e) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Bad state: ', '')), backgroundColor: AppColors.error));
          }
          return;
        }
        if (ctx.mounted) Navigator.pop(ctx);
      }, child: const Text('حفظ'))],
    )));
  }

  void _showPasswordDialog(BuildContext context, WidgetRef ref, {required dynamic user}) {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.settingsUsersManage)) return;
    final password = TextEditingController();
    final confirm = TextEditingController();
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('تغيير كلمة مرور ${user.fullName}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة *')),
        const SizedBox(height: 8),
        TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور *')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () async {
          if (password.text.length < 6 || password.text != confirm.text) return;
          try {
            await ref.read(authRepositoryProvider).changeUserPassword(id: user.id, newPassword: password.text, actor: ref.read(authControllerProvider).user);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Bad state: ', '')), backgroundColor: AppColors.error));
            }
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('حفظ')),
      ],
    ));
  }

  void _showCopyRoleDialog(BuildContext context, WidgetRef ref, {required dynamic role}) {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.settingsUsersManage)) return;
    final name = TextEditingController(text: '${role.name} - نسخة');
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('نسخ دور'),
      content: TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الدور الجديد *')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () async {
          if (name.text.trim().isEmpty) return;
          try {
            await ref.read(authRepositoryProvider).duplicateRole(role.id, newName: name.text.trim(), actor: ref.read(authControllerProvider).user);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Bad state: ', '')), backgroundColor: AppColors.error));
            }
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('نسخ')),
      ],
    ));
  }

  void _showRoleDialog(BuildContext context, WidgetRef ref, {dynamic role}) {
    if (!ref.read(permissionServiceProvider).can(PermissionKeys.settingsUsersManage)) return;
    final actorUser = ref.read(authControllerProvider).user;
    final actorLevel = actorUser == null ? 0 : actorUser.effectiveLevel;
    final isOwnerActor = actorUser?.isOwner ?? false;
    // لا يجوز تعديل دور يساوي مستوى المنفّذ أو يعلوه.
    if (role != null && !isOwnerActor && (role.hierarchyLevel as int) >= actorLevel) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('لا يمكنك تعديل دور بمستوى صلاحيات يساوي مستواك أو يعلوه'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    final name = TextEditingController(text: role?.name ?? '');
    final description = TextEditingController(text: role?.description ?? '');
    // الحد الأقصى المسموح: أقل من مستوى المنفّذ بدرجة، والمالك بلا سقف.
    final maxLevel = isOwnerActor ? AuthRepository.ownerLevel : (actorLevel - 1).clamp(0, AuthRepository.ownerLevel);
    int levelValue = (role?.hierarchyLevel as int?) ?? (maxLevel < 10 ? maxLevel : 10);
    if (levelValue > maxLevel) levelValue = maxLevel;
    final levelController = TextEditingController(text: '$levelValue');
    final selected = <String>{};
    if (role != null) selected.addAll((role.permissions as Set<String>));
    showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(role == null ? 'إنشاء دور' : 'تعديل دور'),
      content: SizedBox(width: 720, height: 560, child: Column(children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الدور *')),
        const SizedBox(height: 8),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'وصف اختياري')),
        const SizedBox(height: 8),
        TextField(
          controller: levelController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'مستوى الدور في الهرم الإداري *',
            helperText: isOwnerActor
                ? 'مالك المكتب = ${AuthRepository.ownerLevel}، مدير = 80، محامي أستاذ = 60'
                : 'الحد الأعلى المسموح لك: $maxLevel (لا يمكنك إنشاء دور يوازي مستواك أو يعلوه)',
          ),
        ),
        if (role != null && role.userCount > 0) ...[
          const SizedBox(height: 8),
          MaterialBanner(
            content: Text('هذا الدور مستخدم من ${role.userCount} مستخدم/مستخدمين. أي تعديل سيطبق عليهم جميعاً.'),
            actions: const [SizedBox.shrink()],
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: PermissionCatalog.groups.map((g) {
              final groupPermissions = PermissionCatalog.byGroup(g.key);
              final allSelected = groupPermissions.every((p) => selected.contains(p.key));
              final anySelected = groupPermissions.any((p) => selected.contains(p.key));
              return ExpansionTile(
                title: Text(g.label, style: AppTextStyles.labelLarge),
                children: [
                  CheckboxListTile(
                    value: allSelected ? true : (anySelected ? null : false),
                    tristate: true,
                    title: const Text('تحديد كل صلاحيات هذا القسم'),
                    subtitle: Text('عدد الصلاحيات: ${groupPermissions.length}'),
                    secondary: const Icon(Icons.select_all),
                    onChanged: (v) => setDialog(() {
                      if (v == true || !allSelected) {
                        selected.addAll(groupPermissions.map((p) => p.key));
                      } else {
                        selected.removeAll(groupPermissions.map((p) => p.key));
                      }
                    }),
                  ),
                  const Divider(height: 1),
                  ...groupPermissions.map((p) => CheckboxListTile(
                    value: selected.contains(p.key),
                    title: Text(p.label),
                    subtitle: Text(p.description),
                    secondary: p.sensitive ? Icon(Icons.warning_amber, color: AppColors.warning) : null,
                    onChanged: (v) => setDialog(() { if (v == true) selected.add(p.key); else selected.remove(p.key); }),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(onPressed: () async {
        if (name.text.trim().isEmpty) return;
        final repo = ref.read(authRepositoryProvider);
        final actor = ref.read(authControllerProvider).user;
        final level = int.tryParse(levelController.text.trim()) ?? 0;
        try {
          if (role == null) {
            await repo.createRole(name: name.text.trim(), description: description.text.trim(), permissions: selected, hierarchyLevel: level, actor: actor);
          } else {
            await repo.updateRole(id: role.id, name: name.text.trim(), description: description.text.trim(), permissions: selected, hierarchyLevel: level, actor: actor);
          }
        } catch (e) {
          // أخطاء منع التصعيد تُعرض للمستخدم بدل ابتلاعها.
          if (ctx.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$e'.replaceFirst('Bad state: ', '')),
              backgroundColor: AppColors.error,
            ));
          }
          return;
        }
        if (ctx.mounted) Navigator.pop(ctx);
      }, child: const Text('حفظ'))],
    )));
  }
}

class _AuditTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends ConsumerState<_AuditTab> {
  final _query = TextEditingController();
  String _severity = 'all';
  String _category = 'all';
  String _action = 'all';
  String _user = 'all';
  String _dateRange = 'all';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(authRepositoryProvider);
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([repo.getSessions(), repo.getAuditEvents()]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final sessions = snapshot.data![0] as List;
        final allEvents = snapshot.data![1] as List;
        var events = allEvents;
        final q = _query.text.trim().toLowerCase();
        final now = DateTime.now();
        events = events.where((dynamic e) {
          final okSeverity = _severity == 'all' || e.severity == _severity;
          final okCategory = _category == 'all' || e.category == _category;
          final okAction = _action == 'all' || e.action == _action;
          final okUser = _user == 'all' || e.username == _user;
          bool okDate = true;
          if (_dateRange == 'today') {
            okDate = e.createdAt.year == now.year && e.createdAt.month == now.month && e.createdAt.day == now.day;
          } else if (_dateRange == '7d') {
            okDate = e.createdAt.isAfter(now.subtract(const Duration(days: 7)));
          } else if (_dateRange == '30d') {
            okDate = e.createdAt.isAfter(now.subtract(const Duration(days: 30)));
          }
          final haystack = '${e.fullName} ${e.username} ${e.roleName} ${e.action} ${e.category} ${e.entityTitle} ${e.description}'.toLowerCase();
          final okQuery = q.isEmpty || haystack.contains(q);
          return okSeverity && okCategory && okAction && okUser && okDate && okQuery;
        }).toList();
        final categories = <String>{'all', ...allEvents.map((dynamic e) => e.category as String)}.toList();
        final actions = <String>{'all', ...allEvents.map((dynamic e) => e.action as String)}.toList();
        final users = <String>{'all', ...allEvents.map((dynamic e) => e.username as String)}.toList();
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: TabBar(tabs: [Tab(text: 'سجل المسؤولية'), Tab(text: 'جلسات الدخول')])),
                  if (ref.watch(permissionServiceProvider).can(PermissionKeys.auditExport))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('تصدير CSV'),
                        onPressed: () => _exportAudit(events),
                      ),
                    ),
                ],
              ),
              Expanded(child: TabBarView(children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _query,
                              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'بحث في سجل المسؤولية'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(value: _severity, decoration: const InputDecoration(labelText: 'الأهمية'), items: const [
                            DropdownMenuItem(value: 'all', child: Text('الكل')),
                            DropdownMenuItem(value: 'info', child: Text('معلومة')),
                            DropdownMenuItem(value: 'warning', child: Text('تحذير')),
                            DropdownMenuItem(value: 'critical', child: Text('حرج')),
                          ], onChanged: (v) => setState(() => _severity = v ?? 'all'))),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(value: categories.contains(_category) ? _category : 'all', decoration: const InputDecoration(labelText: 'القسم'), items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c == 'all' ? 'الكل' : c))).toList(), onChanged: (v) => setState(() => _category = v ?? 'all'))),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(value: actions.contains(_action) ? _action : 'all', decoration: const InputDecoration(labelText: 'العملية'), items: actions.map((a) => DropdownMenuItem(value: a, child: Text(a == 'all' ? 'الكل' : a))).toList(), onChanged: (v) => setState(() => _action = v ?? 'all'))),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(value: users.contains(_user) ? _user : 'all', decoration: const InputDecoration(labelText: 'المستخدم'), items: users.map((u) => DropdownMenuItem(value: u, child: Text(u == 'all' ? 'الكل' : u))).toList(), onChanged: (v) => setState(() => _user = v ?? 'all'))),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(value: _dateRange, decoration: const InputDecoration(labelText: 'الفترة'), items: const [
                            DropdownMenuItem(value: 'all', child: Text('كل الفترات')),
                            DropdownMenuItem(value: 'today', child: Text('اليوم')),
                            DropdownMenuItem(value: '7d', child: Text('آخر 7 أيام')),
                            DropdownMenuItem(value: '30d', child: Text('آخر 30 يوم')),
                          ], onChanged: (v) => setState(() => _dateRange = v ?? 'all'))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: events.length,
                        itemBuilder: (_, i) {
                          final dynamic e = events[i];
                          return Card(child: ListTile(
                            leading: Icon(e.severity == 'critical' ? Icons.error : e.severity == 'warning' ? Icons.warning : Icons.info_outline, color: e.severity == 'critical' ? AppColors.error : e.severity == 'warning' ? AppColors.warning : AppColors.info),
                            title: Text('${e.fullName} • ${e.action} • ${e.category}'),
                            subtitle: Text('${e.description}\n${e.entityTitle} • ${e.createdAt.toString().substring(0, 16)}'),
                            isThreeLine: true,
                            onTap: () => _showAuditDetails(context, e),
                          ));
                        },
                      ),
                    ),
                  ],
                ),
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (_, i) {
                    final dynamic s = sessions[i];
                    return Card(child: ListTile(
                      leading: Icon(s.status == 'failed' ? Icons.lock : Icons.login, color: s.status == 'failed' ? AppColors.error : AppColors.success),
                      title: Text('${s.fullName.isEmpty ? s.username : s.fullName} • ${s.status}'),
                      subtitle: Text('${s.roleName}\nدخول: ${s.loginAt.toString().substring(0, 16)}${s.logoutAt == null ? '' : ' • خروج: ${s.logoutAt.toString().substring(0, 16)}'}${s.failedReason == null ? '' : ' • ${s.failedReason}'}'),
                      isThreeLine: true,
                    ));
                  },
                ),
              ])),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportAudit(List events) async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.auditExport)) return;
    final buffer = StringBuffer('time,user,role,action,category,entity,description,severity\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final dynamic e in events) {
      buffer.writeln([
        esc(e.createdAt),
        esc(e.fullName),
        esc(e.roleName),
        esc(e.action),
        esc(e.category),
        esc(e.entityTitle),
        esc(e.description),
        esc(e.severity),
      ].join(','));
    }
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(path.join(dir.path, AppConstants.appDataDirectoryName, 'audit_exports'));
    if (!await exportDir.exists()) await exportDir.create(recursive: true);
    final file = File(path.join(exportDir.path, 'audit_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await file.writeAsString(buffer.toString());
    await ref.read(auditServiceProvider).log(action: 'export', category: 'audit', entityType: 'audit_events', entityTitle: file.path, description: 'تصدير سجل المسؤولية CSV', severity: 'critical');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تصدير سجل المسؤولية: ${file.path}'), backgroundColor: AppColors.success));
    }
  }

  Widget _jsonDetails(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: decoded.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SelectableText('${e.key}: ${e.value}'),
                  ))
              .toList(),
        );
      }
    } catch (_) {}
    return SelectableText(raw);
  }

  void _showAuditDetails(BuildContext context, dynamic e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفاصيل العملية'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المستخدم: ${e.fullName} (${e.username})'),
                Text('الدور: ${e.roleName}'),
                Text('الوقت: ${e.createdAt}'),
                Text('القسم: ${e.category}'),
                Text('العملية: ${e.action}'),
                Text('السجل: ${e.entityTitle}'),
                const Divider(),
                Text(e.description),
                if (e.beforeJson != null) ...[
                  const SizedBox(height: 12),
                  Text('قبل التعديل', style: AppTextStyles.labelLarge),
                  _jsonDetails(e.beforeJson!),
                ],
                if (e.afterJson != null) ...[
                  const SizedBox(height: 12),
                  Text('بعد التعديل', style: AppTextStyles.labelLarge),
                  _jsonDetails(e.afterJson!),
                ],
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }
}
