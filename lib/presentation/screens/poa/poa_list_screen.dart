import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/auth/permission_catalog.dart';
import '../../../data/database/database.dart' as db;
import '../../../data/repositories/archive_intake_repository.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/archive_context_banner.dart';
import '../documents/document_viewer.dart';
import '../persons/person_models.dart';
import 'poa_detail_screen.dart';

/// شاشة إدارة الوكالات القضائية والقانونية في المرحلة 6.
class PoaListScreen extends ConsumerStatefulWidget {
  final ArchiveEntryContext? archiveContext;
  const PoaListScreen({super.key, this.archiveContext});

  @override
  ConsumerState<PoaListScreen> createState() => _PoaListScreenState();
}

class _PoaListScreenState extends ConsumerState<PoaListScreen> {
  String _query = '';
  AgencySource? _sourceFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personsDirectoryProvider);
    final permissions = ref.watch(permissionServiceProvider);
    final agencies = state.agencies.where((agency) {
      final principal = state.personById(agency.principalPersonId);
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          agency.number.toLowerCase().contains(q) ||
          agency.branch.toLowerCase().contains(q) ||
          agency.agentName.toLowerCase().contains(q) ||
          (principal?.fullName.toLowerCase().contains(q) ?? false);
      final matchesSource = _sourceFilter == null || agency.source == _sourceFilter;
      return matchesQuery && matchesSource;
    }).toList();

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.archiveContext == null ? 'أرشيف الوكالات' : (widget.archiveContext!.isRunning ? 'إدخال وكالة أرشيفية جارية' : 'أرشفة وكالة منتهية')),
            actions: [
              if (permissions.can(PermissionKeys.poaCreate))
                IconButton(
                  tooltip: 'إضافة وكالة',
                  icon: const Icon(Icons.add),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AddAgencyDialog(archiveContext: widget.archiveContext),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              if (widget.archiveContext != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ArchiveContextBanner(contextInfo: widget.archiveContext),
                ),
              _toolbar(),
              Expanded(
                child: agencies.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: agencies.length,
                        itemBuilder: (context, index) {
                          final agency = agencies[index];
                          final principal = state.personById(agency.principalPersonId);
                          return _AgencyCard(
                            agency: agency,
                            principalName: principal?.fullName ?? 'غير محدد',
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
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
                hintText: 'بحث برقم الوكالة، الموكل، الفرع، الوكيل...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<AgencySource?>(
            value: _sourceFilter,
            items: const [
              DropdownMenuItem<AgencySource?>(value: null, child: Text('كل الجهات')),
              DropdownMenuItem<AgencySource?>(value: AgencySource.notary, child: Text('كاتب عدل')),
              DropdownMenuItem<AgencySource?>(value: AgencySource.barDelegate, child: Text('مندوب نقابة')),
            ],
            onChanged: (value) => setState(() => _sourceFilter = value),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_shared_outlined, size: 72, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text('لا توجد وكالات مطابقة', style: AppTextStyles.headline5),
          const SizedBox(height: 8),
          Text('غيّر البحث أو فلتر جهة التنظيم.', style: AppTextStyles.bodySmallSecondary),
        ],
      ),
    );
  }
}

class _AgencyCard extends ConsumerWidget {
  final AgencyRecord agency;
  final String principalName;

  const _AgencyCard({required this.agency, required this.principalName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PoaDetailScreen(agencyId: agency.id)),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: agency.hasDocument ? AppColors.success.withOpacity(0.12) : AppColors.warning.withOpacity(0.12),
                    child: Icon(Icons.verified_user, color: agency.hasDocument ? AppColors.success : AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${agency.type.displayName} • ${agency.number}',
                      style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy),
                    ),
                  ),
                  _badge(agency.hasDocument ? 'صورة مرفقة' : 'صورة ناقصة', agency.hasDocument ? AppColors.success : AppColors.warning),
                ],
              ),
              const SizedBox(height: 12),
              _line(Icons.person, 'الموكل: $principalName'),
              _line(Icons.gavel, 'الوكيل: ${agency.agentName}'),
              _line(Icons.account_balance, '${agency.source.displayName} - ${agency.branch}'),
              _line(Icons.calendar_today, 'تاريخ التنظيم: ${_formatDate(agency.issuedAt)}'),
              _line(Icons.link, 'الدعاوى المرتبطة: ${agency.linkedCaseIds.isEmpty ? 'لا توجد' : agency.linkedCaseIds.join(', ')}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (permissions.can(PermissionKeys.poaFilesView))
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description),
                      label: const Text('فتح السند'),
                      onPressed: agency.hasDocument ? () => openDocument(context, agency.documentId) : null,
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
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => PoaDetailScreen(agencyId: agency.id)),
                    ),
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  void _showLinkDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ربط وكالة بدعوى'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'رقم الدعوى')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final caseId = int.tryParse(controller.text.trim());
              final poaId = int.tryParse(agency.id);
              if (caseId == null || poaId == null) return;
              try {
                await ref.read(poaRepositoryProvider).linkPoaToCase(caseId, poaId);
                await ref.read(auditServiceProvider).log(
                  action: 'link',
                  category: 'poa',
                  entityType: 'poa',
                  entityId: agency.id,
                  entityTitle: agency.number,
                  description: 'ربط وكالة بدعوى رقم $caseId',
                  severity: 'info',
                );
                ref.invalidate(uiPersonsDirectoryProvider);
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الربط: $e'), backgroundColor: AppColors.error));
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

class AddAgencyDialog extends ConsumerStatefulWidget {
  final ArchiveEntryContext? archiveContext;
  const AddAgencyDialog({super.key, this.archiveContext});

  @override
  ConsumerState<AddAgencyDialog> createState() => _AddAgencyDialogState();
}

class _AddAgencyDialogState extends ConsumerState<AddAgencyDialog> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _agentController = TextEditingController(text: 'الأستاذ هادي فيصل البني');
  final TextEditingController _branchController = TextEditingController(text: 'دمشق');
  final TextEditingController _scopeController = TextEditingController();
  final TextEditingController _customTypeController = TextEditingController();
  final TextEditingController _documentController = TextEditingController();
  AgencyType _type = AgencyType.general;
  AgencySource _source = AgencySource.barDelegate;
  int? _selectedDelegateId;
  String? _principalPersonId;
  DateTime _issuedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final archive = widget.archiveContext;
    if (archive != null) {
      final poaType = archive.poaType ?? '';
      // Convert string type to AgencyType enum
      if (poaType.contains('خاص') || poaType.contains('بيع')) {
        _type = AgencyType.special;
      } else if (poaType.contains('شرع')) {
        _type = AgencyType.sharia;
      } else {
        _type = AgencyType.general; // Default to general
      }
      
      if (poaType.contains('نقابة') || poaType.contains('قضائية')) {
        _source = AgencySource.barDelegate;
      } else {
        _source = AgencySource.notary; // Default to notary
      }
      
      _scopeController.text = archive.isClosed ? 'أرشفة وكالة منتهية - $poaType' : 'إدخال وكالة جارية - $poaType';
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _agentController.dispose();
    _branchController.dispose();
    _scopeController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final persons = ref.watch(personsDirectoryProvider).persons;
    _principalPersonId ??= persons.isNotEmpty ? persons.first.id : null;

    return AlertDialog(
      title: Text(widget.archiveContext == null ? 'إضافة وكالة جديدة' : (widget.archiveContext!.isRunning ? 'إضافة وكالة أرشيفية جارية' : 'إضافة وكالة منتهية للأرشيف')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ArchiveContextBanner(contextInfo: widget.archiveContext),
              TextField(controller: _numberController, decoration: const InputDecoration(labelText: 'رقم الوكالة / التوثيق')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _principalPersonId,
                decoration: const InputDecoration(labelText: 'الموكل'),
                items: persons.map((person) => DropdownMenuItem(value: person.id, child: Text(person.fullName))).toList(),
                onChanged: (value) => setState(() => _principalPersonId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AgencyType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'نوع الوكالة'),
                items: AgencyType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.displayName))).toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 8),
              TextField(controller: _customTypeController, decoration: const InputDecoration(labelText: 'نوع وكالة آخر / تفصيل غير موجود بالقائمة')),
              const SizedBox(height: 12),
              DropdownButtonFormField<AgencySource>(
                value: _source,
                decoration: const InputDecoration(labelText: 'جهة التنظيم'),
                items: AgencySource.values.map((source) => DropdownMenuItem(value: source, child: Text(source.displayName))).toList(),
                onChanged: (value) => setState(() => _source = value ?? _source),
              ),
              const SizedBox(height: 12),
              TextField(controller: _branchController, decoration: const InputDecoration(labelText: 'فرع النقابة / المحافظة')),
              const SizedBox(height: 12),
              _delegatePicker(),
              const SizedBox(height: 12),
              TextField(controller: _scopeController, maxLines: 2, decoration: const InputDecoration(labelText: 'النطاق')),
              const SizedBox(height: 12),
              TextField(controller: _documentController, decoration: const InputDecoration(labelText: 'معرف المستند المرفق')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('تاريخ التنظيم: ${_formatDate(_issuedAt)}', style: AppTextStyles.bodyMedium)),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _issuedAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _issuedAt = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('اختيار'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }

  Widget _delegatePicker() {
    return FutureBuilder<List<AgencyDelegateRecord>>(
      future: ref.watch(archiveIntakeRepositoryProvider).getAgencyDelegates(includeInactive: false),
      builder: (context, snapshot) {
        final delegates = snapshot.data ?? const <AgencyDelegateRecord>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int?>(
              value: _selectedDelegateId,
              decoration: const InputDecoration(labelText: 'مندوب الوكالات'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('إدخال يدوي / غير محدد')),
                ...delegates.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text('${d.fullName}${d.phone.isNotEmpty ? ' — ${d.phone}' : ''}'))),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDelegateId = value;
                  AgencyDelegateRecord? selected;
                  for (final delegate in delegates) {
                    if (delegate.id == value) {
                      selected = delegate;
                      break;
                    }
                  }
                  if (selected != null) {
                    _agentController.text = selected.fullName;
                    if (selected.barBranch.isNotEmpty) _branchController.text = selected.barBranch;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _agentController, decoration: const InputDecoration(labelText: 'اسم المندوب / الوكيل'))),
                const SizedBox(width: 8),
                OutlinedButton.icon(icon: const Icon(Icons.person_add), label: const Text('إضافة مندوب'), onPressed: _showAddDelegateDialog),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddDelegateDialog() async {
    final name = TextEditingController(text: _agentController.text.trim());
    final phone = TextEditingController();
    final branch = TextEditingController(text: _branchController.text.trim());
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مندوب وكالات'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المندوب *')),
              const SizedBox(height: 12),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
              const SizedBox(height: 12),
              TextField(controller: branch, decoration: const InputDecoration(labelText: 'فرع النقابة')),
              const SizedBox(height: 12),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    ) ?? false;
    if (!ok || name.text.trim().isEmpty) return;
    final id = await ref.read(archiveIntakeRepositoryProvider).upsertAgencyDelegate(fullName: name.text.trim(), phone: phone.text.trim(), barBranch: branch.text.trim(), notes: notes.text.trim());
    await ref.read(auditServiceProvider).log(action: 'create', category: 'lookups', entityType: 'agency_delegate', entityId: '$id', entityTitle: name.text.trim(), description: 'إضافة مندوب وكالات من نافذة الوكالة', severity: 'warning');
    setState(() {
      _selectedDelegateId = id;
      _agentController.text = name.text.trim();
      if (branch.text.trim().isNotEmpty) _branchController.text = branch.text.trim();
    });
  }

  Future<void> _save() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.poaCreate)) {
      await ref.read(auditServiceProvider).log(
            action: 'access_denied',
            category: 'poa',
            entityType: 'poa',
            description: 'محاولة إضافة وكالة دون صلاحية',
            severity: 'warning',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لا تملك صلاحية إضافة وكالة'), backgroundColor: AppColors.error));
      }
      return;
    }

    final principalId = int.tryParse(_principalPersonId ?? '');
    if (principalId == null || _numberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('رقم الوكالة والموكل إلزاميان'), backgroundColor: AppColors.error));
      return;
    }

    try {
      final scope = [
        if (_customTypeController.text.trim().isNotEmpty) 'نوع مخصص: ${_customTypeController.text.trim()}',
        if (_scopeController.text.trim().isNotEmpty) _scopeController.text.trim(),
      ].join('\n');
      
      // Ensure poaType is properly set as integer (0, 1, 2)
      final poaTypeValue = _type.index; // This will be 0, 1, or 2
      
      final poaId = await ref.read(poaRepositoryProvider).createPoa(
            poa: db.PowersOfAttorneyCompanion.insert(
              sourceType: _source == AgencySource.notary ? 'notary' : 'delegate',
              poaType: poaTypeValue, // Use the integer value directly
              poaNumber: Value(_numberController.text.trim()),
              poaDate: Value(_issuedAt),
              category: Value(_source == AgencySource.notary ? 'notarial' : 'judicial'),
              delegateBranch: Value(_branchController.text.trim().isEmpty ? 'دمشق' : _branchController.text.trim()),
              scopeText: Value(scope),
              status: Value(widget.archiveContext?.isClosed == true ? 'archived' : 'active'),
            ),
            principalId: principalId,
          );
      await ref.read(auditServiceProvider).log(
            action: 'create',
            category: 'poa',
            entityType: 'poa',
            entityId: '$poaId',
            entityTitle: _numberController.text.trim(),
            description: 'إضافة وكالة جديدة',
            after: {
              'number': _numberController.text.trim(),
              'principalId': principalId,
              'type': _type.displayName,
              'customType': _customTypeController.text.trim(),
              'source': _source.displayName,
              'poaTypeValue': poaTypeValue,
            },
            severity: 'info',
          );
      ref.invalidate(uiPersonsDirectoryProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حفظ الوكالة: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
