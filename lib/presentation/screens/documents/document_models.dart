import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../providers/ui_data_providers.dart';
import '../../../data/database/database.dart' as db;

/// نماذج نظام المستندات والمرفقات المشتركة بين شاشات المستندات والدعاوى.
///
/// يعتمد الملف على AppColors عبر الأيقونات المعتمدة في الثيم، وتبقى النصوص
/// عربية جاهزة للعرض داخل واجهات RTL.


/// نوع المستند القانوني داخل المكتب.
enum DocumentType {
  caseDocument,
  powerOfAttorney,
  contract,
  companyDocument,
  adminProcedure,
  receipt,
  memo,
  decision,
  courtRecord,
  other;

  String get displayName => const [
        'مستندات الدعاوى',
        'الوكالات',
        'العقود',
        'مستندات الشركات',
        'مستندات الإجراءات',
        'الإيصالات',
        'المذكرات',
        'القرارات',
        'ضبوط المحكمة',
        'أخرى',
      ][index];
}

/// نوع الملف الفيزيائي المحفوظ ضمن الأرشيف.
enum FileType {
  pdf,
  docx,
  doc,
  jpg,
  png,
  txt,
  rtf,
  other;

  String get displayName => const [
        'PDF',
        'Word (DOCX)',
        'Word (DOC)',
        'JPG',
        'PNG',
        'TXT',
        'RTF',
        'آخر',
      ][index];

  IconData get icon => const [
        Icons.picture_as_pdf,
        Icons.description,
        Icons.description,
        Icons.image,
        Icons.image,
        Icons.text_snippet,
        Icons.text_snippet,
        Icons.insert_drive_file,
      ][index];
}

/// عنصر مستند واحد مرتبط بكيان في المكتب؛ دعوى، عقد، شركة، أو إجراء.
class DocumentItem {
  final String id;
  final String title;
  final String filePath;
  final String fileName;
  final String entityType;
  final String entityId;
  final String entityTitle;
  final String physicalLocation;
  final String uploadedBy;
  final String notes;
  final DocumentType documentType;
  final FileType fileType;
  final int fileSize;
  final DateTime uploadDate;
  final bool hasOriginal;
  final bool isMissingOriginal;

  const DocumentItem({
    required this.id,
    required this.title,
    required this.documentType,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.uploadDate,
    required this.uploadedBy,
    required this.physicalLocation,
    this.hasOriginal = true,
    this.isMissingOriginal = false,
    this.notes = '',
  });

  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    }
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}


/// مستندات من SQLite عبر DocumentRepository.
final documentsProvider = Provider<List<DocumentItem>>((ref) {
  final asyncDocs = ref.watch(documentsFutureProvider);
  return asyncDocs.maybeWhen(data: (items) => items, orElse: () => const <DocumentItem>[]);
});

final documentsFutureProvider = FutureProvider<List<DocumentItem>>((ref) async {
  final repo = ref.watch(documentRepositoryProvider);
  if (ref.read(allowDemoSeedProvider)) {
    await repo.seedDemoIfEmpty();
  }
  final docs = await repo.getAllDocuments();
  final links = await repo.getAllLinks();
  final byDoc = <int, db.DocumentLink>{};
  for (final l in links) {
    byDoc.putIfAbsent(l.documentId, () => l);
  }
  return docs.map((d) {
    final link = byDoc[d.id];
    final entityType = link?.entityType ?? 0;
    final entityId = link?.entityId ?? 0;
    return DocumentItem(
      id: '${d.id}',
      title: d.docName,
      documentType: _mapDocType(d.docType),
      entityType: entityType == 1 ? 'contract' : 'case',
      entityId: '$entityId',
      entityTitle: entityType == 1 ? 'عقد #$entityId' : 'دعوى #$entityId',
      filePath: d.filePath ?? '',
      fileName: (d.filePath ?? d.docName).split('/').last,
      fileSize: 0,
      fileType: inferFileType(d.fileType),
      uploadDate: d.dateAdded,
      uploadedBy: 'المكتب',
      physicalLocation: d.physicalLocation == 0 ? 'مكتب المحامي' : 'خارج المكتب',
      isMissingOriginal: d.status != 0,
      notes: d.notes ?? '',
    );
  }).toList();
});

DocumentType _mapDocType(String? raw) {
  final v = (raw ?? '').toLowerCase();
  if (v.contains('poa') || v.contains('power') || v.contains('وكال')) return DocumentType.powerOfAttorney;
  if (v.contains('contract') || v.contains('عقد')) return DocumentType.contract;
  if (v.contains('memo') || v.contains('مذكر')) return DocumentType.memo;
  if (v.contains('decision') || v.contains('قرار')) return DocumentType.decision;
  if (v.contains('receipt') || v.contains('إيص')) return DocumentType.receipt;
  return DocumentType.caseDocument;
}

/// استنتاج نوع الملف من الامتداد عند رفع مستند جديد.
FileType inferFileType(String? extension) {
  switch ((extension ?? '').toLowerCase()) {
    case 'pdf':
      return FileType.pdf;
    case 'docx':
      return FileType.docx;
    case 'doc':
      return FileType.doc;
    case 'jpg':
    case 'jpeg':
      return FileType.jpg;
    case 'png':
      return FileType.png;
    case 'txt':
      return FileType.txt;
    case 'rtf':
      return FileType.rtf;
    default:
      return FileType.other;
  }
}
