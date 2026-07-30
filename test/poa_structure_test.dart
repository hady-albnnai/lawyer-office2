import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/constants/court_catalog.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/office_file_repository.dart';
import 'package:lawyer_office/data/repositories/poa_repository.dart';
import 'package:lawyer_office/data/services/file_storage_service.dart';
import 'package:lawyer_office/presentation/screens/cases/case_models.dart'
    show CaseType;

/// هيكل الوكالة حسب البندين 3 و7 من خطة ملف الوكالة،
/// وتصحيح قائمة المحاكم الإدارية.
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

  test('Main POA categories match the agency plan', () {
    final labels = PoaCategory.values.map((c) => c.label).toList();
    expect(labels, containsAll(['وكالة قضائية', 'وكالة عدلية']));
  });

  test('Judicial POA offers the three sanad sub-types', () {
    expect(PoaCategory.judicial.subTypes, [
      'سند توكيل عام',
      'سند توكيل خاص',
      'سند توكيل خاص شرعي',
    ]);
  });

  test('Notarial POA has its own distinct sub-types', () {
    expect(PoaCategory.notarial.subTypes, [
      'وكالة عامة',
      'وكالة خاصة',
      'وكالة إدارية',
    ]);
    // لا تتداخل تصنيفات العدلية مع القضائية
    expect(PoaCategory.notarial.subTypes, isNot(contains('سند توكيل عام')));
  });

  test('Only judicial POA requires bar branch data', () {
    expect(PoaCategory.judicial.requiresBarBranch, isTrue);
    expect(PoaCategory.notarial.requiresBarBranch, isFalse);
    expect(PoaCategory.foreign.requiresBarBranch, isFalse);
  });

  test('All fourteen Syrian provinces are available as bar branches', () {
    expect(SyrianProvinces.all, hasLength(14));
    expect(SyrianProvinces.all, containsAll(['دمشق', 'ريف دمشق', 'السويداء', 'القنيطرة']));
  });

  test('Judicial POA persists registry, white number, branch and delegate', () async {
    final personId = await db.into(db.persons).insert(
          PersonsCompanion.insert(fullName: 'موكل'),
        );

    final poaId = await repo.createPoa(
      poa: PowersOfAttorneyCompanion.insert(
        poaNumber: const Value('1234'),
        poaDate: Value(DateTime(2026, 5, 10)),
        sourceType: 'delegate',
        poaType: PoaType.special.index,
        category: const Value('judicial'),
        subType: const Value('سند توكيل خاص'),
        registryNumber: const Value('1234'),
        whiteNumber: const Value('أ-77'),
        delegateBranch: const Value('دمشق'),
        delegateName: const Value('الأستاذ سامر'),
        delegatePhone: const Value('0933000000'),
        scopeText: Value(PoaUsage.firstInstance.label),
        status: Value(PoaStatus.active.dbValue),
      ),
      principalId: personId,
    );

    final saved = (await db.personDao.getAllPoas()).firstWhere((p) => p.id == poaId);
    expect(saved.category, 'judicial');
    expect(saved.subType, 'سند توكيل خاص');
    expect(saved.registryNumber, '1234');
    expect(saved.whiteNumber, 'أ-77');
    expect(saved.delegateBranch, 'دمشق');
    expect(saved.delegateName, 'الأستاذ سامر');
    expect(saved.delegatePhone, '0933000000');
    expect(saved.scopeText, 'بدائية');
  });

  test('Notarial POA saves without bar branch data', () async {
    final personId = await db.into(db.persons).insert(
          PersonsCompanion.insert(fullName: 'موكل عدلي'),
        );

    final poaId = await repo.createPoa(
      poa: PowersOfAttorneyCompanion.insert(
        poaNumber: const Value('عدلية-9'),
        sourceType: 'notary',
        poaType: PoaType.general.index,
        category: const Value('notarial'),
        subType: const Value('وكالة إدارية'),
        status: Value(PoaStatus.active.dbValue),
      ),
      principalId: personId,
    );

    final saved = (await db.personDao.getAllPoas()).firstWhere((p) => p.id == poaId);
    expect(saved.category, 'notarial');
    expect(saved.subType, 'وكالة إدارية');
    expect(saved.delegateBranch, isNull);
  });

  test('Administrative court list has no "نقض إداري"', () {
    // كان الفحص يقرأ نص شاشة الأرشيف بحثاً عن سلسلة حرفية. صارت
    // قائمة المحاكم تُشتق من `CourtCatalog`، فيُفحص السلوك نفسه:
    // لا نقض إداري، وأعلى درجة هي المحكمة الإدارية العليا.
    final labels = CourtCatalog.forCaseType(CaseType.administrative)
        .map((k) => k.label)
        .toList();

    expect(labels.any((l) => l.contains('نقض')), isFalse,
        reason: 'لا يوجد نقض إداري في النظام القضائي السوري');
    expect(labels, contains('المحكمة الإدارية العليا'));

    final top = CourtCatalog.forCaseTypeAndDegree(
      CaseType.administrative,
      LitigationDegree.cassation,
    ).map((k) => k.id);
    expect(top, [CourtCatalog.supremeAdministrativeCourt]);
  });
}
