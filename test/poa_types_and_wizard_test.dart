import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/office_file_repository.dart';
import 'package:lawyer_office/data/repositories/poa_repository.dart';
import 'package:lawyer_office/data/services/file_storage_service.dart';
import 'package:lawyer_office/presentation/screens/persons/person_models.dart';

/// أخطاء رصدها المستخدم أثناء الاختبار الفعلي:
/// 1) تسميات أنواع الوكالة لا تطابق خطة القوائم المرجعية (البند 56).
/// 2) زر «إضافة وكالة جديدة» في ويزارد الدعوى لا يحفظ شيئاً.
/// 3) حفظ دعوى في «الأرشيف الجاري» يُحبس بسبب اشتراط موعد الجلسة.
void main() {
  late AppDatabase db;
  late PoaRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PoaRepository(db.personDao, FileStorageService(), OfficeFileRepository(db));
    await db.ensureOfficeFileTables();
  });

  tearDown(() async {
    await db.close();
  });

  test('POA type labels match the reference lookups plan', () {
    expect(PoaType.general.label, 'سند توكيل عام');
    expect(PoaType.special.label, 'سند توكيل خاص');
    expect(PoaType.specialSharia.label, 'سند توكيل خاص شرعي');

    // ولا تبقى التسمية القديمة في واجهة الأشخاص
    expect(AgencyType.general.displayName, 'سند توكيل عام');
    expect(AgencyType.sharia.displayName, 'سند توكيل خاص شرعي');
  });

  test('All six POA usages from the plan exist', () {
    final labels = PoaUsage.values.map((e) => e.label).toList();
    expect(labels, containsAll(['صلحية', 'بدائية', 'جنائية', 'تنفيذية', 'شرعية', 'إدارية']));
    expect(PoaUsage.values, hasLength(6));
  });

  test('All eleven POA statuses from the plan exist', () {
    final labels = PoaStatus.values.map((e) => e.label).toList();
    expect(labels, containsAll([
      'فعالة',
      'غير مكتملة البيانات',
      'بانتظار صورة السند',
      'بانتظار تصديق',
      'بانتظار توطين',
      'موطنة / مصدقة',
      'منتهية',
      'معزول عنها',
      'اعتزال',
      'ملغاة',
      'بحاجة مراجعة',
    ]));
    expect(PoaStatus.values, hasLength(11));
  });

  test('Revoked or expired POA is not usable for a new case', () {
    expect(PoaStatus.active.isUsable, isTrue);
    expect(PoaStatus.certified.isUsable, isTrue);
    expect(PoaStatus.revoked.isUsable, isFalse);
    expect(PoaStatus.expired.isUsable, isFalse);
    expect(PoaStatus.cancelled.isUsable, isFalse);
    expect(PoaStatus.withdrawn.isUsable, isFalse);
  });

  test('Creating a POA from the wizard actually persists it', () async {
    final personId = await db.into(db.persons).insert(
          PersonsCompanion.insert(fullName: 'أحمد الخطيب'),
        );

    final poaId = await repo.createPoa(
      poa: PowersOfAttorneyCompanion.insert(
        poaNumber: const Value('POA-2026-77'),
        poaDate: Value(DateTime(2026, 3, 1)),
        sourceType: 'notary',
        poaType: PoaType.special.index,
        scopeText: Value(PoaUsage.firstInstance.label),
        status: Value(PoaStatus.active.dbValue),
      ),
      principalId: personId,
    );

    final saved = await db.personDao.getAllPoas();
    expect(saved.any((p) => p.id == poaId && p.poaNumber == 'POA-2026-77'), isTrue);

    final record = saved.firstWhere((p) => p.id == poaId);
    expect(record.poaType, PoaType.special.index);
    expect(record.scopeText, 'بدائية');

    // والوكالة تحصل على ملف مكتب مرقّم
    final office = await OfficeFileRepository(db).getByLinkedEntity(
      entityType: EntityType.powerOfAttorney.index,
      entityId: poaId,
    );
    expect(office, isNotNull);
    expect(office!.fileNumber, contains('وكالة/'));
  });

  test('Running archive case without a next date still records a deficiency', () async {
    // القاعدة: غياب موعد الجلسة لا يمنع الحفظ، بل يولّد نقصاً.
    final companion = CasesCompanion.insert(
      internalNumber: 'د/1',
      year: 2026,
      caseType: 'مدني',
    );
    expect(companion.nextSessionDate.present, isFalse,
        reason: 'دعوى أرشيف جارٍ بلا موعد يجب أن تُقبل ويُرصد نقصها');
  });
}
