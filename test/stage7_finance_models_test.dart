import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/presentation/screens/finance/finance_models.dart';

void main() {
  test('FinanceNotifier calculates summary and accepts new movements', () {
    final notifier = FinanceNotifier();
    final initialSummary = notifier.state.summary;

    expect(initialSummary.agreementsTotal, greaterThan(0));
    expect(initialSummary.paymentsTotal, greaterThan(0));
    expect(initialSummary.expensesTotal, greaterThan(0));

    final agreement = FinanceAgreement(
      id: 'agreement_test',
      entityType: FinanceEntityType.caseFile,
      entityId: 'case_test',
      entityTitle: 'دعوى اختبار',
      partyId: 'person_test',
      partyName: 'موكل اختبار',
      agreementType: FeeAgreementType.fixed,
      totalAmount: 1000,
      agreementDate: DateTime(2026, 7, 10),
    );
    notifier.addAgreement(agreement);
    notifier.addPayment(
      FinancePayment(
        id: 'payment_test',
        agreementId: agreement.id,
        amount: 400,
        paymentDate: DateTime(2026, 7, 10),
        receiptNumber: 'R-2026-TEST',
      ),
    );
    notifier.addExpense(
      FinanceExpense(
        id: 'expense_test',
        entityType: FinanceEntityType.caseFile,
        entityId: 'case_test',
        entityTitle: 'دعوى اختبار',
        category: ExpenseCategory.courtFee,
        description: 'رسم اختبار',
        amount: 100,
        expenseDate: DateTime(2026, 7, 10),
      ),
    );

    expect(notifier.state.paidForAgreement(agreement.id), 400);
    expect(
      notifier.state.summary.agreementsTotal,
      initialSummary.agreementsTotal + 1000,
    );
    expect(
      notifier.state.summary.paymentsTotal,
      initialSummary.paymentsTotal + 400,
    );
    expect(
      notifier.state.summary.expensesTotal,
      initialSummary.expensesTotal + 100,
    );
  });

  test('Client receivables aggregate by party and track remaining balances', () {
    final notifier = FinanceNotifier();
    final clients = notifier.state.clientReceivables;

    expect(clients, isNotEmpty);

    final ahmad = clients.firstWhere((c) => c.partyId == 'person_1');
    expect(ahmad.partyName, 'أحمد محمد الخطيب');
    expect(ahmad.agreementsCount, greaterThanOrEqualTo(2));
    expect(ahmad.agreementsTotal, 5000000 + 800000);
    expect(ahmad.paymentsTotal, 1500000 + 300000);
    expect(ahmad.remaining, 5800000 - 1800000);
    expect(ahmad.isSettled, isFalse);

    final company = clients.firstWhere((c) => c.partyId == 'person_3');
    expect(company.remaining, greaterThanOrEqualTo(0));
  });

  test('Work order entity type and expediter expenses are supported', () {
    final notifier = FinanceNotifier();
    final workOrderAgreements = notifier.state.agreements
        .where((a) => a.entityType == FinanceEntityType.workOrder)
        .toList();
    final expediterExpenses = notifier.state.expenses
        .where(
          (e) =>
              e.category == ExpenseCategory.expediter ||
              e.entityType == FinanceEntityType.workOrder,
        )
        .toList();

    expect(workOrderAgreements, isNotEmpty);
    expect(expediterExpenses, isNotEmpty);
    expect(FinanceEntityType.workOrder.displayName, contains('أمر عمل'));
    expect(ExpenseCategory.expediter.displayName, contains('معقب'));
  });

  test('Payment receipt numbers are generated or preserved', () {
    final withNumber = FinancePayment(
      id: 'p1',
      agreementId: 'a1',
      amount: 100,
      paymentDate: DateTime(2026, 7, 10),
      receiptNumber: 'R-2026-0099',
    );
    final withoutNumber = FinancePayment(
      id: 'payment_xyz',
      agreementId: 'a1',
      amount: 100,
      paymentDate: DateTime(2026, 7, 10),
    );

    expect(withNumber.displayReceiptNumber, 'R-2026-0099');
    expect(withoutNumber.displayReceiptNumber, startsWith('R-2026-'));
  });

  test('Entity and payment filters work with search query', () {
    final notifier = FinanceNotifier();
    notifier.setEntityFilter(FinanceEntityType.caseFile);
    expect(
      notifier.state.filteredAgreements
          .every((a) => a.entityType == FinanceEntityType.caseFile),
      isTrue,
    );

    notifier.setSearchQuery('أحمد');
    expect(notifier.state.filteredAgreements, isNotEmpty);
    expect(
      notifier.state.filteredAgreements
          .every((a) => a.partyName.contains('أحمد')),
      isTrue,
    );

    notifier.setEntityFilter(null);
    notifier.setSearchQuery('');
    expect(notifier.state.entityFilter, isNull);
  });

  test('Entity summary returns scoped finance totals', () {
    final state = FinanceNotifier().state;
    final summary = state.entitySummary(FinanceEntityType.caseFile, '1');

    expect(summary.agreementsTotal, 5000000);
    expect(summary.paymentsTotal, 1500000);
    expect(summary.expensesTotal, 100000);
    expect(summary.remainingFees, 3500000);
  });
}
