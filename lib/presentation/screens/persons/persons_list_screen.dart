import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/auth/permission_catalog.dart';
import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart' as db;
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';
import '../../theme/app_theme.dart';
import 'person_detail_screen.dart';
import 'person_models.dart';

/// شاشة إدارة الأشخاص والجهات للمرحلة 6.
class PersonsListScreen extends ConsumerStatefulWidget {
  /// دور ابتدائي للفلترة (يُمرر من السايدبار عبر query parameter)
  final String? initialRole;
  const PersonsListScreen({super.key, this.initialRole});

  @override
  ConsumerState<PersonsListScreen> createState() => _PersonsListScreenState();
}

class _PersonsListScreenState extends ConsumerState<PersonsListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<PersonDirectoryRole?> _tabs = const [
    null,
    PersonDirectoryRole.client,
    PersonDirectoryRole.opponent,
    PersonDirectoryRole.opponentLawyer,
    PersonDirectoryRole.notary,
    PersonDirectoryRole.barDelegate,
    PersonDirectoryRole.teamMember,
    PersonDirectoryRole.legalEntity,
  ];

  /// مطابقة نص الدور من الـ query parameter مع PersonDirectoryRole
  int _initialTabIndex() {
    final role = widget.initialRole;
    if (role == null || role.isEmpty) return 0;
    switch (role) {
      case 'client': return 1;
      case 'opponent': return 2;
      case 'opponentLawyer': return 3;
      case 'notary': return 4;
      case 'barDelegate': return 5;
      case 'teamMember': return 6;
      case 'legalEntity': return 7;
      default: return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = _initialTabIndex();
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(personsDirectoryProvider.notifier).setRoleFilter(_tabs[_tabController.index]);
      }
    });
    // تطبيق الفلتر الأولي
    if (initialIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(personsDirectoryProvider.notifier).setRoleFilter(_tabs[initialIndex]);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personsDirectoryProvider);

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
        children: [
          _buildToolbar(state),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((role) => _PersonsTab(role: role)).toList(),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildToolbar(PersonsDirectoryState state) {
    final permissions = ref.watch(permissionServiceProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم، الهوية، الهاتف، المدينة...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref.read(personsDirectoryProvider.notifier).setSearchQuery(value),
            ),
          ),
          const SizedBox(width: 12),
          _counterCard('السجلات', state.persons.length, Icons.people, AppColors.primaryNavy),
          const SizedBox(width: 12),
          _counterCard('الوكالات', state.agencies.length, Icons.verified_user, AppColors.secondaryGold),
          const SizedBox(width: 12),
          if (permissions.can(PermissionKeys.personsCreate))
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة سجل'),
              onPressed: () => _openAddPersonDialog(context),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: AppColors.primaryNavy,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.secondaryGold,
        labelColor: AppColors.secondaryGold,
        unselectedLabelColor: AppColors.textOnLight.withOpacity(0.75),
        labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: AppTextStyles.labelMedium,
        tabs: const [
          Tab(text: 'الكل'),
          Tab(text: 'الموكلون'),
          Tab(text: 'الخصوم'),
          Tab(text: 'محامو الخصوم'),
          Tab(text: 'كتاب العدل'),
          Tab(text: 'مندوبو النقابة'),
          Tab(text: 'فريق المكتب'),
          Tab(text: 'الشركات والجهات'),
        ],
      ),
    );
  }

  Widget _counterCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text('$title: ', style: AppTextStyles.labelSmall),
          Text('$count', style: AppTextStyles.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }

  void _openAddPersonDialog(BuildContext context) {
    // تحديد الدور الحالي من التبويب المختار
    final currentRole = _tabs[_tabController.index];
    showDialog<void>(
      context: context,
      builder: (context) => QuickAddPersonDialog(defaultRole: currentRole),
    );
  }
}

class _PersonsTab extends ConsumerWidget {
  final PersonDirectoryRole? role;

  const _PersonsTab({required this.role});

  /// اسم الدور بالعربية لرسالة الحالة الفارغة
  String get _roleLabel {
    if (role == null) return 'شخص';
    switch (role!) {
      case PersonDirectoryRole.client: return 'موكل';
      case PersonDirectoryRole.opponent: return 'خصم';
      case PersonDirectoryRole.opponentLawyer: return 'محامي خصم';
      case PersonDirectoryRole.notary: return 'كاتب عدل';
      case PersonDirectoryRole.barDelegate: return 'مندوب نقابة';
      case PersonDirectoryRole.teamMember: return 'عضو فريق';
      case PersonDirectoryRole.legalEntity: return 'جهة اعتبارية';
      default: return 'شخص';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personsDirectoryProvider);
    final permissions = ref.watch(permissionServiceProvider);
    final canCreate = permissions.can(PermissionKeys.personsCreate);
    final persons = state.filteredPersons.where((person) => role == null || person.hasRole(role!)).toList();

    if (persons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text('لا يوجد $_roleLabel', style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
              const SizedBox(height: 8),
              Text(
                role == null
                    ? 'لا توجد سجلات مطابقة للبحث الحالي.'
                    : 'لم تُضف أي $_roleLabel بعد. أضف واحداً الآن.',
                style: AppTextStyles.bodyMediumSecondary,
                textAlign: TextAlign.center,
              ),
              if (canCreate && role != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => QuickAddPersonDialog(defaultRole: role),
                  ),
                  icon: const Icon(Icons.person_add, size: 20),
                  label: Text('إضافة $_roleLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.secondaryGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: persons.length,
      itemBuilder: (context, index) => PersonDirectoryCard(person: persons[index]),
    );
  }
}

class PersonDirectoryCard extends ConsumerWidget {
  final PersonDirectoryRecord person;

  const PersonDirectoryCard({super.key, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    final canViewSensitive = permissions.can(PermissionKeys.personsSensitiveView);
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PersonDetailScreen(personId: person.id)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: person.kind == PersonDirectoryKind.legal
                    ? AppColors.primaryNavy.withOpacity(0.12)
                    : AppColors.secondaryGold.withOpacity(0.18),
                child: Icon(person.kind.icon, color: person.kind == PersonDirectoryKind.legal ? AppColors.primaryNavy : AppColors.secondaryGold),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(person.fullName, style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy))),
                        _kindBadge(person.kind.displayName),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: person.roles.map((role) => _roleBadge(role)).toList(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _iconText(Icons.phone, !canViewSensitive ? 'الهاتف مخفي حسب الصلاحيات' : (person.phone.isEmpty ? 'لا يوجد هاتف' : person.phone)),
                        _iconText(Icons.location_on, person.city.isEmpty ? 'غير محدد' : person.city),
                        _iconText(Icons.verified_user, 'وكالات: ${person.agencyIds.length}'),
                        _iconText(Icons.gavel, 'دعاوى: ${person.caseIds.length}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('آخر تحديث: ${_formatDate(person.updatedAt)}', style: AppTextStyles.bodySmallSecondary),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: Text(label, style: AppTextStyles.labelSmall),
    );
  }

  Widget _roleBadge(PersonDirectoryRole role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: role.color.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(role.displayName, style: AppTextStyles.labelSmall.copyWith(color: role.color)),
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmallSecondary),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class QuickAddPersonDialog extends ConsumerStatefulWidget {
  /// الدور الافتراضي (يُملأ تلقائياً حسب التبويب الحالي)
  final PersonDirectoryRole? defaultRole;
  const QuickAddPersonDialog({super.key, this.defaultRole});

  @override
  ConsumerState<QuickAddPersonDialog> createState() => _QuickAddPersonDialogState();
}

class _QuickAddPersonDialogState extends ConsumerState<QuickAddPersonDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController(text: 'دمشق');
  PersonDirectoryKind _kind = PersonDirectoryKind.natural;
  late PersonDirectoryRole _role;

  @override
  void initState() {
    super.initState();
    _role = widget.defaultRole ?? PersonDirectoryRole.client;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة سجل سريع'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'الاسم الكامل / اسم الجهة')),
            const SizedBox(height: 12),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'الهاتف')),
            const SizedBox(height: 12),
            TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'المدينة')),
            const SizedBox(height: 12),
            DropdownButtonFormField<PersonDirectoryKind>(
              value: _kind,
              decoration: const InputDecoration(labelText: 'نوع السجل'),
              items: PersonDirectoryKind.values.map((kind) => DropdownMenuItem(value: kind, child: Text(kind.displayName))).toList(),
              onChanged: (value) => setState(() => _kind = value ?? _kind),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PersonDirectoryRole>(
              value: _role,
              decoration: const InputDecoration(labelText: 'الدور'),
              items: PersonDirectoryRole.values.map((role) => DropdownMenuItem(value: role, child: Text(role.displayName))).toList(),
              onChanged: (value) => setState(() => _role = value ?? _role),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }

  Future<void> _save() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.personsCreate)) {
      await ref.read(auditServiceProvider).log(
            action: 'access_denied',
            category: 'persons',
            entityType: 'person',
            description: 'محاولة إضافة شخص/جهة دون صلاحية',
            severity: 'warning',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('لا تملك صلاحية إضافة الأشخاص والجهات'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('الاسم إلزامي'), backgroundColor: AppColors.error));
      return;
    }

    try {
      final role = _mapUiRoleToDb(_role);
      final personId = await ref.read(personRepositoryProvider).createPerson(
            person: db.PersonsCompanion.insert(
              fullName: name,
              type: Value(_kind == PersonDirectoryKind.legal ? PersonType.legal.index : PersonType.natural.index),
              phone1: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
              whatsapp: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
              city: Value(_cityController.text.trim().isEmpty ? null : _cityController.text.trim()),
            ),
            initialRoles: role == null ? null : [role],
          );
      await ref.read(auditServiceProvider).log(
            action: 'create',
            category: 'persons',
            entityType: 'person',
            entityId: '$personId',
            entityTitle: name,
            description: 'إضافة سجل شخص/جهة',
            after: {
              'name': name,
              'kind': _kind.displayName,
              'role': _role.displayName,
              'phone': _phoneController.text.trim(),
              'city': _cityController.text.trim(),
            },
            severity: 'info',
          );
      ref.invalidate(allPersonsProvider(null));
      ref.invalidate(uiPersonsDirectoryProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حفظ السجل: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  PersonRoleType? _mapUiRoleToDb(PersonDirectoryRole role) {
    switch (role) {
      case PersonDirectoryRole.client:
        return PersonRoleType.client;
      case PersonDirectoryRole.opponent:
        return PersonRoleType.opponent;
      case PersonDirectoryRole.teamMember:
        return PersonRoleType.teamMember;
      case PersonDirectoryRole.contractParty:
        return PersonRoleType.contractParty;
      case PersonDirectoryRole.legalEntity:
        return PersonRoleType.client;
      case PersonDirectoryRole.opponentLawyer:
      case PersonDirectoryRole.notary:
      case PersonDirectoryRole.barDelegate:
        return null;
    }
  }
}
