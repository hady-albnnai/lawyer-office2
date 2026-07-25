import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ArchiveEntryContext {
  final String status;
  final String kind;
  final String summary;
  final String? caseType;
  final String? courtLevel;
  final String? companyGroup;
  final String? companyType;
  final String? procedureType;
  final String? contractType;
  final String? poaType;

  const ArchiveEntryContext({
    required this.status,
    required this.kind,
    required this.summary,
    this.caseType,
    this.courtLevel,
    this.companyGroup,
    this.companyType,
    this.procedureType,
    this.contractType,
    this.poaType,
  });

  bool get isArchive => status.isNotEmpty;
  bool get isRunning => status == 'running';
  bool get isClosed => status == 'closed';

  String get statusLabel => isRunning ? 'أرشيف جارٍ' : 'أرشيف منتهٍ';

  static ArchiveEntryContext? fromQuery(Map<String, String> query) {
    final status = query['archiveStatus'] ?? '';
    if (status.isEmpty) return null;
    return ArchiveEntryContext(
      status: status,
      kind: query['archiveKind'] ?? '',
      summary: query['archiveSummary'] ?? '',
      caseType: query['caseType'],
      courtLevel: query['courtLevel'],
      companyGroup: query['companyGroup'],
      companyType: query['companyType'],
      procedureType: query['procedureType'],
      contractType: query['contractType'],
      poaType: query['poaType'],
    );
  }
}

class ArchiveContextBanner extends StatelessWidget {
  final ArchiveEntryContext? contextInfo;
  final String closedMessage;
  final String runningMessage;

  const ArchiveContextBanner({
    super.key,
    required this.contextInfo,
    this.closedMessage = 'هذا الإدخال سيعامل كأرشيف منتهٍ للحفظ والبحث فقط، ولا يولّد مواعيد في مكتب العمل.',
    this.runningMessage = 'هذا الإدخال سيعامل كأرشيف جارٍ؛ أي موعد قادم تسجله هنا سينعكس على مكتب العمل والتقويم.',
  });

  @override
  Widget build(BuildContext context) {
    final info = contextInfo;
    if (info == null) return const SizedBox.shrink();
    final color = info.isRunning ? AppColors.success : AppColors.primaryNavy;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(info.isRunning ? Icons.pending_actions : Icons.inventory_2, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.statusLabel, style: AppTextStyles.labelLarge.copyWith(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (info.summary.isNotEmpty) Text(info.summary, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 4),
                Text(info.isRunning ? runningMessage : closedMessage, style: AppTextStyles.bodySmallSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
