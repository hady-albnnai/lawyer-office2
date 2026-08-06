/// معالج حل النواقص الذكي — كل نوع نقص له معالجة مخصصة
///
/// أنواع النواقص المدعومة:
///   next_session_date  → Date/Time picker → حفظ موعد بالدعوى
///   base_number        → Text field → حفظ رقم الأساس بالدعوى
///   poa_attachment     → File picker → إرفاق صورة الوكالة
///   representative_doc → File picker → إرفاق سند التمثيل
///   registration_number→ Text field → حفظ رقم السجل بالشركة
///   partners_list      → توجيه لملف الشركة
///   directors_list     → توجيه لملف الشركة
///
/// آخر تحديث: 2026-08-06
library;

import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/app_enums.dart';
import '../../../data/database/database.dart' as db;
import '../../../data/services/deficiency_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// حوار حل النقص الذكي
class DeficiencyResolverDialog extends ConsumerStatefulWidget {
  final db.Deficiency deficiency;
  const DeficiencyResolverDialog({super.key, required this.deficiency});

  @override
  ConsumerState<DeficiencyResolverDialog> createState() =>
      _DeficiencyResolverDialogState();
}

class _DeficiencyResolverDialogState
    extends ConsumerState<DeficiencyResolverDialog> {
  // حالة عامة
  bool _saving = false;
  final _reasonController = TextEditingController();

  // لحل نقص الموعد
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;

  // لحل نقص النص
  final _textController = TextEditingController();

  // لحل نقص المرفقات
  File? _pickedFile;
  String? _pickedFileName;

  @override
  void dispose() {
    _reasonController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // معلومات النقص
  // ===========================================================================

  String get _fieldName => widget.deficiency.fieldName;
  String get _description => widget.deficiency.description;
  int get _entityId => widget.deficiency.entityId;
  int get _entityType => widget.deficiency.entityType;

  String get _entityLabel => switch (_entityType) {
        0 => 'الدعوى',
        1 => 'العقد',
        2 => 'الشركة',
        3 => 'الإجراء',
        4 => 'الشخص',
        5 => 'الوكالة',
        _ => 'الملف',
      };

  IconData get _entityIcon => switch (_entityType) {
        0 => Icons.gavel,
        1 => Icons.description,
        2 => Icons.business,
        3 => Icons.assignment,
        _ => Icons.folder,
      };

  String get _entityRoute {
    switch (_entityType) {
      case 0: return '/cases/$_entityId';
      case 1: return '/contracts/$_entityId';
      case 2: return '/companies/$_entityId';
      case 3: return '/procedures/$_entityId';
      case 4: return '/persons/$_entityId';
      case 5: return '/poa/$_entityId';
      default: return '';
    }
  }

  /// نوع المعالجة حسب نوع النقص
  String get _resolutionType {
    switch (_fieldName) {
      case 'next_session_date':
        return 'date';
      case 'base_number':
      case 'registration_number':
        return 'text';
      case 'poa_attachment':
      case 'representative_doc':
        return 'file';
      case 'partners_list':
      case 'directors_list':
        return 'navigate';
      default:
        return 'navigate';
    }
  }

  /// عنوان زر المعالجة
  String get _actionLabel {
    switch (_fieldName) {
      case 'next_session_date':
        return 'تحديد موعد الجلسة';
      case 'base_number':
        return 'إدخال رقم الأساس';
      case 'registration_number':
        return 'إدخال رقم السجل';
      case 'poa_attachment':
        return 'إرفاق صورة الوكالة';
      case 'representative_doc':
        return 'إرفاق سند التمثيل';
      default:
        return 'فتح $_entityLabel';
    }
  }

  IconData get _actionIcon {
    switch (_fieldName) {
      case 'next_session_date':
        return Icons.event;
      case 'base_number':
      case 'registration_number':
        return Icons.edit;
      case 'poa_attachment':
      case 'representative_doc':
        return Icons.upload_file;
      default:
        return Icons.open_in_new;
    }
  }

  // ===========================================================================
  // الواجهة
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                    _buildDescriptionCard(),
                    const SizedBox(height: 20),
                    _buildResolutionSection(),
                    const SizedBox(height: 20),
                    _buildIgnoreSection(),
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
              color: AppColors.secondaryGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_actionIcon, color: AppColors.secondaryGold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('معالجة نقص',
                    style:
                        AppTextStyles.headline6.copyWith(color: Colors.white)),
                Text(_actionLabel,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.secondaryGold)),
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

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_entityIcon, color: AppColors.primaryNavy, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_description,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$_entityLabel — $_fieldName',
                    style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionSection() {
    switch (_resolutionType) {
      case 'date':
        return _buildDateResolution();
      case 'text':
        return _buildTextResolution();
      case 'file':
        return _buildFileResolution();
      default:
        return _buildNavigateResolution();
    }
  }

  // ---------------------------------------------------------------------------
  // 1. نقص الموعد → Date + Time picker
  // ---------------------------------------------------------------------------
  Widget _buildDateResolution() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondaryGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_actionLabel,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18, color: AppColors.primaryNavy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pickedDate == null
                                ? 'اختر التاريخ'
                                : '${_pickedDate!.year}-${_pickedDate!.month.toString().padLeft(2, '0')}-${_pickedDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: _pickedDate == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: _pickedTime != null
                          ? AppColors.primaryNavy.withValues(alpha: 0.06)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _pickedTime != null
                            ? AppColors.primaryNavy
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 18,
                            color: _pickedTime != null
                                ? AppColors.primaryNavy
                                : AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          _pickedTime == null
                              ? '--:--'
                              : '${_pickedTime!.hour.toString().padLeft(2, '0')}:${_pickedTime!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: _pickedTime != null
                                ? AppColors.primaryNavy
                                : AppColors.textSecondary,
                            fontWeight: _pickedTime != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. نقص نصي → Text field
  // ---------------------------------------------------------------------------
  Widget _buildTextResolution() {
    final label = _fieldName == 'base_number'
        ? 'رقم الأساس القضائي'
        : 'رقم السجل التجاري';
    final hint = _fieldName == 'base_number'
        ? 'مثال: 1234/2026'
        : 'مثال: 56789';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondaryGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_actionLabel,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: const Icon(Icons.tag),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primaryNavy, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. نقص مرفق → File picker
  // ---------------------------------------------------------------------------
  Widget _buildFileResolution() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondaryGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_actionLabel,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.primaryNavy)),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _pickedFile != null
                    ? AppColors.success.withValues(alpha: 0.06)
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _pickedFile != null
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _pickedFile != null
                        ? Icons.attach_file
                        : Icons.cloud_upload_outlined,
                    color: _pickedFile != null
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pickedFileName ?? 'اضغط لاختيار ملف (PDF/صورة)',
                      style: TextStyle(
                        color: _pickedFile != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_pickedFile != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(
                          () => {_pickedFile = null, _pickedFileName = null}),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. نقص يحتاج توجيه → Navigate only
  // ---------------------------------------------------------------------------
  Widget _buildNavigateResolution() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'هذا النوع من النواقص يُعالج من داخل ملف $_entityLabel. اضغط "فتح $_entityLabel" للانتقال.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIgnoreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('أو تجاهل النقص مع السبب:',
            style: AppTextStyles.bodySmallSecondary),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonController,
          decoration: InputDecoration(
            labelText: 'سبب التجاهل (اختياري)',
            hintText: 'مثال: تم استكماله خارج النظام',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primaryNavy, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          const SizedBox(width: 8),
          if (_resolutionType == 'navigate')
            ElevatedButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      Navigator.pop(context);
                      context.go(_entityRoute);
                    },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text('فتح $_entityLabel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: AppColors.secondaryGold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          if (_resolutionType != 'navigate') ...[
            if (_reasonController.text.isNotEmpty ||
                _pickedDate != null ||
                _textController.text.isNotEmpty ||
                _pickedFile != null)
              TextButton(
                onPressed: _saving ? null : _handleIgnore,
                child: const Text('تجاهل'),
              ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saving ? null : _handleResolve,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(_actionIcon, size: 16),
              label: Text(_saving ? 'جارٍ...' : _actionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: AppColors.secondaryGold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // الاختيار
  // ===========================================================================

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _pickedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _pickedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _pickedTime = picked);
    }
  }

  Future<void> _pickFile() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx', 'doc'],
    );
    if (result != null && result.files.single.path != null && mounted) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _pickedFileName = result.files.single.name;
      });
    }
  }

  // ===========================================================================
  // التنفيذ
  // ===========================================================================

  Future<void> _handleResolve() async {
    // التحقق من المدخلات
    switch (_resolutionType) {
      case 'date':
        if (_pickedDate == null) {
          _showError('يرجى تحديد التاريخ');
          return;
        }
        break;
      case 'text':
        if (_textController.text.trim().isEmpty) {
          _showError('يرجى إدخال القيمة');
          return;
        }
        break;
      case 'file':
        if (_pickedFile == null) {
          _showError('يرجى اختيار ملف');
          return;
        }
        break;
    }

    setState(() => _saving = true);
    try {
      final database = ref.read(databaseProvider);

      switch (_resolutionType) {
        case 'date':
          await _resolveDateDeficiency(database);
          break;
        case 'text':
          await _resolveTextDeficiency(database);
          break;
        case 'file':
          await _resolveFileDeficiency(database);
          break;
      }

      // إغلاق النقص
      await DeficiencyService(database).resolveDeficiency(
        EntityType.values[_entityType],
        _entityId,
        _fieldName,
      );

      // تحديث الواجهة
      ref.invalidate(openDeficienciesProvider(null));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم حل النقص: $_description'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('فشل حل النقص: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resolveDateDeficiency(db.AppDatabase database) async {
    var nextDate = _pickedDate!;
    if (_pickedTime != null) {
      nextDate = DateTime(nextDate.year, nextDate.month, nextDate.day,
          _pickedTime!.hour, _pickedTime!.minute);
    }

    if (_entityType == 0) {
      // دعوى → تحديث next_session_date
      await database
          .customStatement('UPDATE cases SET next_session_date = ?, updated_at = ? WHERE id = ?', [
        nextDate.millisecondsSinceEpoch ~/ 1000,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        _entityId,
      ]);

      // إغلاق نواقص الموعد
      await database.customStatement(
        "UPDATE deficiencies SET status = 'resolved', resolved_at = CURRENT_TIMESTAMP WHERE entity_type = 0 AND entity_id = ? AND field_name = 'next_session_date' AND status = 'open'",
        [_entityId],
      );
    }
  }

  Future<void> _resolveTextDeficiency(db.AppDatabase database) async {
    final value = _textController.text.trim();

    if (_fieldName == 'base_number' && _entityType == 0) {
      await database.customStatement(
        'UPDATE cases SET base_number = ?, updated_at = ? WHERE id = ?',
        [
          value,
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          _entityId,
        ],
      );
    } else if (_fieldName == 'registration_number' && _entityType == 2) {
      await database.customStatement(
        'UPDATE companies SET registration_number = ?, updated_at = ? WHERE id = ?',
        [
          value,
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          _entityId,
        ],
      );
    }
  }

  Future<void> _resolveFileDeficiency(db.AppDatabase database) async {
    // حفظ المرفق عبر DocumentRepository
    final docRepo = ref.read(documentRepositoryProvider);
    final userRef =
        ref.read(authControllerProvider).user?.fullName ?? 'المكتب';

    final entityType = EntityType.values[_entityType];
    final docType = _fieldName == 'poa_attachment'
        ? 'سند توكيل'
        : 'سند تمثيل';

    await docRepo.addDocument(
      docName: _pickedFileName ?? docType,
      docType: docType,
      fileType: _pickedFileName?.split('.').last.toLowerCase(),
      summary: 'مرفق لحل نقص $_fieldName من لوحة اليوم',
      sourceFile: _pickedFile!,
      entityType: entityType.index,
      entityId: _entityId,
      userRef: userRef,
    );
  }

  Future<void> _handleIgnore() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _showError('اكتب سبب التجاهل أولاً');
      return;
    }

    setState(() => _saving = true);
    try {
      final userRef =
          ref.read(authControllerProvider).user?.fullName ?? 'المكتب';
      final database = ref.read(databaseProvider);
      await DeficiencyService(database)
          .ignoreDeficiency(widget.deficiency.id, reason, userRef);

      ref.invalidate(openDeficienciesProvider(null));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تجاهل النقص'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('فشل التجاهل: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }
}
