/// نماذج وحالة واجهة المالية الموحدة.
///
/// تعرض بيانات SQLite عبر FinanceRepository. في الاختبارات يمكن تشغيل
/// FinanceNotifier بلا مستودع (ذاكرة فقط).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart' as db;
import '../../../data/repositories/finance_repository.dart';
import '../../providers/app_providers.dart';

/// نوع الكيان المالي المرتبط بالحركة.
enum FinanceEntityType {
  caseFile,
  contract,
  company,
  adminProcedure,
  person,
  workOrder;

  String get displayName => const [
        'دعوى',
        'عقد',
        'شركة',
        'إجراء إداري',
        'شخص / جهة',
        'أمر عمل للمعقب',
      ][index];

  IconData get icon => const [
        Icons.gavel,
        Icons.description,
        Icons.business,
        Icons.assignment,
        Icons.person,
        Icons.assignment_ind,
      ][index];
}

/// نوع اتفاق الأتعاب.
enum FeeAgreementType {
  fixed,
  percentage,
  perSession,
  free;

  String get displayName => const [
        'مقطوع',
        'نسبة',
        'حسب الجلسة',
        'مجاني',
      ][index];
}

/// طريقة الدفع.
enum FinancePaymentMethod {
  cash,
  bankTransfer,
  cheque,
  other;

  String get displayName => const [
        'نقداً',
        'تحويل بنكي',
        'شيك',
        'أخرى',
      ][index];
}

/// فئة المصروف.
enum ExpenseCategory {
  courtFee,
  stamps,
  expert,
  transport,
  photocopy,
  office,
  expediter,
  other;

  String get displayName => const [
        'رسم محكمة',
        'طوابع',
        'خبرة',
        'مواصلات',
        'تصوير',
        'مصاريف مكتبية',
        'مصاريف معقب',
        'أخرى',
      ][index];
}

/// اتفاق أتعاب مع موكل أو جهة.
class FinanceAgreement {
  final String id;
  final FinanceEntityType entityType;
  final String entityId;
  final String entityTitle;
  final String partyId;
  final String partyName;
  final FeeAgreementType agreementType;
  final double totalAmount;
  final String currency;
  final DateTime agreementDate;
  final String contractDocumentId;
  final String notes;

  const FinanceAgreement({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    required this.partyId,
    required this.partyName,
    required this.agreementType,
    required this.totalAmount,
    this.currency = 'ل.س',
    required this.agreementDate,
    this.contractDocumentId = '',
    this.notes = '',
  });

  bool get hasContractDocument => contractDocumentId.isNotEmpty;

  FinanceAgreement copyWith({
    String? partyName,
    FeeAgreementType? agreementType,
    double? totalAmount,
    String? currency,
    DateTime? agreementDate,
    String? contractDocumentId,
    String? notes,
  }) {
    return FinanceAgreement(
      id: id,
      entityType: entityType,
      entityId: entityId,
      entityTitle: entityTitle,
      partyId: partyId,
      partyName: partyName ?? this.partyName,
      agreementType: agreementType ?? this.agreementType,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      agreementDate: agreementDate ?? this.agreementDate,
      contractDocumentId: contractDocumentId ?? this.contractDocumentId,
      notes: notes ?? this.notes,
    );
  }
}

/// سند قبض أو دفعة أتعاب.
class FinancePayment {
  final String id;
  final String agreementId;
  final double amount;
  final String currency;
  final DateTime paymentDate;
  final FinancePaymentMethod method;
  final String receiptDocumentId;
  final String notes;
  final String receiptNumber;

  const FinancePayment({
    required this.id,
    required this.agreementId,
    required this.amount,
    this.currency = 'ل.س',
    required this.paymentDate,
    this.method = FinancePaymentMethod.cash,
    this.receiptDocumentId = '',
    this.notes = '',
    this.receiptNumber = '',
  });

  bool get hasReceipt => receiptDocumentId.isNotEmpty;

  String get displayReceiptNumber {
    if (receiptNumber.isNotEmpty) return receiptNumber;
    return 'R-${paymentDate.year}-${id.hashCode.abs().toString().padLeft(4, '0').substring(0, 4)}';
  }
}

/// مصروف قضائي أو مكتبي.
class FinanceExpense {
  final String id;
  final FinanceEntityType entityType;
  final String entityId;
  final String entityTitle;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final String currency;
  final DateTime expenseDate;
  final String paidBy;
  final String receiptDocumentId;
  final String notes;

  const FinanceExpense({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    required this.category,
    required this.description,
    required this.amount,
    this.currency = 'ل.س',
    required this.expenseDate,
    this.paidBy = 'مكتب المحامي',
    this.receiptDocumentId = '',
    this.notes = '',
  });

  bool get hasReceipt => receiptDocumentId.isNotEmpty;
}

/// ذمة موكل مجمّعة.
class ClientReceivable {
  final String partyId;
  final String partyName;
  final double agreementsTotal;
  final double paymentsTotal;
  final double expensesTotal;
  final int agreementsCount;
  final int unpaidAgreementsCount;
  final List<String> entityTitles;

  const ClientReceivable({
    required this.partyId,
    required this.partyName,
    required this.agreementsTotal,
    required this.paymentsTotal,
    required this.expensesTotal,
    required this.agreementsCount,
    required this.unpaidAgreementsCount,
    required this.entityTitles,
  });

  /// الأتعاب غير المقبوضة فقط (لا تشمل المصاريف).
  double get remaining => agreementsTotal - paymentsTotal;

  bool get isSettled => remaining <= 0;

  /// إجمالي ما على الموكل: أتعاب متفق عليها + مصاريف صرفها المكتب عن ملفاته.
  double get totalDue => agreementsTotal + expensesTotal;

  /// رصيد حساب الموكل الكامل.
  ///
  /// موجب => على الموكل مبلغ للمكتب.
  /// سالب => للموكل رصيد دائن (أمانة) لدى المكتب.
  double get accountBalance => totalDue - paymentsTotal;

  /// هل للموكل رصيد دائن (دفع أكثر مما استحق عليه)؟
  bool get hasCredit => accountBalance < 0;

  /// قيمة الأمانة المحتفظ بها للموكل.
  double get creditAmount => hasCredit ? -accountBalance : 0;

  /// حالة الحساب بصيغة معروضة للمستخدم.
  String get accountStatusLabel {
    if (accountBalance > 0) return 'ذمة قائمة';
    if (accountBalance < 0) return 'رصيد دائن (أمانة)';
    return 'مسدّد';
  }
}

/// حركة واحدة في كشف حساب الموكل.
class ClientStatementEntry {
  final DateTime date;
  final String description;
  final String reference;

  /// مستحق على الموكل (أتعاب أو مصروف صرفه المكتب عنه).
  final double debit;

  /// مقبوض من الموكل.
  final double credit;

  const ClientStatementEntry({
    required this.date,
    required this.description,
    required this.reference,
    this.debit = 0,
    this.credit = 0,
  });
}

/// كشف حساب موكل: الحركات مرتبة زمنياً مع الرصيد التراكمي.
class ClientStatement {
  final String partyId;
  final String partyName;
  final List<ClientStatementEntry> entries;

  const ClientStatement({
    required this.partyId,
    required this.partyName,
    required this.entries,
  });

  double get totalDebit => entries.fold(0, (sum, e) => sum + e.debit);
  double get totalCredit => entries.fold(0, (sum, e) => sum + e.credit);

  /// موجب => على الموكل، سالب => أمانة للموكل.
  double get balance => totalDebit - totalCredit;

  bool get hasCredit => balance < 0;
  double get creditAmount => hasCredit ? -balance : 0;

  /// الأرصدة التراكمية بنفس ترتيب [entries].
  List<double> get runningBalances {
    final result = <double>[];
    var running = 0.0;
    for (final entry in entries) {
      running += entry.debit - entry.credit;
      result.add(running);
    }
    return result;
  }
}

/// تقرير مالي مختصر لكيان أو لكل المكتب.
class FinanceReportSummary {
  final double agreementsTotal;
  final double paymentsTotal;
  final double expensesTotal;

  const FinanceReportSummary({
    required this.agreementsTotal,
    required this.paymentsTotal,
    required this.expensesTotal,
  });

  double get remainingFees => agreementsTotal - paymentsTotal;

  double get netBalance => paymentsTotal - expensesTotal;
}

/// حالة شاشة المالية.
class FinanceState {
  final List<FinanceAgreement> agreements;
  final List<FinancePayment> payments;
  final List<FinanceExpense> expenses;
  final String searchQuery;
  final FinanceEntityType? entityFilter;

  const FinanceState({
    required this.agreements,
    required this.payments,
    required this.expenses,
    this.searchQuery = '',
    this.entityFilter,
  });

  List<FinanceAgreement> get filteredAgreements {
    final query = searchQuery.trim().toLowerCase();
    return agreements.where((agreement) {
      final filterOk = entityFilter == null || agreement.entityType == entityFilter;
      final queryOk = query.isEmpty ||
          agreement.entityTitle.toLowerCase().contains(query) ||
          agreement.partyName.toLowerCase().contains(query) ||
          agreement.entityId.toLowerCase().contains(query);
      return filterOk && queryOk;
    }).toList();
  }

  List<FinanceExpense> get filteredExpenses {
    final query = searchQuery.trim().toLowerCase();
    return expenses.where((expense) {
      final filterOk = entityFilter == null || expense.entityType == entityFilter;
      final queryOk = query.isEmpty ||
          expense.entityTitle.toLowerCase().contains(query) ||
          expense.description.toLowerCase().contains(query) ||
          expense.paidBy.toLowerCase().contains(query) ||
          expense.category.displayName.toLowerCase().contains(query);
      return filterOk && queryOk;
    }).toList();
  }

  List<FinancePayment> get filteredPayments {
    final allowedAgreementIds = filteredAgreements.map((a) => a.id).toSet();
    final query = searchQuery.trim().toLowerCase();
    return payments.where((payment) {
      if (!allowedAgreementIds.contains(payment.agreementId) && entityFilter != null) {
        return false;
      }
      if (query.isEmpty) return true;
      final agreement = agreementById(payment.agreementId);
      return payment.displayReceiptNumber.toLowerCase().contains(query) ||
          payment.method.displayName.toLowerCase().contains(query) ||
          (agreement?.partyName.toLowerCase().contains(query) ?? false) ||
          (agreement?.entityTitle.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  FinanceAgreement? agreementById(String agreementId) {
    for (final agreement in agreements) {
      if (agreement.id == agreementId) return agreement;
    }
    return null;
  }

  List<FinancePayment> paymentsForAgreement(String agreementId) {
    return payments.where((payment) => payment.agreementId == agreementId).toList();
  }

  double paidForAgreement(String agreementId) {
    return paymentsForAgreement(agreementId).fold(0, (sum, payment) => sum + payment.amount);
  }

  FinanceReportSummary get summary {
    return FinanceReportSummary(
      agreementsTotal: filteredAgreements.fold(0, (sum, agreement) => sum + agreement.totalAmount),
      paymentsTotal: filteredAgreements.fold(0, (sum, agreement) => sum + paidForAgreement(agreement.id)),
      expensesTotal: filteredExpenses.fold(0, (sum, expense) => sum + expense.amount),
    );
  }

  /// ذمم الموكلين مجمّعة حسب partyId ضمن الفلتر الحالي.
  List<ClientReceivable> get clientReceivables {
    final Map<String, List<FinanceAgreement>> byParty = {};
    for (final agreement in filteredAgreements) {
      byParty.putIfAbsent(agreement.partyId, () => []).add(agreement);
    }

    final result = <ClientReceivable>[];
    for (final entry in byParty.entries) {
      final partyAgreements = entry.value;
      final partyId = entry.key;
      final partyName = partyAgreements.first.partyName;
      final agreementsTotal = partyAgreements.fold(0.0, (sum, a) => sum + a.totalAmount);
      final paymentsTotal = partyAgreements.fold(0.0, (sum, a) => sum + paidForAgreement(a.id));
      final entityIds = partyAgreements.map((a) => '${a.entityType.index}:${a.entityId}').toSet();
      final expensesTotal = filteredExpenses
          .where((e) => entityIds.contains('${e.entityType.index}:${e.entityId}'))
          .fold(0.0, (sum, e) => sum + e.amount);
      final unpaidCount =
          partyAgreements.where((a) => paidForAgreement(a.id) < a.totalAmount).length;
      final titles = partyAgreements.map((a) => a.entityTitle).toSet().toList();

      result.add(
        ClientReceivable(
          partyId: partyId,
          partyName: partyName,
          agreementsTotal: agreementsTotal,
          paymentsTotal: paymentsTotal,
          expensesTotal: expensesTotal,
          agreementsCount: partyAgreements.length,
          unpaidAgreementsCount: unpaidCount,
          entityTitles: titles,
        ),
      );
    }

    result.sort((a, b) => b.remaining.compareTo(a.remaining));
    return result;
  }

  /// كشف حساب موكل واحد: أتعابه + المصاريف المصروفة على ملفاته − مقبوضاته.
  ///
  /// المصاريف تُحمَّل على الموكل فقط إذا كانت على كيان له فيه اتفاق أتعاب،
  /// حتى لا تُحمَّل مصاريف ملف على موكل لا علاقة له به.
  ClientStatement clientStatement(String partyId) {
    final partyAgreements = agreements.where((a) => a.partyId == partyId).toList();
    final partyName = partyAgreements.isEmpty ? '' : partyAgreements.first.partyName;
    final entries = <ClientStatementEntry>[];

    for (final agreement in partyAgreements) {
      entries.add(ClientStatementEntry(
        date: agreement.agreementDate,
        description: 'اتفاق أتعاب — ${agreement.entityTitle}',
        reference: agreement.id,
        debit: agreement.totalAmount,
      ));

      for (final payment in payments.where((p) => p.agreementId == agreement.id)) {
        entries.add(ClientStatementEntry(
          date: payment.paymentDate,
          description: 'سند قبض ${payment.displayReceiptNumber}',
          reference: payment.id,
          credit: payment.amount,
        ));
      }
    }

    final entityKeys = partyAgreements.map((a) => '${a.entityType.index}:${a.entityId}').toSet();
    for (final expense in expenses) {
      if (!entityKeys.contains('${expense.entityType.index}:${expense.entityId}')) continue;
      entries.add(ClientStatementEntry(
        date: expense.expenseDate,
        description: 'مصروف ${expense.category.displayName} — ${expense.entityTitle}',
        reference: expense.id,
        debit: expense.amount,
      ));
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    return ClientStatement(partyId: partyId, partyName: partyName, entries: entries);
  }

  /// كشف مالي لملف/كيان محدد.
  FinanceReportSummary entitySummary(FinanceEntityType type, String entityId) {
    final entityAgreements =
        agreements.where((a) => a.entityType == type && a.entityId == entityId).toList();
    final entityExpenses =
        expenses.where((e) => e.entityType == type && e.entityId == entityId).toList();
    return FinanceReportSummary(
      agreementsTotal: entityAgreements.fold(0, (sum, a) => sum + a.totalAmount),
      paymentsTotal: entityAgreements.fold(0, (sum, a) => sum + paidForAgreement(a.id)),
      expensesTotal: entityExpenses.fold(0, (sum, e) => sum + e.amount),
    );
  }

  FinanceState copyWith({
    List<FinanceAgreement>? agreements,
    List<FinancePayment>? payments,
    List<FinanceExpense>? expenses,
    String? searchQuery,
    FinanceEntityType? entityFilter,
    bool clearEntityFilter = false,
  }) {
    return FinanceState(
      agreements: agreements ?? this.agreements,
      payments: payments ?? this.payments,
      expenses: expenses ?? this.expenses,
      searchQuery: searchQuery ?? this.searchQuery,
      entityFilter: clearEntityFilter ? null : entityFilter ?? this.entityFilter,
    );
  }
}


/// تحويل صفوف Drift إلى نماذج الواجهة.
class FinanceMapper {
  static FinanceEntityType entityTypeFromIndex(int index) {
    if (index < 0 || index >= FinanceEntityType.values.length) {
      return FinanceEntityType.caseFile;
    }
    return FinanceEntityType.values[index];
  }

  static String agreementTypeToDb(FeeAgreementType t) {
    switch (t) {
      case FeeAgreementType.fixed:
        return 'fixed';
      case FeeAgreementType.percentage:
        return 'percentage';
      case FeeAgreementType.perSession:
        return 'per_session';
      case FeeAgreementType.free:
        return 'free';
    }
  }

  static FeeAgreementType agreementTypeFromDb(String raw) {
    switch (raw) {
      case 'percentage':
        return FeeAgreementType.percentage;
      case 'per_session':
        return FeeAgreementType.perSession;
      case 'free':
        return FeeAgreementType.free;
      default:
        return FeeAgreementType.fixed;
    }
  }

  static FinancePaymentMethod methodFromDb(String? raw) {
    switch (raw) {
      case 'تحويل بنكي':
      case 'bank':
      case 'bankTransfer':
        return FinancePaymentMethod.bankTransfer;
      case 'شيك':
      case 'cheque':
        return FinancePaymentMethod.cheque;
      case 'أخرى':
      case 'other':
        return FinancePaymentMethod.other;
      default:
        return FinancePaymentMethod.cash;
    }
  }

  static String methodToDb(FinancePaymentMethod m) => m.displayName;

  static ExpenseCategory categoryFromDb(String raw) {
    for (final c in ExpenseCategory.values) {
      if (c.displayName == raw) return c;
    }
    if (raw.contains('معقب')) return ExpenseCategory.expediter;
    if (raw.contains('محكمة')) return ExpenseCategory.courtFee;
    if (raw.contains('طابع')) return ExpenseCategory.stamps;
    return ExpenseCategory.other;
  }

  static FinanceAgreement mapAgreement(
    db.FeeAgreement row,
    Map<int, String> personNames,
  ) {
    return FinanceAgreement(
      id: '${row.id}',
      entityType: entityTypeFromIndex(row.entityType),
      entityId: '${row.entityId}',
      entityTitle: _entityTitle(row.entityType, row.entityId),
      partyId: '${row.partyId}',
      partyName: personNames[row.partyId] ?? 'موكل #${row.partyId}',
      agreementType: agreementTypeFromDb(row.agreementType),
      totalAmount: row.totalAmount,
      currency: row.currency,
      agreementDate: row.createdAt,
      contractDocumentId: row.contractPath ?? '',
      notes: row.notes ?? '',
    );
  }

  static FinancePayment mapPayment(db.FeePayment row) {
    return FinancePayment(
      id: '${row.id}',
      agreementId: '${row.agreementId}',
      amount: row.amount,
      paymentDate: row.paymentDate,
      method: methodFromDb(row.method),
      receiptDocumentId: row.receiptPath ?? '',
      notes: row.notes ?? '',
      receiptNumber: 'R-${row.paymentDate.year}-${row.id.toString().padLeft(4, '0')}',
    );
  }

  static FinanceExpense mapExpense(db.Expense row) {
    return FinanceExpense(
      id: '${row.id}',
      entityType: entityTypeFromIndex(row.entityType),
      entityId: '${row.entityId}',
      entityTitle: _entityTitle(row.entityType, row.entityId),
      category: categoryFromDb(row.expenseType),
      description: row.expenseType,
      amount: row.amount,
      expenseDate: row.expenseDate,
      paidBy: (row.notes != null && row.notes!.contains('معقب')) ? 'المعقب' : 'مكتب المحامي',
      receiptDocumentId: row.receiptPath ?? '',
      notes: row.notes ?? '',
    );
  }

  static String _entityTitle(int type, int id) {
    final t = entityTypeFromIndex(type).displayName;
    return '$t #$id';
  }
}

final financeProvider = StateNotifierProvider<FinanceNotifier, FinanceState>((ref) {
  return FinanceNotifier(repository: ref.watch(financeRepositoryProvider))..bootstrap();
});

class FinanceNotifier extends StateNotifier<FinanceState> {
  FinanceNotifier({FinanceRepository? repository})
      : _repository = repository,
        super(repository == null ? _seedState() : const FinanceState(agreements: [], payments: [], expenses: []));

  final FinanceRepository? _repository;
  bool _bootstrapped = false;

  Future<void> bootstrap() async {
    final repo = _repository;
    if (repo == null || _bootstrapped) return;
    _bootstrapped = true;
    try {
      await reload();
    } catch (_) {
      // إن فشل DB في بيئة بلا ملفات، نُبقي الحالة الحالية.
      if (state.agreements.isEmpty) {
        state = _seedState();
      }
    }
  }

  Future<void> reload() async {
    try {
    final repo = _repository;
    if (repo == null) return;
    final agreements = await repo.getAllAgreements();
    final payments = await repo.getAllPayments();
    final expenses = await repo.getAllExpenses();
    final persons = await repo.getAllPersons();
    final names = {for (final p in persons) p.id: p.fullName};
    state = FinanceState(
      agreements: agreements.map((a) => FinanceMapper.mapAgreement(a, names)).toList(),
      payments: payments.map(FinanceMapper.mapPayment).toList(),
      expenses: expenses.map(FinanceMapper.mapExpense).toList(),
      searchQuery: state.searchQuery,
      entityFilter: state.entityFilter,
    );
    } catch (_) {
      if (state.agreements.isEmpty) {
        state = _seedState();
      }
    }
  }

  static FinanceState _seedState() {
    final today = DateTime(2026, 7, 10);
    final agreements = [
      FinanceAgreement(
        id: 'agreement_1',
        entityType: FinanceEntityType.caseFile,
        entityId: '1',
        entityTitle: 'دعوى تعويض 2026/001',
        partyId: 'person_1',
        partyName: 'أحمد محمد الخطيب',
        agreementType: FeeAgreementType.fixed,
        totalAmount: 5000000,
        agreementDate: today.subtract(const Duration(days: 9)),
        contractDocumentId: 'doc_fee_1',
        notes: 'أتعاب مقطوعة على دفعتين.',
      ),
      FinanceAgreement(
        id: 'agreement_2',
        entityType: FinanceEntityType.caseFile,
        entityId: '3',
        entityTitle: 'دعوى تجارية 2026/003',
        partyId: 'person_3',
        partyName: 'شركة التطوير الحديث',
        agreementType: FeeAgreementType.fixed,
        totalAmount: 2500000,
        agreementDate: today.subtract(const Duration(days: 25)),
      ),
      FinanceAgreement(
        id: 'agreement_3',
        entityType: FinanceEntityType.contract,
        entityId: 'contract_1',
        entityTitle: 'عقد بيع عقار',
        partyId: 'person_1',
        partyName: 'أحمد محمد الخطيب',
        agreementType: FeeAgreementType.fixed,
        totalAmount: 800000,
        agreementDate: today.subtract(const Duration(days: 4)),
      ),
      FinanceAgreement(
        id: 'agreement_4',
        entityType: FinanceEntityType.workOrder,
        entityId: 'wo_12',
        entityTitle: 'أمر عمل: مراجعة ديوان تنفيذ',
        partyId: 'person_3',
        partyName: 'شركة التطوير الحديث',
        agreementType: FeeAgreementType.fixed,
        totalAmount: 150000,
        agreementDate: today.subtract(const Duration(days: 1)),
        notes: 'أتعاب مرتبطة بأمر عمل معقب.',
      ),
    ];

    final payments = [
      FinancePayment(
        id: 'payment_1',
        agreementId: 'agreement_1',
        amount: 1500000,
        paymentDate: today.subtract(const Duration(days: 8)),
        receiptDocumentId: 'receipt_1',
        receiptNumber: 'R-2026-0001',
      ),
      FinancePayment(
        id: 'payment_2',
        agreementId: 'agreement_2',
        amount: 2500000,
        paymentDate: today.subtract(const Duration(days: 3)),
        method: FinancePaymentMethod.bankTransfer,
        receiptDocumentId: 'receipt_2',
        receiptNumber: 'R-2026-0002',
      ),
      FinancePayment(
        id: 'payment_3',
        agreementId: 'agreement_3',
        amount: 300000,
        paymentDate: today.subtract(const Duration(days: 2)),
        receiptNumber: 'R-2026-0003',
      ),
    ];

    final expenses = [
      FinanceExpense(
        id: 'expense_1',
        entityType: FinanceEntityType.caseFile,
        entityId: '1',
        entityTitle: 'دعوى تعويض 2026/001',
        category: ExpenseCategory.courtFee,
        description: 'رسم دعوى',
        amount: 100000,
        expenseDate: today.subtract(const Duration(days: 7)),
        receiptDocumentId: 'expense_doc_1',
      ),
      FinanceExpense(
        id: 'expense_2',
        entityType: FinanceEntityType.caseFile,
        entityId: '3',
        entityTitle: 'دعوى تجارية 2026/003',
        category: ExpenseCategory.expediter,
        description: 'مصاريف معقب - تصوير ضبط',
        amount: 25000,
        expenseDate: today.subtract(const Duration(days: 6)),
        paidBy: 'المعقب',
      ),
      FinanceExpense(
        id: 'expense_3',
        entityType: FinanceEntityType.contract,
        entityId: 'contract_1',
        entityTitle: 'عقد بيع عقار',
        category: ExpenseCategory.stamps,
        description: 'طوابع عقد',
        amount: 45000,
        expenseDate: today.subtract(const Duration(days: 2)),
      ),
      FinanceExpense(
        id: 'expense_4',
        entityType: FinanceEntityType.workOrder,
        entityId: 'wo_12',
        entityTitle: 'أمر عمل: مراجعة ديوان تنفيذ',
        category: ExpenseCategory.expediter,
        description: 'مواصلات ومراجعات معقب',
        amount: 35000,
        expenseDate: today.subtract(const Duration(days: 1)),
        paidBy: 'المعقب',
      ),
    ];

    return FinanceState(agreements: agreements, payments: payments, expenses: expenses);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setEntityFilter(FinanceEntityType? entityType) {
    state = entityType == null
        ? state.copyWith(clearEntityFilter: true)
        : state.copyWith(entityFilter: entityType);
  }

  void addAgreement(FinanceAgreement agreement) {
    state = state.copyWith(agreements: [agreement, ...state.agreements]);
    final repo = _repository;
    if (repo != null) {
      final partyId = int.tryParse(agreement.partyId) ?? 0;
      final entityId = int.tryParse(agreement.entityId) ?? 0;
      repo
          .createAgreement(
            entityType: agreement.entityType.index,
            entityId: entityId == 0 ? DateTime.now().millisecondsSinceEpoch % 100000 : entityId,
            partyId: partyId == 0 ? 1 : partyId,
            agreementType: FinanceMapper.agreementTypeToDb(agreement.agreementType),
            totalAmount: agreement.totalAmount,
            currency: agreement.currency,
            notes: agreement.notes.isEmpty ? null : agreement.notes,
            userRef: 'المحامي',
          )
          .then((_) => reload())
          .catchError((_) {});
    }
  }

  void addPayment(FinancePayment payment) {
    state = state.copyWith(payments: [payment, ...state.payments]);
    final repo = _repository;
    if (repo != null) {
      final agreementId = int.tryParse(payment.agreementId) ?? 0;
      if (agreementId > 0) {
        repo
            .addPayment(
              agreementId: agreementId,
              amount: payment.amount,
              method: FinanceMapper.methodToDb(payment.method),
              notes: payment.notes.isEmpty ? null : payment.notes,
              userRef: 'المحامي',
              entityType: 0,
              entityId: 0,
            )
            .then((_) => reload())
            .catchError((_) {});
      }
    }
  }

  void addExpense(FinanceExpense expense) {
    state = state.copyWith(expenses: [expense, ...state.expenses]);
    final repo = _repository;
    if (repo != null) {
      final entityId = int.tryParse(expense.entityId) ?? 0;
      repo
          .addExpense(
            entityType: expense.entityType.index,
            entityId: entityId == 0 ? DateTime.now().millisecondsSinceEpoch % 100000 : entityId,
            expenseType: expense.category.displayName,
            amount: expense.amount,
            notes: expense.notes.isEmpty ? expense.description : expense.notes,
            userRef: 'المحامي',
          )
          .then((_) => reload())
          .catchError((_) {});
    }
  }
}
