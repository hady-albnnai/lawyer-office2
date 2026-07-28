/// شاشة ملفات الوكالات في ملفات المكتب
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../providers/auth_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../poa/poa_list_screen.dart' show AddAgencyDialog;

enum AgencyFileStatus {
  active,
  archived,
  expired;

  String get displayName => const ['جارية', 'مؤرشفة', 'منتهية'][index];
  Color get color => const [AppColors.info, AppColors.textSecondary, AppColors.warning][index];
}

class AgencyFileItem {
  final String id;
  final String fileNumber;
  final String title;
  final String principalName;
  final String agentName;
  final String sourceType;
  final String branch;
  final DateTime issuedAt;
  final AgencyFileStatus status;
  final bool hasDocument;
  final String? documentId;
  final DateTime? expiryDate;
  final List<String> linkedCaseIds;

  const AgencyFileItem({
    required this.id,
    required this.fileNumber,
    required this.title,
    required this.principalName,
    required this.agentName,
    required this.sourceType,
    required this.branch,
    required this.issuedAt,
    required this.status,
    this.hasDocument = false,
    this.documentId,
    this.expiryDate,
    this.linkedCaseIds = const [],
  });
}

final agencyFilesProvider = FutureProvider<List<AgencyFileItem>>((ref) async {
  await ref.watch(coreDataBootstrapProvider.future);
  final directory = await ref.watch(uiPersonsDirectoryProvider.future);
  
  return directory.agencies.map((agency) {
    final principal = directory.personById(agency.principalPersonId);
    return AgencyFileItem(
      id: agency.id,
      fileNumber: agency.number,
      title: '${agency.type.displayName} - ${agency.number}',
      principalName: principal?.fullName ?? 'غير محدد',
      agentName: agency.agentName,
      sourceType: agency.source.displayName,
      branch: agency.branch,
      issuedAt: agency.issuedAt,
      status: agency.isExpired ? AgencyFileStatus.expired : AgencyFileStatus.active,
      hasDocument: agency.hasDocument,
      documentId: agency.documentId,
      expiryDate: agency.expiresAt,
      linkedCaseIds: agency.linkedCaseIds,
    );
  }).toList();
});

class AgencyFilesScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const AgencyFilesScreen({super.key, this.initialStatus});

  @override
  ConsumerState<AgencyFilesScreen> createState() => _AgencyFilesScreenState();
}

class _AgencyFilesScreenState extends ConsumerState<AgencyFilesScreen> {
  late String _statusFilter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus ?? 'all';
  }

  @override
  void didUpdateWidget(covariant AgencyFilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      _statusFilter = widget.initialStatus ?? 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncFiles = ref.watch(agencyFilesProvider);
    final permissions = ref.watch(permissionServiceProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ملفات الوكالات'),
          actions: [
            if (permissions.can(PermissionKeys.poaCreate))
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'إضافة وكالة',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => const AddAgencyDialog(),
                ),
              ),
          ],
        ),
        body: asyncFiles.when(
          data: (files) {
            final filteredFiles = _filteredFiles(files);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilters(files),
                _buildSummary(files, filteredFiles),
                Expanded(child: _buildFilesList(filteredFiles)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 72, color: AppColors.error),
                const SizedBox(height: 16),
                Text('حدث خطأ في تحميل البيانات', style: AppTextStyles.headline6),
                const SizedBox(height: 8),
                Text(error.toString(), style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AgencyFileItem> _filteredFiles(List<AgencyFileItem> all) {
    final q = _query.trim().toLowerCase();
    return all.where((file) {
      final statusOk = switch (_statusFilter) {
        'all' => true,
        'active' => file.status == AgencyFileStatus.active,
        'archived' => file.status == AgencyFileStatus.archived,
        'expired' => file.status == AgencyFileStatus.expired,
        _ => true,
      };
      final queryOk = q.isEmpty ||
          file.fileNumber.toLowerCase().contains(q) ||
          file.title.toLowerCase().contains(q) ||
          file.principalName.toLowerCase().contains(q) ||
          file.agentName.toLowerCase().contains(q) ||
          file.branch.toLowerCase().contains(q);
      return statusOk && queryOk;
    }).toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  Widget _buildFilters(List<AgencyFileItem> allFiles) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'بحث برقم الوكالة، الموكل، الوكيل، الفرع...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip('all', 'الكل'),
                _statusChip('active', 'جارية'),
                _statusChip('archived', 'مؤرشفة'),
                _statusChip('expired', 'منتهية'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String value, String label) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primaryNavy.withOpacity(0.10),
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryNavy : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }

  Widget _buildSummary(List<AgencyFileItem> all, List<AgencyFileItem> filtered) {
    final active = all.where((f) => f.status == AgencyFileStatus.active).length;
    final archived = all.where((f) => f.status == AgencyFileStatus.archived).length;
    final expired = all.where((f) => f.status == AgencyFileStatus.expired).length;
    final withDocs = all.where((f) => f.hasDocument).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _metric('المعروض', filtered.length, Icons.folder_open, AppColors.primaryNavy),
          _metric('جارية', active, Icons.play_circle_outline, AppColors.info),
          _metric('مؤرشفة', archived, Icons.archive, AppColors.textSecondary),
          _metric('منتهية', expired, Icons.warning, AppColors.warning),
          _metric('مع صورة', withDocs, Icons.description, AppColors.success),
        ],
      ),
    );
  }

  Widget _metric(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: AppTextStyles.labelSmall),
          Text('$count', style: AppTextStyles.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildFilesList(List<AgencyFileItem> files) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 72, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('لا توجد وكالات ضمن هذا التبويب', style: AppTextStyles.headline6),
            const SizedBox(height: 8),
            Text('غيّر الفلتر أو أضف وكالة جديدة.', style: AppTextStyles.bodySmallSecondary),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) => AgencyFileCard(file: files[index]),
    );
  }
}

class AgencyFileCard extends ConsumerWidget {
  final AgencyFileItem file;

  const AgencyFileCard({super.key, required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openAgencyDetail(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      file.fileNumber,
                      style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy),
                    ),
                  ),
                  _badge(file.status.displayName, file.status.color),
                  const SizedBox(width: 8),
                  if (file.hasDocument)
                    _badge('صورة مرفقة', AppColors.success)
                  else
                    _badge('صورة ناقصة', AppColors.warning),
                ],
              ),
              const SizedBox(height: 8),
              Text(file.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _line(Icons.person, 'الموكل: ${file.principalName}'),
              _line(Icons.verified_user, 'الوكيل: ${file.agentName}'),
              _line(Icons.account_balance, '${file.sourceType} - ${file.branch}'),
              _line(Icons.calendar_today, 'تاريخ التنظيم: ${_formatDate(file.issuedAt)}'),
              if (file.expiryDate != null)
                _line(Icons.event_busy, 'تاريخ الانتهاء: ${_formatDate(file.expiryDate!)}'),
              if (file.linkedCaseIds.isNotEmpty)
                _line(Icons.link, 'الدعاوى المرتبطة: ${file.linkedCaseIds.join(', ')}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (permissions.can(PermissionKeys.poaFilesView) && file.hasDocument)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description),
                      label: const Text('فتح السند'),
                      onPressed: () => _openDocument(context),
                    ),
                  if (permissions.can(PermissionKeys.poaEdit))
                    ElevatedButton.icon(
                      icon: const Icon(Icons.link),
                      label: const Text('ربط بدعوى'),
                      onPressed: () => _showLinkDialog(context, ref),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('تفاصيل'),
                    onPressed: () => _openAgencyDetail(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTextStyles.bodySmallSecondary)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  void _openAgencyDetail(BuildContext context) {
    context.go('/poa/${file.id}');
  }

  void _openDocument(BuildContext context) {
    if (file.documentId != null && file.documentId!.isNotEmpty) {
      context.go('/documents/${file.documentId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مستند مرتبط'), backgroundColor: AppColors.warning),
      );
    }
  }

  void _showLinkDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ربط وكالة بدعوى'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'رقم الدعوى'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final caseId = int.tryParse(controller.text.trim());
              final poaId = int.tryParse(file.id);
              if (caseId == null || poaId == null) return;
              try {
                await ref.read(poaRepositoryProvider).linkPoaToCase(caseId, poaId);
                await ref.read(auditServiceProvider).log(
                  action: 'link',
                  category: 'poa',
                  entityType: 'poa',
                  entityId: file.id,
                  entityTitle: file.fileNumber,
                  description: 'ربط وكالة بدعوى رقم $caseId',
                  severity: 'info',
                );
                ref.invalidate(agencyFilesProvider);
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل الربط: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('ربط'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}