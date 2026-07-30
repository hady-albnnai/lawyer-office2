import 'package:drift/drift.dart';

import '../../core/enums/app_enums.dart';
import '../database/database.dart';

/// سجل ملف المكتب الموحد.
class OfficeFileRecord {
  final int id;
  final String fileNumber;
  final OfficeFileType fileType;
  final int fileYear;
  final int serial;
  final OfficeFileSource source;
  final OfficeFileStatus status;
  final int? linkedEntityType;
  final int? linkedEntityId;
  final String? title;
  final DateTime openedAt;
  final int? openedByUserId;
  final String? openedByNameSnapshot;
  final DateTime? closedAt;
  final int? closedByUserId;
  final String? closedByNameSnapshot;
  final String? closureReason;
  final String? closureSummary;
  final bool hasPendingFinance;
  final bool hasPendingPaperOriginal;
  final bool hasPostClosureActions;
  final int? handoverDocumentId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OfficeFileRecord({
    required this.id,
    required this.fileNumber,
    required this.fileType,
    required this.fileYear,
    required this.serial,
    required this.source,
    required this.status,
    this.linkedEntityType,
    this.linkedEntityId,
    this.title,
    required this.openedAt,
    this.openedByUserId,
    this.openedByNameSnapshot,
    this.closedAt,
    this.closedByUserId,
    this.closedByNameSnapshot,
    this.closureReason,
    this.closureSummary,
    required this.hasPendingFinance,
    required this.hasPendingPaperOriginal,
    required this.hasPostClosureActions,
    this.handoverDocumentId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime _readDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _readNullableDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory OfficeFileRecord.fromData(Map<String, Object?> data) {
    return OfficeFileRecord(
      id: data['id'] as int,
      fileNumber: data['file_number'] as String,
      fileType: OfficeFileType.fromDb(data['file_type'] as String),
      fileYear: data['file_year'] as int,
      serial: data['serial'] as int,
      source: OfficeFileSource.fromDb(data['source'] as String),
      status: OfficeFileStatus.fromDb(data['status'] as String),
      linkedEntityType: data['linked_entity_type'] as int?,
      linkedEntityId: data['linked_entity_id'] as int?,
      title: data['title'] as String?,
      openedAt: _readDate(data['opened_at']),
      openedByUserId: data['opened_by_user_id'] as int?,
      openedByNameSnapshot: data['opened_by_name_snapshot'] as String?,
      closedAt: _readNullableDate(data['closed_at']),
      closedByUserId: data['closed_by_user_id'] as int?,
      closedByNameSnapshot: data['closed_by_name_snapshot'] as String?,
      closureReason: data['closure_reason'] as String?,
      closureSummary: data['closure_summary'] as String?,
      hasPendingFinance: (data['has_pending_finance'] as int? ?? 0) == 1,
      hasPendingPaperOriginal: (data['has_pending_paper_original'] as int? ?? 0) == 1,
      hasPostClosureActions: (data['has_post_closure_actions'] as int? ?? 0) == 1,
      handoverDocumentId: data['handover_document_id'] as int?,
      notes: data['notes'] as String?,
      createdAt: _readDate(data['created_at']),
      updatedAt: _readDate(data['updated_at']),
    );
  }

}

/// مستودع ملف المكتب الموحد وترقيمه.
class OfficeFileRepository {
  final AppDatabase _db;

  OfficeFileRepository(this._db);

  Future<String> previewPrefix(OfficeFileType type, {int? year}) async {
    final targetYear = year ?? DateTime.now().year;
    return '${type.label}/$targetYear/0001';
  }

  Future<OfficeFileRecord?> getById(int id) async {
    await _db.ensureOfficeFileTables();
    final rows = await _db.customSelect(
      'SELECT * FROM office_files WHERE id = ? LIMIT 1',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return OfficeFileRecord.fromData(rows.first.data);
  }

  Future<OfficeFileRecord?> getByLinkedEntity({required int entityType, required int entityId}) async {
    await _db.ensureOfficeFileTables();
    final rows = await _db.customSelect(
      '''SELECT * FROM office_files
      WHERE linked_entity_type = ? AND linked_entity_id = ?
      ORDER BY id DESC
      LIMIT 1''',
      variables: [Variable.withInt(entityType), Variable.withInt(entityId)],
    ).get();
    if (rows.isEmpty) return null;
    return OfficeFileRecord.fromData(rows.first.data);
  }

  Future<List<OfficeFileRecord>> getAll({OfficeFileStatus? status, OfficeFileType? type}) async {
    await _db.ensureOfficeFileTables();
    final conditions = <String>[];
    final variables = <Variable>[];
    if (status != null) {
      conditions.add('status = ?');
      variables.add(Variable.withString(status.dbValue));
    }
    if (type != null) {
      conditions.add('file_type = ?');
      variables.add(Variable.withString(type.dbValue));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await _db.customSelect(
      'SELECT * FROM office_files $where ORDER BY opened_at DESC, id DESC',
      variables: variables,
    ).get();
    return rows.map((row) => OfficeFileRecord.fromData(row.data)).toList();
  }

  /// معاينة الرقم التالي دون استهلاكه من العدّاد.
  ///
  /// للعرض في الواجهات فقط. الرقم النهائي يُحجَز داخل معاملة
  /// createOfficeFile لضمان عدم التكرار عند الحفظ المتزامن، لذا قد
  /// يختلف الرقم المعروض إن أُنشئ ملف آخر قبل الحفظ.
  Future<String> peekNextFileNumber(OfficeFileType fileType, [int? targetYear]) async {
    await _db.ensureOfficeFileTables();
    final year = targetYear ?? DateTime.now().year;
    final rows = await _db.customSelect(
      '''SELECT last_number FROM office_file_sequences
      WHERE year = ? AND file_type = ? LIMIT 1''',
      variables: [Variable.withInt(year), Variable.withString(fileType.dbValue)],
    ).get();
    final next = rows.isEmpty ? 1 : ((rows.first.data['last_number'] as int) + 1);
    return '${fileType.label}/$year/${next.toString().padLeft(4, '0')}';
  }

  Future<OfficeFileRecord> createOfficeFile({
    required OfficeFileType fileType,
    OfficeFileSource source = OfficeFileSource.newWork,
    OfficeFileStatus status = OfficeFileStatus.active,
    int? linkedEntityType,
    int? linkedEntityId,
    String? title,
    int? openedByUserId,
    String? openedByNameSnapshot,
    String? notes,
    int? targetYear,
  }) async {
    await _db.ensureOfficeFileTables();
    final year = targetYear ?? DateTime.now().year;

    final id = await _db.transaction<int>(() async {
      final currentRows = await _db.customSelect(
        '''SELECT last_number FROM office_file_sequences
        WHERE year = ? AND file_type = ? LIMIT 1''',
        variables: [Variable.withInt(year), Variable.withString(fileType.dbValue)],
      ).get();

      final nextSerial = currentRows.isEmpty ? 1 : ((currentRows.first.data['last_number'] as int) + 1);

      if (currentRows.isEmpty) {
        await _db.customStatement(
          '''INSERT INTO office_file_sequences(year, file_type, prefix, last_number, updated_at)
          VALUES(?, ?, ?, ?, CURRENT_TIMESTAMP)''',
          [year, fileType.dbValue, fileType.label, nextSerial],
        );
      } else {
        await _db.customStatement(
          '''UPDATE office_file_sequences
          SET last_number = ?, prefix = ?, updated_at = CURRENT_TIMESTAMP
          WHERE year = ? AND file_type = ?''',
          [nextSerial, fileType.label, year, fileType.dbValue],
        );
      }

      // Try to insert the office file, handle UNIQUE constraint conflicts
      final fileNumber = '${fileType.label}/$year/${nextSerial.toString().padLeft(4, '0')}';
      
      try {
        await _db.customStatement(
          '''INSERT INTO office_files (
            file_number, file_type, file_year, serial, source, status,
            linked_entity_type, linked_entity_id, title,
            opened_at, opened_by_user_id, opened_by_name_snapshot,
            has_pending_finance, has_pending_paper_original, has_post_closure_actions,
            created_at, updated_at
          ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, ?, 0, 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          )''',
          [
            fileNumber,
            fileType.dbValue,
            year,
            nextSerial,
            source.dbValue,
            status.dbValue,
            linkedEntityType,
            linkedEntityId,
            title,
            openedByUserId,
            openedByNameSnapshot,
          ],
        );
      } catch (e) {
        // Handle UNIQUE constraint conflict
        // Try to find the next available serial number
        final existingRows = await _db.customSelect(
          '''SELECT MAX(serial) as max_serial FROM office_files
          WHERE file_type = ? AND file_year = ?''',
          variables: [Variable.withString(fileType.dbValue), Variable.withInt(year)],
        ).get();
        
        final existingMaxSerial = existingRows.isNotEmpty 
            ? (existingRows.first.data['max_serial'] as int? ?? 0)
            : 0;
        final newSerial = existingMaxSerial + 1;
        final newFileNumber = '${fileType.label}/$year/${newSerial.toString().padLeft(4, '0')}';
        
        // Update the sequence table
        await _db.customStatement(
          '''UPDATE office_file_sequences
          SET last_number = ?, updated_at = CURRENT_TIMESTAMP
          WHERE year = ? AND file_type = ?''',
          [newSerial, year, fileType.dbValue],
        );
        
        // Try the insert again with the new serial
        await _db.customStatement(
          '''INSERT INTO office_files (
            file_number, file_type, file_year, serial, source, status,
            linked_entity_type, linked_entity_id, title,
            opened_at, opened_by_user_id, opened_by_name_snapshot,
            has_pending_finance, has_pending_paper_original, has_post_closure_actions,
            created_at, updated_at
          ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, ?, 0, 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          )''',
          [
            newFileNumber,
            fileType.dbValue,
            year,
            newSerial,
            source.dbValue,
            status.dbValue,
            linkedEntityType,
            linkedEntityId,
            title,
            openedByUserId,
            openedByNameSnapshot,
          ],
        );
      }

      final row = await _db.customSelect('SELECT last_insert_rowid() AS id').getSingle();
      return row.data['id'] as int;
    });

    final created = await getById(id);
    if (created == null) {
      throw StateError('تعذر قراءة ملف المكتب بعد إنشائه');
    }
    return created;
  }

  Future<void> linkOfficeFile({required int officeFileId, required int entityType, required int entityId}) async {
    await _db.ensureOfficeFileTables();
    await _db.customStatement(
      '''UPDATE office_files
      SET linked_entity_type = ?, linked_entity_id = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?''',
      [entityType, entityId, officeFileId],
    );
  }


  Future<void> updatePendingFlagsByLinkedEntity({
    required int entityType,
    required int entityId,
    bool? hasPendingFinance,
    bool? hasPendingPaperOriginal,
    bool? hasPostClosureActions,
  }) async {
    await _db.ensureOfficeFileTables();
    final assignments = <String>[];
    final values = <Object?>[];
    if (hasPendingFinance != null) {
      assignments.add('has_pending_finance = ?');
      values.add(hasPendingFinance ? 1 : 0);
    }
    if (hasPendingPaperOriginal != null) {
      assignments.add('has_pending_paper_original = ?');
      values.add(hasPendingPaperOriginal ? 1 : 0);
    }
    if (hasPostClosureActions != null) {
      assignments.add('has_post_closure_actions = ?');
      values.add(hasPostClosureActions ? 1 : 0);
    }
    if (assignments.isEmpty) return;
    assignments.add('updated_at = CURRENT_TIMESTAMP');
    values.add(entityType);
    values.add(entityId);
    await _db.customStatement(
      'UPDATE office_files SET ${assignments.join(', ')} WHERE linked_entity_type = ? AND linked_entity_id = ?',
      values,
    );
  }

  Future<void> closeOfficeFile({
    required int officeFileId,
    required String reason,
    required String summary,
    int? closedByUserId,
    String? closedByNameSnapshot,
    bool hasPendingFinance = false,
    bool hasPendingPaperOriginal = false,
    bool hasPostClosureActions = false,
    int? handoverDocumentId,
  }) async {
    await _db.ensureOfficeFileTables();
    await _db.customStatement(
      '''UPDATE office_files
      SET status = 'closed',
          closed_at = CURRENT_TIMESTAMP,
          closed_by_user_id = ?,
          closed_by_name_snapshot = ?,
          closure_reason = ?,
          closure_summary = ?,
          has_pending_finance = ?,
          has_pending_paper_original = ?,
          has_post_closure_actions = ?,
          handover_document_id = ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ?''',
      [
        closedByUserId,
        closedByNameSnapshot,
        reason,
        summary,
        hasPendingFinance ? 1 : 0,
        hasPendingPaperOriginal ? 1 : 0,
        hasPostClosureActions ? 1 : 0,
        handoverDocumentId,
        officeFileId,
      ],
    );
  }

  Future<void> reopenOfficeFile({
    required int officeFileId,
    required String reason,
    String? reopenedByNameSnapshot,
  }) async {
    await _db.ensureOfficeFileTables();
    await _db.customStatement(
      '''UPDATE office_files
      SET status = 'active',
          closed_at = NULL,
          closed_by_user_id = NULL,
          closed_by_name_snapshot = NULL,
          closure_reason = NULL,
          closure_summary = NULL,
          has_post_closure_actions = 0,
          notes = COALESCE(notes || char(10), '') || ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ?''',
      ['إعادة فتح: $reason${reopenedByNameSnapshot == null ? '' : ' — بواسطة $reopenedByNameSnapshot'}', officeFileId],
    );
  }

  /// تعديل حالة ملف المكتب المرتبط بكيان دون تسجيل إغلاق إداري كامل.
  /// تُستخدم لمزامنة الأرشيف القديم: جارٍ => active، منتهٍ => closed.
  Future<void> setStatusByLinkedEntity({
    required int entityType,
    required int entityId,
    required OfficeFileStatus status,
    String? reason,
  }) async {
    await _db.ensureOfficeFileTables();
    if (status == OfficeFileStatus.closed) {
      await _db.customStatement(
        '''UPDATE office_files
        SET status = 'closed',
            closed_at = COALESCE(closed_at, CURRENT_TIMESTAMP),
            closure_reason = COALESCE(closure_reason, ?),
            updated_at = CURRENT_TIMESTAMP
        WHERE linked_entity_type = ? AND linked_entity_id = ? AND status <> 'closed' ''',
        [reason ?? 'أرشيف قديم منتهٍ', entityType, entityId],
      );
    } else {
      await _db.customStatement(
        '''UPDATE office_files
        SET status = 'active',
            closed_at = NULL,
            updated_at = CURRENT_TIMESTAMP
        WHERE linked_entity_type = ? AND linked_entity_id = ? AND status <> 'active' ''',
        [entityType, entityId],
      );
    }
  }

  /// إنشاء ملف مكتب من الأرشيف القديم (مصدر old_archive)
  Future<OfficeFileRecord> createFromOldArchive({
    required OfficeFileType fileType,
    required int linkedEntityType,
    required int linkedEntityId,
    required String title,
    OfficeFileStatus status = OfficeFileStatus.active,
    int? targetYear,
    String? notes,
  }) async {
    return createOfficeFile(
      fileType: fileType,
      source: OfficeFileSource.oldArchive,
      status: status,
      linkedEntityType: linkedEntityType,
      linkedEntityId: linkedEntityId,
      title: title,
      notes: notes,
      targetYear: targetYear,
    );
  }

  /// ضمان وجود ملف مكتب لكيان قائم أُنشئ قبل اعتماد OfficeFiles.
  ///
  /// تُستخدم لسدّ الفجوة التاريخية: الكيانات التي أُنشئت قبل تفعيل نظام
  /// ملفات المكتب ليس لها سجل في `office_files`، فتبقى شاشة الملفات معتمدة
  /// على الكيانات بدل أن تكون OfficeFiles مصدر الحقيقة.
  Future<OfficeFileRecord?> ensureOfficeFileForEntity({
    required OfficeFileType fileType,
    required int entityType,
    required int entityId,
    required String title,
    required OfficeFileStatus status,
    int? targetYear,
    String? fallbackNumber,
  }) async {
    if (entityId <= 0) return null;
    final existing = await getByLinkedEntity(entityType: entityType, entityId: entityId);
    if (existing != null) return existing;
    return createOfficeFile(
      fileType: fileType,
      source: OfficeFileSource.manualAdmin,
      status: status,
      linkedEntityType: entityType,
      linkedEntityId: entityId,
      title: title,
      targetYear: targetYear,
      notes: fallbackNumber == null || fallbackNumber.isEmpty
          ? 'ملف مكتب مُستكمل لكيان قائم'
          : 'ملف مكتب مُستكمل لكيان قائم (الرقم السابق: $fallbackNumber)',
    );
  }

  /// ضمان وجود ملف مكتب واحد فقط للكيان القادم من الأرشيف القديم.
  /// إن وُجد ملف مسبقاً تتم فقط مزامنة حالته (جارٍ/منتهٍ) دون إنشاء رقم جديد.
  Future<OfficeFileRecord> ensureOldArchiveOfficeFile({
    required OfficeFileType fileType,
    required int linkedEntityType,
    required int linkedEntityId,
    required String title,
    OfficeFileStatus status = OfficeFileStatus.active,
    int? targetYear,
    String? notes,
  }) async {
    final existing = await getByLinkedEntity(entityType: linkedEntityType, entityId: linkedEntityId);
    if (existing != null) {
      if (existing.status != status) {
        await setStatusByLinkedEntity(
          entityType: linkedEntityType,
          entityId: linkedEntityId,
          status: status,
          reason: 'مزامنة حالة أرشيف قديم',
        );
      }
      return (await getById(existing.id)) ?? existing;
    }
    return createFromOldArchive(
      fileType: fileType,
      linkedEntityType: linkedEntityType,
      linkedEntityId: linkedEntityId,
      title: title,
      status: status,
      targetYear: targetYear,
      notes: notes,
    );
  }

}