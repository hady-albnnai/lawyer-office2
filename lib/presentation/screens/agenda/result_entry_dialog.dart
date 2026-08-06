/// المعالج الشامل لتسجيل النتائج (Unified Result Wizard)
///
/// الفلسفة: ضغطة زر واحدة → سلسلة أتمتة كاملة في معاملة ذرية.
/// هذا المعالج هو قلب التطبيق النابض ويُراعي:
/// - بنية AI-ready (تسجيل كل تفاعل للتعلم المستقبلي)
/// - التناسق البصري (كحلي + ذهبي)
/// - التوسع المستقبلي (عقود، شركات، إجراءات)
///
/// آخر تحديث: 2026-08-06
library;

import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

// =============================================================================
// أنواع النتائج
// =============================================================================

enum WorkResultType {
  completed,
  completedWithNext,
  postponed,
  impossible,
  cancelled,
}

extension _WorkResultTypeExt on WorkResultType {
  String get label {
    switch (this) {
      case WorkResultType.completed: return 'منجز نهائياً';
      case WorkResultType.completedWithNext: return 'منجز وولّد موعداً جديداً';
      case WorkResultType.postponed: return 'مؤجل بسبب';
      case WorkResultType.impossible: return 'متعذر بسبب';
      case WorkResultType.cancelled: return 'ملغى بسبب';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkResultType.completed: return Icons.check_circle;
      case WorkResultType.completedWithNext: return Icons.event_available;
      case WorkResultType.postponed: return Icons.schedule;
      case WorkResultType.impossible: return Icons.block;
      case WorkResultType.cancelled: return Icons.cancel;
    }
  }

  int get lifecycleStatus {
    switch (this) {
      case WorkResultType.completed:
      case WorkResultType.completedWithNext:
        return LifecycleStatus.completed.index;
      case WorkResultType.postponed:
        return LifecycleStatus.postponed.index;
      case WorkResultType.cancelled:
      case WorkResultType.impossible:
        return LifecycleStatus.cancelled.index;
    }
  }
}

// =============================================================================
// أنواع قرار المحكمة
// =============================================================================

enum CourtDecisionType {
  ruling,
  decision,
  adjournment,
  referral,
  settlement,
  other,
}

extension _CourtDecisionExt on CourtDecisionType {
  String get label {
    switch (this) {
      case CourtDecisionType.ruling: return 'حكم';
      case CourtDecisionType.decision: return 'قرار';
      case CourtDecisionType.adjournment: return 'تأجيل';
      case CourtDecisionType.referral: return 'إحالة';
      case CourtDecisionType.settlement: return 'صلح';
      case CourtDecisionType.other: return 'أخرى';
    }
  }
}

// =============================================================================
// الحوار الرئيسي
// =============================================================================

class ResultEntryDialog extends ConsumerStatefulWidget {
  final int? entityId;
  final String entityType; // 'case', 'contract', 'company', 'work_order', 'task'
  final String? initialTitle;

  const ResultEntryDialog({
    super.key,
    this.entityId,
    this.entityType = 'task',
    this.initialTitle,
  });

  @override
  ConsumerState<ResultEntryDialog> createState() => _ResultEntryDialogState();
}

class _ResultEntryDialogState extends ConsumerState<ResultEntryDialog> {
  // النتيجة
  WorkResultType _selectedResult = WorkResultType.completed;
  CourtDecisionType? _courtDecision;

  // الحقول
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _expenseController = TextEditingController();
  final _nextDateController = TextEditingController();
  TimeOfDay? _nextTime;

  // الحضور
  bool _clientAttended = false;
  bool _opponentAttended = false;
  bool _opponentLawyerAttended = false;

  // المرفقات
  File? _attachment;
  String? _attachmentName;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? 'نتيجة عمل يومي';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _expenseController.dispose();
    _nextDateController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // الواجهة
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTitleField(),
                    const SizedBox(height: 20),
                    _buildResultSelector(),
                    if (_needsNextDate) ...[
                      const SizedBox(height: 16),
                      _buildNextDateSection(),
                    ],
                    if (widget.entityType == 'case') ...[
                      const SizedBox(height: 20),
                      _buildAttendanceSection(),
                      const SizedBox(height: 16),
                      _buildCourtDecisionField(),
                    ],
                    const SizedBox(height: 20),
                    _buildExpenseField(),
                    const SizedBox(height: 16),
                    _buildAttachmentSection(),
                    const SizedBox(height: 20),
                    _buildNotesField(),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondaryGold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.edit_note, color: AppColors.secondaryGold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المعالج الشامل لتسجيل النتائج',
                    style: AppTextStyles.headline6.copyWith(color: Colors.white)),
                Text('ضغطة واحدة → 6 عمليات تلقائية',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryGold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'عنوان العمل / الجلسة',
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
        ),
      ),
    );
  }

  Widget _buildResultSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryNavy.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('النتيجة *', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 8),
          ...WorkResultType.values.map((type) {
            final isSelected = _selectedResult == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedResult = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryNavy.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: AppColors.primaryNavy, width: 1.5)
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(type.icon, size: 20,
                          color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(type.label, style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primaryNavy : AppColors.textPrimary,
                      )),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppColors.primaryNavy, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  bool get _needsNextDate =>
      _selectedResult == WorkResultType.completedWithNext ||
      _selectedResult == WorkResultType.postponed;

  Widget _buildNextDateSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryGold.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, color: AppColors.secondaryGold, size: 18),
              const SizedBox(width: 6),
              Text('الموعد القادم', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
            ],
          ),
          const SizedBox(height: 8),
          Text('يُولّد مهمة متابعة تلقائياً + يُحدّث موعد الجلسة القادمة',
              style: AppTextStyles.bodySmallSecondary),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'التاريخ *',
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_nextDateController.text.isEmpty
                        ? 'اختر التاريخ'
                        : _nextDateController.text),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'الوقت',
                      prefixIcon: const Icon(Icons.access_time, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_nextTime == null
                        ? '--:--'
                        : '${_nextTime!.hour.toString().padLeft(2, '0')}:${_nextTime!.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الحضور', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
        const SizedBox(height: 8),
        Row(
          children: [
            _attendanceChip('الموكل', _clientAttended, (v) => setState(() => _clientAttended = v)),
            const SizedBox(width: 8),
            _attendanceChip('الخصم', _opponentAttended, (v) => setState(() => _opponentAttended = v)),
            const SizedBox(width: 8),
            _attendanceChip('محامي الخصم', _opponentLawyerAttended, (v) => setState(() => _opponentLawyerAttended = v)),
          ],
        ),
      ],
    );
  }

  Widget _attendanceChip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(
        color: value ? AppColors.primaryNavy : AppColors.textSecondary,
        fontWeight: value ? FontWeight.bold : FontWeight.normal,
      )),
      selected: value,
      onSelected: onChanged,
      selectedColor: AppColors.primaryNavy.withOpacity(0.12),
      checkmarkColor: AppColors.primaryNavy,
      avatar: value
          ? const Icon(Icons.check_circle, size: 16, color: AppColors.primaryNavy)
          : const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
    );
  }

  Widget _buildCourtDecisionField() {
    return DropdownButtonFormField<CourtDecisionType>(
      value: _courtDecision,
      decoration: InputDecoration(
        labelText: 'نوع قرار المحكمة (اختياري)',
        prefixIcon: const Icon(Icons.gavel),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      items: CourtDecisionType.values
          .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
          .toList(),
      onChanged: (v) => setState(() => _courtDecision = v),
    );
  }

  Widget _buildExpenseField() {
    return TextField(
      controller: _expenseController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'المصاريف المدفوعة (تُسجَّل تلقائياً في الصندوق)',
        prefixIcon: const Icon(Icons.attach_money),
        suffixText: 'ل.س',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('مرفقات (اختياري)', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryNavy)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickAttachment,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _attachment != null
                  ? AppColors.success.withOpacity(0.06)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _attachment != null ? AppColors.success.withOpacity(0.3) : AppColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _attachment != null ? Icons.attach_file : Icons.cloud_upload_outlined,
                  color: _attachment != null ? AppColors.success : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _attachmentName ?? 'اضغط لإرفاق صورة ضبط أو مستند',
                    style: TextStyle(
                      color: _attachment != null ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (_attachment != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() { _attachment = null; _attachmentName = null; }),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'ملاحظات / تفاصيل إضافية',
        hintText: 'قرار المحكمة، أسباب التأجيل، ملاحظات للملف...',
        alignLabelWithHint: true,
        prefixIcon: const Icon(Icons.notes, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _saving ? null : _submitResult,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_saving ? 'جارٍ المعالجة...' : 'حفظ وتنفيذ الأتمتة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: AppColors.secondaryGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // الاختيار
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SY'),
    );
    if (picked != null) {
      _nextDateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _nextTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _nextTime = picked);
    }
  }

  Future<void> _pickAttachment() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx', 'doc'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachment = File(result.files.single.path!);
        _attachmentName = result.files.single.name;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // التنفيذ (المعاملة الذرية)
  // ---------------------------------------------------------------------------

  Future<void> _submitResult() async {
    if ((_selectedResult == WorkResultType.completedWithNext ||
            _selectedResult == WorkResultType.postponed) &&
        _nextDateController.text.trim().isEmpty) {
      _showError('يرجى تحديد الموعد القادم');
      return;
    }

    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now();
      final title = _titleController.text.trim().isEmpty ? 'نتيجة عمل' : _titleController.text.trim();

      // بناء ملاحظات شاملة (AI-ready: بيانات منظمة)
      final attendanceInfo = widget.entityType == 'case'
          ? 'حضور: موكل=${_clientAttended ? "نعم" : "لا"} | خصم=${_opponentAttended ? "نعم" : "لا"} | محامي_خصم=${_opponentLawyerAttended ? "نعم" : "لا"}'
          : '';
      final decisionInfo = _courtDecision != null ? 'قرار: ${_courtDecision!.label}' : '';
      final timeInfo = _nextTime != null
          ? ' ${_nextTime!.hour.toString().padLeft(2, '0')}:${_nextTime!.minute.toString().padLeft(2, '0')}'
          : '';
      final notes = [
        _selectedResult.label,
        attendanceInfo,
        decisionInfo,
        _notesController.text.trim(),
      ].where((s) => s.isNotEmpty).join('\n');

      final sourceType = switch (widget.entityType) {
        'case' => 'cases',
        'contract' => 'contracts',
        'company' => 'companies',
        'work_order' => 'work_order',
        _ => 'manual',
      };

      await db.transaction(() async {
        // 1. تسجيل النتيجة
        final taskId = await db.into(db.dailyTasks).insert(
          DailyTasksCompanion.insert(
            taskType: 'manual_result',
            title: title,
            taskDate: DateTime(now.year, now.month, now.day),
            taskTime: Value('${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'),
            status: Value(_selectedResult.lifecycleStatus),
            assignedTo: const Value('المحامي'),
            priority: const Value(1),
            sourceType: Value(sourceType),
            sourceId: Value(widget.entityId),
            notes: Value(notes),
          ),
        );

        // 2. المصاريف
        final expenseValue = double.tryParse(_expenseController.text.trim());
        if (expenseValue != null && expenseValue > 0 && widget.entityId != null && widget.entityType == 'case') {
          await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              entityType: EntityType.caseEntity.index,
              entityId: widget.entityId!,
              expenseType: 'مصاريف جلسة/مراجعة',
              amount: expenseValue,
              notes: Value('مصاريف آلية من: $title'),
              expenseDate: Value(now),
            ),
          );
        }

        // 3. تحديث الجلسة + موعد قادم (للدعاوى)
        if (widget.entityId != null && widget.entityType == 'case' && _nextDateController.text.isNotEmpty) {
          final parts = _nextDateController.text.trim().split('-');
          var nextDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          if (_nextTime != null) {
            nextDate = DateTime(nextDate.year, nextDate.month, nextDate.day, _nextTime!.hour, _nextTime!.minute);
          }

          await db.customStatement('UPDATE cases SET next_session_date = ? WHERE id = ?', [nextDate, widget.entityId]);

          final todayStart = DateTime(now.year, now.month, now.day);
          final tomorrowStart = todayStart.add(const Duration(days: 1));
          await db.customStatement(
            'UPDATE case_sessions SET status = ?, decision = ?, notes = ? WHERE case_id = ? AND session_date >= ? AND session_date < ?',
            [_selectedResult.lifecycleStatus, '${_courtDecision?.label ?? ''} ${_selectedResult.label}'.trim(), notes, widget.entityId, todayStart, tomorrowStart],
          );
        }

        // 4. توليد مهمة متابعة
        if (_nextDateController.text.isNotEmpty) {
          final parts = _nextDateController.text.trim().split('-');
          var nextDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          if (_nextTime != null) {
            nextDate = DateTime(nextDate.year, nextDate.month, nextDate.day, _nextTime!.hour, _nextTime!.minute);
          }

          await db.into(db.dailyTasks).insert(
            DailyTasksCompanion.insert(
              taskType: 'follow_up',
              title: 'متابعة: $title',
              taskDate: nextDate,
              status: Value(LifecycleStatus.scheduled.index),
              assignedTo: const Value('المحامي'),
              priority: const Value(1),
              sourceType: Value(sourceType),
              sourceId: Value(widget.entityId),
              notes: Value('مولَّد آلياً من المعالج الشامل #$taskId'),
            ),
          );

          // إغلاق نواقص الموعد القادم
          if (widget.entityId != null && widget.entityType == 'case') {
            await db.customStatement(
              "UPDATE deficiencies SET status = 'resolved', resolved_at = CURRENT_TIMESTAMP WHERE entity_type = ? AND entity_id = ? AND status = 'open' AND field_name IN ('next_session_date', 'followup_pending', 'work_order_pending')",
              [EntityType.caseEntity.index, widget.entityId],
            );
          }
        }

        // 5. فتح نقص جديد عند التعذر
        if (_selectedResult == WorkResultType.impossible && widget.entityId != null && widget.entityType == 'case') {
          await db.into(db.deficiencies).insert(
            DeficienciesCompanion.insert(
              entityType: EntityType.caseEntity.index,
              entityId: widget.entityId!,
              fieldName: 'session_blocked',
              description: 'جلسة متعذرة: $title — ${_notesController.text.trim()}',
              severity: const Value(1), // 0=required, 1=warning
            ),
          );
        }

        // 6. Audit Log
        await db.into(db.activityLog).insert(
          ActivityLogCompanion.insert(
            affectedTable: 'daily_tasks',
            recordId: taskId,
            action: 'unified_result_entry',
            userRef: const Value('المحامي'),
            details: Value('{result: ${_selectedResult.label}, expense: $expenseValue, nextDate: ${_nextDateController.text}$timeInfo, decision: ${_courtDecision?.label ?? "N/A"}, attendance: {client: $_clientAttended, opponent: $_opponentAttended, opponentLawyer: $_opponentLawyerAttended}}'),
          ),
        );
      });

      // تحديث الواجهة
      ref.invalidate(tasksByDateProvider(DateTime.now()));
      ref.invalidate(openDeficienciesProvider(null));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم: ${_selectedResult.label} — نُفذت كل العمليات بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('فشل المعالج: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }
}
