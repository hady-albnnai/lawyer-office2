/// شاشة عمل جديد — مسارات إنشاء حقيقية (لا Placeholder).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../admin_procedures/create_procedure_screen.dart';
import '../cases/create_case_wizard.dart';
import '../companies/create_company_wizard.dart';
import '../contracts/create_contract_screen.dart';
import '../work_orders/work_order_dialogs.dart';

class NewWorkScreen extends ConsumerWidget {
  const NewWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    final items = <_NewWorkAction>[
      _NewWorkAction(
        title: 'دعوى قضائية',
        subtitle: 'معالج إنشاء دعوى كاملة',
        icon: Icons.gavel,
        color: AppColors.primaryNavy,
        permission: PermissionKeys.casesCreateNew,
        onTap: () => context.push('/cases/create'),
      ),
      _NewWorkAction(
        title: 'عقد',
        subtitle: 'تنظيم عقد وحفظه',
        icon: Icons.description,
        color: AppColors.info,
        permission: PermissionKeys.contractsCreate,
        onTap: () => context.push('/contracts/create'),
      ),
      _NewWorkAction(
        title: 'شركة',
        subtitle: 'تأسيس شركة ومراحلها',
        icon: Icons.business,
        color: AppColors.secondaryGold,
        permission: PermissionKeys.companiesCreate,
        onTap: () => context.push('/companies/create'),
      ),
      _NewWorkAction(
        title: 'إجراء إداري',
        subtitle: 'معاملة إدارية + Checklist',
        icon: Icons.assignment,
        color: AppColors.warning,
        permission: PermissionKeys.proceduresCreate,
        onTap: () => context.push('/procedures/create'),
      ),
      _NewWorkAction(
        title: 'أمر عمل للمعقب',
        subtitle: 'إنشاء أمر offline (PDF/واتساب)',
        icon: Icons.assignment_ind,
        color: AppColors.success,
        permission: PermissionKeys.workOrdersCreate,
        onTap: () => showDialog(
          context: context,
          builder: (_) => const CreateWorkOrderDialog(),
        ),
      ),
      _NewWorkAction(
        title: 'ملف وكالة',
        subtitle: 'إدارة الوكالات ضمن ملفات المكتب',
        icon: Icons.verified_user,
        color: AppColors.info,
        permission: PermissionKeys.poaCreate,
        onTap: () => context.go('/poa'),
      ),
    ].where((item) => permissions.can(item.permission)).toList();

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('عمل جديد')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ابدأ عملاً جديدًا', style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy)),
                const SizedBox(height: 8),
                Text(
                  'اختر نوع العمل الجديد. إدخال الأرشيف القديم يتم فقط من تبويب إدخال الأرشيف القديم.',
                  style: AppTextStyles.bodyMediumSecondary,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: item.onTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: item.color.withOpacity(0.12),
                                  child: Icon(item.icon, color: item.color),
                                ),
                                const Spacer(),
                                Text(item.title, style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
                                const SizedBox(height: 4),
                                Text(item.subtitle, style: AppTextStyles.bodySmallSecondary),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewWorkAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String permission;
  final VoidCallback onTap;
  _NewWorkAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.permission,
    required this.onTap,
  });
}
