import '../../theme/glassmorphism_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import 'create_contract_screen.dart';
import 'contract_detail_screen.dart';
import 'templates_management_screen.dart';

/// شاشة إدارة وقائمة العقود والنماذج القانونية في المكتب (ContractsListScreen)
class ContractsListScreen extends ConsumerStatefulWidget {
  const ContractsListScreen({super.key});

  @override
  ConsumerState<ContractsListScreen> createState() => _ContractsListScreenState();
}

class _ContractsListScreenState extends ConsumerState<ContractsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
          color: AppConstants.surfaceWhite,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'بحث بعنوان العقد، رقم الملف الداخلي، أو رقم التوثيق...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text('إدارة قوالب Word'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const TemplatesManagementScreen()),
                  );
                },
              ),
              const SizedBox(width: 12),
              if (permissions.can(PermissionKeys.contractsCreate))
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentGold, foregroundColor: AppConstants.primaryNavy),
                  icon: const Icon(Icons.add),
                  label: const Text('تنظيم عقد جديد'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CreateContractScreen()),
                    );
                  },
                ),
            ],
          ),
        ),
        Container(
          color: AppConstants.primaryNavy,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppConstants.accentGold,
            labelColor: AppConstants.accentGold,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'الكل'),
              Tab(text: 'عقارية'),
              Tab(text: 'تجارية'),
              Tab(text: 'مهنية وعمل'),
              Tab(text: 'شراكة وشركات'),
              Tab(text: 'تسوية وصلح'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(null),
              _buildList('عقاري'),
              _buildList('تجاري'),
              _buildList('مهني'),
              _buildList('شركات'),
              _buildList('تسوية'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(String? category) {
    final contractsAsync = ref.watch(allContractsProvider);

    return contractsAsync.when(
      data: (contracts) {
        final filtered = contracts.where((c) {
          bool matchesCat = category == null || c.contractType.contains(category);
          final matchesSearch = c.title.toLowerCase().contains(_searchQuery) ||
              c.internalNumber.toLowerCase().contains(_searchQuery);
          return matchesCat && matchesSearch;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 64, color: AppConstants.textMuted),
                SizedBox(height: 16),
                Text('لا توجد عقود مطابقة للبحث الحالي', style: TextStyle(fontSize: 18, color: AppConstants.textMuted)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final c = filtered[index];
            final isActive = c.status == 'active';

            return GlassmorphicCard(
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive ? AppConstants.primaryNavy : Colors.grey,
                  child: const Icon(Icons.description, color: AppConstants.accentGold),
                ),
                title: Text(
                  'عقد [${c.title}] • رقم الملف: ${c.internalNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppConstants.primaryNavy),
                ),
                subtitle: Text(
                  'النوع: ${c.contractType} • تاريخ الإبرام: ${c.dateSigned?.toString().substring(0, 10) ?? "---"} • القيمة: ${c.financialValue ?? 0} ${c.currency}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ContractDetailScreen(contractId: c.id)),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ في تحميل العقود: $err')),
    );
  }
}
