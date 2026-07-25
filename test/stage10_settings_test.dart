import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/utils/crypto_utils.dart';
import 'package:lawyer_office/presentation/screens/settings/settings_models.dart';

void main() {
  test('Seed settings include security backups courts and activity log', () {
    final state = SettingsHubNotifier().state;
    expect(state.preferences.officeTitle, isNotEmpty);
    expect(state.security.isConfigured, isTrue);
    expect(state.backups, isNotEmpty);
    expect(state.courts, isNotEmpty);
    expect(state.activityLog, isNotEmpty);
  });

  test('Password update validates current password and confirmation', () async {
    final notifier = SettingsHubNotifier();

    final wrong = await notifier.updateSecurity(
      currentPassword: 'wrong',
      newPassword: 'NewPass1',
      confirmPassword: 'NewPass1',
      securityQuestion: 'سؤال؟',
      securityAnswer: 'جواب',
    );
    expect(wrong, isNotNull);

    final mismatch = await notifier.updateSecurity(
      currentPassword: 'Office@2026',
      newPassword: 'NewPass1',
      confirmPassword: 'Other',
      securityQuestion: 'سؤال؟',
      securityAnswer: 'جواب',
    );
    expect(mismatch, contains('تأكيد'));

    final ok = await notifier.updateSecurity(
      currentPassword: 'Office@2026',
      newPassword: 'NewPass1',
      confirmPassword: 'NewPass1',
      securityQuestion: 'ما لونك المفضل؟',
      securityAnswer: 'أزرق',
      lockTimeoutMinutes: 15,
    );
    expect(ok, isNull);
    expect(notifier.state.security.lockTimeoutMinutes, 15);
    expect(
      CryptoUtils.verifyPassword('NewPass1', notifier.state.security.passwordHash),
      isTrue,
    );
    expect(notifier.verifySecurityAnswer('أزرق'), isTrue);
    expect(notifier.state.activityLog.first.tableName, 'security');
  });

  test('Create backup updates list lastBackup and activity log', () async {
    final notifier = SettingsHubNotifier();
    final before = notifier.state.backups.length;
    final rec = await notifier.createBackup(includeAttachments: true, type: 'manual');
    expect(rec.path, contains('SyrLawOffice_Backup_'));
    expect(notifier.state.backups.length, before + 1);
    expect(notifier.state.preferences.lastBackupAt, isNotNull);
    expect(notifier.state.needsWeeklyBackup, isFalse);
    expect(notifier.state.activityLog.first.action, 'export');
  });

  test('Restore backup and external path logging', () async {
    final notifier = SettingsHubNotifier();
    final id = notifier.state.backups.first.id;
    expect(await notifier.restoreBackup(id), isTrue);
    expect(await notifier.restoreBackup('missing'), isFalse);
    notifier.setExternalBackupPath('E:/USB_Backups');
    expect(notifier.state.preferences.externalBackupPath, 'E:/USB_Backups');
  });

  test('Add court and filter activity log', () {
    final notifier = SettingsHubNotifier();
    final before = notifier.state.courts.length;
    notifier.addCourt(
      const SettingsCourtItem(
        id: 'cx',
        name: 'محكمة اختبار',
        type: 'صلح',
        city: 'السويداء',
      ),
    );
    expect(notifier.state.courts.length, before + 1);
    notifier.setActivityFilter('محكمة');
    expect(notifier.state.filteredActivity, isNotEmpty);
    notifier.setActivityFilter('لا_يوجد_هذا_النص');
    expect(notifier.state.filteredActivity, isEmpty);
  });

  test('Save office preferences updates state', () async {
    final notifier = SettingsHubNotifier();
    final next = notifier.state.preferences.copyWith(
      officeTitle: 'مكتب اختبار',
      lawyerName: 'محامي اختبار',
      workOrderDefaultPriority: 2,
    );
    await notifier.saveOfficePreferences(next);
    expect(notifier.state.preferences.officeTitle, 'مكتب اختبار');
    expect(notifier.state.preferences.workOrderDefaultPriority, 2);
    expect(notifier.state.activityLog.first.tableName, 'app_settings');
  });
}
