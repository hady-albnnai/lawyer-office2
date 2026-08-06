import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart' show allCasesProvider, poaRepositoryProvider;
import '../../providers/ui_data_providers.dart' show uiPersonsDirectoryProvider;
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';
import '../../theme/app_theme.dart';
import '../documents/document_viewer.dart';
import '../persons/person_models.dart';

/// شاشة تفاصيل وكالة قضائية أو قانونية ضمن المرحلة 6.
class PoaDetailScreen extends ConsumerStatefulWidget {
  final String agencyId;

  const PoaDetailScreen({super.key, required this.agencyId});

  @override
  ConsumerState<PoaDetailScreen> createState() => _PoaDetailScreenState();
}

class _PoaDetailScreenState extends ConsumerState<PoaDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personsDirectoryProvider);
    final agency = state.agencyById(widget.agencyId);
    final principal = agency == null ? null : state.personById(agency.principalPersonId);

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: agency == null
            ? Scaffold(
                appBar: AppBar(title: const Text('الوكالة غير موجودة')),
                body: _emptyState(Icons.verified_user_outlined, 'الوكالة غير موجودة', 'لم يتم العثور على سجل الوكالة المطلوب.'),
              )
            : Scaffold(
                appBar: AppBar(
                  title: Text('وكالة رقم ${agency.number}'),
                  actions: [
                    IconButton(
                      tooltip: 'ربط بدعوى',
                      icon: const Icon(Icons.link),
                      onPressed: () => _showLinkDialog(agency),
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: AppColors.secondaryGold,
                    labelColor: AppColors.secondaryGold,
                    unselectedLabelColor: AppColors.textOnLight.withOpacity(0.75),
                    labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'الملخص'),
                      Tab(text: 'الأطراف'),
                      Tab(text: 'الدعاوى المرتبطة'),
                      Tab(text: 'المستندات'),
                      Tab(text: 'الخط الزمني'),
                    ],
                  ),
                ),
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _summaryTab(agency, principal),
                    _partiesTab(agency, principal),
                    _casesTab(agency),
                    _documentsTab(agency),
                    _timelineTab(agency),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summaryTab(AgencyRecord agency, PersonDirectoryRecord? principal) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: agency.hasDocument ? AppColors.success.withOpacity(0.12) : AppColors.warning.withOpacity(0.12),
                    child: Icon(Icons.verified_user, color: agency.hasDocument ? AppColors.success : AppColors.warning, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${agency.type.displayName} • ${agency.number}', style: AppTextStyles.headline4.copyWith(color: AppColors.primaryNavy)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _badge(agency.source.displayName, AppColors.primaryNavy),
                            _badge(agency.hasDocument ? 'سند مرفق' : 'سند ناقص', agency.hasDocument ? AppColors.success : AppColors.warning),
                            if (agency.isExpired) _badge('منتهية', AppColors.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _infoCard(
            title: 'بيانات الوكالة',
            icon: Icons.assignment_ind,
            children: [
              _infoRow('الموكل', principal?.fullName ?? 'غير محدد'),
              _infoRow('الوكيل', agency.agentName),
              _infoRow('جهة التنظيم', '${agency.source.displayName} - ${agency.branch}'),
              _infoRow('تاريخ التنظيم', _formatDate(agency.issuedAt)),
              _infoRow('تاريخ الانتهاء', agency.expiresAt == null ? 'غير محدد' : _formatDate(agency.expiresAt!)),
              _infoRow('النطاق', agency.scope.isEmpty ? 'غير مدخل' : agency.scope),
              _infoRow('ملاحظات', agency.notes.isEmpty ? 'لا توجد ملاحظات' : agency.notes),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partiesTab(AgencyRecord agency, PersonDirectoryRecord? principal) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.success.withOpacity(0.12), child: Icon(Icons.person, color: AppColors.success)),
            title: Text(principal?.fullName ?? 'غير محدد', style: AppTextStyles.labelLarge),
            subtitle: Text('الموكل / صاحب التوكيل', style: AppTextStyles.bodySmallSecondary),
            onTap: principal == null
                ? null
                : () => GoRouter.of(context).push('/persons/${principal.id}'),
          ),
        ),
        Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.primaryNavy.withOpacity(0.12), child: Icon(Icons.gavel, color: AppColors.primaryNavy)),
            title: Text(agency.agentName, style: AppTextStyles.labelLarge),
            subtitle: Text('الوكيل', style: AppTextStyles.bodySmallSecondary),
          ),
        ),
      ],
    );
  }

  Widget _casesTab(AgencyRecord agency) {
    if (agency.linkedCaseIds.isEmpty) {
      return _emptyState(Icons.gavel, 'لا توجد دعاوى مرتبطة', 'استخدم زر الربط لإضافة دعوى إلى هذه الوكالة.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agency.linkedCaseIds.length,
      itemBuilder: (context, index) => Card(
        child: ListTile(
          leading: Icon(Icons.gavel, color: AppColors.primaryNavy),
          title: Text('دعوى رقم ${agency.linkedCaseIds[index]}', style: AppTextStyles.labelLarge),
          subtitle: Text('مرتبطة بهذه الوكالة', style: AppTextStyles.bodySmallSecondary),
        ),
      ),
    );
  }

  Widget _documentsTab(AgencyRecord agency) {
    if (!agency.hasDocument) {
      return _emptyState(Icons.folder_off, 'سند الوكالة غير مرفق', 'يجب إرفاق صورة الوكالة لتكتمل الثبوتيات.');
    }
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.open_in_new),
        label: const Text('فتح سند الوكالة'),
        onPressed: () => openDocument(context, agency.documentId),
      ),
    );
  }

  Widget _timelineTab(AgencyRecord agency) {
    final events = [
      ...agency.timeline,
      DirectoryTimelineEvent(
        id: 'agency_created_${agency.id}',
        title: 'تنظيم الوكالة',
        description: 'تم تنظيم الوكالة رقم ${agency.number}.',
        type: 'created',
        date: agency.issuedAt,
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) => Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: AppColors.primaryNavy, child: const Icon(Icons.history, color: AppColors.textOnLight)),
          title: Text(events[index].title, style: AppTextStyles.labelLarge),
          subtitle: Text('${events[index].description}\n${_formatDate(events[index].date)}', style: AppTextStyles.bodySmallSecondary),
        ),
      ),
    );
  }

  Widget _infoCard({required String title, required IconData icon, required List<Widget> children}) {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryNavy),
                const SizedBox(width: 8),
                Text(title, style: AppTextStyles.headline5.copyWith(color: AppColors.primaryNavy)),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: AppTextStyles.labelMedium)),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.headline5),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyles.bodySmallSecondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showLinkDialog(AgencyRecord agency) {
    int? selectedCaseId;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('ربط الوكالة بدعوى'),
          // اختيار دعوى حقيقية بدل رقم نصي حر، والربط يُحفظ في case_poa_links.
          content: ref.watch(allCasesProvider).maybeWhen(
                data: (cases) => cases.isEmpty
                    ? const Text('لا توجد دعاوى متاحة للربط.')
                    : DropdownButtonFormField<int>(
                        value: selectedCaseId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'اختر الدعوى'),
                        items: cases
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.internalNumber} — ${c.subject ?? 'دعوى'}',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setDialog(() => selectedCaseId = v),
                      ),
                orElse: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
              ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final poaId = int.tryParse(agency.id);
                if (selectedCaseId == null || poaId == null) return;
                try {
                  await ref.read(poaRepositoryProvider).linkPoaToCase(selectedCaseId!, poaId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر ربط الوكالة: $e'), backgroundColor: AppColors.error),
                    );
                  }
                  return;
                }
                ref.invalidate(uiPersonsDirectoryProvider);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم ربط الوكالة بالدعوى.'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('ربط'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
