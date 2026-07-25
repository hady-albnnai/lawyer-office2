import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import 'create_company_wizard.dart';
import 'company_detail_screen.dart';

/// شاشة إدارة وقائمة الشركات التجارية والمدنية في المكتب (CompaniesListScreen)
class CompaniesListScreen extends ConsumerStatefulWidget {
  const CompaniesListScreen({super.key});

  @override
  ConsumerState<CompaniesListScreen> createState() => _CompaniesListScreenState();
}

class _CompaniesListScreenState extends ConsumerState<CompaniesListScreen> {
  String _searchQuery = '';
  String _selectedStatusFilter = 'الكل';

  final List<String> _statusFilters = ['الكل', 'قيد التأسيس', 'نشطة / عاملة', 'منحلة / مصفاة'];

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(allCompaniesProvider);
    final permissions = ref.watch(permissionServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشيف وملفات الشركات في مكتب المحاماة'),
        actions: [
          if (permissions.can(PermissionKeys.companiesCreate))
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentGold, foregroundColor: AppConstants.primaryNavy),
              icon: const Icon(Icons.add_business),
              label: const Text('تأسيس أو أرشفة شركة'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const CreateCompanyWizard()),
                );
              },
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلترة
          Container(
            padding: const EdgeInsets.all(16),
            color: AppConstants.surfaceWhite,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'بحث باسم الشركة، رقم الملف الداخلي، أو رقم السجل التجاري...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedStatusFilter,
                  items: _statusFilters.map((s) => DropdownMenuItem(value: s, child: Text('الحالة: $s'))).toList(),
                  onChanged: (val) => setState(() => _selectedStatusFilter = val!),
                ),
              ],
            ),
          ),

          // قائمة ملفات الشركات
          Expanded(
            child: companiesAsync.when(
              data: (companies) {
                final filtered = companies.where((c) {
                  bool matchesStatus = true;
                  if (_selectedStatusFilter == 'قيد التأسيس') matchesStatus = c.legalStatus == 'under_establishment';
                  if (_selectedStatusFilter == 'نشطة / عاملة') matchesStatus = c.legalStatus == 'active';
                  if (_selectedStatusFilter == 'منحلة / مصفاة') matchesStatus = c.legalStatus == 'dissolved';

                  final matchesSearch = c.name.toLowerCase().contains(_searchQuery) ||
                      c.internalNumber.toLowerCase().contains(_searchQuery) ||
                      (c.registrationNumber?.toLowerCase().contains(_searchQuery) ?? false);
                  return matchesStatus && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_center_outlined, size: 64, color: AppConstants.textMuted),
                        SizedBox(height: 16),
                        Text('لا توجد ملفات شركات مطابقة للبحث الحالي', style: TextStyle(fontSize: 18, color: AppConstants.textMuted)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    final isUnderEst = c.legalStatus == 'under_establishment';
                    final isDissolved = c.legalStatus == 'dissolved';

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppConstants.primaryNavy.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: isDissolved ? Colors.grey : AppConstants.primaryNavy,
                          child: const Icon(Icons.business, color: AppConstants.accentGold, size: 30),
                        ),
                        title: Row(
                          children: [
                            Text(
                              'شركة [${c.name}] • ملف رقم [${c.internalNumber}]',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppConstants.primaryNavy),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isUnderEst ? AppConstants.statusWarning : (isDissolved ? Colors.grey : AppConstants.statusSuccess),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isUnderEst ? 'قيد التأسيس ⏳' : (isDissolved ? 'منحلة ✖' : 'عاملة ✓'),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text('الشكل القانوني: ${c.companyType} • النشاط: ${c.activity ?? "غير محدد"}'),
                            const SizedBox(height: 4),
                            Text(
                              'رقم السجل التجاري: ${c.registrationNumber ?? "بانتظار الصدور ⚠️"} • المقر: ${c.mainAddress ?? "سوريا"}',
                              style: TextStyle(fontWeight: FontWeight.w600, color: c.registrationNumber == null ? AppConstants.statusDanger : AppConstants.textDark),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: AppConstants.primaryNavy),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => CompanyDetailScreen(companyId: c.id)),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('خطأ في تحميل قائمة الشركات: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
