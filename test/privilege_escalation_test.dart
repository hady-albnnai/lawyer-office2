import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/core/auth/permission_catalog.dart';
import 'package:lawyer_office/data/database/database.dart';
import 'package:lawyer_office/data/repositories/auth_repository.dart';

/// اختبارات منع التصعيد في الصلاحيات.
///
/// القاعدة المطبقة: لا يجوز لمستخدم أن يمنح صلاحية لا يملكها، ولا أن يتعامل
/// مع دور أو مستخدم بمستوى يساوي مستواه أو يعلوه. المالك وحده فوق هذه القيود.
void main() {
  late AppDatabase db;
  late AuthRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AuthRepository(db);
    await repo.ensureReady();
  });

  tearDown(() async {
    await db.close();
  });

  Future<AuthUser> loginOwner() async {
    await repo.createOwner(fullName: 'هادي البني', username: 'owner', password: 'Owner#123');
    final user = await repo.login(username: 'owner', password: 'Owner#123');
    return user!;
  }

  /// ينشئ مديراً بمستوى 80 ويسجّل دخوله.
  Future<AuthUser> createAndLoginManager(
    AuthUser owner, {
    Set<String>? permissions,
    int level = 80,
  }) async {
    final roleId = await repo.createRole(
      name: 'مدير المكتب',
      permissions: permissions ?? {PermissionKeys.settingsUsersManage},
      hierarchyLevel: level,
      actor: owner,
    );
    await repo.createUser(
      fullName: 'مدير',
      username: 'manager',
      password: 'Mgr#12345',
      roleId: roleId,
      actor: owner,
    );
    final user = await repo.login(username: 'manager', password: 'Mgr#12345');
    return user!;
  }

  test('Owner sits at the top of the hierarchy', () async {
    final owner = await loginOwner();
    expect(owner.isOwner, isTrue);
    expect(owner.effectiveLevel, AuthRepository.ownerLevel);
    expect(owner.permissions, isNotEmpty);
  });

  test('A user cannot grant permissions they do not hold', () async {
    final owner = await loginOwner();
    // مدير يملك صلاحية إدارة المستخدمين فقط
    final manager = await createAndLoginManager(owner);

    expect(
      () => repo.createRole(
        name: 'دور مهرب',
        permissions: {PermissionKeys.settingsUsersManage, ...PermissionCatalog.allKeys.take(5)},
        hierarchyLevel: 10,
        actor: manager,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('A user cannot create a role at or above their own level', () async {
    final owner = await loginOwner();
    final manager = await createAndLoginManager(owner);

    // مساوٍ لمستواه
    expect(
      () => repo.createRole(
        name: 'مدير مواز',
        permissions: {PermissionKeys.settingsUsersManage},
        hierarchyLevel: 80,
        actor: manager,
      ),
      throwsA(isA<StateError>()),
    );

    // أعلى من مستواه
    expect(
      () => repo.createRole(
        name: 'فوق المدير',
        permissions: {PermissionKeys.settingsUsersManage},
        hierarchyLevel: 95,
        actor: manager,
      ),
      throwsA(isA<StateError>()),
    );

    // أدنى منه: مسموح
    final okId = await repo.createRole(
      name: 'موظف مكتب',
      permissions: {PermissionKeys.settingsUsersManage},
      hierarchyLevel: 20,
      actor: manager,
    );
    expect(okId, greaterThan(0));
  });

  test('A user cannot promote their own role above their level', () async {
    final owner = await loginOwner();
    final manager = await createAndLoginManager(owner);

    expect(
      () => repo.updateRole(
        id: manager.roleId,
        name: 'مدير المكتب',
        permissions: {PermissionKeys.settingsUsersManage},
        hierarchyLevel: AuthRepository.ownerLevel,
        actor: manager,
      ),
      throwsA(isA<StateError>()),
    );

    // يبقى المستوى كما هو
    expect(await repo.hierarchyLevelForRole(manager.roleId), 80);
  });

  test('A user cannot edit, disable or reset the password of a higher user', () async {
    final owner = await loginOwner();
    final manager = await createAndLoginManager(owner);

    expect(
      () => repo.setUserActive(owner.id, false, actor: manager),
      throwsA(isA<StateError>()),
    );
    expect(
      () => repo.changeUserPassword(id: owner.id, newPassword: 'Hacked#123', actor: manager),
      throwsA(isA<StateError>()),
    );
    expect(
      () => repo.updateUser(
        id: owner.id,
        fullName: 'مخترق',
        username: 'owner',
        roleId: owner.roleId,
        actor: manager,
      ),
      throwsA(isA<StateError>()),
    );

    // المالك ما زال فعالاً وكلمة مروره لم تتغير
    final stillOwner = await repo.login(username: 'owner', password: 'Owner#123');
    expect(stillOwner, isNotNull);
    expect(stillOwner!.isActive, isTrue);
  });

  test('A user cannot assign themselves a higher role', () async {
    final owner = await loginOwner();
    final manager = await createAndLoginManager(owner);

    expect(
      () => repo.updateUser(
        id: manager.id,
        fullName: 'مدير',
        username: 'manager',
        roleId: owner.roleId, // دور المالك
        actor: manager,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('A user cannot create another user holding a higher role', () async {
    final owner = await loginOwner();
    final manager = await createAndLoginManager(owner);

    expect(
      () => repo.createUser(
        fullName: 'مالك مزيف',
        username: 'fake_owner',
        password: 'Fake#12345',
        roleId: owner.roleId,
        actor: manager,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('Duplicating a role keeps its level and stays guarded', () async {
    final owner = await loginOwner();
    final manager = await createAndLoginManager(owner);

    // المدير لا يستطيع نسخ دور المالك لأن مستواه يعلوه
    expect(
      () => repo.duplicateRole(owner.roleId, newName: 'نسخة المالك', actor: manager),
      throwsA(isA<StateError>()),
    );

    // المالك يستطيع، والنسخة تحتفظ بالمستوى
    final copyId = await repo.duplicateRole(owner.roleId, newName: 'نسخة المالك', actor: owner);
    expect(await repo.hierarchyLevelForRole(copyId), AuthRepository.ownerLevel);
  });

  test('A manager can still manage lower users normally', () async {
    final owner = await loginOwner();
    final manager = await createAndLoginManager(owner);

    final clerkRole = await repo.createRole(
      name: 'موظفة مكتب',
      permissions: {PermissionKeys.settingsUsersManage},
      hierarchyLevel: 20,
      actor: manager,
    );
    final clerkId = await repo.createUser(
      fullName: 'موظفة',
      username: 'clerk',
      password: 'Clerk#1234',
      roleId: clerkRole,
      actor: manager,
    );

    // لا يرمي استثناء
    await repo.changeUserPassword(id: clerkId, newPassword: 'NewPass#123', actor: manager);
    await repo.setUserActive(clerkId, false, actor: manager);

    final users = await repo.getUsers();
    final clerk = users.firstWhere((u) => u.id == clerkId);
    expect(clerk.isActive, isFalse);
    expect(clerk.hierarchyLevel, 20);
  });

  test('Last active owner cannot be disabled', () async {
    final owner = await loginOwner();
    expect(
      () => repo.setUserActive(owner.id, false, actor: owner),
      throwsA(isA<StateError>()),
    );
  });
}
