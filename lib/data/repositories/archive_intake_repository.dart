import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/enums/app_enums.dart';
import '../database/database.dart';
import '../services/file_storage_service.dart';
import 'office_file_repository.dart';

class ArchiveBatchRecord {
  final int id;
  final String name;
  final String sourceType;
  final String status;
  final String? sourcePath;
  final String? createdBy;
  final DateTime createdAt;
  final int totalFiles;
  final int processedFiles;
  final int failedFiles;
  final int duplicateFiles;
  final int unclassifiedFiles;
  final int approvedFiles;
  final String? notes;

  const ArchiveBatchRecord({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.status,
    this.sourcePath,
    this.createdBy,
    required this.createdAt,
    required this.totalFiles,
    required this.processedFiles,
    required this.failedFiles,
    required this.duplicateFiles,
    required this.unclassifiedFiles,
    required this.approvedFiles,
    this.notes,
  });
}



class ArchiveItemRecord {
  final int id;
  final int batchId;
  final String originalFileName;
  final String? sourcePath;
  final String? storedPath;
  final String? fileType;
  final int fileSize;
  final String? sha256;
  final String status;
  final String reviewStatus;
  final String? errorMessage;
  final String? suggestedDocumentType;
  final int? suggestedEntityType;
  final int? suggestedEntityId;
  final String? confirmedDocumentType;
  final int? confirmedEntityType;
  final int? confirmedEntityId;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final DateTime createdAt;

  const ArchiveItemRecord({
    required this.id,
    required this.batchId,
    required this.originalFileName,
    this.sourcePath,
    this.storedPath,
    this.fileType,
    required this.fileSize,
    this.sha256,
    required this.status,
    required this.reviewStatus,
    this.errorMessage,
    this.suggestedDocumentType,
    this.suggestedEntityType,
    this.suggestedEntityId,
    this.confirmedDocumentType,
    this.confirmedEntityType,
    this.confirmedEntityId,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    required this.createdAt,
  });
}

class ArchiveReferenceValueRecord {
  final int id;
  final String category;
  final String value;
  final String? parentValue;
  final bool isActive;

  const ArchiveReferenceValueRecord({
    required this.id,
    required this.category,
    required this.value,
    this.parentValue,
    required this.isActive,
  });
}

class AgencyDelegateRecord {
  final int id;
  final String fullName;
  final String phone;
  final String barBranch;
  final String notes;
  final bool isActive;

  const AgencyDelegateRecord({
    required this.id,
    required this.fullName,
    this.phone = '',
    this.barBranch = '',
    this.notes = '',
    this.isActive = true,
  });
}

class ArchiveImportSummary {
  final int imported;
  final int duplicates;
  final int failed;

  const ArchiveImportSummary({
    required this.imported,
    required this.duplicates,
    required this.failed,
  });
}

class ArchiveCsvPreview {
  final String fileName;
  final String delimiter;
  final List<String> headers;
  final int rowCount;
  final List<Map<String, String>> sampleRows;
  final List<String> warnings;

  const ArchiveCsvPreview({
    required this.fileName,
    required this.delimiter,
    required this.headers,
    required this.rowCount,
    required this.sampleRows,
    this.warnings = const [],
  });
}

class ArchiveIntakeRepository {
  final AppDatabase _db;
  final FileStorageService _storage;

  ArchiveIntakeRepository(this._db, this._storage);

  Future<void> ensureReady() => _db.ensureArchiveTables();

  Future<List<AgencyDelegateRecord>> getAgencyDelegates({bool includeInactive = true, String? query}) async {
    await ensureReady();
    final rows = await _db.customSelect(
      includeInactive
          ? 'SELECT * FROM agency_delegates ORDER BY is_active DESC, full_name COLLATE NOCASE'
          : 'SELECT * FROM agency_delegates WHERE is_active = 1 ORDER BY full_name COLLATE NOCASE',
    ).get();
    final normalizedQuery = (query ?? '').trim().toLowerCase();
    final mapped = rows.map((row) {
      final d = row.data;
      return AgencyDelegateRecord(
        id: d['id'] as int,
        fullName: d['full_name'] as String,
        phone: d['phone'] as String? ?? '',
        barBranch: d['bar_branch'] as String? ?? '',
        notes: d['notes'] as String? ?? '',
        isActive: ((d['is_active'] as int?) ?? 1) == 1,
      );
    }).toList();
    if (normalizedQuery.isEmpty) return mapped;
    return mapped.where((d) =>
      d.fullName.toLowerCase().contains(normalizedQuery) ||
      d.phone.toLowerCase().contains(normalizedQuery) ||
      d.barBranch.toLowerCase().contains(normalizedQuery) ||
      d.notes.toLowerCase().contains(normalizedQuery)
    ).toList();
  }

  Future<int> upsertAgencyDelegate({int? id, required String fullName, String? phone, String? barBranch, String? notes, bool isActive = true}) async {
    await ensureReady();
    final cleanName = fullName.trim();
    if (cleanName.isEmpty) throw StateError('اسم مندوب الوكالات إلزامي');
    if (id == null) {
      await _db.customStatement('''
        INSERT INTO agency_delegates(full_name, phone, bar_branch, notes, is_active)
        VALUES(?, ?, ?, ?, ?)
      ''', [cleanName, phone?.trim(), barBranch?.trim(), notes?.trim(), isActive ? 1 : 0]);
      final row = (await _db.customSelect('SELECT last_insert_rowid() AS id').get()).first;
      return row.data['id'] as int;
    }
    await _db.customStatement('''
      UPDATE agency_delegates
      SET full_name = ?, phone = ?, bar_branch = ?, notes = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    ''', [cleanName, phone?.trim(), barBranch?.trim(), notes?.trim(), isActive ? 1 : 0, id]);
    return id;
  }

  Future<void> setAgencyDelegateActive(int id, bool active) async {
    await ensureReady();
    await _db.customStatement(
      'UPDATE agency_delegates SET is_active = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [active ? 1 : 0, id],
    );
  }

  Future<List<ArchiveReferenceValueRecord>> getAllReferenceValues({bool includeInactive = true}) async {
    await ensureReady();
    final rows = await _db.customSelect(
      includeInactive
          ? 'SELECT * FROM archive_reference_values ORDER BY category, parent_value, is_active DESC, value COLLATE NOCASE'
          : 'SELECT * FROM archive_reference_values WHERE is_active = 1 ORDER BY category, parent_value, value COLLATE NOCASE',
    ).get();
    return rows.map((row) {
      final d = row.data;
      return ArchiveReferenceValueRecord(
        id: d['id'] as int,
        category: d['category'] as String,
        value: d['value'] as String,
        parentValue: d['parent_value'] as String?,
        isActive: ((d['is_active'] as int?) ?? 1) == 1,
      );
    }).toList();
  }

  Future<List<ArchiveReferenceValueRecord>> getReferenceValues({required String category, String? parentValue}) async {
    await ensureReady();
    final rows = await _db.customSelect(
      parentValue == null
          ? 'SELECT * FROM archive_reference_values WHERE category = ? AND parent_value IS NULL AND is_active = 1 ORDER BY value COLLATE NOCASE'
          : 'SELECT * FROM archive_reference_values WHERE category = ? AND parent_value = ? AND is_active = 1 ORDER BY value COLLATE NOCASE',
      variables: parentValue == null ? [Variable.withString(category)] : [Variable.withString(category), Variable.withString(parentValue)],
    ).get();
    return rows.map((row) {
      final d = row.data;
      return ArchiveReferenceValueRecord(
        id: d['id'] as int,
        category: d['category'] as String,
        value: d['value'] as String,
        parentValue: d['parent_value'] as String?,
        isActive: ((d['is_active'] as int?) ?? 1) == 1,
      );
    }).toList();
  }

  Future<void> addReferenceValue({required String category, required String value, String? parentValue}) async {
    await ensureReady();
    final clean = value.trim();
    if (clean.isEmpty) return;
    final existing = await _db.customSelect(
      parentValue == null
          ? 'SELECT id FROM archive_reference_values WHERE category = ? AND parent_value IS NULL AND value = ? LIMIT 1'
          : 'SELECT id FROM archive_reference_values WHERE category = ? AND parent_value = ? AND value = ? LIMIT 1',
      variables: parentValue == null ? [Variable.withString(category), Variable.withString(clean)] : [Variable.withString(category), Variable.withString(parentValue), Variable.withString(clean)],
    ).get();
    if (existing.isNotEmpty) {
      await _db.customStatement('UPDATE archive_reference_values SET is_active = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [existing.first.data['id'] as int]);
      return;
    }
    await _db.customStatement('''
      INSERT INTO archive_reference_values(category, parent_value, value)
      VALUES(?, ?, ?)
    ''', [category, parentValue, clean]);
  }

  Future<void> renameReferenceValue({required int id, required String value}) async {
    await ensureReady();
    final clean = value.trim();
    if (clean.isEmpty) return;
    await _db.customStatement(
      'UPDATE archive_reference_values SET value = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [clean, id],
    );
  }

  Future<void> disableReferenceValue(int id) async {
    await ensureReady();
    await _db.customStatement(
      'UPDATE archive_reference_values SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [id],
    );
  }

  Future<void> enableReferenceValue(int id) async {
    await ensureReady();
    await _db.customStatement(
      'UPDATE archive_reference_values SET is_active = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [id],
    );
  }

  Future<int> createBatch({
    required String name,
    required String sourceType,
    String? sourcePath,
    String? createdBy,
    String? notes,
  }) async {
    await ensureReady();
    await _db.customStatement('''
      INSERT INTO archive_batches(name, source_type, source_path, created_by_name_snapshot, notes)
      VALUES(?, ?, ?, ?, ?)
    ''', [name, sourceType, sourcePath, createdBy, notes]);
    final row = (await _db.customSelect('SELECT last_insert_rowid() AS id').get()).first;
    return row.data['id'] as int;
  }

  Future<void> updateBatchStatus(int id, String status) async {
    await ensureReady();
    await _db.customStatement(
      "UPDATE archive_batches SET status = ?, started_at = CASE WHEN ? = 'processing' THEN CURRENT_TIMESTAMP ELSE started_at END, completed_at = CASE WHEN ? LIKE 'completed%' THEN CURRENT_TIMESTAMP ELSE completed_at END WHERE id = ?",
      [status, status, status, id],
    );
  }

  Future<void> updateBatchSourcePath(int id, String sourcePath) async {
    await ensureReady();
    final clean = sourcePath.trim();
    if (clean.isEmpty) return;
    await _db.customStatement(
      'UPDATE archive_batches SET source_path = ? WHERE id = ?',
      [clean, id],
    );
  }

  Future<void> updateBatchDetails({
    required int id,
    required String name,
    String? sourcePath,
    String? notes,
  }) async {
    await ensureReady();
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    await _db.customStatement('''
      UPDATE archive_batches
      SET name = ?,
          source_path = ?,
          notes = ?
      WHERE id = ?
    ''', [
      cleanName,
      sourcePath == null || sourcePath.trim().isEmpty ? null : sourcePath.trim(),
      notes == null || notes.trim().isEmpty ? null : notes.trim(),
      id,
    ]);
  }

  Future<ArchiveImportSummary> importFilesToBatch(int batchId, List<File> files) async {
    await ensureReady();
    await updateBatchStatus(batchId, 'processing');
    var imported = 0;
    var duplicates = 0;
    var failed = 0;

    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        final duplicateRows = await _db.customSelect(
          'SELECT id FROM archive_items WHERE sha256 = ? LIMIT 1',
          variables: [Variable.withString(hash)],
        ).get();
        final isDuplicate = duplicateRows.isNotEmpty;
        final duplicateOfId = isDuplicate ? duplicateRows.first.data['id'] as int? : null;
        String? storedPath;
        if (isDuplicate) {
          duplicates++;
        } else {
          storedPath = await _storage.saveAttachment(
            sourceFile: file,
            folderType: 'archive_intake',
            entityId: batchId,
          );
          imported++;
        }

        await _db.customStatement('''
          INSERT INTO archive_items(
            batch_id, original_file_name, source_path, stored_path, file_type, file_size, sha256,
            status, review_status, suggested_document_type, error_message
          ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          batchId,
          file.path.split(Platform.pathSeparator).last,
          file.path,
          storedPath,
          _extension(file.path),
          bytes.length,
          hash,
          isDuplicate ? 'duplicate' : 'imported',
          'needs_review',
          _suggestDocumentType(file.path),
          isDuplicate ? 'ملف مكرر محتمل${duplicateOfId == null ? '' : ' للعنصر #$duplicateOfId'}' : null,
        ]);
      } catch (e) {
        failed++;
        await _db.customStatement('''
          INSERT INTO archive_items(batch_id, original_file_name, source_path, status, review_status, error_message)
          VALUES(?, ?, ?, 'failed', 'needs_review', ?)
        ''', [
          batchId,
          file.path.split(Platform.pathSeparator).last,
          file.path,
          '$e',
        ]);
      }
    }

    await _db.customStatement('''
      UPDATE archive_batches
      SET total_files = total_files + ?,
          processed_files = processed_files + ?,
          failed_files = failed_files + ?,
          duplicate_files = duplicate_files + ?,
          unclassified_files = unclassified_files + ?,
          status = ?
      WHERE id = ?
    ''', [
      files.length,
      imported + duplicates + failed,
      failed,
      duplicates,
      imported + duplicates,
      failed > 0 ? 'completed_with_errors' : 'waiting_review',
      batchId,
    ]);

    return ArchiveImportSummary(imported: imported, duplicates: duplicates, failed: failed);
  }


  Future<ArchiveCsvPreview> previewCsvFile(File csvFile) async {
    await ensureReady();
    final content = _stripBom(await csvFile.readAsString(encoding: utf8));
    final rows = _parseCsv(content);
    if (rows.isEmpty) throw StateError('ملف CSV فارغ');
    final headers = rows.first.map((value) => value.trim()).toList();
    final dataRows = rows.skip(1).where((row) => row.any((cell) => cell.trim().isNotEmpty)).toList();
    Map<String, String> mapRow(List<String> row) {
      final mapped = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        mapped[headers[c]] = c < row.length ? row[c] : '';
      }
      return mapped;
    }

    final delimiter = _detectCsvDelimiter(content);
    final warnings = _csvWarnings(headers, dataRows);
    final existingDuplicates = await _countExistingCsvRowDuplicates(headers, dataRows);
    if (existingDuplicates > 0) {
      warnings.add('يوجد $existingDuplicates صف يبدو أنه مستورد سابقاً في الأرشيف بناءً على البصمة.');
    }
    return ArchiveCsvPreview(
      fileName: csvFile.path.split(Platform.pathSeparator).last,
      delimiter: delimiter == '\t' ? 'Tab' : delimiter,
      headers: headers,
      rowCount: dataRows.length,
      sampleRows: dataRows.take(5).map(mapRow).toList(),
      warnings: warnings,
    );
  }

  Future<ArchiveImportSummary> importCsvRowsToBatch(int batchId, File csvFile) async {
    await ensureReady();
    await updateBatchStatus(batchId, 'processing');
    var imported = 0;
    var duplicates = 0;
    var failed = 0;
    final fileName = csvFile.path.split(Platform.pathSeparator).last;

    try {
      final content = await csvFile.readAsString(encoding: utf8);
      final rows = _parseCsv(_stripBom(content));
      if (rows.isEmpty) {
        throw StateError('ملف CSV فارغ');
      }
      final headers = rows.first.map((value) => value.trim()).toList();
      final dataRows = rows.skip(1).where((row) => row.any((cell) => cell.trim().isNotEmpty)).toList();
      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final mapped = <String, String>{};
        for (var c = 0; c < headers.length; c++) {
          mapped[headers[c]] = c < row.length ? row[c] : '';
        }
        final rowTitle = _csvRowTitle(fileName, i + 2, mapped);
        final rowHash = sha256.convert(utf8.encode(jsonEncode(mapped))).toString();
        final duplicateRows = await _db.customSelect(
          'SELECT id FROM archive_items WHERE sha256 = ? LIMIT 1',
          variables: [Variable.withString(rowHash)],
        ).get();
        final isDuplicate = duplicateRows.isNotEmpty;
        final duplicateOfId = isDuplicate ? duplicateRows.first.data['id'] as int? : null;
        await _db.customStatement('''
          INSERT INTO archive_items(
            batch_id, original_file_name, source_path, file_type, file_size, sha256,
            status, review_status, suggested_document_type, error_message
          ) VALUES(?, ?, ?, 'csv_row', 0, ?, ?, 'needs_review', ?, ?)
        ''', [
          batchId,
          rowTitle,
          csvFile.path,
          rowHash,
          isDuplicate ? 'duplicate' : 'imported',
          _suggestCsvDocumentType(fileName, headers),
          isDuplicate ? 'صف CSV مكرر محتمل${duplicateOfId == null ? '' : ' للعنصر #$duplicateOfId'}\n${jsonEncode(mapped)}' : jsonEncode(mapped),
        ]);
        if (isDuplicate) {
          duplicates++;
        } else {
          imported++;
        }
      }
    } catch (e) {
      failed++;
      await _db.customStatement('''
        INSERT INTO archive_items(batch_id, original_file_name, source_path, file_type, status, review_status, error_message)
        VALUES(?, ?, ?, 'csv', 'failed', 'needs_review', ?)
      ''', [batchId, fileName, csvFile.path, '$e']);
    }

    await _db.customStatement('''
      UPDATE archive_batches
      SET total_files = total_files + ?,
          processed_files = processed_files + ?,
          failed_files = failed_files + ?,
          duplicate_files = duplicate_files + ?,
          unclassified_files = unclassified_files + ?,
          status = ?
      WHERE id = ?
    ''', [
      imported + duplicates + failed,
      imported + duplicates + failed,
      failed,
      duplicates,
      imported + duplicates + failed,
      failed > 0 ? 'completed_with_errors' : 'waiting_review',
      batchId,
    ]);
    await refreshBatchCounters(batchId);
    return ArchiveImportSummary(imported: imported, duplicates: duplicates, failed: failed);
  }

  Future<int> _countExistingCsvRowDuplicates(List<String> headers, List<List<String>> rows) async {
    var count = 0;
    for (final row in rows) {
      final mapped = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        mapped[headers[c]] = c < row.length ? row[c] : '';
      }
      final rowHash = sha256.convert(utf8.encode(jsonEncode(mapped))).toString();
      final existing = await _db.customSelect(
        'SELECT id FROM archive_items WHERE sha256 = ? LIMIT 1',
        variables: [Variable.withString(rowHash)],
      ).get();
      if (existing.isNotEmpty) count++;
    }
    return count;
  }

  List<String> _csvWarnings(List<String> headers, List<List<String>> rows) {
    final warnings = <String>[];
    final normalized = headers.map((h) => h.trim().toLowerCase()).toList();
    final emptyHeaders = headers.where((h) => h.trim().isEmpty).length;
    if (emptyHeaders > 0) warnings.add('يوجد $emptyHeaders عمود بلا اسم.');
    final duplicates = <String>{};
    final seen = <String>{};
    for (final header in normalized.where((h) => h.isNotEmpty)) {
      if (!seen.add(header)) duplicates.add(header);
    }
    if (duplicates.isNotEmpty) warnings.add('أسماء أعمدة مكررة: ${duplicates.join(', ')}');
    if (rows.isEmpty) warnings.add('لا توجد صفوف بيانات بعد سطر العناوين.');
    final known = {'full_name', 'client_name', 'company_name', 'internal_number', 'file_number', 'case_type', 'poa_number', 'file_name', 'document_type', 'title'};
    if (!normalized.any(known.contains)) {
      warnings.add('لم يتم العثور على أعمدة تعريف معروفة مثل full_name أو internal_number أو file_name؛ سيتم الاستيراد كصفوف مراجعة عامة.');
    }
    final widthMismatch = rows.where((row) => row.length != headers.length).length;
    if (widthMismatch > 0) warnings.add('يوجد $widthMismatch صف بعدد خلايا مختلف عن عدد الأعمدة.');

    final rowHashes = <String>{};
    var duplicateRowsInsideFile = 0;
    for (final row in rows) {
      final mapped = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        mapped[headers[c]] = c < row.length ? row[c] : '';
      }
      final rowHash = sha256.convert(utf8.encode(jsonEncode(mapped))).toString();
      if (!rowHashes.add(rowHash)) duplicateRowsInsideFile++;
    }
    if (duplicateRowsInsideFile > 0) warnings.add('يوجد $duplicateRowsInsideFile صف مكرر داخل ملف CSV نفسه.');
    if (rows.length > 1000) warnings.add('الملف يحتوي ${rows.length} صف؛ قد تستغرق عملية الاستيراد والمراجعة وقتاً أطول.');
    return warnings;
  }

  String _stripBom(String content) {
    if (content.startsWith('\uFEFF')) return content.substring(1);
    return content;
  }

  String _detectCsvDelimiter(String content) {
    final firstLine = content.split(RegExp(r'\r?\n')).firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    final comma = ','.allMatches(firstLine).length;
    final semicolon = ';'.allMatches(firstLine).length;
    final tab = '\t'.allMatches(firstLine).length;
    if (semicolon > comma && semicolon >= tab) return ';';
    if (tab > comma && tab > semicolon) return '\t';
    return ',';
  }

  List<List<String>> _parseCsv(String content) {
    final delimiter = _detectCsvDelimiter(content);
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      final next = i + 1 < content.length ? content[i + 1] : '';
      if (char == '"') {
        if (inQuotes && next == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        currentRow.add(current.toString());
        current.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && next == '\n') i++;
        currentRow.add(current.toString());
        current.clear();
        if (currentRow.any((cell) => cell.trim().isNotEmpty)) rows.add(List<String>.from(currentRow));
        currentRow.clear();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(current.toString());
      if (currentRow.any((cell) => cell.trim().isNotEmpty)) rows.add(List<String>.from(currentRow));
    }
    return rows;
  }

  String _csvRowTitle(String fileName, int lineNumber, Map<String, String> row) {
    for (final key in const ['internal_number', 'file_number', 'poa_number', 'full_name', 'client_name', 'company_name', 'title', 'file_name']) {
      final value = row[key]?.trim();
      if (value != null && value.isNotEmpty) return '$fileName / السطر $lineNumber — $value';
    }
    return '$fileName / السطر $lineNumber';
  }

  String? _formatCsvRowNotes(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) return rawJson;
      final lines = <String>['بيانات صف CSV:'];
      for (final entry in decoded.entries) {
        final key = '${entry.key}'.trim();
        if (key.isEmpty) continue;
        lines.add('$key: ${entry.value ?? ''}');
      }
      return lines.join('\n');
    } catch (_) {
      return rawJson;
    }
  }

  String _suggestCsvDocumentType(String fileName, List<String> headers) {
    final raw = '${fileName.toLowerCase()} ${headers.join(' ').toLowerCase()}';
    if (raw.contains('poa') || raw.contains('وكال')) return 'power_of_attorney';
    if (raw.contains('case') || raw.contains('دعوى')) return 'case_document';
    if (raw.contains('contract') || raw.contains('عقد')) return 'contract';
    if (raw.contains('receipt') || raw.contains('قبض') || raw.contains('ايصال') || raw.contains('إيصال')) return 'receipt';
    return 'archive_document';
  }


  Future<List<ArchiveItemRecord>> getItemsByStatus(String status) async {
    await ensureReady();
    final rows = await _db.customSelect(
      'SELECT * FROM archive_items WHERE status = ? ORDER BY created_at DESC',
      variables: [Variable.withString(status)],
    ).get();
    return rows.map(_mapItem).toList();
  }

  Future<List<ArchiveItemRecord>> getItemsByReviewStatus(String reviewStatus) async {
    await ensureReady();
    final rows = await _db.customSelect(
      'SELECT * FROM archive_items WHERE review_status = ? ORDER BY created_at DESC',
      variables: [Variable.withString(reviewStatus)],
    ).get();
    return rows.map(_mapItem).toList();
  }

  ArchiveItemRecord _mapItem(QueryRow row) {
    final d = row.data;
    DateTime parseDate(Object? value) => DateTime.tryParse('${value ?? ''}') ?? DateTime.now();
    return ArchiveItemRecord(
      id: d['id'] as int,
      batchId: d['batch_id'] as int,
      originalFileName: d['original_file_name'] as String,
      sourcePath: d['source_path'] as String?,
      storedPath: d['stored_path'] as String?,
      fileType: d['file_type'] as String?,
      fileSize: (d['file_size'] as int?) ?? 0,
      sha256: d['sha256'] as String?,
      status: d['status'] as String,
      reviewStatus: d['review_status'] as String,
      errorMessage: d['error_message'] as String?,
      suggestedDocumentType: d['suggested_document_type'] as String?,
      suggestedEntityType: d['suggested_entity_type'] as int?,
      suggestedEntityId: d['suggested_entity_id'] as int?,
      confirmedDocumentType: d['confirmed_document_type'] as String?,
      confirmedEntityType: d['confirmed_entity_type'] as int?,
      confirmedEntityId: d['confirmed_entity_id'] as int?,
      reviewedBy: d['reviewed_by'] as String?,
      reviewedAt: d['reviewed_at'] == null ? null : parseDate(d['reviewed_at']),
      reviewNote: d['review_note'] as String?,
      createdAt: parseDate(d['created_at']),
    );
  }

  Future<List<ArchiveItemRecord>> getItemsForBatch(int batchId) async {
    await ensureReady();
    final rows = await _db.customSelect(
      'SELECT * FROM archive_items WHERE batch_id = ? ORDER BY created_at DESC',
      variables: [Variable.withInt(batchId)],
    ).get();
    return rows.map(_mapItem).toList();
  }


  Future<ArchiveItemRecord?> getItemById(int itemId) async {
    await ensureReady();
    final rows = await _db.customSelect(
      'SELECT * FROM archive_items WHERE id = ? LIMIT 1',
      variables: [Variable.withInt(itemId)],
    ).get();
    if (rows.isEmpty) return null;
    return _mapItem(rows.first);
  }

  Future<int> promoteItemToDocument({
    required int itemId,
    required String documentType,
    required int entityType,
    required int entityId,
    required String userRef,
    String? archiveNotes,
    int? physicalLocation,
    bool? paperOriginalSaved,
    String? paperLocation,
    String? paperBox,
    String? paperShelf,
    String? paperFolder,
    bool? canDestroyOriginal,
    String? reviewedBy,
    /// حالة ملف المكتب الناتجة عن مسار الأرشيف القديم:
    /// أرشيف جارٍ => active، أرشيف منتهٍ => closed.
    OfficeFileStatus? officeFileStatus,
  }) async {
    await ensureReady();
    final item = await getItemById(itemId);
    if (item == null) throw StateError('عنصر الأرشيف غير موجود');
    final isMetadataOnlyCsvRow = item.fileType == 'csv_row' && item.status == 'imported';
    if ((item.storedPath == null || item.storedPath!.isEmpty) && !isMetadataOnlyCsvRow) {
      throw StateError('لا يمكن اعتماد عنصر بلا ملف محفوظ، غالباً لأنه مكرر أو فشل استيراده');
    }
    return _db.transaction(() async {
      final csvRowNotes = isMetadataOnlyCsvRow ? _formatCsvRowNotes(item.errorMessage) : null;
      final docId = await _db.into(_db.documents).insert(
            DocumentsCompanion.insert(
              docName: item.originalFileName,
              docType: Value(documentType),
              filePath: Value(item.storedPath),
              fileType: Value(item.fileType),
              summary: Value(isMetadataOnlyCsvRow ? 'بيانات مستوردة من صف CSV عبر مركز الأرشيف' : 'مستند مستورد من مركز إدخال الأرشيف'),
              notes: Value([
                'ArchiveItem #$itemId / SHA256: ${item.sha256 ?? '-'}',
                if ((csvRowNotes ?? '').trim().isNotEmpty) csvRowNotes!.trim(),
                if ((archiveNotes ?? '').trim().isNotEmpty) archiveNotes!.trim(),
              ].join('\n')),
              physicalLocation: Value(physicalLocation ?? 0),
            ),
          );
      final hasPaperMetadata = paperOriginalSaved != null ||
          (paperLocation ?? '').trim().isNotEmpty ||
          (paperBox ?? '').trim().isNotEmpty ||
          (paperShelf ?? '').trim().isNotEmpty ||
          (paperFolder ?? '').trim().isNotEmpty ||
          canDestroyOriginal != null ||
          (reviewedBy ?? '').trim().isNotEmpty;
      if (hasPaperMetadata) {
        await _db.customStatement('''
          INSERT OR REPLACE INTO document_paper_metadata(
            document_id, paper_original_saved, paper_location, box, shelf, paper_folder,
            can_destroy_original, reviewed_by, reviewed_at, notes, updated_at
          ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, CURRENT_TIMESTAMP)
        ''', [
          docId,
          (paperOriginalSaved ?? false) ? 1 : 0,
          paperLocation,
          paperBox,
          paperShelf,
          paperFolder,
          (canDestroyOriginal ?? false) ? 1 : 0,
          reviewedBy,
          archiveNotes,
        ]);
      }

      await _db.into(_db.documentLinks).insert(
            DocumentLinksCompanion.insert(
              documentId: docId,
              entityType: entityType,
              entityId: entityId,
              linkType: const Value('archive_import'),
            ),
          );
      await updateItemReview(
        itemId: itemId,
        status: 'imported',
        reviewStatus: 'approved',
        documentType: documentType,
        entityType: entityType,
        entityId: entityId,
        reviewedBy: userRef,
        reviewNote: 'ربط واعتماد كمستند رقم $docId',
      );
      await refreshBatchCounters(item.batchId);
      await _db.into(_db.timelineEvents).insert(
            TimelineEventsCompanion.insert(
              entityType: entityType,
              entityId: entityId,
              eventType: 'archive_document_linked',
              eventDate: Value(DateTime.now()),
              description: 'تم ربط مستند من الأرشيف القديم: ${item.originalFileName}',
              userRef: Value(userRef),
            ),
          );

      // === ربط الأرشيف القديم بملف المكتب الموحد (OfficeFile) ===
      // ملاحظة: لا يتم إنشاء ملف مكتب للأشخاص (entityType = 4) لأن الأشخاص دليل مركزي.
      // ولا يتم ابتلاع الخطأ بصمت: يُسجل في notes الخاصة بعنصر الأرشيف حتى ينتبه المكتب.
      final officeFileType = _mapEntityTypeToOfficeFileType(entityType);
      if (officeFileType != null) {
        try {
          final officeRepo = OfficeFileRepository(_db);
          await officeRepo.ensureOldArchiveOfficeFile(
            fileType: officeFileType,
            linkedEntityType: entityType,
            linkedEntityId: entityId,
            title: item.originalFileName,
            status: officeFileStatus ?? OfficeFileStatus.active,
            notes: 'مستورد من الأرشيف القديم (ArchiveItem #$itemId)',
          );
        } catch (e) {
          // الترويج لا يفشل، لكن الخطأ يُسجَّل صراحة في مراجعة العنصر وفي الخط الزمني.
          await updateItemReview(
            itemId: itemId,
            status: 'imported',
            reviewStatus: 'approved',
            reviewNote: 'تحذير: تعذر إنشاء/مزامنة ملف المكتب لهذا الكيان: $e',
          );
          await _db.into(_db.timelineEvents).insert(
                TimelineEventsCompanion.insert(
                  entityType: entityType,
                  entityId: entityId,
                  eventType: 'office_file_sync_failed',
                  eventDate: Value(DateTime.now()),
                  description: 'تعذر إنشاء/مزامنة ملف المكتب أثناء ترويج عنصر أرشيف #$itemId: $e',
                  userRef: Value(userRef),
                ),
              );
        }
      }

      return docId;
    });
  }

  Future<void> updateItemReview({
    required int itemId,
    required String status,
    required String reviewStatus,
    String? documentType,
    int? entityType,
    int? entityId,
    String? errorMessage,
    String? reviewedBy,
    String? reviewNote,
  }) async {
    await ensureReady();
    await _db.customStatement('''
      UPDATE archive_items
      SET status = ?,
          review_status = ?,
          confirmed_document_type = COALESCE(?, confirmed_document_type),
          confirmed_entity_type = COALESCE(?, confirmed_entity_type),
          confirmed_entity_id = COALESCE(?, confirmed_entity_id),
          error_message = COALESCE(?, error_message),
          reviewed_by = COALESCE(?, reviewed_by),
          reviewed_at = CASE WHEN ? IS NOT NULL THEN CURRENT_TIMESTAMP ELSE reviewed_at END,
          review_note = COALESCE(?, review_note),
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    ''', [status, reviewStatus, documentType, entityType, entityId, errorMessage, reviewedBy, reviewedBy, reviewNote, itemId]);
  }

  Future<void> refreshBatchCounters(int batchId) async {
    await ensureReady();
    await _db.customStatement('''
      UPDATE archive_batches SET
        total_files = (SELECT COUNT(*) FROM archive_items WHERE batch_id = ?),
        failed_files = (SELECT COUNT(*) FROM archive_items WHERE batch_id = ? AND status = 'failed'),
        duplicate_files = (SELECT COUNT(*) FROM archive_items WHERE batch_id = ? AND status = 'duplicate'),
        unclassified_files = (SELECT COUNT(*) FROM archive_items WHERE batch_id = ? AND review_status = 'needs_review'),
        approved_files = (SELECT COUNT(*) FROM archive_items WHERE batch_id = ? AND review_status = 'approved'),
        processed_files = (SELECT COUNT(*) FROM archive_items WHERE batch_id = ?),
        status = CASE
          WHEN (SELECT COUNT(*) FROM archive_items WHERE batch_id = ? AND review_status = 'needs_review') > 0 THEN 'waiting_review'
          WHEN (SELECT COUNT(*) FROM archive_items WHERE batch_id = ? AND status = 'failed') > 0 THEN 'completed_with_errors'
          ELSE 'completed'
        END,
        completed_at = CASE
          WHEN (SELECT COUNT(*) FROM archive_items WHERE batch_id = ? AND review_status = 'needs_review') = 0 THEN CURRENT_TIMESTAMP
          ELSE completed_at
        END
      WHERE id = ?
    ''', [batchId, batchId, batchId, batchId, batchId, batchId, batchId, batchId, batchId, batchId]);
  }

  Future<List<ArchiveBatchRecord>> getBatches() async {
    await ensureReady();
    final rows = await _db.customSelect('SELECT * FROM archive_batches ORDER BY created_at DESC').get();
    return rows.map((row) {
      final d = row.data;
      DateTime parseDate(Object? value) => DateTime.tryParse('${value ?? ''}') ?? DateTime.now();
      return ArchiveBatchRecord(
        id: d['id'] as int,
        name: d['name'] as String,
        sourceType: d['source_type'] as String,
        status: d['status'] as String,
        sourcePath: d['source_path'] as String?,
        createdBy: d['created_by_name_snapshot'] as String?,
        createdAt: parseDate(d['created_at']),
        totalFiles: d['total_files'] as int,
        processedFiles: d['processed_files'] as int,
        failedFiles: d['failed_files'] as int,
        duplicateFiles: d['duplicate_files'] as int,
        unclassifiedFiles: d['unclassified_files'] as int,
        approvedFiles: d['approved_files'] as int,
        notes: d['notes'] as String?,
      );
    }).toList();
  }

  Stream<List<ArchiveBatchRecord>> watchBatches() {
    return Stream.fromFuture(getBatches());
  }

  String _extension(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot == -1 ? 'file' : name.substring(dot + 1).toLowerCase();
  }

  String _suggestDocumentType(String filePath) {
    final raw = filePath.toLowerCase();
    if (raw.contains('وكال') || raw.contains('poa') || raw.contains('power')) {
      return 'power_of_attorney';
    }
    if (raw.contains('جلس') || raw.contains('ضبط') || raw.contains('محضر') || raw.contains('session')) {
      return 'court_record';
    }
    if (raw.contains('حكم') || raw.contains('قرار') || raw.contains('decision') || raw.contains('judgment')) {
      return 'decision';
    }
    if (raw.contains('قبض') || raw.contains('ايصال') || raw.contains('إيصال') || raw.contains('receipt')) {
      return 'receipt';
    }
    if (raw.contains('عقد') || raw.contains('contract')) {
      return 'contract';
    }
    if (raw.contains('مذكرة') || raw.contains('لائحة') || raw.contains('memo')) {
      return 'memo';
    }
    return 'archive_document';
  }

  /// تحويل نوع الكيان إلى نوع ملف المكتب
  OfficeFileType? _mapEntityTypeToOfficeFileType(int entityType) {
    switch (entityType) {
      case 0: return OfficeFileType.caseFile;       // دعوى
      case 1: return OfficeFileType.contract;       // عقد
      case 2: return OfficeFileType.company;        // شركة
      case 3: return OfficeFileType.procedure;      // إجراء إداري
      case 5: return OfficeFileType.agency;         // وكالة
      default: return null;
    }
  }
}
