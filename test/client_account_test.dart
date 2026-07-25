import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/presentation/screens/finance/finance_models.dart';
import 'package:lawyer_office/presentation/screens/search_reports/search_report_models.dart';

/// اختبارات حساب الموكل: المستحق عليه يشمل الأتعاب والمصاريف المصروفة على
/// ملفاته، والرصيد السالب يعني أمانة محتفظ بها له لدى المكتب.
void main() {
  FinanceAgreement agreement({
    required String id,
    required String partyId,
    required String entityId,
    required double amount,
    String partyName = 'موكل',
    FinanceEntityType type = FinanceEntityType.caseFile,
    DateTime? date,
  }) {
    return FinanceAgreement(
      id: id,
      entityType: type,
      entityId: entityId,
      entityTitle: 'ملف $entityId',
      partyId: partyId,
      partyName: partyName,
      agreementType: FeeAgreementType.fixed,
      totalAmount: amount,
      agreementDate: date ?? DateTime(2026, 1, 1),
    );
  }

  FinancePayment payment({
    required String id,
    required String agreementId,
    required double amount,
    DateTime? date,
  }) {
    return FinancePayment(
      id: id,
      agreementId: agreementId,
      amount: amount,
      paymentDate: date ?? DateTime(2026, 2, 1),
    );
  }

  FinanceExpense expense({
    required String id,
    required String entityId,
    required double amount,
    FinanceEntityType type = FinanceEntityType.caseFile,
    DateTime? date,
  }) {
    return FinanceExpense(
      id: id,
      entityType: type,
      entityId: entityId,
      entityTitle: 'ملف $entityId',
      category: ExpenseCategory.courtFee,
      description: 'رسم',
      amount: amount,
      expenseDate: date ?? DateTime(2026, 1, 15),
    );
  }

  test('Client owes fees plus expenses spent on their files', () {
    final state = FinanceState(
      agreements: [agreement(id: 'a1', partyId: 'p1', entityId: '1', amount: 1000000)],
      payments: [payment(id: 'pay1', agreementId: 'a1', amount: 400000)],
      expenses: [expense(id: 'e1', entityId: '1', amount: 150000)],
    );

    final client = state.clientReceivables.single;
    expect(client.agreementsTotal, 1000000);
    expect(client.expensesTotal, 150000);
    expect(client.paymentsTotal, 400000);

    // الأتعاب غير المقبوضة فقط
    expect(client.remaining, 600000);
    // الحساب الكامل يشمل المصاريف
    expect(client.totalDue, 1150000);
    expect(client.accountBalance, 750000);
    expect(client.hasCredit, isFalse);
    expect(client.accountStatusLabel, 'ذمة قائمة');
  });

  test('Overpayment becomes a client credit (trust) instead of a negative debt', () {
    final state = FinanceState(
      agreements: [agreement(id: 'a1', partyId: 'p1', entityId: '1', amount: 500000)],
      payments: [payment(id: 'pay1', agreementId: 'a1', amount: 800000)],
      expenses: const [],
    );

    final client = state.clientReceivables.single;
    expect(client.accountBalance, -300000);
    expect(client.hasCredit, isTrue);
    expect(client.creditAmount, 300000);
    expect(client.accountStatusLabel, 'رصيد دائن (أمانة)');
  });

  test('Fully settled account reports as settled', () {
    final state = FinanceState(
      agreements: [agreement(id: 'a1', partyId: 'p1', entityId: '1', amount: 300000)],
      payments: [payment(id: 'pay1', agreementId: 'a1', amount: 350000)],
      expenses: [expense(id: 'e1', entityId: '1', amount: 50000)],
    );

    final client = state.clientReceivables.single;
    expect(client.accountBalance, 0);
    expect(client.hasCredit, isFalse);
    expect(client.accountStatusLabel, 'مسدّد');
  });

  test('Expenses on unrelated files are not charged to the client', () {
    final state = FinanceState(
      agreements: [agreement(id: 'a1', partyId: 'p1', entityId: '1', amount: 100000)],
      payments: const [],
      // مصروف على ملف لا يملك الموكل فيه اتفاق أتعاب
      expenses: [expense(id: 'e9', entityId: '99', amount: 500000)],
    );

    final client = state.clientReceivables.single;
    expect(client.expensesTotal, 0);
    expect(client.accountBalance, 100000);
  });

  test('Client statement lists movements in date order with running balance', () {
    final state = FinanceState(
      agreements: [
        agreement(id: 'a1', partyId: 'p1', entityId: '1', amount: 1000000, date: DateTime(2026, 1, 1)),
      ],
      payments: [
        payment(id: 'pay1', agreementId: 'a1', amount: 400000, date: DateTime(2026, 3, 1)),
      ],
      expenses: [
        expense(id: 'e1', entityId: '1', amount: 200000, date: DateTime(2026, 2, 1)),
      ],
    );

    final statement = state.clientStatement('p1');
    expect(statement.entries.length, 3);

    // الترتيب الزمني: اتفاق ثم مصروف ثم قبض
    expect(statement.entries[0].debit, 1000000);
    expect(statement.entries[1].debit, 200000);
    expect(statement.entries[2].credit, 400000);

    expect(statement.runningBalances, [1000000, 1200000, 800000]);
    expect(statement.totalDebit, 1200000);
    expect(statement.totalCredit, 400000);
    expect(statement.balance, 800000);
    expect(statement.hasCredit, isFalse);
  });

  test('Client statement reports a credit balance for overpaying clients', () {
    final state = FinanceState(
      agreements: [agreement(id: 'a1', partyId: 'p1', entityId: '1', amount: 200000)],
      payments: [payment(id: 'pay1', agreementId: 'a1', amount: 500000)],
      expenses: const [],
    );

    final statement = state.clientStatement('p1');
    expect(statement.balance, -300000);
    expect(statement.hasCredit, isTrue);
    expect(statement.creditAmount, 300000);
  });

  test('Client accounts report exposes balances and trust totals', () {
    final state = FinanceState(
      agreements: [
        agreement(id: 'a1', partyId: 'p1', entityId: '1', amount: 1000000, partyName: 'أحمد'),
        agreement(id: 'a2', partyId: 'p2', entityId: '2', amount: 200000, partyName: 'سمير'),
      ],
      payments: [
        payment(id: 'pay1', agreementId: 'a1', amount: 300000),
        payment(id: 'pay2', agreementId: 'a2', amount: 500000),
      ],
      expenses: const [],
    );

    final engine = SearchReportEngine(
      index: const [],
      sessions: const [],
      overdue: const [],
      deficient: const [],
      workOrders: const [],
      memos: const [],
      financeState: state,
    );

    final report = engine.generate(ReportKind.clientAccounts);
    expect(report.title, 'كشف حسابات الموكلين');
    expect(report.rowCount, 2);
    expect(report.summary.containsKey('أمانات الموكلين'), isTrue);
    // سمير دفع 500000 مقابل 200000 => أمانة 300000
    expect(report.summary['أمانات الموكلين'], contains('300'));
  });
}
