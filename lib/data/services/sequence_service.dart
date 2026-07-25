import 'package:drift/drift.dart';
import '../database/database.dart';

/// محرك الترقيم السنوي الآمن للمكتب (SequenceService)
/// يضمن توليد أرقام تسلسلية داخلية غير مكررة لكل عام قضائي (مثال: 2026/001، 2026/002...)
class SequenceService {
  final AppDatabase db;
  SequenceService(this.db);

  /// توليد الرقم الداخلي التالي بأمان تام عبر قفل المعاملة (Transaction Lock)
  Future<String> generateNextInternalNumber({int? targetYear}) async {
    final int year = targetYear ?? DateTime.now().year;

    return await db.transaction(() async {
      // 1. البحث عن سجل السنة في جدول YearlySequences
      final query = db.select(db.yearlySequences)..where((t) => t.year.equals(year));
      final seq = await query.getSingleOrNull();

      int nextNum;
      if (seq == null) {
        // إنشاء سجل جديد للسنة الحالية يبدأ من الرقم 1
        nextNum = 1;
        await db.into(db.yearlySequences).insert(
          YearlySequencesCompanion.insert(
            year: year,
            lastNumber: const Value(1),
            prefix: const Value(''),
          ),
        );
      } else {
        // زيادة العداد بمقدار 1
        nextNum = seq.lastNumber + 1;
        await (db.update(db.yearlySequences)..where((t) => t.year.equals(year))).write(
          YearlySequencesCompanion(lastNumber: Value(nextNum)),
        );
      }

      // تنسيق الرقم مع 3 أصفار على الأقل (مثال: 2026/001، 2026/015، 2026/120)
      final String formattedNum = nextNum.toString().padLeft(3, '0');
      return '$year/$formattedNum';
    });
  }

  /// جلب آخر رقم وصل إليه عداد المكتب لسنة محددة
  Future<int> getCurrentSequence(int year) async {
    final query = db.select(db.yearlySequences)..where((t) => t.year.equals(year));
    final seq = await query.getSingleOrNull();
    return seq?.lastNumber ?? 0;
  }
}
