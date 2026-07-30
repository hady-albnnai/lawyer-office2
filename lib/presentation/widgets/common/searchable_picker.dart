import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// تطبيع النص العربي لأغراض البحث.
///
/// يوحّد الهمزات والتاء المربوطة والألف المقصورة ويزيل التشكيل،
/// حتى يطابق "احمد" و"أحمد"، و"حماه" و"حماة"، و"يحيى" و"يحيي".
String normalizeArabic(String input) {
  return input
      .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '') // تشكيل وتطويل
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

/// حقل اختيار قابل للبحث من قائمة بيانات أدخلها المستخدم سابقاً.
///
/// يحلّ محل DropdownButtonFormField في كل الحقول المرجعية (الموكل،
/// الخصم، الوكالة، المحكمة، الشريك، المدير...) لأن القوائم الجامدة
/// تصبح غير عملية بعد عشرات السجلات.
///
/// يدعم:
///  - بحثاً فورياً غير حسّاس للهمزات والتشكيل.
///  - البحث في حقول إضافية (الهاتف، الرقم الوطني) عبر [searchTermsOf].
///  - إنشاء عنصر جديد دون مغادرة الشاشة عبر [onCreateNew].
class SearchablePicker<T> extends StatelessWidget {
  const SearchablePicker({
    super.key,
    required this.label,
    required this.items,
    required this.labelOf,
    required this.onSelected,
    this.value,
    this.searchTermsOf,
    this.subtitleOf,
    this.onCreateNew,
    this.createNewLabel,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.prefixIcon,
  });

  final String label;
  final List<T> items;

  /// النص الظاهر للعنصر، وهو أيضاً أحد حقول البحث.
  final String Function(T item) labelOf;

  /// حقول بحث إضافية (هاتف، رقم وطني، رقم داخلي...).
  final List<String> Function(T item)? searchTermsOf;

  /// سطر ثانٍ يوضّح العنصر عند العرض.
  final String? Function(T item)? subtitleOf;

  final T? value;
  final ValueChanged<T> onSelected;

  /// عند تمريرها يظهر زر إضافة عنصر جديد داخل نافذة البحث.
  final Future<T?> Function(String typedQuery)? onCreateNew;
  final String? createNewLabel;

  final String? hintText;
  final String? errorText;
  final bool enabled;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final selected = value;
    return InkWell(
      onTap: enabled ? () => _openSheet(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          errorText: errorText,
          enabled: enabled,
          prefixIcon: prefixIcon,
          suffixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        isEmpty: selected == null,
        child: selected == null
            ? null
            : Text(
                labelOf(selected),
                style: AppTextStyles.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet<T>(
        title: label,
        items: items,
        labelOf: labelOf,
        searchTermsOf: searchTermsOf,
        subtitleOf: subtitleOf,
        onCreateNew: onCreateNew,
        createNewLabel: createNewLabel ?? 'إضافة جديد',
      ),
    );
    if (picked != null) onSelected(picked);
  }
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.createNewLabel,
    this.searchTermsOf,
    this.subtitleOf,
    this.onCreateNew,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final List<String> Function(T)? searchTermsOf;
  final String? Function(T)? subtitleOf;
  final Future<T?> Function(String)? onCreateNew;
  final String createNewLabel;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<T> get _filtered {
    final q = normalizeArabic(_query.text);
    if (q.isEmpty) return widget.items;
    return widget.items.where((item) {
      final terms = <String>[
        widget.labelOf(item),
        ...?widget.searchTermsOf?.call(item),
      ];
      return terms.any((t) => normalizeArabic(t).contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(widget.title, style: AppTextStyles.cardTitle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                focusNode: _focus,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو الرقم...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _query.clear()),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: results.isEmpty
                  ? _buildEmpty(context)
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 0.5),
                      itemBuilder: (context, i) {
                        final item = results[i];
                        final sub = widget.subtitleOf?.call(item);
                        return ListTile(
                          title: Text(widget.labelOf(item)),
                          subtitle: sub == null || sub.isEmpty
                              ? null
                              : Text(sub, style: AppTextStyles.bodySmall),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
            if (widget.onCreateNew != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(widget.createNewLabel),
                      onPressed: () async {
                        final created =
                            await widget.onCreateNew!(_query.text.trim());
                        if (created != null && context.mounted) {
                          Navigator.pop(context, created);
                        }
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            _query.text.isEmpty ? 'لا توجد عناصر' : 'لا نتائج مطابقة',
            style: AppTextStyles.bodyMediumSecondary,
          ),
          if (widget.onCreateNew != null && _query.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'يمكنك إضافة «${_query.text.trim()}» كعنصر جديد',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
