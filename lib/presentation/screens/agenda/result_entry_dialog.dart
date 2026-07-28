/// حوار تسجيل نتيجة عمل (معالج الإدخال الموحد - Unified Result Wizard)
/// بناءً على الخطة الماسية لإعادة الهيكلة 2026
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum WorkResultType {
  completed,
  completedWithNext,
  postponed,
  impossible,
  cancelled,
}

extension on WorkResultType {
  String get label {
    switch (this) {
      case WorkResultType.completed: return 'منجز نهائياً';
      case WorkResultType.completedWithNext: return 'منجز وولّد موعداً جديداً';
      case WorkResultType.postponed: return 'مؤجل بسبب';
      case WorkResultType.impossible: return 'متعذر بسبب';
      case WorkResultType.cancelled: return 'ملغى بسبب';
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

class ResultEntryDialog extends ConsumerStatefulWidget {
  final int? entityId;
  final String entityType; // 'case', 'work_order', 'task'
  final String? initialTitle;

  const ResultEntryDialog({super.key, this.entityId, this.entityType = 'task', this.initialTitle});

  @override
  ConsumerState<ResultEntryDialog> createState() => _ResultEntryDialogState();
}

class _ResultEntryDialogState extends ConsumerState<ResultEntryDialog> {
  WorkResultType? _selectedResult = WorkResultType.completed;
  final _notesController = TextEditingController();
  final _nextDateController = TextEditingController();
  final _titleController = TextEditingController();
  final _expenseController = TextEditingController();
  bool _clientAttended = false;
  bool _opponentAttended = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? 'نتيجة عمل يومي';
  }

  @override
  void dispose() {
    _notesController.dispose();
    _nextDateController.dispose();
    _titleController.dispose();
    _expenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_note, color: AppColors.primaryNavy),
          const SizedBox(width: 8),
          Text('المعالج الشامل لتسجيل النتائج', style: AppTextStyles.headline6),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'عنوان العمل/الجلسة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('النتيجة (Transaction Action) *', style: AppTextStyles.labelLarge),
                    Wrap(
                      children: WorkResultType.values.map(
                        (type) => SizedBox(
                          width: 280,
                          child: RadioListTile<WorkResultType>(
                            title: Text(type.label, style: AppTextStyles.bodyMedium),
                            value: type,
                            groupValue: _selectedResult,
                            onChanged: (v) => setState(() => _selectedResult = v),
                            activeColor: AppColors.primaryNavy,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ).toList(),
                    ),
                  ],
                ),
              ),
              
              if (_selectedResult == WorkResultType.completedWithNext || _selectedResult == WorkResultType.postponed) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _nextDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'الموعد القادم (يولد مهمة تلقائياً)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
                  ),
                  onTap: _pickDate,
                ),
              ],
              
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('حضور الموكل'),
                      value: _clientAttended,
                      onChanged: (v) => setState(() => _clientAttended = v ?? false),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('حضور الخصم'),
                      value: _opponentAttended,
                      onChanged: (v) => setState(() => _opponentAttended = v ?? false),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              TextField(
                controller: _expenseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المصاريف المدفوعة (تُسجل تلقائياً في الصندوق)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: 'ل.س',
                ),
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'قرار المحكمة / الملاحظات / أسباب التأجيل',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submitResult,
          icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
          label: Text(_saving ? 'جارٍ المعالجة (Transaction)...' : 'حفظ وتنفيذ الأتمتة'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SY'),
    );
    if (picked != null) {
      _nextDateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submitResult() async {
    final result = _selectedResult;
    if (result == null) return;
    if ((result == WorkResultType.completedWithNext || result == WorkResultType.postponed) && _nextDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدد الموعد القادم'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now();
      final title = _titleController.text.trim().isEmpty ? 'نتيجة عمل' : _titleController.text.trim();
      final notes = '${result.label}\nحضور موكل: ${_clientAttended ? 'نعم' : 'لا'} | حضور خصم: ${_opponentAttended ? 'نعم' : 'لا'}\n${_notesController.text.trim()}';
      final resultSourceType = widget.entityType == 'case'
          ? 'cases'
          : (widget.entityType == 'work_order' ? 'work_order' : 'manual');
      final resultSourceId = widget.entityId;

      // 1. Transaction Start (نستخدم transaction لضمان عدم ضياع البيانات)
      await db.transaction(() async {
        
        // أ. تسجيل النتيجة الأساسية
        final taskId = await db.into(db.dailyTasks).insert(
          DailyTasksCompanion.insert(
            taskType: 'manual_result',
            title: title,
            taskDate: DateTime(now.year, now.month, now.day),
            taskTime: Value('${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'),
            status: Value(result.lifecycleStatus),
            assignedTo: const Value('المحامي'),
            priority: const Value(1),
            sourceType: Value(resultSourceType),
            sourceId: Value(resultSourceId),
            notes: Value(notes),
          ),
        );

        // ب. الأتمتة: تسجيل مصروف عند وجود سياق دعوى واضح فقط.
        final expenseValue = double.tryParse(_expenseController.text.trim());
        if (expenseValue != null && expenseValue > 0 && widget.entityId != null && widget.entityType == 'case') {
          await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              entityType: EntityType.caseEntity.index,
              entityId: widget.entityId!,
              expenseType: 'مصاريف جلسة/مراجعة',
              amount: expenseValue,
              notes: Value('مصاريف آلية من الجلسة: $title'),
              expenseDate: Value(now),
            ),
          );
        }

        // ج. الأتمتة: تحديث حالة الجلسة + next_session_date + إغلاق النواقص
        if (widget.entityId != null && widget.entityType == 'case') {
          if (_nextDateController.text.trim().isNotEmpty) {
            final parts = _nextDateController.text.trim().split('-');
            final nextDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));

            await db.customStatement(
              'UPDATE cases SET next_session_date = ? WHERE id = ?',
              [nextDate, widget.entityId],
            );

            // session_date مخزّن كعدد Unix epoch، فتُستخدم مقارنة مجال اليوم
            // بدل DATE() التي تُرجع NULL على الأعداد ولا تطابق أي صف.
            final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            final tomorrowStart = todayStart.add(const Duration(days: 1));
            await db.customStatement(
              'UPDATE case_sessions SET status = ?, decision = ?, notes = ? WHERE case_id = ? AND session_date >= ? AND session_date < ?',
              [result.lifecycleStatus, result.label, notes, widget.entityId, todayStart, tomorrowStart],
            );

          }
        }

        // ج. الأتمتة: توليد موعد قادم في الأجندة
        if (_nextDateController.text.trim().isNotEmpty) {
          final parts = _nextDateController.text.trim().split('-');
          final nextDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          
          await db.into(db.dailyTasks).insert(
            DailyTasksCompanion.insert(
              taskType: 'follow_up',
              title: 'متابعة: $title',
              taskDate: nextDate,
              status: Value(LifecycleStatus.scheduled.index),
              assignedTo: const Value('المحامي'),
              priority: const Value(1),
              sourceType: Value(resultSourceType),
              sourceId: Value(resultSourceId),
              notes: Value('مولَّد آلياً من المعالج الشامل للعمل #$taskId'),
            ),
          );

          // د. إغلاق النواقص المتعلقة بغياب موعد قادم دون حذف السجلات.
          if (widget.entityId != null && widget.entityType == 'case') {
            await db.customStatement(
              "UPDATE deficiencies SET status = 'resolved', resolved_at = CURRENT_TIMESTAMP WHERE entity_type = ? AND entity_id = ? AND status = 'open' AND field_name IN ('next_session_date', 'followup_pending', 'work_order_pending')",
              [EntityType.caseEntity.index, widget.entityId],
            );
          }
        }

        // هـ. الأتمتة: تسجيل في الـ Audit Log
        await db.into(db.activityLog).insert(
          ActivityLogCompanion.insert(
            affectedTable: 'daily_tasks',
            recordId: taskId,
            action: 'unified_result_entry',
            userRef: const Value('المحامي'),
            details: Value('Transaction: {result: ${result.label}, expense: $expenseValue, nextDate: ${_nextDateController.text}}'),
          ),
        );
      }); // End of Transaction

      // تحديث الواجهة التفاعلية
      ref.invalidate(tasksByDateProvider(DateTime.now()));
      ref.invalidate(openDeficienciesProvider(null));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تنفيذ كافة الإجراءات بنجاح (معاملة ذرية)'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل المعالج: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
