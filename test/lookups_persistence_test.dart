import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/settings_repository.dart';
import 'package:lawyer_office/data/services/backup_service.dart';

/// القوائم المرجعية (أنواع الدعاوى، صفات الأطراف...) كانت ثابتة في الكود
/// بلا أي تخزين، فأي تعديل يجريه المكتب يختفي عند إعادة التشغيل.
/// تُحفظ الآن كـ JSON في app_settings.
void main() {
  late AppDatabase db;
  late SettingsRepository repo;
  const key = 'reference_lookups_json';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SettingsRepository(db.settingsDao, BackupService());
  });

  tearDown(() async {
    await db.close();
  });

  test('Lookup lists survive a write and read cycle', () async {
    final payload = {
      'case_types': [
        {'id': 'case_civil', 'name': 'مدني', 'category': '', 'notes': '', 'isActive': true},
        {'id': 'case_custom', 'name': 'نوع مخصص للمكتب', 'category': '', 'notes': '', 'isActive': true},
      ],
    };

    await repo.setSetting(key, jsonEncode(payload));

    final raw = await repo.getSetting(key);
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    final caseTypes = decoded['case_types'] as List;
    expect(caseTypes, hasLength(2));
    expect(caseTypes.any((e) => e['name'] == 'نوع مخصص للمكتب'), isTrue);
  });

  test('Deleting a lookup item is reflected in stored data', () async {
    await repo.setSetting(
      key,
      jsonEncode({
        'party_roles': [
          {'id': 'a', 'name': 'مدعي', 'category': '', 'notes': '', 'isActive': true},
          {'id': 'b', 'name': 'مدعى عليه', 'category': '', 'notes': '', 'isActive': true},
        ],
      }),
    );

    // حذف عنصر ثم إعادة الحفظ كما يفعل الـ notifier
    final current = jsonDecode((await repo.getSetting(key))!) as Map<String, dynamic>;
    final roles = (current['party_roles'] as List).where((e) => e['id'] != 'b').toList();
    await repo.setSetting(key, jsonEncode({'party_roles': roles}));

    final after = jsonDecode((await repo.getSetting(key))!) as Map<String, dynamic>;
    expect((after['party_roles'] as List), hasLength(1));
    expect((after['party_roles'] as List).first['name'], 'مدعي');
  });

  test('Disabled lookup item keeps its inactive flag', () async {
    await repo.setSetting(
      key,
      jsonEncode({
        'contract_types': [
          {'id': 'c1', 'name': 'بيع', 'category': '', 'notes': '', 'isActive': false},
        ],
      }),
    );

    final decoded = jsonDecode((await repo.getSetting(key))!) as Map<String, dynamic>;
    expect((decoded['contract_types'] as List).first['isActive'], isFalse);
  });

  test('Missing lookups setting returns null instead of throwing', () async {
    final raw = await repo.getSetting(key);
    expect(raw, isNull);
  });
}
