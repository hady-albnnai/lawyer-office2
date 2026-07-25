import 'dart:io';
import 'package:drift/drift.dart';
import '../../core/enums/app_enums.dart';
import '../database/database.dart';
import '../database/daos/finance_dao.dart';
import '../services/file_storage_service.dart';
import 'office_file_repository.dart';

/// مستودع إدارة المالية الموحدة — مصدر الحقيقة: SQLite عبر Drift.
class FinanceRepository {
  final FinanceDao _financeDao;
  final FileStorageService _storageService;

  FinanceRepository(this._financeDao, this._storageService);

  Stream<List<FeeAgreement>> watchAllAgreements() => _financeDao.watchAllAgreements();
  Stream<List<FeePayment>> watchAllPayments() => _financeDao.watchAllPayments();
  Stream<List<Expense>> watchAllExpenses() => _financeDao.watchAllExpenses();

  Future<List<FeeAgreement>> getAllAgreements() => _financeDao.getAllAgreements();
  Future<List<FeePayment>> getAllPayments() => _financeDao.getAllPayments();
  Future<List<Expense>> getAllExpenses() => _financeDao.getAllExpenses();
  Future<List<PersonEntity>> getAllPersons() => _financeDao.getAllPersons();
  Future<PersonEntity?> getPersonById(int id) => _financeDao.getPersonById(id);

  Stream<List<FeeAgreement>> watchAgreementsByEntity(EntityType entityType, int entityId) {
    return _financeDao.watchAgreementsByEntity(entityType.index, entityId);
  }

  /// اتفاقيات الأتعاب المرتبطة بكيان محدد (دعوى/عقد/شركة/إجراء).
  Future<List<FeeAgreement>> getAgreementsByEntity(int entityType, int entityId) {
    return _financeDao.getAgreementsByEntity(entityType, entityId);
  }

  /// الدفعات المقبوضة على اتفاقيات كيان محدد.
  Future<List<FeePayment>> getPaymentsByEntity(int entityType, int entityId) async {
    final agreements = await _financeDao.getAgreementsByEntity(entityType, entityId);
    if (agreements.isEmpty) return const <FeePayment>[];
    return _financeDao.getPaymentsByAgreements(agreements.map((a) => a.id).toList());
  }

  /// مصاريف كيان محدد.
  Future<List<Expense>> getExpensesByEntity(int entityType, int entityId) {
    return _financeDao.getExpensesByEntity(entityType, entityId);
  }

  /// إنشاء اتفاقية أتعاب مع إمكانية إرفاق صورة العقد
  Future<int> createAgreement({
    required int entityType,
    required int entityId,
    required int partyId,
    required String agreementType,
    required double totalAmount,
    String currency = 'ل.س',
    String? notes,
    File? contractFile,
    required String userRef,
  }) async {
    return await _financeDao.db.transaction(() async {
      final agreementId = await _financeDao.insertAgreement(
        FeeAgreementsCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          partyId: partyId,
          agreementType: Value(agreementType),
          totalAmount: Value(totalAmount),
          currency: Value(currency),
          notes: Value(notes),
        ),
      );

      if (contractFile != null) {
        final filePath = await _storageService.saveAttachment(
          sourceFile: contractFile,
          folderType: 'fee_agreements',
          entityId: agreementId,
        );
        await (_financeDao.update(_financeDao.feeAgreements)
              ..where((t) => t.id.equals(agreementId)))
            .write(FeeAgreementsCompanion(contractPath: Value(filePath)));
      }

      await _financeDao.into(_financeDao.db.timelineEvents).insert(
            TimelineEventsCompanion.insert(
              entityType: entityType,
              entityId: entityId,
              eventType: 'fee_agreement_created',
              eventDate: Value(DateTime.now()),
              description: 'إنشاء اتفاق أتعاب بمبلغ $totalAmount $currency',
              userRef: Value(userRef),
            ),
          );

      await _financeDao.into(_financeDao.db.activityLog).insert(
            ActivityLogCompanion.insert(
              affectedTable: 'fee_agreements',
              recordId: agreementId,
              action: 'insert',
              userRef: Value(userRef),
              details: Value('اتفاق أتعاب $totalAmount $currency'),
            ),
          );

      await OfficeFileRepository(_financeDao.db).updatePendingFlagsByLinkedEntity(entityType: entityType, entityId: entityId, hasPendingFinance: true);
      return agreementId;
    });
  }

  Stream<List<FeePayment>> watchPaymentsByAgreement(int agreementId) {
    return _financeDao.watchPaymentsByAgreement(agreementId);
  }

  /// تسجيل سند قبض
  Future<int> addPayment({
    required int agreementId,
    required double amount,
    required String method,
    String? notes,
    File? receiptFile,
    required String userRef,
    required int entityType,
    required int entityId,
  }) async {
    return await _financeDao.db.transaction(() async {
      final paymentId = await _financeDao.insertPayment(
        FeePaymentsCompanion.insert(
          agreementId: agreementId,
          amount: amount,
          method: Value(method),
          notes: Value(notes),
        ),
      );

      if (receiptFile != null) {
        final filePath = await _storageService.saveAttachment(
          sourceFile: receiptFile,
          folderType: 'fee_payments',
          entityId: paymentId,
        );
        await (_financeDao.update(_financeDao.feePayments)..where((t) => t.id.equals(paymentId)))
            .write(FeePaymentsCompanion(receiptPath: Value(filePath)));
      }

      await _financeDao.into(_financeDao.db.timelineEvents).insert(
            TimelineEventsCompanion.insert(
              entityType: entityType,
              entityId: entityId,
              eventType: 'payment_received',
              eventDate: Value(DateTime.now()),
              description: 'قبض دفعة أتعاب: $amount ($method)',
              userRef: Value(userRef),
            ),
          );

      await _financeDao.into(_financeDao.db.activityLog).insert(
            ActivityLogCompanion.insert(
              affectedTable: 'fee_payments',
              recordId: paymentId,
              action: 'insert',
              userRef: Value(userRef),
              details: Value('سند قبض $amount'),
            ),
          );

      await OfficeFileRepository(_financeDao.db).updatePendingFlagsByLinkedEntity(entityType: entityType, entityId: entityId, hasPendingFinance: true);
      return paymentId;
    });
  }

  Stream<List<Expense>> watchExpensesByEntity(EntityType entityType, int entityId) {
    return _financeDao.watchExpensesByEntity(entityType.index, entityId);
  }

  /// إدراج مصروف
  Future<int> addExpense({
    required int entityType,
    required int entityId,
    required String expenseType,
    required double amount,
    String? notes,
    File? receiptFile,
    required String userRef,
  }) async {
    return await _financeDao.db.transaction(() async {
      final expenseId = await _financeDao.insertExpense(
        ExpensesCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          expenseType: expenseType,
          amount: amount,
          notes: Value(notes),
        ),
      );

      if (receiptFile != null) {
        final filePath = await _storageService.saveAttachment(
          sourceFile: receiptFile,
          folderType: 'expenses',
          entityId: expenseId,
        );
        await (_financeDao.update(_financeDao.expenses)..where((t) => t.id.equals(expenseId)))
            .write(ExpensesCompanion(receiptPath: Value(filePath)));
      }

      await _financeDao.into(_financeDao.db.timelineEvents).insert(
            TimelineEventsCompanion.insert(
              entityType: entityType,
              entityId: entityId,
              eventType: 'expense_added',
              eventDate: Value(DateTime.now()),
              description: 'صرف [$amount] عن: $expenseType',
              userRef: Value(userRef),
            ),
          );

      await _financeDao.into(_financeDao.db.activityLog).insert(
            ActivityLogCompanion.insert(
              affectedTable: 'expenses',
              recordId: expenseId,
              action: 'insert',
              userRef: Value(userRef),
              details: Value('مصروف $expenseType = $amount'),
            ),
          );

      await OfficeFileRepository(_financeDao.db).updatePendingFlagsByLinkedEntity(entityType: entityType, entityId: entityId, hasPendingFinance: true);
      return expenseId;
    });
  }

  /// بذر بيانات مالية تجريبية عند كون الجداول فارغة (أول تشغيل فقط).
  Future<void> seedDemoIfEmpty() async {
    final existing = await _financeDao.getAllAgreements();
    if (existing.isNotEmpty) return;

    // تأكد من وجود أشخاص
    var persons = await _financeDao.getAllPersons();
    if (persons.isEmpty) {
      final p1 = await _financeDao.into(_financeDao.persons).insert(
            PersonsCompanion.insert(fullName: 'أحمد محمد الخطيب', phone1: const Value('0933000001')),
          );
      final p2 = await _financeDao.into(_financeDao.persons).insert(
            PersonsCompanion.insert(
              fullName: 'شركة التطوير الحديث',
              type: const Value(1),
              phone1: const Value('0111234567'),
            ),
          );
      persons = await _financeDao.getAllPersons();
      assert(persons.any((p) => p.id == p1) && persons.any((p) => p.id == p2));
    }

    final client = persons.first;
    final company = persons.length > 1 ? persons[1] : persons.first;

    final a1 = await createAgreement(
      entityType: EntityType.caseEntity.index,
      entityId: 1,
      partyId: client.id,
      agreementType: 'fixed',
      totalAmount: 5000000,
      notes: 'أتعاب مقطوعة على دفعتين',
      userRef: 'النظام',
    );
    final a2 = await createAgreement(
      entityType: EntityType.caseEntity.index,
      entityId: 3,
      partyId: company.id,
      agreementType: 'fixed',
      totalAmount: 2500000,
      userRef: 'النظام',
    );
    final a3 = await createAgreement(
      entityType: EntityType.contract.index,
      entityId: 1,
      partyId: client.id,
      agreementType: 'fixed',
      totalAmount: 800000,
      userRef: 'النظام',
    );

    await addPayment(
      agreementId: a1,
      amount: 1500000,
      method: 'نقداً',
      userRef: 'النظام',
      entityType: EntityType.caseEntity.index,
      entityId: 1,
    );
    await addPayment(
      agreementId: a2,
      amount: 2500000,
      method: 'تحويل بنكي',
      userRef: 'النظام',
      entityType: EntityType.caseEntity.index,
      entityId: 3,
    );
    await addPayment(
      agreementId: a3,
      amount: 300000,
      method: 'نقداً',
      userRef: 'النظام',
      entityType: EntityType.contract.index,
      entityId: 1,
    );

    await addExpense(
      entityType: EntityType.caseEntity.index,
      entityId: 1,
      expenseType: 'رسم محكمة',
      amount: 100000,
      userRef: 'النظام',
    );
    await addExpense(
      entityType: EntityType.caseEntity.index,
      entityId: 3,
      expenseType: 'مصاريف معقب',
      amount: 25000,
      notes: 'تصوير ضبط',
      userRef: 'النظام',
    );
    await addExpense(
      entityType: EntityType.contract.index,
      entityId: 1,
      expenseType: 'طوابع',
      amount: 45000,
      userRef: 'النظام',
    );
  }
}
