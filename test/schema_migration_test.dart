import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/data/database/database.dart';

/// يحرس القاعدة الإلزامية: أي عمود يُضاف إلى schema.dart يجب أن يصل
/// إلى قواعد المستخدمين القائمة عبر ترحيل صريح.
///
/// خلفية العطل: بقي schemaVersion على 3 بينما أُضيفت أعمدة كثيرة،
/// فكانت قواعد المستخدمين تفتقر إليها بينما يولّدها Drift في INSERT
/// => SQLite error 1 (no such column) عند إضافة وكالة أو أمر عمل.
void main() {
  group('ترحيل المخطط', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('schemaVersion لم يعد 3 بعد إضافة أعمدة جديدة', () {
      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(4),
        reason: 'أي عمود جديد يستوجب رفع schemaVersion وإضافة addColumn',
      );
    });

    test('جدول الوكالات يحوي كل أعمدة ملف الوكالة', () async {
      await db.customStatement('SELECT 1');
      final info =
          await db.customSelect('PRAGMA table_info(powers_of_attorney)').get();
      final columns =
          info.map((row) => row.data['name'] as String).toSet();

      const required = {
        'category',
        'sub_type',
        'registry_number',
        'white_number',
        'delegate_name',
        'delegate_phone',
        'delegate_branch',
        'scope_text',
        'file_path',
        'status',
        'expiry_date',
        'notary_id',
        'delegate_id',
      };

      final missing = required.difference(columns);
      expect(missing, isEmpty, reason: 'أعمدة مفقودة: $missing');
    });

    test('جدول أوامر العمل يحوي office_file_id', () async {
      await db.customStatement('SELECT 1');
      final info =
          await db.customSelect('PRAGMA table_info(work_orders)').get();
      final columns = info.map((row) => row.data['name'] as String).toSet();

      expect(
        columns,
        contains('office_file_id'),
        reason: 'عمود المرحلة السادسة من خارطة التنفيذ مفقود',
      );
    });

    test('إدخال وكالة كاملة ينجح دون خطأ SQLite', () async {
      await db.customStatement('SELECT 1');

      // إدخال يشمل الأعمدة المتأخرة تحديداً — هو ما كان يفشل.
      await db.customInsert(
        '''
        INSERT INTO powers_of_attorney
          (source_type, poa_type, category, sub_type, registry_number,
           white_number, delegate_name, delegate_phone, scope_text, status)
        VALUES ('notary', 0, 'judicial', 'عام', 'R-1',
                'W-1', 'مندوب', '0999', 'نطاق', 'active')
        ''',
      );

      final rows =
          await db.customSelect('SELECT COUNT(*) AS c FROM powers_of_attorney')
              .getSingle();
      expect(rows.data['c'], 1);
    });

    test('شبكة الأمان قابلة لإعادة التنفيذ دون خطأ', () async {
      // تُستدعى في beforeOpen؛ تكرارها يجب ألا يفشل بعمود مكرر.
      await db.ensurePoaColumns();
      await db.ensurePoaColumns();
      await db.ensureUpgradeTableColumns();
      await db.ensureUpgradeTableColumns();

      final info =
          await db.customSelect('PRAGMA table_info(powers_of_attorney)').get();
      final names = info.map((r) => r.data['name'] as String).toList();
      expect(
        names.length,
        names.toSet().length,
        reason: 'تكرار في أسماء الأعمدة بعد إعادة التنفيذ',
      );
    });
  });
}
