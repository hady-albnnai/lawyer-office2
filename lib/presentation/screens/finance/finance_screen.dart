/// شاشة المالية الموحدة - المرحلة 7.
///
/// تغطي: لوحة مالية، اتفاقيات الأتعاب، سندات القبض مع طباعة إيصال PDF،
/// المصاريف (بما فيها مصاريف المعقبين وأوامر العمل)، الأرصدة،
/// ذمم الموكلين، والتقارير مع تصدير PDF offline.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/auth/permission_catalog.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../providers/office_settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/glassmorphism_helpers.dart';
import '../../theme/app_theme.dart';
import '../documents/document_viewer.dart';
import 'finance_models.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  /// التبويب الابتدائي (من السايدبار: ?tab=agreements, payments, expenses, cashbox)
  final String? initialTab;
  /// فلترة تلقائية حسب نوع الكيان (من شاشة تفاصيل العقد: ?entityType=contract)
  final String? entityType;
  /// معرف الكيان للفلترة (من شاشة تفاصيل العقد: ?entityId=123)
  final int? entityId;
  
  const FinanceScreen({super.key, this.initialTab, this.entityType, this.entityId});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// مطابقة اسم التبويب من query parameter مع فهرس التبويب
  int _tabIndex() {
    switch (widget.initialTab) {
      case 'agreements': return 1;
      case 'payments': return 2;
      case 'expenses': return 3;
      case 'balances': return 4;
      case 'clients': return 5;
      case 'cashbox': return 6;
      case 'reports': return 7;
      default: return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this, initialIndex: _tabIndex());
    
    // تطبيق الفلتر التلقائي إذا تم تمرير entityType
    if (widget.entityType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FinanceEntityType? filterType;
        switch (widget.entityType) {
          case 'contract':
            filterType = FinanceEntityType.contract;
            break;
          case 'case':
            filterType = FinanceEntityType.caseFile;
            break;
          case 'company':
            filterType = FinanceEntityType.company;
            break;
          case 'procedure':
            filterType = FinanceEntityType.adminProcedure;
            break;
          case 'poa':
            filterType = FinanceEntityType.powerOfAttorney;
            break;
        }
        if (filterType != null) {
          ref.read(financeProvider.notifier).setEntityFilter(filterType);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider);
    final permissions = ref.watch(permissionServiceProvider);

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('المالية الموحدة'),
            actions: [
              if (permissions.can(PermissionKeys.financeAgreementsCreate))
                IconButton(
                  tooltip: 'إضافة اتفاق أتعاب',
                  icon: const Icon(Icons.note_add),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => const AddAgreementDialog(),
                  ),
                ),
              if (permissions.can(PermissionKeys.financePaymentsCreate))
                IconButton(
                  tooltip: 'إضافة دفعة',
                  icon: const Icon(Icons.payments),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => const AddPaymentDialog(),
                  ),
                ),
              if (permissions.can(PermissionKeys.financeExpensesCreate))
                IconButton(
                  tooltip: 'إضافة مصروف',
                  icon: const Icon(Icons.receipt_long),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => const AddExpenseDialog(),
                  ),
                ),
              if (permissions.can(PermissionKeys.financeReportsView))
                IconButton(
                  tooltip: 'تصدير تقرير PDF',
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: permissions.can(PermissionKeys.financeReportsView) ? () => _exportFinanceReportPdf(state) : null,
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
                Tab(text: 'لوحة مالية'),
                Tab(text: 'اتفاقيات الأتعاب'),
                Tab(text: 'سندات القبض'),
                Tab(text: 'المصاريف'),
                Tab(text: 'الأرصدة'),
                Tab(text: 'ذمم الموكلين'),
                Tab(text: 'صندوق المكتب'),
                Tab(text: 'التقارير'),
              ],
            ),
          ),
          body: Column(
            children: [
              _filtersBar(state),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _dashboardTab(state),
                    _agreementsTab(state),
                    _paymentsTab(state),
                    _expensesTab(state),
                    _balancesTab(state),
                    _clientsTab(state),
                    _cashboxTab(state),
                    _reportsTab(state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtersBar(FinanceState state) {
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
                hintText: 'بحث باسم الموكل، الملف، رقم الكيان، رقم الإيصال...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref.read(financeProvider.notifier).setSearchQuery(value),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<FinanceEntityType?>(
            value: state.entityFilter,
            items: [
              const DropdownMenuItem<FinanceEntityType?>(value: null, child: Text('كل الملفات')),
              ...FinanceEntityType.values.map(
                (type) => DropdownMenuItem<FinanceEntityType?>(
                  value: type,
                  child: Text(type.displayName),
                ),
              ),
            ],
            onChanged: (value) => ref.read(financeProvider.notifier).setEntityFilter(value),
          ),
        ],
      ),
    );
  }

  Widget _dashboardTab(FinanceState state) {
    final summary = state.summary;
    final expediterExpenses = state.filteredExpenses
        .where((e) =>
            e.category == ExpenseCategory.expediter ||
            e.entityType == FinanceEntityType.workOrder)
        .fold(0.0, (sum, e) => sum + e.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                'إجمالي الأتعاب',
                _formatCurrency(summary.agreementsTotal),
                Icons.assignment_turned_in,
                AppColors.primaryNavy,
              ),
              _metricCard(
                'المقبوض',
                _formatCurrency(summary.paymentsTotal),
                Icons.payments,
                AppColors.success,
              ),
              _metricCard(
                'المتبقي',
                _formatCurrency(summary.remainingFees),
                Icons.pending_actions,
                AppColors.warning,
              ),
              _metricCard(
                'المصاريف',
                _formatCurrency(summary.expensesTotal),
                Icons.receipt,
                AppColors.error,
              ),
              _metricCard(
                'مصاريف المعقبين',
                _formatCurrency(expediterExpenses),
                Icons.directions_walk,
                AppColors.info,
              ),
              _metricCard(
                'الصافي',
                _formatCurrency(summary.netBalance),
                Icons.account_balance_wallet,
                summary.netBalance >= 0 ? AppColors.success : AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'تنبيهات مالية',
            icon: Icons.notifications_active,
            children: [
              _alertLine(
                Icons.warning_amber,
                'اتفاقيات غير مسددة بالكامل: ${_unpaidAgreements(state).length}',
                AppColors.warning,
              ),
              _alertLine(
                Icons.people_alt,
                'موكلون لديهم ذمم: ${state.clientReceivables.where((c) => c.accountBalance > 0).length}',
                AppColors.warning,
              ),
              if (state.clientReceivables.any((c) => c.hasCredit))
                _alertLine(
                  Icons.savings,
                  'موكلون لديهم أمانات: ${state.clientReceivables.where((c) => c.hasCredit).length}',
                  AppColors.info,
                ),
              _alertLine(
                Icons.receipt_long,
                'مصاريف دون إيصال: ${state.filteredExpenses.where((e) => !e.hasReceipt).length}',
                AppColors.error,
              ),
              _alertLine(
                Icons.description,
                'اتفاقيات دون عقد أتعاب مرفق: ${state.filteredAgreements.where((a) => !a.hasContractDocument).length}',
                AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _agreementsTab(FinanceState state) {
    final permissions = ref.watch(permissionServiceProvider);
    final canCreate = permissions.can(PermissionKeys.financeAgreementsCreate);
    final agreements = [...state.filteredAgreements]
      ..sort((a, b) => b.agreementDate.compareTo(a.agreementDate));
    if (agreements.isEmpty) {
      return _emptyStateWithAction(
        icon: Icons.assignment,
        title: 'لا توجد اتفاقيات أتعاب',
        subtitle: 'أضف اتفاق أتعاب جديد لربطه بملفات المكتب.',
        actionLabel: 'إضافة اتفاق أتعاب',
        actionIcon: Icons.note_add,
        onPressed: canCreate
            ? () => showDialog<void>(context: context, builder: (_) => const AddAgreementDialog())
            : null,
      );
    }
    return Column(
      children: [
        if (canCreate) _inlineAddButton('إضافة اتفاق أتعاب', Icons.note_add,
            () => showDialog<void>(context: context, builder: (_) => const AddAgreementDialog())),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: agreements.length,
            itemBuilder: (context, index) => _agreementCard(state, agreements[index]),
          ),
        ),
      ],
    );
  }

  Widget _paymentsTab(FinanceState state) {
    final permissions = ref.watch(permissionServiceProvider);
    final canCreate = permissions.can(PermissionKeys.financePaymentsCreate);
    final payments = [...state.filteredPayments]
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    if (payments.isEmpty) {
      return _emptyStateWithAction(
        icon: Icons.payments,
        title: 'لا توجد سندات قبض',
        subtitle: 'سجّل دفعة أو سند قبض جديد.',
        actionLabel: 'إضافة دفعة / سند قبض',
        actionIcon: Icons.payments,
        onPressed: canCreate
            ? () => showDialog<void>(context: context, builder: (_) => const AddPaymentDialog())
            : null,
      );
    }
    return Column(
      children: [
        if (canCreate) _inlineAddButton('إضافة دفعة / سند قبض', Icons.payments,
            () => showDialog<void>(context: context, builder: (_) => const AddPaymentDialog())),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) => _paymentCard(state, payments[index]),
          ),
        ),
      ],
    );
  }

  Widget _expensesTab(FinanceState state) {
    final permissions = ref.watch(permissionServiceProvider);
    final canCreate = permissions.can(PermissionKeys.financeExpensesCreate);
    final expenses = [...state.filteredExpenses]
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    if (expenses.isEmpty) {
      return _emptyStateWithAction(
        icon: Icons.receipt_long,
        title: 'لا توجد مصاريف',
        subtitle: 'أضف مصروفاً جديداً (رسوم قضائية، تنقل، قرطاسية...).',
        actionLabel: 'إضافة مصروف',
        actionIcon: Icons.receipt_long,
        onPressed: canCreate
            ? () => showDialog<void>(context: context, builder: (_) => const AddExpenseDialog())
            : null,
      );
    }
    return Column(
      children: [
        if (canCreate) _inlineAddButton('إضافة مصروف', Icons.receipt_long,
            () => showDialog<void>(context: context, builder: (_) => const AddExpenseDialog())),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            itemBuilder: (context, index) => _expenseCard(expenses[index]),
          ),
        ),
      ],
    );
  }

  /// زر إضافة بارز داخل كل تبويب (ليس مخبياً في AppBar)
  Widget _inlineAddButton(String label, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            foregroundColor: AppColors.secondaryGold,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  /// حالة فارغة مع زر إضافة (بدلاً من "أضف من الشريط العلوي")
  Widget _emptyStateWithAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required IconData actionIcon,
    VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
            const SizedBox(height: 8),
            Text(subtitle, style: AppTextStyles.bodyMediumSecondary, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(actionIcon, size: 20),
                label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: AppColors.secondaryGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
              ),
            ),
            if (onPressed == null) ...[
              const SizedBox(height: 12),
              Text('ليس لديك صلاحية الإضافة', style: AppTextStyles.bodySmallSecondary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _balancesTab(FinanceState state) {
    final agreements = state.filteredAgreements;
    if (agreements.isEmpty) {
      return _emptyState(
        Icons.account_balance_wallet,
        'لا توجد أرصدة',
        'لا توجد اتفاقيات ضمن الفلتر الحالي.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agreements.length,
      itemBuilder: (context, index) {
        final agreement = agreements[index];
        final paid = state.paidForAgreement(agreement.id);
        final remaining = agreement.totalAmount - paid;
        return GlassmorphicCard(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: remaining <= 0
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.warning.withOpacity(0.12),
              child: Icon(
                remaining <= 0 ? Icons.verified : Icons.pending_actions,
                color: remaining <= 0 ? AppColors.success : AppColors.warning,
              ),
            ),
            title: Text(agreement.entityTitle, style: AppTextStyles.labelLarge),
            subtitle: Text(
              '${agreement.partyName} • ${agreement.entityType.displayName} • المقبوض: ${_formatCurrency(paid)}',
              style: AppTextStyles.bodySmallSecondary,
            ),
            trailing: Text(
              _formatCurrency(remaining),
              style: AppTextStyles.numberText.copyWith(
                color: remaining <= 0 ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _clientsTab(FinanceState state) {
    final clients = state.clientReceivables;
    if (clients.isEmpty) {
      return _emptyState(
        Icons.people_alt,
        'لا توجد ذمم موكلين',
        'أضف اتفاقيات أتعاب لموكلين لعرض الذمم.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        return GlassmorphicCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _accountColor(client).withOpacity(0.12),
                      child: Icon(
                        client.hasCredit
                            ? Icons.savings
                            : (client.accountBalance == 0 ? Icons.verified_user : Icons.person),
                        color: _accountColor(client),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        client.partyName,
                        style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy),
                      ),
                    ),
                    _badge(client.accountStatusLabel, _accountColor(client)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _miniMetric('اتفاقيات', '${client.agreementsCount}'),
                    _miniMetric('غير مسددة', '${client.unpaidAgreementsCount}'),
                    _miniMetric('إجمالي الأتعاب', _formatCurrency(client.agreementsTotal)),
                    _miniMetric('المقبوض', _formatCurrency(client.paymentsTotal)),
                    _miniMetric('أتعاب متبقية', _formatCurrency(client.remaining)),
                    _miniMetric('مصاريف عنه', _formatCurrency(client.expensesTotal)),
                    _miniMetric(
                      client.hasCredit ? 'أمانة له' : 'رصيد الحساب',
                      _formatCurrency(client.accountBalance.abs()),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'الملفات: ${client.entityTitles.join(' • ')}',
                  style: AppTextStyles.bodySmallSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cashboxTab(FinanceState state) {
    final payments = [...state.filteredPayments]..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    final expenses = [...state.filteredExpenses]..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    final incoming = payments.fold(0.0, (sum, p) => sum + p.amount);
    final officeExpenses = expenses.where((e) => e.paidBy.contains('مكتب')).toList();
    final outgoing = officeExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final balance = incoming - outgoing;
    final movements = <({DateTime date, String title, String subtitle, double amount, bool incoming})>[
      ...payments.map((p) {
        final agreement = state.agreementById(p.agreementId);
        return (
          date: p.paymentDate,
          title: 'سند قبض ${p.displayReceiptNumber}',
          subtitle: agreement == null ? p.method.displayName : '${agreement.partyName} • ${agreement.entityTitle}',
          amount: p.amount,
          incoming: true,
        );
      }),
      ...officeExpenses.map((e) => (
            date: e.expenseDate,
            title: e.description,
            subtitle: '${e.entityTitle} • ${e.category.displayName}',
            amount: e.amount,
            incoming: false,
          )),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard('الوارد الفعلي', _formatCurrency(incoming), Icons.call_received, AppColors.success),
              _metricCard('الصادر من المكتب', _formatCurrency(outgoing), Icons.call_made, AppColors.error),
              _metricCard('الرصيد التقريبي', _formatCurrency(balance), Icons.account_balance, balance >= 0 ? AppColors.primaryNavy : AppColors.error),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'حركات صندوق المكتب',
            icon: Icons.account_balance_wallet,
            children: movements.isEmpty
                ? [Text('لا توجد حركات صندوق ضمن الفلتر الحالي.', style: AppTextStyles.bodySmallSecondary)]
                : movements
                    .take(80)
                    .map(
                      (m) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (m.incoming ? AppColors.success : AppColors.error).withOpacity(0.12),
                          child: Icon(m.incoming ? Icons.add : Icons.remove, color: m.incoming ? AppColors.success : AppColors.error),
                        ),
                        title: Text(m.title, style: AppTextStyles.labelLarge),
                        subtitle: Text('${_formatDate(m.date)} • ${m.subtitle}', style: AppTextStyles.bodySmallSecondary),
                        trailing: Text(
                          '${m.incoming ? '+' : '-'} ${_formatCurrency(m.amount)}',
                          style: AppTextStyles.numberText.copyWith(color: m.incoming ? AppColors.success : AppColors.error),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _reportsTab(FinanceState state) {
    final summary = state.summary;
    final clients = state.clientReceivables;
    final expediterExpenses = state.filteredExpenses
        .where((e) =>
            e.category == ExpenseCategory.expediter ||
            e.entityType == FinanceEntityType.workOrder)
        .fold(0.0, (sum, e) => sum + e.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionCard(
            title: 'تقرير مالي مختصر',
            icon: Icons.summarize,
            children: [
              _reportRow('إجمالي اتفاقيات الأتعاب', _formatCurrency(summary.agreementsTotal)),
              _reportRow('إجمالي المقبوضات', _formatCurrency(summary.paymentsTotal)),
              _reportRow('إجمالي المتبقي على الموكلين', _formatCurrency(summary.remainingFees)),
              _reportRow('إجمالي المصروفات', _formatCurrency(summary.expensesTotal)),
              _reportRow('مصاريف المعقبين / أوامر العمل', _formatCurrency(expediterExpenses)),
              _reportRow('صافي صندوق الملفات', _formatCurrency(summary.netBalance)),
              _reportRow('إجمالي المستحق على الموكلين (أتعاب + مصاريف)', _formatCurrency(clients.fold<double>(0, (sum, c) => sum + c.totalDue))),
              _reportRow('ذمم قائمة', _formatCurrency(clients.where((c) => c.accountBalance > 0).fold<double>(0, (sum, c) => sum + c.accountBalance))),
              _reportRow('أمانات محتفظ بها للموكلين', _formatCurrency(clients.fold<double>(0, (sum, c) => sum + c.creditAmount))),
              _reportRow('عدد الموكلين ذوي الذمم', '${clients.where((c) => c.accountBalance > 0).length}'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('تصدير كشف مالي PDF'),
                    onPressed: ref.watch(permissionServiceProvider).can(PermissionKeys.financeReportsView) ? () => _exportFinanceReportPdf(state) : null,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('معاينة وطباعة'),
                    onPressed: ref.watch(permissionServiceProvider).can(PermissionKeys.financeReportsView) ? () => _previewFinanceReportPdf(state) : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'كشف ذمم الموكلين',
            icon: Icons.people,
            children: clients.isEmpty
                ? [Text('لا توجد ذمم ضمن الفلتر الحالي.', style: AppTextStyles.bodySmallSecondary)]
                : clients
                    .map(
                      (client) => _reportRow(
                        client.partyName,
                        _formatCurrency(client.remaining),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _agreementCard(FinanceState state, FinanceAgreement agreement) {
    final permissions = ref.watch(permissionServiceProvider);
    final paid = state.paidForAgreement(agreement.id);
    final remaining = agreement.totalAmount - paid;
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(agreement.entityType.icon, color: AppColors.primaryNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    agreement.entityTitle,
                    style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy),
                  ),
                ),
                _badge(agreement.entityType.displayName, AppColors.primaryNavy),
                const SizedBox(width: 6),
                _badge(agreement.agreementType.displayName, AppColors.info),
              ],
            ),
            const SizedBox(height: 8),
            _detailLine(Icons.person, 'الموكل: ${agreement.partyName}'),
            _detailLine(Icons.calendar_today, 'تاريخ الاتفاق: ${_formatDate(agreement.agreementDate)}'),
            _detailLine(
              Icons.assignment,
              'الإجمالي: ${_formatCurrency(agreement.totalAmount)} • المقبوض: ${_formatCurrency(paid)} • المتبقي: ${_formatCurrency(remaining)}',
            ),
            if (agreement.notes.isNotEmpty) _detailLine(Icons.note, agreement.notes),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.description),
                  label: const Text('عقد الأتعاب'),
                  onPressed: agreement.hasContractDocument
                      ? () => openDocument(context, agreement.contractDocumentId)
                      : null,
                ),
                if (permissions.can(PermissionKeys.financePaymentsCreate))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة دفعة'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AddPaymentDialog(defaultAgreementId: agreement.id),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(FinanceState state, FinancePayment payment) {
    final agreement = state.agreementById(payment.agreementId);
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withOpacity(0.12),
          child: Icon(Icons.payments, color: AppColors.success),
        ),
        title: Text(
          '${_formatCurrency(payment.amount)} • ${payment.displayReceiptNumber}',
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.success),
        ),
        subtitle: Text(
          '${agreement?.partyName ?? 'غير محدد'} • ${agreement?.entityTitle ?? ''} • ${payment.method.displayName} • ${_formatDate(payment.paymentDate)}',
          style: AppTextStyles.bodySmallSecondary,
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.receipt),
              tooltip: 'طباعة إيصال',
              onPressed: () => _printReceipt(state, payment),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed:
                  payment.hasReceipt ? () => openDocument(context, payment.receiptDocumentId) : null,
              tooltip: 'فتح سند القبض',
            ),
          ],
        ),
      ),
    );
  }

  Widget _expenseCard(FinanceExpense expense) {
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.error.withOpacity(0.12),
          child: Icon(Icons.receipt_long, color: AppColors.error),
        ),
        title: Text(
          '${expense.description} • ${_formatCurrency(expense.amount)}',
          style: AppTextStyles.labelLarge,
        ),
        subtitle: Text(
          '${expense.entityTitle} • ${expense.entityType.displayName} • ${expense.category.displayName} • ${expense.paidBy} • ${_formatDate(expense.expenseDate)}',
          style: AppTextStyles.bodySmallSecondary,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: expense.hasReceipt ? () => openDocument(context, expense.receiptDocumentId) : null,
          tooltip: 'فتح الإيصال',
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(title, style: AppTextStyles.bodySmallSecondary),
              const SizedBox(height: 4),
              Text(value, style: AppTextStyles.numberText.copyWith(color: color, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

  /// لون حالة حساب الموكل: أخضر مسدّد، أزرق أمانة له، برتقالي ذمة عليه.
  Color _accountColor(ClientReceivable client) {
    if (client.hasCredit) return AppColors.info;
    if (client.accountBalance == 0) return AppColors.success;
    return AppColors.warning;
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text('$label: $value', style: AppTextStyles.bodySmall),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
                Text(title, style: AppTextStyles.headline6.copyWith(color: AppColors.primaryNavy)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _alertLine(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }

  Widget _detailLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Text(value, style: AppTextStyles.numberText.copyWith(color: AppColors.primaryNavy)),
        ],
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

  List<FinanceAgreement> _unpaidAgreements(FinanceState state) {
    return state.filteredAgreements
        .where((agreement) => state.paidForAgreement(agreement.id) < agreement.totalAmount)
        .toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')} ل.س';
  }

  Future<OfficeSettingsModel> _loadSettings() async {
    final asyncSettings = ref.read(officeSettingsProvider);
    return asyncSettings.maybeWhen(
      data: (settings) => settings,
      orElse: () => const OfficeSettingsModel(
        officeTitle: AppConstants.defaultOfficeTitle,
        lawyerName: AppConstants.defaultLawyerName,
        officeAddress: AppConstants.defaultAddress,
        officePhone: AppConstants.defaultPhone,
      ),
    );
  }

  Future<void> _printReceipt(FinanceState state, FinancePayment payment) async {
    final agreement = state.agreementById(payment.agreementId);
    final settings = await _loadSettings();
    final bytes = await FinancePdfBuilder.buildReceipt(
      settings: settings,
      payment: payment,
      agreement: agreement,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'receipt_${payment.displayReceiptNumber}.pdf',
    );
  }

  Future<void> _exportFinanceReportPdf(FinanceState state) async {
    final settings = await _loadSettings();
    final bytes = await FinancePdfBuilder.buildFinanceReport(
      settings: settings,
      state: state,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'finance_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _previewFinanceReportPdf(FinanceState state) async {
    final settings = await _loadSettings();
    final bytes = await FinancePdfBuilder.buildFinanceReport(
      settings: settings,
      state: state,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: const Text('معاينة التقرير المالي')),
            body: PdfPreview(
              build: (_) async => bytes,
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName: 'finance_report.pdf',
            ),
          ),
        ),
      ),
    );
  }
}

/// مولّد PDF للإيصالات والكشوف المالية (Offline).
class FinancePdfBuilder {
  static Future<Uint8List> buildReceipt({
    required OfficeSettingsModel settings,
    required FinancePayment payment,
    FinanceAgreement? agreement,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900, width: 1.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  settings.officeTitle,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'الأستاذ: ${settings.lawyerName}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontBold, fontSize: 12),
                ),
                pw.Text(
                  settings.officeAddress,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.Divider(thickness: 1.2, color: PdfColors.blue900),
                pw.SizedBox(height: 8),
                pw.Text(
                  'سند قبض',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontBold, fontSize: 18),
                ),
                pw.SizedBox(height: 12),
                _pdfRow('رقم الإيصال', payment.displayReceiptNumber, fontBold),
                _pdfRow('التاريخ', _date(payment.paymentDate), fontRegular),
                _pdfRow('الموكل', agreement?.partyName ?? '—', fontRegular),
                _pdfRow('الملف', agreement?.entityTitle ?? '—', fontRegular),
                _pdfRow('نوع الكيان', agreement?.entityType.displayName ?? '—', fontRegular),
                _pdfRow('طريقة الدفع', payment.method.displayName, fontRegular),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  color: PdfColors.blue50,
                  child: pw.Text(
                    'المبلغ المقبوض: ${_money(payment.amount)}',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900),
                  ),
                ),
                if (payment.notes.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('ملاحظات: ${payment.notes}', style: const pw.TextStyle(fontSize: 10)),
                ],
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('توقيع المستلم', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                    pw.Text('ختم المكتب', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'صادر عن نظام مكتب المحامي V6.2 Offline',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> buildFinanceReport({
    required OfficeSettingsModel settings,
    required FinanceState state,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final summary = state.summary;
    final clients = state.clientReceivables;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(settings.officeTitle,
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900)),
                  pw.Text('الأستاذ: ${settings.lawyerName}',
                      style: pw.TextStyle(font: fontBold, fontSize: 11)),
                ],
              ),
              pw.Text(AppConstants.defaultCountry,
                  style: pw.TextStyle(font: fontBold, fontSize: 11)),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount} — كشف مالي Offline',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'الكشف المالي الموحد للمكتب',
              style: pw.TextStyle(font: fontBold, fontSize: 16),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'تاريخ الإصدار: ${_date(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['البند', 'القيمة'],
            data: [
              ['إجمالي اتفاقيات الأتعاب', _money(summary.agreementsTotal)],
              ['إجمالي المقبوضات', _money(summary.paymentsTotal)],
              ['المتبقي على الموكلين', _money(summary.remainingFees)],
              ['إجمالي المصروفات', _money(summary.expensesTotal)],
              ['صافي الصندوق', _money(summary.netBalance)],
            ],
            headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 11),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
            cellAlignment: pw.Alignment.centerRight,
          ),
          pw.SizedBox(height: 16),
          pw.Text('ذمم الموكلين', style: pw.TextStyle(font: fontBold, fontSize: 13)),
          pw.SizedBox(height: 8),
          if (clients.isEmpty)
            pw.Text('لا توجد ذمم', style: pw.TextStyle(font: fontRegular, fontSize: 10))
          else
            pw.Table.fromTextArray(
              headers: ['الموكل', 'اتفاقيات', 'المتبقي', 'الحالة'],
              data: clients
                  .map(
                    (c) => [
                      c.partyName,
                      '${c.agreementsCount}',
                      _money(c.remaining),
                      c.isSettled ? 'مسدّد' : 'ذمة قائمة',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 11),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
              cellAlignment: pw.Alignment.centerRight,
            ),
          pw.SizedBox(height: 16),
          pw.Text('سندات القبض', style: pw.TextStyle(font: fontBold, fontSize: 13)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['رقم الإيصال', 'الموكل', 'الملف', 'المبلغ', 'التاريخ'],
            data: state.filteredPayments.map((p) {
              final a = state.agreementById(p.agreementId);
              return [
                p.displayReceiptNumber,
                a?.partyName ?? '—',
                a?.entityTitle ?? '—',
                _money(p.amount),
                _date(p.paymentDate),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
            cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
            cellAlignment: pw.Alignment.centerRight,
          ),
          pw.SizedBox(height: 16),
          pw.Text('المصاريف', style: pw.TextStyle(font: fontBold, fontSize: 13)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['الوصف', 'الكيان', 'الفئة', 'المبلغ', 'التاريخ'],
            data: state.filteredExpenses
                .map(
                  (e) => [
                    e.description,
                    e.entityTitle,
                    e.category.displayName,
                    _money(e.amount),
                    _date(e.expenseDate),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
            cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
            cellAlignment: pw.Alignment.centerRight,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 11)),
        ],
      ),
    );
  }

  static String _date(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _money(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ل.س';
  }
}

class AddAgreementDialog extends ConsumerStatefulWidget {
  const AddAgreementDialog({super.key});

  @override
  ConsumerState<AddAgreementDialog> createState() => _AddAgreementDialogState();
}

class _AddAgreementDialogState extends ConsumerState<AddAgreementDialog> {
  final TextEditingController _entityTitleController = TextEditingController();
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _documentController = TextEditingController();
  FinanceEntityType _entityType = FinanceEntityType.caseFile;
  FeeAgreementType _agreementType = FeeAgreementType.fixed;

  @override
  void dispose() {
    _entityTitleController.dispose();
    _partyController.dispose();
    _amountController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FinanceDialogFrame(
      title: 'إضافة اتفاق أتعاب',
      onSave: _save,
      children: [
        TextField(
          controller: _entityTitleController,
          decoration: const InputDecoration(labelText: 'عنوان الملف / الكيان'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _partyController,
          decoration: const InputDecoration(labelText: 'اسم الموكل'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(labelText: 'المبلغ الإجمالي'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<FinanceEntityType>(
          value: _entityType,
          decoration: const InputDecoration(labelText: 'نوع الكيان'),
          items: FinanceEntityType.values
              .map((type) => DropdownMenuItem(value: type, child: Text(type.displayName)))
              .toList(),
          onChanged: (value) => setState(() => _entityType = value ?? _entityType),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<FeeAgreementType>(
          value: _agreementType,
          decoration: const InputDecoration(labelText: 'نوع الاتفاق'),
          items: FeeAgreementType.values
              .map((type) => DropdownMenuItem(value: type, child: Text(type.displayName)))
              .toList(),
          onChanged: (value) => setState(() => _agreementType = value ?? _agreementType),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _documentController,
          decoration: const InputDecoration(labelText: 'معرف عقد الأتعاب المرفق'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.financeAgreementsCreate)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'finance', entityType: 'agreement', description: 'محاولة إضافة اتفاق أتعاب دون صلاحية', severity: 'warning');
      _error('لا تملك صلاحية إضافة اتفاق أتعاب');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (_entityTitleController.text.trim().isEmpty ||
        _partyController.text.trim().isEmpty ||
        amount <= 0) {
      _error('عنوان الملف واسم الموكل والمبلغ إلزامية');
      return;
    }
    final now = DateTime.now();
    final partyName = _partyController.text.trim();
    final agreementId = 'agreement_${now.microsecondsSinceEpoch}';
    ref.read(financeProvider.notifier).addAgreement(
          FinanceAgreement(
            id: agreementId,
            entityType: _entityType,
            entityId: 'manual_${now.microsecondsSinceEpoch}',
            entityTitle: _entityTitleController.text.trim(),
            partyId: 'party_${partyName.hashCode.abs()}',
            partyName: partyName,
            agreementType: _agreementType,
            totalAmount: amount,
            agreementDate: now,
            contractDocumentId: _documentController.text.trim(),
          ),
        );
    await ref.read(auditServiceProvider).log(
      action: 'create',
      category: 'finance',
      entityType: 'fee_agreement',
      entityId: agreementId,
      entityTitle: _entityTitleController.text.trim(),
      description: 'إضافة اتفاق أتعاب',
      after: {'party': partyName, 'amount': amount, 'type': _agreementType.displayName},
      severity: 'warning',
    );
    Navigator.of(context).pop();
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: AppColors.error),
    );
  }
}

class AddPaymentDialog extends ConsumerStatefulWidget {
  final String? defaultAgreementId;

  const AddPaymentDialog({super.key, this.defaultAgreementId});

  @override
  ConsumerState<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends ConsumerState<AddPaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _receiptController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  FinancePaymentMethod _method = FinancePaymentMethod.cash;
  String? _agreementId;

  @override
  void initState() {
    super.initState();
    _agreementId = widget.defaultAgreementId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _receiptController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agreements = ref.watch(financeProvider).agreements;
    _agreementId ??= agreements.isNotEmpty ? agreements.first.id : null;
    return _FinanceDialogFrame(
      title: 'إضافة سند قبض',
      onSave: _save,
      children: [
        DropdownButtonFormField<String>(
          value: _agreementId,
          decoration: const InputDecoration(labelText: 'اتفاق الأتعاب'),
          items: agreements
              .map(
                (agreement) => DropdownMenuItem(
                  value: agreement.id,
                  child: Text('${agreement.partyName} - ${agreement.entityTitle}'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _agreementId = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(labelText: 'المبلغ المقبوض'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<FinancePaymentMethod>(
          value: _method,
          decoration: const InputDecoration(labelText: 'طريقة الدفع'),
          items: FinancePaymentMethod.values
              .map((method) => DropdownMenuItem(value: method, child: Text(method.displayName)))
              .toList(),
          onChanged: (value) => setState(() => _method = value ?? _method),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _receiptController,
          decoration: const InputDecoration(labelText: 'معرف سند القبض / المرفق'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(labelText: 'ملاحظات'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.financePaymentsCreate)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'finance', entityType: 'payment', description: 'محاولة إضافة سند قبض دون صلاحية', severity: 'warning');
      _error('لا تملك صلاحية إضافة سند قبض');
      return;
    }
    final agreementId = _agreementId;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (agreementId == null || amount <= 0) {
      _error('الاتفاق والمبلغ إلزاميان');
      return;
    }
    final now = DateTime.now();
    final seq = (ref.read(financeProvider).payments.length + 1).toString().padLeft(4, '0');
    final paymentId = 'payment_${now.microsecondsSinceEpoch}';
    ref.read(financeProvider.notifier).addPayment(
          FinancePayment(
            id: paymentId,
            agreementId: agreementId,
            amount: amount,
            paymentDate: now,
            method: _method,
            receiptDocumentId: _receiptController.text.trim(),
            notes: _notesController.text.trim(),
            receiptNumber: 'R-${now.year}-$seq',
          ),
        );
    await ref.read(auditServiceProvider).log(
      action: 'create',
      category: 'finance',
      entityType: 'fee_payment',
      entityId: paymentId,
      entityTitle: agreementId,
      description: 'إضافة سند قبض',
      after: {'agreementId': agreementId, 'amount': amount, 'method': _method.displayName},
      severity: 'warning',
    );
    Navigator.of(context).pop();
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: AppColors.error),
    );
  }
}

class AddExpenseDialog extends ConsumerStatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final TextEditingController _entityTitleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _receiptController = TextEditingController();
  final TextEditingController _paidByController = TextEditingController(text: 'مكتب المحامي');
  FinanceEntityType _entityType = FinanceEntityType.caseFile;
  ExpenseCategory _category = ExpenseCategory.courtFee;

  @override
  void dispose() {
    _entityTitleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _receiptController.dispose();
    _paidByController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FinanceDialogFrame(
      title: 'إضافة مصروف',
      onSave: _save,
      children: [
        TextField(
          controller: _entityTitleController,
          decoration: const InputDecoration(labelText: 'عنوان الملف / الكيان'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: 'وصف المصروف'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(labelText: 'المبلغ'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<FinanceEntityType>(
          value: _entityType,
          decoration: const InputDecoration(labelText: 'نوع الكيان'),
          items: FinanceEntityType.values
              .map((type) => DropdownMenuItem(value: type, child: Text(type.displayName)))
              .toList(),
          onChanged: (value) => setState(() => _entityType = value ?? _entityType),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ExpenseCategory>(
          value: _category,
          decoration: const InputDecoration(labelText: 'فئة المصروف'),
          items: ExpenseCategory.values
              .map((category) => DropdownMenuItem(value: category, child: Text(category.displayName)))
              .toList(),
          onChanged: (value) => setState(() => _category = value ?? _category),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _paidByController,
          decoration: const InputDecoration(labelText: 'الجهة الدافعة (مكتب / معقب)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _receiptController,
          decoration: const InputDecoration(labelText: 'معرف الإيصال'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.can(PermissionKeys.financeExpensesCreate)) {
      await ref.read(auditServiceProvider).log(action: 'access_denied', category: 'finance', entityType: 'expense', description: 'محاولة إضافة مصروف دون صلاحية', severity: 'warning');
      _error('لا تملك صلاحية إضافة مصروف');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (_entityTitleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        amount <= 0) {
      _error('عنوان الملف والوصف والمبلغ إلزامية');
      return;
    }
    final now = DateTime.now();
    final expenseId = 'expense_${now.microsecondsSinceEpoch}';
    ref.read(financeProvider.notifier).addExpense(
          FinanceExpense(
            id: expenseId,
            entityType: _entityType,
            entityId: 'manual_${now.microsecondsSinceEpoch}',
            entityTitle: _entityTitleController.text.trim(),
            category: _category,
            description: _descriptionController.text.trim(),
            amount: amount,
            expenseDate: now,
            paidBy: _paidByController.text.trim().isEmpty
                ? 'مكتب المحامي'
                : _paidByController.text.trim(),
            receiptDocumentId: _receiptController.text.trim(),
          ),
        );
    await ref.read(auditServiceProvider).log(
      action: 'create',
      category: 'finance',
      entityType: 'expense',
      entityId: expenseId,
      entityTitle: _entityTitleController.text.trim(),
      description: 'إضافة مصروف',
      after: {'entity': _entityTitleController.text.trim(), 'amount': amount, 'category': _category.displayName},
      severity: 'warning',
    );
    Navigator.of(context).pop();
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: AppColors.error),
    );
  }
}

class _FinanceDialogFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;

  const _FinanceDialogFrame({
    required this.title,
    required this.onSave,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 560,
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () => onSave(), child: const Text('حفظ')),
      ],
    );
  }
}
