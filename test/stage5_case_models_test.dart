import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/presentation/screens/cases/case_models.dart';

void main() {
  test('Case model calculates fees, expenses, balance, and deficiencies', () {
    final caseItem = Case(
      id: 'test-case',
      caseNumber: '2026/TST',
      title: 'اختبار نموذج دعوى',
      type: CaseType.civil,
      court: 'محكمة الاختبار',
      creationDate: DateTime(2026, 7, 10),
      fees: [
        CaseFee(id: 'fee-1', clientId: 'client-1', amount: 1000, agreementDate: DateTime(2026, 7, 10)),
        CaseFee(id: 'fee-2', clientId: 'client-1', amount: 500, agreementDate: DateTime(2026, 7, 10)),
      ],
      expenses: [
        CaseExpense(id: 'expense-1', description: 'رسم', amount: 250, expenseDate: DateTime(2026, 7, 10)),
      ],
      deficiencies: [
        CaseDeficiency(id: 'def-1', field: 'poa', description: 'نقص وكالة', createdAt: DateTime(2026, 7, 10)),
        CaseDeficiency(id: 'def-2', field: 'base', description: 'رقم أساس', createdAt: DateTime(2026, 7, 10), isResolved: true),
      ],
      sessions: [
        CaseSession(
          id: 'session-1',
          sessionDate: DateTime.now().add(const Duration(days: 2)),
          sessionTime: const TimeOfDay(hour: 9, minute: 0),
          type: SessionType.ordinary,
          court: 'محكمة الاختبار',
        ),
      ],
    );

    expect(caseItem.totalFees, 1500);
    expect(caseItem.totalExpenses, 250);
    expect(caseItem.balance, 1250);
    expect(caseItem.openDeficienciesCount, 1);
    expect(caseItem.nextSession, isNotNull);
  });
}
