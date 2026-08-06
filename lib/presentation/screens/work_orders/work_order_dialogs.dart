import 'dart:io';
import 'dart:typed_data';
/// حوارات أوامر العمل — تنفيذ حقيقي على SQLite + PDF + واتساب.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/office_settings_provider.dart';
import '../../providers/ui_data_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';
import 'work_order_models.dart';

String workOrderTypeToDb(WorkOrderType t) {
  switch (t) {
    case WorkOrderType.courtAttendance:
      return 'court_attendance';
    case WorkOrderType.documentPhotocopy:
      return 'document_photocopy';
    case WorkOrderType.feePayment:
      return 'fee_payment';
    case WorkOrderType.extractCopy:
      return 'extract_copy';
    case WorkOrderType.organizeAgency:
      return 'organize_agency';
    case WorkOrderType.notaryReview:
      return 'notary_review';
    case WorkOrderType.notificationFollowup:
      return 'notification_followup';
    case WorkOrderType.executionFollowup:
      return 'execution_followup';
    case WorkOrderType.commercialRegistry:
      return 'commercial_registry';
    case WorkOrderType.financialReview:
      return 'financial_review';
    case WorkOrderType.other:
      return 'other';
  }
}

String workOrderPriorityToDb(WorkOrderPriority p) {
  switch (p) {
    case WorkOrderPriority.high:
      return 'high';
    case WorkOrderPriority.low:
      return 'low';
    case WorkOrderPriority.medium:
      return 'medium';
  }
}

enum WorkOrderLinkTarget {
  none,
  caseFile,
  procedure,
  company,
  contract,
  person;

  String get label => const [
        'بدون ارتباط / أمر عام',
        'دعوى',
        'إجراء إداري',
        'شركة',
        'عقد',
        'موكل / جهة',
      ][index];

  int get entityType {
    switch (this) {
      case WorkOrderLinkTarget.none:
      case WorkOrderLinkTarget.caseFile:
        return EntityType.caseEntity.index;
      case WorkOrderLinkTarget.procedure:
        return EntityType.adminProcedure.index;
      case WorkOrderLinkTarget.company:
        return EntityType.company.index;
      case WorkOrderLinkTarget.contract:
        return EntityType.contract.index;
      case WorkOrderLinkTarget.person:
        return EntityType.person.index;
    }
  }
}

const int workOrderDocumentEntityType = 99;

String _fileExtension(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  return dot == -1 ? 'file' : name.substring(dot + 1).toLowerCase();
}

class CreateWorkOrderDialog extends ConsumerStatefulWidget {
  const CreateWorkOrderDialog({super.key});

  @override
  ConsumerState<CreateWorkOrderDialog> createState() => _CreateWorkOrderDialogState();
}

class _CreateWorkOrderDialogState extends ConsumerState<CreateWorkOrderDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _instructions = TextEditingController();
  final _linkSearch = TextEditingController();
  WorkOrderLinkTarget _linkTarget = WorkOrderLinkTarget.none;
  int _linkedEntityId = 0;
  String _linkedEntityTitle = 'أمر عام';
  WorkOrderType _type = WorkOrderType.courtAttendance;
  WorkOrderPriority _priority = WorkOrderPriority.medium;
  DateTime _due = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _instructions.dispose();
    _linkSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إنشاء أمر عمل للمعقب'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المكلف *')),
              const SizedBox(height: 10),
              TextField(controller: _phone, decoration: const InputDecoration(labelText: 'هاتف المكلف')),
              const SizedBox(height: 10),
              DropdownButtonFormField<WorkOrderType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'نوع التكليف'),
                items: WorkOrderType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<WorkOrderPriority>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'الأولوية'),
                items: WorkOrderPriority.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.displayName)))
                    .toList(),
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<WorkOrderLinkTarget>(
                value: _linkTarget,
                decoration: const InputDecoration(labelText: 'يرتبط هذا الأمر بـ'),
                items: WorkOrderLinkTarget.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _linkTarget = v ?? WorkOrderLinkTarget.none;
                  _linkedEntityId = 0;
                  _linkedEntityTitle = _linkTarget == WorkOrderLinkTarget.none ? 'أمر عام' : '';
                  _linkSearch.clear();
                }),
              ),
              if (_linkTarget != WorkOrderLinkTarget.none) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _linkSearch,
                  decoration: InputDecoration(
                    labelText: _linkSearchLabel,
                    hintText: _linkSearchHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                _buildLinkResults(),
              ],
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('موعد التنفيذ: ${_due.toString().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _due,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('ar', 'SY'),
                  );
                  if (picked != null) setState(() => _due = picked);
                },
              ),
              TextField(
                controller: _instructions,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'تعليمات الأستاذ'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جارٍ الحفظ...' : 'إنشاء وحفظ'),
        ),
      ],
    );
  }

  String get _linkSearchLabel {
    switch (_linkTarget) {
      case WorkOrderLinkTarget.caseFile:
        return 'اختر الدعوى';
      case WorkOrderLinkTarget.procedure:
        return 'اختر المعاملة / الإجراء';
      case WorkOrderLinkTarget.company:
        return 'اختر الشركة';
      case WorkOrderLinkTarget.contract:
        return 'اختر العقد';
      case WorkOrderLinkTarget.person:
        return 'اختر الموكل أو الجهة';
      case WorkOrderLinkTarget.none:
        return '';
    }
  }

  String get _linkSearchHint {
    switch (_linkTarget) {
      case WorkOrderLinkTarget.caseFile:
        return 'اسم الموكل أو رقم الدعوى أو موضوعها';
      case WorkOrderLinkTarget.procedure:
        return 'اسم الموكل أو عنوان المعاملة أو رقمها';
      case WorkOrderLinkTarget.company:
        return 'اسم الشركة أو رقم الملف';
      case WorkOrderLinkTarget.contract:
        return 'عنوان العقد أو أحد الأطراف';
      case WorkOrderLinkTarget.person:
        return 'الاسم أو الهاتف أو رقم الهوية';
      case WorkOrderLinkTarget.none:
        return '';
    }
  }

  Widget _buildLinkResults() {
    final query = _linkSearch.text.trim().toLowerCase();
    switch (_linkTarget) {
      case WorkOrderLinkTarget.caseFile:
        final asyncItems = ref.watch(allCasesProvider);
        return asyncItems.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('تعذر تحميل الدعاوى: $e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          data: (items) => _buildChoices(items
              .where((c) => query.isEmpty || c.internalNumber.toLowerCase().contains(query) || (c.subject ?? '').toLowerCase().contains(query) || (c.baseNumber ?? '').toLowerCase().contains(query))
              .take(8)
              .map((c) => (id: c.id, title: '${c.internalNumber} — ${c.subject ?? 'دعوى'}'))
              .toList()),
        );
      case WorkOrderLinkTarget.procedure:
        final asyncItems = ref.watch(allProceduresProvider);
        return asyncItems.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('تعذر تحميل الإجراءات: $e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          data: (items) => _buildChoices(items
              .where((p) => query.isEmpty || p.title.toLowerCase().contains(query) || (p.transactionNumber ?? '').toLowerCase().contains(query))
              .take(8)
              .map((p) => (id: p.id, title: '${p.title} — ${p.transactionNumber ?? p.procedureType}'))
              .toList()),
        );
      case WorkOrderLinkTarget.company:
        final asyncItems = ref.watch(allCompaniesProvider);
        return asyncItems.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('تعذر تحميل الشركات: $e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          data: (items) => _buildChoices(items
              .where((c) => query.isEmpty || c.name.toLowerCase().contains(query) || c.internalNumber.toLowerCase().contains(query))
              .take(8)
              .map((c) => (id: c.id, title: '${c.name} — ${c.internalNumber}'))
              .toList()),
        );
      case WorkOrderLinkTarget.contract:
        final asyncItems = ref.watch(allContractsProvider);
        return asyncItems.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('تعذر تحميل العقود: $e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          data: (items) => _buildChoices(items
              .where((c) => query.isEmpty || c.title.toLowerCase().contains(query) || c.internalNumber.toLowerCase().contains(query))
              .take(8)
              .map((c) => (id: c.id, title: '${c.title} — ${c.internalNumber}'))
              .toList()),
        );
      case WorkOrderLinkTarget.person:
        final asyncItems = ref.watch(allPersonsProvider(null));
        return asyncItems.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('تعذر تحميل الأشخاص: $e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          data: (items) => _buildChoices(items
              .where((p) => query.isEmpty || p.fullName.toLowerCase().contains(query) || (p.phone1 ?? '').toLowerCase().contains(query) || (p.nationalId ?? '').toLowerCase().contains(query))
              .take(8)
              .map((p) => (id: p.id, title: p.fullName))
              .toList()),
        );
      case WorkOrderLinkTarget.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChoices(List<({int id, String title})> choices) {
    if (choices.isEmpty) {
      return Text('لا توجد نتائج مطابقة', style: AppTextStyles.bodySmallSecondary);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: choices.length,
        itemBuilder: (_, i) {
          final item = choices[i];
          final selected = item.id == _linkedEntityId;
          return ListTile(
            dense: true,
            selected: selected,
            leading: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? AppColors.success : AppColors.textSecondary),
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => setState(() {
              _linkedEntityId = item.id;
              _linkedEntityTitle = item.title;
            }),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.workOrdersCreate)) {
      await ref.read(auditServiceProvider).log(
            action: 'access_denied',
            category: 'work_orders',
            entityType: 'work_order',
            description: 'محاولة إنشاء أمر عمل دون صلاحية',
            severity: 'warning',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('لا تملك صلاحية إنشاء أمر عمل'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    if (_linkTarget != WorkOrderLinkTarget.none && _linkedEntityId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('اختر الملف المرتبط بأمر العمل أو اختر بدون ارتباط'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('اسم المكلف إلزامي'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(workOrderRepositoryProvider);
      final currentUser = ref.read(authControllerProvider).user;
      final orderId = await repo.create(
        assignedToName: _name.text.trim(),
        assignedToPhone: _phone.text.trim(),
        orderType: workOrderTypeToDb(_type),
        priority: workOrderPriorityToDb(_priority),
        status: 'draft',
        dueDate: _due,
        instructions: _instructions.text.trim(),
        createdBy: currentUser?.fullName ?? 'المحامي',
        linkedEntityType: _linkTarget.entityType,
        linkedEntityId: _linkTarget == WorkOrderLinkTarget.none ? 0 : _linkedEntityId,
      );
      await ref.read(auditServiceProvider).log(
        action: 'create',
        category: 'work_orders',
        entityType: 'work_order',
        entityId: '$orderId',
        entityTitle: _linkedEntityTitle,
        description: 'إنشاء أمر عمل للمعقب مرتبط بـ: $_linkedEntityTitle',
        severity: 'info',
      );
      ref.invalidate(uiWorkOrdersProvider);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('تم إنشاء أمر العمل وحفظه'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class EnterWorkOrderResultDialog extends ConsumerStatefulWidget {
  final WorkOrder workOrder;
  const EnterWorkOrderResultDialog({super.key, required this.workOrder});

  @override
  ConsumerState<EnterWorkOrderResultDialog> createState() => _EnterWorkOrderResultDialogState();
}

class _EnterWorkOrderResultDialogState extends ConsumerState<EnterWorkOrderResultDialog> {
  WorkOrderResultStatus? _status = WorkOrderResultStatus.completed;
  final _result = TextEditingController();
  final List<File> _attachments = [];
  DateTime? _nextDate;
  bool _saving = false;

  @override
  void dispose() {
    _result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('نتيجة أمر ${widget.workOrder.internalNumber}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            DropdownButtonFormField<WorkOrderResultStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'نتيجة التنفيذ'),
              items: WorkOrderResultStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 10),
            TextField(controller: _result, maxLines: 3, decoration: const InputDecoration(labelText: 'تفاصيل النتيجة')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_nextDate == null ? 'موعد لاحق (اختياري)' : 'موعد لاحق: ${_nextDate!.toString().substring(0, 10)}'),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _nextDate = picked);
              },
            ),
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Text('مرفقات النتيجة', style: AppTextStyles.labelLarge),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickAttachments,
              icon: const Icon(Icons.attach_file),
              label: const Text('إضافة ملف أو صورة'),
            ),
            if (_attachments.isNotEmpty)
              ..._attachments.asMap().entries.map((entry) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(entry.value.path.split(Platform.pathSeparator).last, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _attachments.removeAt(entry.key)),
                    ),
                  )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _saving ? null : _save, child: const Text('حفظ النتيجة')),
      ],
    );
  }

  Future<void> _pickAttachments() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true,
      type: fp.FileType.custom,
      allowedExtensions: AppConstants.allowedAttachmentExtensions,
    );
    if (result == null) return;
    final files = result.paths.whereType<String>().map(File.new).toList();
    if (files.isNotEmpty) setState(() => _attachments.addAll(files));
  }

  Future<void> _save() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.workOrdersResultEnter)) {
      await ref.read(auditServiceProvider).log(
            action: 'access_denied',
            category: 'work_orders',
            entityType: 'work_order',
            entityId: widget.workOrder.id,
            entityTitle: widget.workOrder.internalNumber,
            description: 'محاولة إدخال نتيجة أمر عمل دون صلاحية',
            severity: 'warning',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('لا تملك صلاحية إدخال نتيجة أمر عمل'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    if (_status == null) return;
    setState(() => _saving = true);
    try {
      final id = int.tryParse(widget.workOrder.id);
      if (id == null) throw Exception('معرف غير صالح');
      await ref.read(workOrderRepositoryProvider).enterResult(
            id: id,
            resultStatus: _status!.toString().split('.').last,
            resultText: _result.text.trim().isEmpty ? _status!.displayName : _result.text.trim(),
            nextDate: _nextDate,
            userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب',
          );
      // بعد إدخال النتيجة تصبح بانتظار الاعتماد
      await ref.read(workOrderRepositoryProvider).setStatus(id, 'waiting_for_approval', userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب');
      await ref.read(auditServiceProvider).log(
        action: 'result_enter',
        category: 'work_orders',
        entityType: 'work_order',
        entityId: widget.workOrder.id,
        entityTitle: widget.workOrder.internalNumber,
        description: 'إدخال نتيجة أمر عمل مع ${_attachments.length} مرفق',
        severity: 'info',
      );
      if (_attachments.isNotEmpty) {
        final docRepo = ref.read(documentRepositoryProvider);
        final db = ref.read(databaseProvider);
        final userRef = ref.read(authControllerProvider).user?.fullName ?? 'المكتب';
        for (final file in _attachments) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          final isGeneral = widget.workOrder.linkedEntityId == '0';
          final primaryEntityType = isGeneral ? workOrderDocumentEntityType : _entityTypeFromWorkOrder(widget.workOrder.linkedEntityType);
          final primaryEntityId = isGeneral ? id : int.tryParse(widget.workOrder.linkedEntityId) ?? 0;
          final docId = await docRepo.addDocument(
            docName: 'نتيجة ${widget.workOrder.internalNumber} - $fileName',
            docType: 'work_order_result',
            fileType: _fileExtension(file.path),
            summary: _result.text.trim(),
            notes: 'مرفق نتيجة أمر عمل ${widget.workOrder.internalNumber}',
            sourceFile: file,
            entityType: primaryEntityType,
            entityId: primaryEntityId,
            userRef: userRef,
          );
          if (!isGeneral) {
            await db.documentDao.linkDocument(docId, workOrderDocumentEntityType, id, linkType: 'work_order_result');
          }
          await ref.read(auditServiceProvider).log(
            action: 'attachment_upload',
            category: 'work_orders',
            entityType: 'work_order',
            entityId: widget.workOrder.id,
            entityTitle: widget.workOrder.internalNumber,
            description: 'رفع مرفق نتيجة أمر عمل: $fileName',
            severity: 'info',
          );
        }
      }
      ref.invalidate(uiWorkOrdersProvider);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('تم حفظ النتيجة في قاعدة البيانات'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}


int _entityTypeFromWorkOrder(String type) {
  switch (type) {
    case 'case':
      return EntityType.caseEntity.index;
    case 'procedure':
      return EntityType.adminProcedure.index;
    case 'company':
      return EntityType.company.index;
    case 'contract':
      return EntityType.contract.index;
    case 'person':
      return EntityType.person.index;
    default:
      return workOrderDocumentEntityType;
  }
}

class ApproveWorkOrderDialog extends ConsumerWidget {
  final WorkOrder workOrder;
  const ApproveWorkOrderDialog({super.key, required this.workOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('اعتماد نتيجة أمر العمل'),
      content: Text('اعتماد ${workOrder.internalNumber}؟\n${workOrder.resultText ?? ''}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.textOnLight),
          onPressed: () async {
            final permissions = ref.read(permissionServiceProvider);
            if (!permissions.can(PermissionKeys.workOrdersApprove)) {
              await ref.read(auditServiceProvider).log(
                action: 'access_denied',
                category: 'work_orders',
                entityType: 'work_order',
                entityId: workOrder.id,
                entityTitle: workOrder.internalNumber,
                description: 'محاولة اعتماد أمر عمل دون صلاحية',
                severity: 'warning',
              );
              return;
            }
            final id = int.tryParse(workOrder.id);
            if (id == null) return;
            await ref.read(workOrderRepositoryProvider).approve(id, userRef: ref.read(authControllerProvider).user?.fullName ?? 'الأستاذ');
            await ref.read(auditServiceProvider).log(
              action: 'approve',
              category: 'work_orders',
              entityType: 'work_order',
              entityId: workOrder.id,
              entityTitle: workOrder.internalNumber,
              description: 'اعتماد نتيجة أمر عمل',
              severity: 'warning',
            );
            ref.invalidate(uiWorkOrdersProvider);
            if (context.mounted) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('تم الاعتماد وحفظه'), backgroundColor: AppColors.success),
              );
            }
          },
          child: const Text('اعتماد'),
        ),
      ],
    );
  }
}

class PrintWorkOrderDialog extends ConsumerWidget {
  final WorkOrder workOrder;
  const PrintWorkOrderDialog({super.key, required this.workOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text('طباعة ${workOrder.internalNumber}'),
      content: const Text('سيتم توليد PDF رسمي وتحديث حالة الأمر إلى «مطبوع».'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('توليد PDF وحفظ الحالة'),
          onPressed: () async {
            final permissions = ref.read(permissionServiceProvider);
            if (!permissions.can(PermissionKeys.workOrdersPrint)) {
              await ref.read(auditServiceProvider).log(
                action: 'access_denied',
                category: 'work_orders',
                entityType: 'work_order',
                entityId: workOrder.id,
                entityTitle: workOrder.internalNumber,
                description: 'محاولة طباعة أمر عمل دون صلاحية',
                severity: 'warning',
              );
              return;
            }
            final settings = ref.read(officeSettingsProvider).maybeWhen(
                  data: (s) => s,
                  orElse: () => const OfficeSettingsModel(
                    officeTitle: AppConstants.defaultOfficeTitle,
                    lawyerName: AppConstants.defaultLawyerName,
                    officeAddress: AppConstants.defaultAddress,
                    officePhone: AppConstants.defaultPhone,
                  ),
                );
            final bytes = await WorkOrderPdfBuilder.build(settings: settings, order: workOrder);
            final id = int.tryParse(workOrder.id);
            if (id != null) {
              await ref.read(workOrderRepositoryProvider).markPrinted(id, userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب');
              ref.invalidate(uiWorkOrdersProvider);
            }
            await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${workOrder.internalNumber}.pdf');
            if (context.mounted) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('تم توليد PDF وتحديث الحالة'), backgroundColor: AppColors.success),
              );
            }
          },
        ),
      ],
    );
  }
}

class WhatsAppDialog extends ConsumerWidget {
  final WorkOrder workOrder;
  const WhatsAppDialog({super.key, required this.workOrder});

  String _message(OfficeSettingsModel settings) {
    final due = '${workOrder.dueDate.year}-${workOrder.dueDate.month.toString().padLeft(2, '0')}-${workOrder.dueDate.day.toString().padLeft(2, '0')}';
    return '''
السلام عليكم ${workOrder.assignedToName}،
أمر عمل من ${settings.officeTitle}
الأستاذ: ${settings.lawyerName}
رقم الأمر: ${workOrder.internalNumber}
الملف: ${workOrder.linkedEntityType} ${workOrder.linkedEntityId}
المطلوب: ${workOrder.orderTypeText}
الموعد: $due
التعليمات: ${workOrder.instructions}
يرجى تنفيذ المطلوب وإرسال صور المرفقات إن وجدت.
'''.trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(officeSettingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const OfficeSettingsModel(
            officeTitle: AppConstants.defaultOfficeTitle,
            lawyerName: AppConstants.defaultLawyerName,
            officeAddress: AppConstants.defaultAddress,
            officePhone: AppConstants.defaultPhone,
          ),
        );
    final msg = _message(settings);
    return AlertDialog(
      title: const Text('رسالة واتساب للمعقب'),
      content: SizedBox(
        width: 480,
        child: SelectableText(msg, style: AppTextStyles.bodyMedium),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('نسخ'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: msg));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('تم نسخ الرسالة'), backgroundColor: AppColors.info),
              );
            }
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.message),
          label: const Text('فتح واتساب وتحديث الحالة'),
          onPressed: () async {
            final permissions = ref.read(permissionServiceProvider);
            if (!permissions.can(PermissionKeys.workOrdersSend)) {
              await ref.read(auditServiceProvider).log(
                action: 'access_denied',
                category: 'work_orders',
                entityType: 'work_order',
                entityId: workOrder.id,
                entityTitle: workOrder.internalNumber,
                description: 'محاولة إرسال أمر عمل دون صلاحية',
                severity: 'warning',
              );
              return;
            }
            await Clipboard.setData(ClipboardData(text: msg));
            final phone = workOrder.assignedToPhone.replaceAll(RegExp(r'[^0-9]'), '');
            final encoded = Uri.encodeComponent(msg);
            final appUri = Uri.parse(phone.isEmpty ? 'whatsapp://send?text=$encoded' : 'whatsapp://send?phone=$phone&text=$encoded');
            final webUri = Uri.parse(phone.isEmpty ? 'https://wa.me/?text=$encoded' : 'https://wa.me/$phone?text=$encoded');

            var opened = await launchUrl(appUri, mode: LaunchMode.externalApplication);
            if (!opened) {
              opened = await launchUrl(webUri, mode: LaunchMode.externalApplication);
            }

            var shouldMarkSent = opened;
            if (!opened && context.mounted) {
              shouldMarkSent = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('تعذر فتح واتساب تلقائياً'),
                      content: const Text('تم نسخ الرسالة إلى الحافظة. هل تريد اعتبار أمر العمل مرسلاً بعد لصقها يدوياً؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لا')),
                        ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('نعم، اعتبره مرسلاً')),
                      ],
                    ),
                  ) ??
                  false;
            }

            if (shouldMarkSent) {
              final id = int.tryParse(workOrder.id);
              if (id != null) {
                await ref.read(workOrderRepositoryProvider).markWhatsAppSent(id, userRef: ref.read(authControllerProvider).user?.fullName ?? 'المكتب');
                ref.invalidate(uiWorkOrdersProvider);
              }
            }
            if (context.mounted) {
              Navigator.pop(context, shouldMarkSent);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(shouldMarkSent ? 'تم فتح/تأكيد واتساب وتحديث الحالة' : 'تم نسخ الرسالة فقط دون تحديث الحالة'),
                  backgroundColor: shouldMarkSent ? AppColors.success : AppColors.info,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class WorkOrderPdfBuilder {
  static Future<Uint8List> build({
    required OfficeSettingsModel settings,
    required WorkOrder order,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(settings.officeTitle, style: pw.TextStyle(font: bold, fontSize: 18), textAlign: pw.TextAlign.center),
            pw.Text('الأستاذ: ${settings.lawyerName}', textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.Text('أمر عمل للمعقب', style: pw.TextStyle(font: bold, fontSize: 16), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 12),
            _row('رقم الأمر', order.internalNumber, bold),
            _row('المكلف', '${order.assignedToName} — ${order.assignedToPhone}', font),
            _row('النوع', order.orderTypeText, font),
            _row('الأولوية', order.priorityText, font),
            _row('الملف', '${order.linkedEntityType} ${order.linkedEntityId}', font),
            _row('الموعد', order.dueDate.toString().substring(0, 10), font),
            _row('الحالة', order.statusText, font),
            pw.SizedBox(height: 10),
            pw.Text('التعليمات:', style: pw.TextStyle(font: bold)),
            pw.Text(order.instructions.isEmpty ? '—' : order.instructions),
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('توقيع المعقب: ............'),
                pw.Text('ختم المكتب: ............'),
              ],
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  static pw.Widget _row(String k, String v, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(k, style: pw.TextStyle(font: font)), pw.Text(v, style: pw.TextStyle(font: font))],
      ),
    );
  }
}
