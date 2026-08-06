import '../../theme/app_colors.dart';
import '../../theme/glassmorphism_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import 'create_procedure_screen.dart';
import 'procedure_detail_screen.dart';

/// شاشة إدارة وقائمة الإجراءات الإدارية والمعاملات في المكتب (ProceduresListScreen)
class ProceduresListScreen extends ConsumerStatefulWidget {
  const ProceduresListScreen({super.key});

  @override
  ConsumerState<ProceduresListScreen> createState() => _ProceduresListScreenState();
}

class _ProceduresListScreenState extends ConsumerState<ProceduresListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionServiceProvider);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.cardBackground,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'بحث باسم الموكل، عنوان المعاملة، أو رقم الطلب...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 16),
              if (permissions.can(PermissionKeys.proceduresCreate))
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryGold, foregroundColor: AppColors.primaryNavy),
                  icon: const Icon(Icons.add_task),
                  label: const Text('تسجيل معاملة إدارية جديدة'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CreateProcedureScreen()),
                    );
                  },
                ),
            ],
          ),
        ),
        Container(
          color: AppColors.primaryNavy,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppColors.secondaryGold,
            labelColor: AppColors.secondaryGold,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'الكل'),
              Tab(text: 'أحوال شخصية'),
              Tab(text: 'إجراءات عقارية'),
              Tab(text: 'إجراءات تجارية'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(null),
              _buildList('أحوال شخصية'),
              _buildList('عقاري'),
              _buildList('تجاري'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(String? category) {
    final stream = ref.watch(allProceduresProvider);

    return stream.when(
      data: (procedures) {
        final filtered = procedures.where((p) {
          bool matchesCat = category == null || p.procedureType.contains(category);
          final matchesSearch = p.title.toLowerCase().contains(_searchQuery) ||
              p.internalNumber.toLowerCase().contains(_searchQuery) ||
              (p.transactionNumber?.toLowerCase().contains(_searchQuery) ?? false);
          return matchesCat && matchesSearch;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: AppColors.textSecondary),
                SizedBox(height: 16),
                Text('لا توجد معاملات مطابقة للبحث الحالي', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final p = filtered[index];
            return GlassmorphicCard(
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryNavy,
                  child: Icon(
                    p.procedureType.contains('عقاري') ? Icons.location_city : (p.procedureType.contains('تجاري') ? Icons.business : Icons.family_restroom),
                    color: AppColors.secondaryGold,
                  ),
                ),
                title: Text(
                  'معاملة [${p.title}] • رقم الملف: ${p.internalNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.primaryNavy),
                ),
                subtitle: Text(
                  'التصنيف: ${p.procedureType} (${p.subType ?? ""}) • الدائرة: ${p.department ?? "---"} • رقم الطلب: ${p.transactionNumber ?? "بانتظار التسجيل"}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ProcedureDetailScreen(procedureId: p.id)),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ في تحميل المعاملات: $err')),
    );
  }
}
