import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/presentation/screens/files/files_screen.dart';

/// المرحلة التاسعة من خارطة التنفيذ: المؤشرات المالية على الملف
/// ومنع الإغلاق مع مالية مفتوحة.
void main() {
  test('All six finance indicators from the roadmap exist', () {
    final labels = FileFinanceStatus.values.map((e) => e.displayName).toList();
    expect(labels, containsAll([
      'لا مالية',
      'أتعاب مفتوحة',
      'مدفوع جزئياً',
      'مدفوع بالكامل',
      'مصاريف غير مسددة',
      'مالية تحتاج مراجعة',
    ]));
    expect(FileFinanceStatus.values, hasLength(6));
  });

  test('Only unsettled states block closure', () {
    expect(FileFinanceStatus.none.blocksClosure, isFalse);
    expect(FileFinanceStatus.fullyPaid.blocksClosure, isFalse,
        reason: 'الملف المسدد بالكامل يُغلق دون تأكيد إضافي');

    expect(FileFinanceStatus.openFees.blocksClosure, isTrue);
    expect(FileFinanceStatus.partiallyPaid.blocksClosure, isTrue);
    expect(FileFinanceStatus.unpaidExpenses.blocksClosure, isTrue);
    expect(FileFinanceStatus.needsReview.blocksClosure, isTrue);
  });

  test('FileItem defaults to no finance when unspecified', () {
    final item = FileItem(
      id: '1',
      fileNumber: 'دعوى/2026/0001',
      title: 'دعوى',
      type: FileType.caseFile,
      court: 'بداية',
      status: FileStatus.active,
      createdAt: DateTime(2026, 1, 1),
      lastUpdated: DateTime(2026, 1, 1),
    );
    expect(item.financeStatus, FileFinanceStatus.none);
    expect(item.financeStatus.blocksClosure, isFalse);
  });

  test('Finance status is carried on the file item', () {
    final item = FileItem(
      id: '2',
      fileNumber: 'دعوى/2026/0002',
      title: 'دعوى',
      type: FileType.caseFile,
      court: 'بداية',
      status: FileStatus.active,
      createdAt: DateTime(2026, 1, 1),
      lastUpdated: DateTime(2026, 1, 1),
      financeStatus: FileFinanceStatus.partiallyPaid,
    );
    expect(item.financeStatus.displayName, 'مدفوع جزئياً');
    expect(item.financeStatus.blocksClosure, isTrue);
  });
}
