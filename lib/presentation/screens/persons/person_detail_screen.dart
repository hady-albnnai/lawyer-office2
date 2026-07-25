import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart' show allCasesProvider, poaRepositoryProvider, personRepositoryProvider;
import '../../providers/auth_providers.dart' show authControllerProvider;
import '../../providers/ui_data_providers.dart' show uiPersonsDirectoryProvider;
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../documents/document_viewer.dart';
import 'person_models.dart';

/// ملف الشخص أو الجهة في المرحلة 6.
class PersonDetailScreen extends ConsumerStatefulWidget {
  final String personId;

  const PersonDetailScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(personsDirectoryProvider);
    final person = directory.persons.where((item) => item.id == widget.personId).firstOrNull;

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: person == null
          ? Scaffold(
              appBar: AppBar(title: const Text('السجل غير موجود')),
              body: _emptyState(Icons.person_off, 'السجل غير موجود', 'لم يتم العثور على بيانات هذا الشخص أو الجهة.'),
            )
          : Scaffold(
              appBar: AppBar(
                title: Text('سجل: ${person.fullName}'),
                actions: [
                  IconButton(
                    tooltip: 'إضافة ملاحظة',
                    icon: const Icon(Icons.note_add),
                    onPressed: () => _showAddTimelineDialog(person),
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
                    Tab(text: 'البيانات'),
                    Tab(text: 'الوكالات'),
                    Tab(text: 'الدعاوى'),
                    Tab(text: 'العقود'),
                    Tab(text: 'الشركات'),
                    Tab(text: 'الإجراءات'),
                    Tab(text: 'المستندات'),
                    Tab(text: 'المالية'),
                    Tab(text: 'الخط الزمني'),
                  ],
                ),
              ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  _summaryTab(person),
                  _agenciesTab(person),
                  _linkedIdsTab(Icons.gavel, 'الدعاوى المرتبطة', person.caseIds, 'دعوى'),
                  _linkedIdsTab(Icons.description, 'العقود المرتبطة', person.contractIds, 'عقد'),
                  _linkedIdsTab(Icons.business, 'الشركات المرتبطة', person.companyIds, 'شركة'),
                  _linkedIdsTab(Icons.assignment, 'الإجراءات المرتبطة', person.procedureIds, 'إجراء'),
                  _documentsTab(person),
                  _financeTab(person),
                  _timelineTab(person),
                ],
              ),
            ),
      ),
    );
  }

  Widget _summaryTab(PersonDirectoryRecord person) {
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
                    radius: 42,
                    backgroundColor: AppColors.primaryNavy.withOpacity(0.1),
                    child: Icon(person.kind.icon, color: AppColors.primaryNavy, size: 42),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.fullName, style: AppTextStyles.headline3.copyWith(color: AppColors.primaryNavy)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _badge(person.kind.displayName, AppColors.primaryNavy),
                            ...person.roles.map((role) => _badge(role.displayName, role.color)),
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
            title: 'البيانات الأساسية',
            icon: Icons.badge,
            children: [
              if (person.kind == PersonDirectoryKind.natural) ...[
                _infoRow('اسم الأب', person.fatherName.isEmpty ? 'غير مدخل' : person.fatherName),
                _infoRow('اسم الأم', person.motherName.isEmpty ? 'غير مدخل' : person.motherName),
                _infoRow('الرقم الوطني', person.nationalId.isEmpty ? 'غير مدخل' : person.nationalId),
                _infoRow('القيد المدني', person.registryInfo.isEmpty ? 'غير مدخل' : person.registryInfo),
                _infoRow('المهنة', person.profession.isEmpty ? 'غير مدخلة' : person.profession),
              ] else ...[
                _infoRow('الممثل القانوني', person.legalRepresentative.isEmpty ? 'غير مدخل' : person.legalRepresentative),
                _infoRow('صفة الممثل', person.representativeCapacity.isEmpty ? 'غير مدخلة' : person.representativeCapacity),
              ],
              _infoRow('الهاتف', person.phone.isEmpty ? 'غير مدخل' : person.phone),
              _infoRow('واتساب', person.whatsapp.isEmpty ? 'غير مدخل' : person.whatsapp),
              _infoRow('البريد الإلكتروني', person.email.isEmpty ? 'غير مدخل' : person.email),
              _infoRow('المدينة', person.city.isEmpty ? 'غير محددة' : person.city),
              _infoRow('العنوان', person.address.isEmpty ? 'غير مدخل' : person.address),
              _infoRow('ملاحظات', person.notes.isEmpty ? 'لا توجد ملاحظات' : person.notes),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard('وكالات', person.agencyIds.length.toString(), Icons.verified_user, AppColors.secondaryGold),
              _metricCard('دعاوى', person.caseIds.length.toString(), Icons.gavel, AppColors.primaryNavy),
              _metricCard('عقود', person.contractIds.length.toString(), Icons.description, AppColors.info),
              _metricCard('مستندات', person.documentIds.length.toString(), Icons.folder, AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _agenciesTab(PersonDirectoryRecord person) {
    final agencies = ref.watch(personsDirectoryProvider).agencies.where((agency) => agency.principalPersonId == person.id).toList();

    if (agencies.isEmpty) {
      return _emptyState(Icons.verified_user_outlined, 'لا توجد وكالات', 'لم يتم ربط أي وكالة بهذا السجل بعد.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agencies.length,
      itemBuilder: (context, index) {
        final agency = agencies[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: agency.hasDocument ? AppColors.success.withOpacity(0.12) : AppColors.warning.withOpacity(0.12),
              child: Icon(Icons.verified_user, color: agency.hasDocument ? AppColors.success : AppColors.warning),
            ),
            title: Text('${agency.type.displayName} • ${agency.number}', style: AppTextStyles.labelLarge),
            subtitle: Text('${agency.source.displayName} - ${agency.branch} • ${_formatDate(agency.issuedAt)}', style: AppTextStyles.bodySmallSecondary),
            trailing: _badge(agency.hasDocument ? 'صورة مرفقة' : 'صورة ناقصة', agency.hasDocument ? AppColors.success : AppColors.warning),
            onTap: () => _showAgencySheet(agency, person),
          ),
        );
      },
    );
  }

  Widget _linkedIdsTab(IconData icon, String title, List<String> ids, String prefix) {
    if (ids.isEmpty) {
      return _emptyState(icon, 'لا توجد عناصر', 'لا توجد $title لهذا السجل حالياً.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ids.length,
      itemBuilder: (context, index) => Card(
        child: ListTile(
          leading: Icon(icon, color: AppColors.primaryNavy),
          title: Text('$prefix رقم ${ids[index]}', style: AppTextStyles.labelLarge),
          subtitle: Text('مرتبط بسجل الشخص ضمن المرحلة 6', style: AppTextStyles.bodySmallSecondary),
        ),
      ),
    );
  }

  Widget _documentsTab(PersonDirectoryRecord person) {
    if (person.documentIds.isEmpty) {
      return _emptyState(Icons.folder_off, 'لا توجد مستندات', 'لم يتم ربط مستندات بهذا السجل.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: person.documentIds.length,
      itemBuilder: (context, index) {
        final documentId = person.documentIds[index];
        return Card(
          child: ListTile(
            leading: Icon(Icons.description, color: AppColors.primaryNavy),
            title: Text('مستند $documentId', style: AppTextStyles.labelLarge),
            subtitle: Text('مرتبط بسجل ${person.fullName}', style: AppTextStyles.bodySmallSecondary),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openDocument(context, documentId),
            ),
            onTap: () => openDocument(context, documentId),
          ),
        );
      },
    );
  }

  Widget _financeTab(PersonDirectoryRecord person) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metricCard('المستحق للمكتب', _formatCurrency(person.receivables), Icons.trending_up, AppColors.success),
          _metricCard('المدفوعات / المصروفات', _formatCurrency(person.payables), Icons.trending_down, AppColors.error),
          _metricCard('الرصيد', _formatCurrency(person.balance), Icons.account_balance_wallet, person.balance >= 0 ? AppColors.success : AppColors.error),
        ],
      ),
    );
  }

  Widget _timelineTab(PersonDirectoryRecord person) {
    final events = [
      ...person.timeline,
      DirectoryTimelineEvent(
        id: 'created_${person.id}',
        title: 'إنشاء السجل',
        description: 'تم فتح السجل في المكتب.',
        type: 'created',
        date: person.createdAt,
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) => _timelineTile(events[index]),
    );
  }

  Widget _infoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(title, style: AppTextStyles.bodySmallSecondary),
              Text(value, style: AppTextStyles.headline5.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timelineTile(DirectoryTimelineEvent event) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.primaryNavy, child: const Icon(Icons.history, color: AppColors.textOnLight)),
        title: Text(event.title, style: AppTextStyles.labelLarge),
        subtitle: Text('${event.description}\n${_formatDate(event.date)} • ${event.createdBy}', style: AppTextStyles.bodySmallSecondary),
      ),
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

  void _showAgencySheet(AgencyRecord agency, PersonDirectoryRecord person) {
    int? selectedCaseId;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تفاصيل الوكالة ${agency.number}', style: AppTextStyles.headline5.copyWith(color: AppColors.primaryNavy)),
              const SizedBox(height: 12),
              _infoRow('الموكل', person.fullName),
              _infoRow('الوكيل', agency.agentName),
              _infoRow('النوع', agency.type.displayName),
              _infoRow('المصدر', '${agency.source.displayName} - ${agency.branch}'),
              _infoRow('النطاق', agency.scope.isEmpty ? 'غير محدد' : agency.scope),
              _infoRow('الدعاوى المرتبطة', agency.linkedCaseIds.isEmpty ? 'لا توجد' : agency.linkedCaseIds.join(', ')),
              const SizedBox(height: 12),
              // اختيار دعوى حقيقية بدل إدخال رقم نصي حر قد لا يقابل أي دعوى.
              ref.watch(allCasesProvider).maybeWhen(
                    data: (cases) => DropdownButtonFormField<int>(
                      value: selectedCaseId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'اختر الدعوى للربط'),
                      items: cases
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.internalNumber} — ${c.subject ?? 'دعوى'}',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setSheet(() => selectedCaseId = v),
                    ),
                    orElse: () => const LinearProgressIndicator(),
                  ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('ربط الوكالة بالدعوى'),
                onPressed: () async {
                  final poaId = int.tryParse(agency.id);
                  if (selectedCaseId == null || poaId == null) return;
                  // الحفظ الفعلي في جدول case_poa_links.
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
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _showAddTimelineDialog(PersonDirectoryRecord person) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة ملاحظة للخط الزمني'),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'الملاحظة')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                return;
              }
              final personId = int.tryParse(person.id);
              if (personId == null) return;
              // الحفظ في جدول timeline_events بدل حالة الشاشة فقط.
              try {
                await ref.read(personRepositoryProvider).addTimelineNote(
                      personId: personId,
                      note: text,
                      userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
                    );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تعذر حفظ الملاحظة: $e'), backgroundColor: AppColors.error),
                  );
                }
                return;
              }
              ref.invalidate(uiPersonsDirectoryProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')} ل.س';
  }
}
