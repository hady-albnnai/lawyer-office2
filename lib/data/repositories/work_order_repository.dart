import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/daos/work_order_dao.dart';
import 'office_file_repository.dart';

class WorkOrderRepository {
  final WorkOrderDao _dao;
  WorkOrderRepository(this._dao);

  Stream<List<WorkOrder>> watchAll() => _dao.watchAll();
  Future<List<WorkOrder>> getAll() => _dao.getAll();
  Future<WorkOrder?> getById(int id) async {
    final all = await _dao.getAll();
    for (final w in all) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<String> nextInternalNumber() async {
    final year = DateTime.now().year;
    final all = await _dao.getAll();
    var maxSeq = 0;
    final prefix = 'WO-$year-';
    for (final w in all) {
      if (w.internalNumber.startsWith(prefix)) {
        final seq = int.tryParse(w.internalNumber.substring(prefix.length)) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
    return '$prefix${(maxSeq + 1).toString().padLeft(3, '0')}';
  }

  Future<int> create({
    String? internalNumber,
    required String assignedToName,
    String? assignedToPhone,
    required String orderType,
    required String priority,
    String status = 'draft',
    required DateTime dueDate,
    String? instructions,
    String? createdBy,
    int linkedEntityType = 0,
    int linkedEntityId = 0,
  }) async {
    final number = internalNumber ?? await nextInternalNumber();
    final id = await _dao.insertOrder(
      WorkOrdersCompanion.insert(
        internalNumber: number,
        assignedToName: assignedToName,
        assignedToPhone: Value(assignedToPhone),
        orderType: orderType,
        priority: Value(priority),
        status: Value(status),
        dueDate: dueDate,
        instructions: Value(instructions),
        createdBy: Value(createdBy),
        linkedEntityType: Value(linkedEntityType),
        linkedEntityId: Value(linkedEntityId),
        // ربط مباشر بملف المكتب (المرحلة السادسة من خارطة التنفيذ).
        officeFileId: Value(
          (await OfficeFileRepository(_dao.db).getByLinkedEntity(
            entityType: linkedEntityType,
            entityId: linkedEntityId,
          ))
              ?.id,
        ),
      ),
    );
    await _log('work_orders', id, 'insert', createdBy, 'إنشاء أمر عمل $number');
    await _refreshLinkedOfficeFileWorkFlag(linkedEntityType, linkedEntityId);
    return id;
  }

  Future<void> markPrinted(int id, {String? userRef}) async {
    final current = await getById(id);
    if (current == null) return;
    await _dao.updateOrder(
      WorkOrdersCompanion(
        id: Value(id),
        internalNumber: Value(current.internalNumber),
        linkedEntityType: Value(current.linkedEntityType),
        linkedEntityId: Value(current.linkedEntityId),
        assignedToName: Value(current.assignedToName),
        assignedToPhone: Value(current.assignedToPhone),
        orderType: Value(current.orderType),
        priority: Value(current.priority),
        status: const Value('printed'),
        dueDate: Value(current.dueDate),
        instructions: Value(current.instructions),
        createdBy: Value(current.createdBy),
        printedAt: Value(DateTime.now()),
        whatsappSentAt: Value(current.whatsappSentAt),
        resultStatus: Value(current.resultStatus),
        resultText: Value(current.resultText),
        resultDate: Value(current.resultDate),
        nextDate: Value(current.nextDate),
        approvedAt: Value(current.approvedAt),
        createdAt: Value(current.createdAt),
      ),
    );
    await _log('work_orders', id, 'update', userRef, 'طباعة أمر العمل');
  }

  Future<void> markWhatsAppSent(int id, {String? userRef}) async {
    final current = await getById(id);
    if (current == null) return;
    await _dao.updateOrder(
      WorkOrdersCompanion(
        id: Value(id),
        internalNumber: Value(current.internalNumber),
        linkedEntityType: Value(current.linkedEntityType),
        linkedEntityId: Value(current.linkedEntityId),
        assignedToName: Value(current.assignedToName),
        assignedToPhone: Value(current.assignedToPhone),
        orderType: Value(current.orderType),
        priority: Value(current.priority),
        status: const Value('waiting_for_result'),
        dueDate: Value(current.dueDate),
        instructions: Value(current.instructions),
        createdBy: Value(current.createdBy),
        printedAt: Value(current.printedAt ?? DateTime.now()),
        whatsappSentAt: Value(DateTime.now()),
        resultStatus: Value(current.resultStatus),
        resultText: Value(current.resultText),
        resultDate: Value(current.resultDate),
        nextDate: Value(current.nextDate),
        approvedAt: Value(current.approvedAt),
        createdAt: Value(current.createdAt),
      ),
    );
    await _log('work_orders', id, 'update', userRef, 'إرسال واتساب / بانتظار النتيجة');
  }

  Future<void> enterResult({
    required int id,
    required String resultStatus,
    required String resultText,
    DateTime? nextDate,
    String? userRef,
  }) async {
    final current = await getById(id);
    if (current == null) return;
    await _dao.updateOrder(
      WorkOrdersCompanion(
        id: Value(id),
        internalNumber: Value(current.internalNumber),
        linkedEntityType: Value(current.linkedEntityType),
        linkedEntityId: Value(current.linkedEntityId),
        assignedToName: Value(current.assignedToName),
        assignedToPhone: Value(current.assignedToPhone),
        orderType: Value(current.orderType),
        priority: Value(current.priority),
        status: const Value('result_entered'),
        dueDate: Value(current.dueDate),
        instructions: Value(current.instructions),
        createdBy: Value(current.createdBy),
        printedAt: Value(current.printedAt),
        whatsappSentAt: Value(current.whatsappSentAt),
        resultStatus: Value(resultStatus),
        resultText: Value(resultText),
        resultDate: Value(DateTime.now()),
        nextDate: Value(nextDate),
        approvedAt: Value(current.approvedAt),
        createdAt: Value(current.createdAt),
      ),
    );
    await _log('work_orders', id, 'update', userRef, 'إدخال نتيجة: $resultStatus');
  }

  Future<void> approve(int id, {String? userRef}) async {
    final current = await getById(id);
    if (current == null) return;
    await _dao.updateOrder(
      WorkOrdersCompanion(
        id: Value(id),
        internalNumber: Value(current.internalNumber),
        linkedEntityType: Value(current.linkedEntityType),
        linkedEntityId: Value(current.linkedEntityId),
        assignedToName: Value(current.assignedToName),
        assignedToPhone: Value(current.assignedToPhone),
        orderType: Value(current.orderType),
        priority: Value(current.priority),
        status: const Value('approved'),
        dueDate: Value(current.dueDate),
        instructions: Value(current.instructions),
        createdBy: Value(current.createdBy),
        printedAt: Value(current.printedAt),
        whatsappSentAt: Value(current.whatsappSentAt),
        resultStatus: Value(current.resultStatus),
        resultText: Value(current.resultText),
        resultDate: Value(current.resultDate),
        nextDate: Value(current.nextDate),
        approvedAt: Value(DateTime.now()),
        createdAt: Value(current.createdAt),
      ),
    );

    // أتمتة بعد الاعتماد: timeline + مهمة متابعة + مصروف اختياري من نص النتيجة
    final now = DateTime.now();
    await _dao.db.into(_dao.db.timelineEvents).insert(
          TimelineEventsCompanion.insert(
            entityType: current.linkedEntityType,
            entityId: current.linkedEntityId <= 0 ? 0 : current.linkedEntityId,
            eventType: 'work_order_approved',
            eventDate: Value(now),
            description:
                'اعتماد أمر ${current.internalNumber} (${current.orderType}) — النتيجة: ${current.resultStatus ?? '-'} / ${current.resultText ?? ''}',
            userRef: Value(userRef),
          ),
        );

    // مهمة متابعة إذا وُجد موعد لاحق
    if (current.nextDate != null) {
      await _dao.db.into(_dao.db.dailyTasks).insert(
            DailyTasksCompanion.insert(
              taskType: 'work_order_followup',
              title: 'متابعة أمر ${current.internalNumber}',
              taskDate: DateTime(current.nextDate!.year, current.nextDate!.month, current.nextDate!.day),
              status: const Value(0), // scheduled
              assignedTo: Value(current.assignedToName),
              priority: Value(current.priority == 'high' ? 2 : 1),
              sourceType: const Value('work_order'),
              sourceId: Value(id),
              isAutoGenerated: const Value(true),
              notes: Value('مولَّد تلقائياً بعد اعتماد أمر العمل. ${current.resultText ?? ''}'),
            ),
          );
    }

    // إن كانت النتيجة تشير إلى دفع/رسم أنشئ مصروفًا مرتبطًا بالكيان
    final resultBlob = '${current.resultText ?? ''} ${current.orderType}'.toLowerCase();
    final looksLikeExpense = current.orderType.contains('fee') ||
        resultBlob.contains('رسم') ||
        resultBlob.contains('دفع') ||
        resultBlob.contains('مصروف');
    if (looksLikeExpense && current.linkedEntityId > 0) {
      await _dao.db.into(_dao.db.expenses).insert(
            ExpensesCompanion.insert(
              entityType: current.linkedEntityType,
              entityId: current.linkedEntityId,
              expenseType: current.orderType == 'fee_payment' ? 'رسم محكمة' : 'مصاريف معقب',
              amount: 0, // يُعدّل لاحقاً من المالية إن لزم
              notes: Value('من أمر ${current.internalNumber}: ${current.resultText ?? ''}'),
            ),
          );
    }

    // أغلق أي نقص عام مرتبط بنفس الكيان إذا كانت النتيجة completed
    if ((current.resultStatus ?? '') == 'completed' && current.linkedEntityId > 0) {
      await (_dao.db.update(_dao.db.deficiencies)
            ..where((t) =>
                t.entityType.equals(current.linkedEntityType) &
                t.entityId.equals(current.linkedEntityId) &
                t.status.equals('open') &
                t.fieldName.isIn(['work_order_pending', 'followup_pending'])))
          .write(
        DeficienciesCompanion(
          status: const Value('resolved'),
          resolvedAt: Value(now),
        ),
      );
    }

    await _log('work_orders', id, 'update', userRef, 'اعتماد أمر العمل + أتمتة المتابعة');
    await _refreshLinkedOfficeFileWorkFlag(current.linkedEntityType, current.linkedEntityId);
  }

  Future<void> setStatus(int id, String status, {String? userRef}) async {
    final current = await getById(id);
    if (current == null) return;
    await _dao.updateOrder(
      WorkOrdersCompanion(
        id: Value(id),
        internalNumber: Value(current.internalNumber),
        linkedEntityType: Value(current.linkedEntityType),
        linkedEntityId: Value(current.linkedEntityId),
        assignedToName: Value(current.assignedToName),
        assignedToPhone: Value(current.assignedToPhone),
        orderType: Value(current.orderType),
        priority: Value(current.priority),
        status: Value(status),
        dueDate: Value(current.dueDate),
        instructions: Value(current.instructions),
        createdBy: Value(current.createdBy),
        printedAt: Value(current.printedAt),
        whatsappSentAt: Value(current.whatsappSentAt),
        resultStatus: Value(current.resultStatus),
        resultText: Value(current.resultText),
        resultDate: Value(current.resultDate),
        nextDate: Value(current.nextDate),
        approvedAt: Value(current.approvedAt),
        createdAt: Value(current.createdAt),
      ),
    );
    await _log('work_orders', id, 'update', userRef, 'تغيير الحالة إلى $status');
    await _refreshLinkedOfficeFileWorkFlag(current.linkedEntityType, current.linkedEntityId);
  }


  Future<void> _refreshLinkedOfficeFileWorkFlag(int entityType, int entityId) async {
    if (entityId <= 0) return;
    final rows = await _dao.db.customSelect(
      '''
      SELECT COUNT(*) AS c
      FROM work_orders
      WHERE linked_entity_type = ?
        AND linked_entity_id = ?
        AND status NOT IN ('approved', 'cancelled', 'impossible')
      ''',
      variables: [Variable.withInt(entityType), Variable.withInt(entityId)],
    ).get();
    final hasOpenWork = ((rows.first.data['c'] as int?) ?? 0) > 0;
    await OfficeFileRepository(_dao.db).updatePendingFlagsByLinkedEntity(
      entityType: entityType,
      entityId: entityId,
      hasPostClosureActions: hasOpenWork,
    );
  }

  Future<void> _log(String table, int id, String action, String? user, String details) async {
    await _dao.db.into(_dao.db.activityLog).insert(
          ActivityLogCompanion.insert(
            affectedTable: table,
            recordId: id,
            action: action,
            userRef: Value(user),
            details: Value(details),
          ),
        );
  }

  Future<void> seedDemoIfEmpty() async {
    final existing = await _dao.getAll();
    if (existing.isNotEmpty) return;
    final now = DateTime.now();
    final samples = [
      ('WO-${now.year}-001', 'أحمد محمد', '0912345678', 'court_attendance', 'high', 'draft', now, 'حضور جلسة الدعوى'),
      ('WO-${now.year}-002', 'محمد أحمد', '0987654321', 'document_photocopy', 'medium', 'printed', now.add(const Duration(days: 1)), 'تصوير ضبط المحكمة'),
      ('WO-${now.year}-003', 'أحمد محمد', '0912345678', 'fee_payment', 'high', 'waiting_for_result', now.subtract(const Duration(days: 1)), 'دفع رسم الدعوى'),
      ('WO-${now.year}-004', 'محمد أحمد', '0987654321', 'notary_review', 'low', 'result_entered', now.add(const Duration(days: 2)), 'مراجعة كاتب عدل'),
      ('WO-${now.year}-005', 'أحمد محمد', '0912345678', 'execution_followup', 'medium', 'waiting_for_approval', now.add(const Duration(days: 3)), 'متابعة تنفيذ'),
    ];
    for (final s in samples) {
      await create(
        internalNumber: s.$1,
        assignedToName: s.$2,
        assignedToPhone: s.$3,
        orderType: s.$4,
        priority: s.$5,
        status: s.$6,
        dueDate: s.$7,
        instructions: s.$8,
        createdBy: 'المكتب',
        linkedEntityType: 0,
        linkedEntityId: 1,
      );
    }
  }
}
