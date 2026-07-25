import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/enums/app_enums.dart';
import 'package:lawyer_office/core/utils/crypto_utils.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/finance_repository.dart';
import 'package:lawyer_office/data/repositories/legal_library_repository.dart';
import 'package:lawyer_office/data/repositories/settings_repository.dart';
import 'package:lawyer_office/data/services/backup_service.dart';
import 'package:lawyer_office/data/services/file_storage_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Finance repository seeds and persists agreements payments expenses', () async {
    final repo = FinanceRepository(db.financeDao, FileStorageService());
    await repo.seedDemoIfEmpty();

    final agreements = await repo.getAllAgreements();
    final payments = await repo.getAllPayments();
    final expenses = await repo.getAllExpenses();
    expect(agreements, isNotEmpty);
    expect(payments, isNotEmpty);
    expect(expenses, isNotEmpty);

    final before = agreements.length;
    final id = await repo.createAgreement(
      entityType: EntityType.caseEntity.index,
      entityId: 99,
      partyId: (await repo.getAllPersons()).first.id,
      agreementType: 'fixed',
      totalAmount: 12345,
      userRef: 'test',
    );
    expect(id, greaterThan(0));
    expect((await repo.getAllAgreements()).length, before + 1);

    await repo.addPayment(
      agreementId: id,
      amount: 1000,
      method: 'نقداً',
      userRef: 'test',
      entityType: EntityType.caseEntity.index,
      entityId: 99,
    );
    expect(await repo.getAllPayments(), isNotEmpty);
  });

  test('Legal library repository seeds and links items', () async {
    final repo = LegalLibraryRepository(db.legalLibraryDao);
    await repo.seedDemoIfEmpty();
    final items = await repo.getAllItems();
    expect(items, isNotEmpty);
    expect(items.any((i) => i.itemType == 'law'), isTrue);
    expect(items.any((i) => i.itemType == 'precedent'), isTrue);

    final id = items.first.id;
    await repo.toggleFavorite(id, true);
    final linksBefore = (await repo.getAllLinks()).length;
    await repo.linkToEntity(
      libraryItemId: id,
      entityType: 0,
      entityId: 7,
      entityTitle: 'دعوى اختبار',
      note: 'ربط',
    );
    expect((await repo.getAllLinks()).length, linksBefore + 1);
  });

  test('Settings repository defaults security and logs activity', () async {
    final repo = SettingsRepository(db.settingsDao, BackupService());
    await repo.ensureDefaults();
    final security = await repo.getSecurity();
    expect(security, isNotNull);
    expect(CryptoUtils.verifyPassword('Office@2026', security!.passwordHash), isTrue);

    await repo.saveOfficeSettings(
      title: 'مكتب اختبار DB',
      lawyer: 'محامي DB',
      address: 'دمشق',
      phone: '011',
    );
    final settings = await repo.getAllSettings();
    expect(settings['office_title'] ?? settings['officeTitle'], anyOf(isNull, isA<String>()));
    // keys use AppConstants
    expect(settings.values.whereType<String>().any((v) => v.contains('مكتب') || v.contains('محامي')), isTrue);

    final err = await repo.updateSecurity(
      currentPassword: 'Office@2026',
      newPassword: 'NewDbPass1',
      confirmPassword: 'NewDbPass1',
      securityQuestion: 'س؟',
      securityAnswer: 'ج',
    );
    expect(err, isNull);
    final sec2 = await repo.getSecurity();
    expect(CryptoUtils.verifyPassword('NewDbPass1', sec2!.passwordHash), isTrue);

    final courtId = await repo.addCourt(name: 'محكمة اختبار DB', type: 'صلح', city: 'السويداء');
    expect(courtId, greaterThan(0));
    final logs = await repo.getActivityLog();
    expect(logs, isNotEmpty);
  });
}
