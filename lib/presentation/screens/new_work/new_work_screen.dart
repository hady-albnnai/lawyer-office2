/// شاشة عمل جديد — مسارات إنشاء حقيقية (لا Placeholder).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';
import '../../theme/app_theme.dart';
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
        permission: PermissionKeys.casesCreateNew,
        onTap: () => context.push('/cases/create?archiveStatus=running'),
      ),
      _NewWorkAction(
        title: 'عقد',
        subtitle: 'تنظيم عقد وحفظه',
        icon: Icons.description,
        permission: PermissionKeys.contractsCreate,
        onTap: () => context.push('/contracts/create?archiveStatus=running'),
      ),
      _NewWorkAction(
        title: 'شركة',
        subtitle: 'تأسيس شركة ومراحلها',
        icon: Icons.business,
        permission: PermissionKeys.companiesCreate,
        onTap: () => context.push('/companies/create?archiveStatus=running'),
      ),
      _NewWorkAction(
        title: 'إجراء إداري',
        subtitle: 'معاملة إدارية + Checklist',
        icon: Icons.assignment,
        permission: PermissionKeys.proceduresCreate,
        onTap: () => context.push('/procedures/create?archiveStatus=running'),
      ),
      _NewWorkAction(
        title: 'أمر عمل للمعقب',
        subtitle: 'إنشاء أمر offline (PDF/واتساب)',
        icon: Icons.assignment_ind,
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
        permission: PermissionKeys.poaCreate,
        onTap: () => context.go('/poa'),
      ),
      _NewWorkAction(
        title: 'شخص أو جهة',
        subtitle: 'إضافة موكل، خصم، محامي خصم...',
        icon: Icons.person_add,
        permission: PermissionKeys.personsCreate,
        onTap: () => context.go('/persons'),
      ),
      _NewWorkAction(
        title: 'رفع مستند',
        subtitle: 'إضافة مستند مستقل للأرشيف',
        icon: Icons.upload_file,
        permission: PermissionKeys.documentsUpload,
        onTap: () => context.go('/documents'),
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
                      maxCrossAxisExtent: 240,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return InkWell(
                        onTap: item.onTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardBorder, width: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryNavy.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNavy.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(item.icon, color: AppColors.secondaryGold, size: 24),
                              ),
                              const Spacer(),
                              Text(item.title, style: AppTextStyles.headline6.copyWith(
                                color: AppColors.primaryNavy, fontSize: 16,
                              )),
                              const SizedBox(height: 4),
                              Text(item.subtitle, style: AppTextStyles.bodySmallSecondary, maxLines: 2),
                            ],
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
  final String permission;
  final VoidCallback onTap;
  _NewWorkAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.permission,
    required this.onTap,
  });
}
