import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/auth/permission_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/crypto_utils.dart';
import '../database/database.dart';

class AuthUser {
  final int id;
  final String fullName;
  final String username;
  final int roleId;
  final String roleName;
  final bool isOwner;
  final bool isActive;
  final int? sessionId;
  final Set<String> permissions;

  /// مستوى الدور في الهرم الإداري. الأعلى يدير الأدنى فقط.
  final int hierarchyLevel;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.roleId,
    required this.roleName,
    required this.isOwner,
    required this.isActive,
    this.sessionId,
    this.permissions = const {},
    this.hierarchyLevel = 0,
  });

  /// المستوى الفعلي: المالك دائماً في القمة مهما كان مستوى دوره المخزّن.
  int get effectiveLevel => isOwner ? AuthRepository.ownerLevel : hierarchyLevel;

  AuthUser copyWith({int? sessionId, Set<String>? permissions}) => AuthUser(
        id: id,
        fullName: fullName,
        username: username,
        roleId: roleId,
        roleName: roleName,
        isOwner: isOwner,
        isActive: isActive,
        sessionId: sessionId ?? this.sessionId,
        permissions: permissions ?? this.permissions,
        hierarchyLevel: hierarchyLevel,
      );
}

class AuthRole {
  final int id;
  final String name;
  final String description;
  final bool isSystemRole;
  final bool isActive;
  final int userCount;
  final int permissionCount;
  final Set<String> permissions;

  /// مستوى الدور في الهرم الإداري (مالك 100، مدير 80، محامي أستاذ 60...).
  final int hierarchyLevel;

  const AuthRole({
    required this.id,
    required this.name,
    required this.description,
    required this.isSystemRole,
    required this.isActive,
    this.userCount = 0,
    this.permissionCount = 0,
    this.permissions = const {},
    this.hierarchyLevel = 0,
  });
}

class UserSessionRecord {
  final int id;
  final String username;
  final String fullName;
  final String roleName;
  final DateTime loginAt;
  final DateTime? logoutAt;
  final DateTime? lastActiveAt;
  final String status;
  final String? failedReason;

  const UserSessionRecord({
    required this.id,
    required this.username,
    required this.fullName,
    required this.roleName,
    required this.loginAt,
    this.logoutAt,
    this.lastActiveAt,
    required this.status,
    this.failedReason,
  });
}

class AuditEventRecord {
  final int id;
  final int? sessionId;
  final int? userId;
  final String username;
  final String fullName;
  final String roleName;
  final String action;
  final String category;
  final String entityType;
  final String entityId;
  final String entityTitle;
  final String description;
  final String severity;
  final String? beforeJson;
  final String? afterJson;
  final DateTime createdAt;

  const AuditEventRecord({
    required this.id,
    this.sessionId,
    this.userId,
    required this.username,
    required this.fullName,
    required this.roleName,
    required this.action,
    required this.category,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    required this.description,
    required this.severity,
    this.beforeJson,
    this.afterJson,
    required this.createdAt,
  });
}

class AuthRepository {
  final AppDatabase _db;
  AuthRepository(this._db);

  /// مستوى مالك المكتب: أعلى مستوى في الهرم.
  static const int ownerLevel = 100;

  Future<void> ensureReady() => _db.ensureAuthTables();

  // ===========================================================================
  // منع التصعيد في الصلاحيات (Privilege Escalation Guards)
  //
  // القاعدة: لا يجوز لمستخدم أن يمنح صلاحية لا يملكها، ولا أن ينشئ أو يعدّل
  // دوراً أو مستخدماً بمستوى أعلى من مستواه أو مساوٍ له، ولا أن يعدّل على نفسه
  // بما يرفع مستواه. المالك وحده فوق هذه القيود.
  // ===========================================================================

  /// مستوى الدور المخزّن في قاعدة البيانات.
  Future<int> hierarchyLevelForRole(int roleId) async {
    await ensureReady();
    final rows = await _db.customSelect(
      'SELECT hierarchy_level FROM app_roles WHERE id = ? LIMIT 1',
      variables: [Variable.withInt(roleId)],
    ).get();
    if (rows.isEmpty) return 0;
    return (rows.first.data['hierarchy_level'] as int?) ?? 0;
  }

  /// يمنع منح صلاحيات لا يملكها المنفّذ نفسه.
  void _assertNoPermissionEscalation(AuthUser? actor, Iterable<String> permissions) {
    if (actor == null || actor.isOwner) return;
    final granted = permissions.toSet();
    final missing = granted.difference(actor.permissions);
    if (missing.isNotEmpty) {
      throw StateError('لا يمكنك منح صلاحيات لا تملكها: ${missing.join('، ')}');
    }
  }

  /// يمنع التعامل مع دور مستواه أعلى من المنفّذ أو مساوٍ له.
  Future<void> _assertCanManageLevel(AuthUser? actor, int targetLevel, {required String action}) async {
    if (actor == null || actor.isOwner) return;
    if (targetLevel >= actor.effectiveLevel) {
      throw StateError('لا يمكنك $action بمستوى صلاحيات يساوي مستواك أو يعلوه');
    }
  }

  /// يمنع تعديل مستخدم أعلى أو مساوٍ في الهرم (مع السماح بتعديل الحساب الشخصي).
  Future<void> _assertCanManageUser(AuthUser? actor, int targetUserId, {required String action}) async {
    if (actor == null || actor.isOwner) return;
    if (actor.id == targetUserId) return;
    final rows = await _db.customSelect('''
      SELECT u.is_owner, r.hierarchy_level
      FROM app_users u JOIN app_roles r ON r.id = u.role_id
      WHERE u.id = ? LIMIT 1
    ''', variables: [Variable.withInt(targetUserId)]).get();
    if (rows.isEmpty) return;
    final data = rows.first.data;
    final targetIsOwner = (data['is_owner'] as int? ?? 0) == 1;
    final targetLevel = targetIsOwner ? ownerLevel : ((data['hierarchy_level'] as int?) ?? 0);
    if (targetLevel >= actor.effectiveLevel) {
      throw StateError('لا يمكنك $action مستخدماً بمستوى صلاحيات يساوي مستواك أو يعلوه');
    }
  }

  Future<bool> ownerExists() async {
    await ensureReady();
    await expireOpenSessions();
    await _ensureOwnerPermissions();
    final rows = await _db.customSelect('SELECT COUNT(*) AS c FROM app_users WHERE is_owner = 1').get();
    return (rows.first.data['c'] as int) > 0;
  }

  Future<int> createOwner({
    required String fullName,
    required String username,
    required String password,
  }) async {
    await ensureReady();
    final roleId = await _createRoleInternal(
      name: 'مالك المكتب',
      description: 'الدور الأساسي بصلاحيات كاملة',
      isSystemRole: true,
      permissions: PermissionCatalog.allKeys,
      hierarchyLevel: ownerLevel,
    );
    final userId = await _insertUser(
      fullName: fullName,
      username: username,
      password: password,
      roleId: roleId,
      isOwner: true,
    );
    await logAudit(
      user: null,
      action: 'create_owner',
      category: 'users',
      entityType: 'user',
      entityId: '$userId',
      entityTitle: fullName,
      description: 'إنشاء مالك المكتب الأساسي للتطبيق',
      severity: 'critical',
    );
    return userId;
  }

  Future<AuthUser?> login({required String username, required String password}) async {
    await ensureReady();
    final rows = await _db.customSelect(
      '''
      SELECT u.*, r.name AS role_name, r.hierarchy_level AS hierarchy_level
      FROM app_users u
      JOIN app_roles r ON r.id = u.role_id
      WHERE u.username = ?
      LIMIT 1
      ''',
      variables: [Variable.withString(username.trim())],
    ).get();

    if (rows.isEmpty) {
      await _insertFailedSession(username.trim(), 'اسم الدخول غير موجود');
      return null;
    }

    final data = rows.first.data;
    final active = (data['is_active'] as int) == 1;
    final hash = data['password_hash'] as String;
    if (!active || !CryptoUtils.verifyPassword(password, hash)) {
      await _insertFailedSession(username.trim(), active ? 'كلمة مرور غير صحيحة' : 'المستخدم معطل');
      return null;
    }

    final roleId = data['role_id'] as int;
    final permissions = await permissionsForRole(roleId);
    final user = AuthUser(
      id: data['id'] as int,
      fullName: data['full_name'] as String,
      username: data['username'] as String,
      roleId: roleId,
      roleName: data['role_name'] as String,
      isOwner: (data['is_owner'] as int) == 1,
      isActive: active,
      permissions: permissions,
      hierarchyLevel: (data['hierarchy_level'] as int?) ?? 0,
    );
    final sessionId = await _insertSession(user, 'active');
    await _db.customStatement('UPDATE app_users SET last_login_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [user.id]);
    final logged = user.copyWith(sessionId: sessionId);
    await logAudit(
      user: logged,
      action: 'login',
      category: 'auth',
      entityType: 'user',
      entityId: '${user.id}',
      entityTitle: user.fullName,
      description: 'تسجيل دخول ناجح',
      severity: 'info',
    );
    return logged;
  }


  Future<void> expireOpenSessions() async {
    await ensureReady();
    await _db.customStatement(
      "UPDATE user_sessions SET status = 'expired', logout_at = COALESCE(logout_at, CURRENT_TIMESTAMP), last_active_at = COALESCE(last_active_at, CURRENT_TIMESTAMP) WHERE status = 'active' AND logout_at IS NULL",
    );
  }

  Future<void> touchSession(int sessionId) async {
    await ensureReady();
    await _db.customStatement(
      "UPDATE user_sessions SET last_active_at = CURRENT_TIMESTAMP WHERE id = ? AND status = 'active'",
      [sessionId],
    );
  }

  Future<void> logout(AuthUser user) async {
    await ensureReady();
    if (user.sessionId != null) {
      await _db.customStatement(
        "UPDATE user_sessions SET logout_at = CURRENT_TIMESTAMP, last_active_at = CURRENT_TIMESTAMP, status = 'closed' WHERE id = ?",
        [user.sessionId],
      );
    }
    await logAudit(
      user: user,
      action: 'logout',
      category: 'auth',
      entityType: 'user',
      entityId: '${user.id}',
      entityTitle: user.fullName,
      description: 'تسجيل خروج',
      severity: 'info',
    );
  }

  Future<Set<String>> permissionsForRole(int roleId) async {
    await ensureReady();
    final rows = await _db.customSelect(
      'SELECT permission_key FROM role_permissions WHERE role_id = ?',
      variables: [Variable.withInt(roleId)],
    ).get();
    return rows.map((r) => r.data['permission_key'] as String).toSet();
  }

  Future<List<AuthRole>> getRoles() async {
    await ensureReady();
    final rows = await _db.customSelect('''
      SELECT r.*,
        (SELECT COUNT(*) FROM app_users u WHERE u.role_id = r.id) AS user_count,
        (SELECT COUNT(*) FROM role_permissions p WHERE p.role_id = r.id) AS permission_count
      FROM app_roles r
      ORDER BY r.hierarchy_level DESC, r.is_system_role DESC, r.name ASC
    ''').get();
    final result = <AuthRole>[];
    for (final row in rows) {
      final d = row.data;
      result.add(AuthRole(
        id: d['id'] as int,
        name: d['name'] as String,
        description: (d['description'] as String?) ?? '',
        isSystemRole: (d['is_system_role'] as int) == 1,
        isActive: (d['is_active'] as int) == 1,
        userCount: d['user_count'] as int,
        permissionCount: d['permission_count'] as int,
        permissions: await permissionsForRole(d['id'] as int),
        hierarchyLevel: (d['hierarchy_level'] as int?) ?? 0,
      ));
    }
    return result;
  }

  Future<List<AuthUser>> getUsers() async {
    await ensureReady();
    final rows = await _db.customSelect('''
      SELECT u.*, r.name AS role_name, r.hierarchy_level AS hierarchy_level
      FROM app_users u JOIN app_roles r ON r.id = u.role_id
      ORDER BY u.is_owner DESC, u.full_name ASC
    ''').get();
    return rows.map((row) {
      final d = row.data;
      return AuthUser(
        id: d['id'] as int,
        fullName: d['full_name'] as String,
        username: d['username'] as String,
        roleId: d['role_id'] as int,
        roleName: d['role_name'] as String,
        isOwner: (d['is_owner'] as int) == 1,
        isActive: (d['is_active'] as int) == 1,
        hierarchyLevel: (d['hierarchy_level'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<int> createRole({
    required String name,
    String description = '',
    required Iterable<String> permissions,
    int hierarchyLevel = 0,
    AuthUser? actor,
  }) async {
    _assertNoPermissionEscalation(actor, permissions);
    await _assertCanManageLevel(actor, hierarchyLevel, action: 'إنشاء دور');
    final id = await _createRoleInternal(
      name: name,
      description: description,
      permissions: permissions,
      hierarchyLevel: hierarchyLevel,
    );
    await logAudit(user: actor, action: 'create', category: 'roles', entityType: 'role', entityId: '$id', entityTitle: name, description: 'إنشاء دور: $name', severity: 'critical');
    return id;
  }

  Future<void> updateRole({
    required int id,
    required String name,
    String description = '',
    required Iterable<String> permissions,
    int? hierarchyLevel,
    AuthUser? actor,
  }) async {
    _assertNoPermissionEscalation(actor, permissions);
    final currentLevel = await hierarchyLevelForRole(id);
    // لا يجوز تعديل دور يعلو المنفّذ، ولا رفع دور فوق مستواه.
    await _assertCanManageLevel(actor, currentLevel, action: 'تعديل دور');
    if (hierarchyLevel != null) {
      await _assertCanManageLevel(actor, hierarchyLevel, action: 'ترقية دور');
    }
    final before = await permissionsForRole(id);
    await _db.transaction(() async {
      if (hierarchyLevel == null) {
        await _db.customStatement('UPDATE app_roles SET name = ?, description = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [name, description, id]);
      } else {
        await _db.customStatement('UPDATE app_roles SET name = ?, description = ?, hierarchy_level = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [name, description, hierarchyLevel, id]);
      }
      await _db.customStatement('DELETE FROM role_permissions WHERE role_id = ?', [id]);
      for (final key in permissions.toSet()) {
        await _db.customStatement('INSERT OR IGNORE INTO role_permissions(role_id, permission_key) VALUES(?, ?)', [id, key]);
      }
    });
    await logAudit(
      user: actor,
      action: 'permission_change',
      category: 'roles',
      entityType: 'role',
      entityId: '$id',
      entityTitle: name,
      description: 'تعديل صلاحيات الدور: $name',
      before: {'permissions': before.toList()},
      after: {'permissions': permissions.toSet().toList()},
      severity: 'critical',
    );
  }

  Future<int> createUser({required String fullName, required String username, required String password, required int roleId, String? phone, String? email, AuthUser? actor}) async {
    await _assertCanManageLevel(actor, await hierarchyLevelForRole(roleId), action: 'إنشاء مستخدم');
    final id = await _insertUser(fullName: fullName, username: username, password: password, roleId: roleId, phone: phone, email: email);
    await logAudit(user: actor, action: 'create', category: 'users', entityType: 'user', entityId: '$id', entityTitle: fullName, description: 'إنشاء مستخدم: $fullName', severity: 'critical');
    return id;
  }


  Future<void> updateUser({
    required int id,
    required String fullName,
    required String username,
    required int roleId,
    String? phone,
    String? email,
    AuthUser? actor,
  }) async {
    await ensureReady();
    final rows = await _db.customSelect('SELECT full_name, username, role_id, is_owner FROM app_users WHERE id = ?', variables: [Variable.withInt(id)]).get();
    if (rows.isEmpty) return;
    await _assertCanManageUser(actor, id, action: 'تعديل');
    // منع إسناد دور يعلو مستوى المنفّذ (بما في ذلك ترقية النفس).
    await _assertCanManageLevel(actor, await hierarchyLevelForRole(roleId), action: 'إسناد دور');
    final before = rows.first.data;
    await _db.customStatement('''
      UPDATE app_users
      SET full_name = ?, username = ?, role_id = ?, phone = ?, email = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    ''', [fullName, username.trim(), roleId, phone, email, id]);
    await logAudit(
      user: actor,
      action: 'update',
      category: 'users',
      entityType: 'user',
      entityId: '$id',
      entityTitle: fullName,
      description: 'تعديل مستخدم: $fullName',
      before: {'fullName': before['full_name'], 'username': before['username'], 'roleId': before['role_id']},
      after: {'fullName': fullName, 'username': username.trim(), 'roleId': roleId},
      severity: 'critical',
    );
  }

  Future<void> changeUserPassword({required int id, required String newPassword, AuthUser? actor}) async {
    await ensureReady();
    final rows = await _db.customSelect('SELECT full_name FROM app_users WHERE id = ?', variables: [Variable.withInt(id)]).get();
    if (rows.isEmpty) return;
    await _assertCanManageUser(actor, id, action: 'تغيير كلمة مرور');
    await _db.customStatement('UPDATE app_users SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [CryptoUtils.hashPassword(newPassword), id]);
    await logAudit(user: actor, action: 'password_change', category: 'users', entityType: 'user', entityId: '$id', entityTitle: rows.first.data['full_name'] as String, description: 'تغيير كلمة مرور مستخدم', severity: 'critical');
  }

  Future<void> setRoleActive(int id, bool active, {AuthUser? actor}) async {
    await ensureReady();
    final rows = await _db.customSelect('SELECT name, is_system_role, hierarchy_level FROM app_roles WHERE id = ?', variables: [Variable.withInt(id)]).get();
    if (rows.isEmpty) return;
    await _assertCanManageLevel(actor, (rows.first.data['hierarchy_level'] as int?) ?? 0, action: active ? 'تفعيل دور' : 'تعطيل دور');
    if ((rows.first.data['is_system_role'] as int) == 1 && !active) throw StateError('لا يمكن تعطيل دور نظامي');
    if (!active) {
      final users = await _db.customSelect('SELECT COUNT(*) AS c FROM app_users WHERE role_id = ? AND is_active = 1', variables: [Variable.withInt(id)]).get();
      if ((users.first.data['c'] as int) > 0) throw StateError('لا يمكن تعطيل دور مرتبط بمستخدمين فعالين');
    }
    await _db.customStatement('UPDATE app_roles SET is_active = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [active ? 1 : 0, id]);
    await logAudit(user: actor, action: active ? 'enable' : 'disable', category: 'roles', entityType: 'role', entityId: '$id', entityTitle: rows.first.data['name'] as String, description: active ? 'تفعيل دور' : 'تعطيل دور', severity: 'critical');
  }

  Future<int> duplicateRole(int id, {required String newName, AuthUser? actor}) async {
    await ensureReady();
    final rows = await _db.customSelect('SELECT description, hierarchy_level FROM app_roles WHERE id = ?', variables: [Variable.withInt(id)]).get();
    if (rows.isEmpty) throw StateError('الدور غير موجود');
    final permissions = await permissionsForRole(id);
    final sourceLevel = (rows.first.data['hierarchy_level'] as int?) ?? 0;
    final newId = await createRole(
      name: newName,
      description: rows.first.data['description'] as String? ?? '',
      permissions: permissions,
      hierarchyLevel: sourceLevel,
      actor: actor,
    );
    await logAudit(user: actor, action: 'duplicate', category: 'roles', entityType: 'role', entityId: '$newId', entityTitle: newName, description: 'نسخ دور من الدور رقم $id', severity: 'critical');
    return newId;
  }

  Future<void> setUserActive(int id, bool active, {AuthUser? actor}) async {
    final rows = await _db.customSelect('SELECT full_name, is_owner FROM app_users WHERE id = ?', variables: [Variable.withInt(id)]).get();
    if (rows.isEmpty) return;
    await _assertCanManageUser(actor, id, action: active ? 'تفعيل' : 'تعطيل');
    if ((rows.first.data['is_owner'] as int) == 1 && !active) {
      final owners = await _db.customSelect('SELECT COUNT(*) AS c FROM app_users WHERE is_owner = 1 AND is_active = 1 AND id <> ?', variables: [Variable.withInt(id)]).get();
      if ((owners.first.data['c'] as int) == 0) {
        throw StateError('لا يمكن تعطيل آخر مالك للمكتب');
      }
    }
    await _db.customStatement('UPDATE app_users SET is_active = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [active ? 1 : 0, id]);
    await logAudit(user: actor, action: active ? 'enable' : 'disable', category: 'users', entityType: 'user', entityId: '$id', entityTitle: rows.first.data['full_name'] as String, description: active ? 'تفعيل مستخدم' : 'تعطيل مستخدم', severity: 'critical');
  }

  Future<List<UserSessionRecord>> getSessions({int limit = 200}) async {
    await ensureReady();
    final rows = await _db.customSelect('SELECT * FROM user_sessions ORDER BY login_at DESC LIMIT ?', variables: [Variable.withInt(limit)]).get();
    return rows.map((r) {
      final d = r.data;
      return UserSessionRecord(
        id: d['id'] as int,
        username: (d['username_snapshot'] as String?) ?? '',
        fullName: (d['user_full_name_snapshot'] as String?) ?? '',
        roleName: (d['role_name_snapshot'] as String?) ?? '',
        loginAt: DateTime.parse(d['login_at'] as String),
        logoutAt: d['logout_at'] == null ? null : DateTime.parse(d['logout_at'] as String),
        lastActiveAt: d['last_active_at'] == null ? null : DateTime.parse(d['last_active_at'] as String),
        status: d['status'] as String,
        failedReason: d['failed_reason'] as String?,
      );
    }).toList();
  }

  Future<List<AuditEventRecord>> getAuditEvents({int limit = 300}) async {
    await ensureReady();
    final rows = await _db.customSelect('SELECT * FROM audit_events ORDER BY created_at DESC LIMIT ?', variables: [Variable.withInt(limit)]).get();
    return rows.map((r) {
      final d = r.data;
      return AuditEventRecord(
        id: d['id'] as int,
        sessionId: d['session_id'] as int?,
        userId: d['user_id'] as int?,
        username: (d['username_snapshot'] as String?) ?? 'system',
        fullName: (d['user_full_name_snapshot'] as String?) ?? 'النظام',
        roleName: (d['role_name_snapshot'] as String?) ?? '',
        action: d['action'] as String,
        category: d['category'] as String,
        entityType: (d['entity_type'] as String?) ?? '',
        entityId: (d['entity_id'] as String?) ?? '',
        entityTitle: (d['entity_title'] as String?) ?? '',
        description: (d['description'] as String?) ?? '',
        severity: d['severity'] as String,
        beforeJson: d['before_json'] as String?,
        afterJson: d['after_json'] as String?,
        createdAt: DateTime.parse(d['created_at'] as String),
      );
    }).toList();
  }

  Future<void> logAudit({
    AuthUser? user,
    required String action,
    required String category,
    String entityType = '',
    String entityId = '',
    String entityTitle = '',
    String description = '',
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    String severity = 'info',
  }) async {
    await ensureReady();
    await _db.customStatement('''
      INSERT INTO audit_events(
        session_id, user_id, username_snapshot, user_full_name_snapshot, role_name_snapshot,
        action, category, entity_type, entity_id, entity_title, description, before_json, after_json, severity, device_name
      ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      user?.sessionId,
      user?.id,
      user?.username ?? 'system',
      user?.fullName ?? 'النظام',
      user?.roleName ?? '',
      action,
      category,
      entityType,
      entityId,
      entityTitle,
      description,
      before == null ? null : jsonEncode(before),
      after == null ? null : jsonEncode(after),
      severity,
      AppConstants.appDisplayName,
    ]);
  }


  Future<void> _ensureOwnerPermissions() async {
    final rows = await _db.customSelect('''
      SELECT DISTINCT r.id AS role_id
      FROM app_users u JOIN app_roles r ON r.id = u.role_id
      WHERE u.is_owner = 1
    ''').get();
    for (final row in rows) {
      final roleId = row.data['role_id'] as int;
      for (final key in PermissionCatalog.allKeys) {
        await _db.customStatement(
          'INSERT OR IGNORE INTO role_permissions(role_id, permission_key) VALUES(?, ?)',
          [roleId, key],
        );
      }
    }
  }

  Future<int> _createRoleInternal({required String name, String description = '', bool isSystemRole = false, required Iterable<String> permissions, int hierarchyLevel = 0}) async {
    await ensureReady();
    await _db.customStatement(
      'INSERT OR IGNORE INTO app_roles(name, description, is_system_role, is_active, hierarchy_level) VALUES(?, ?, ?, 1, ?)',
      [name, description, isSystemRole ? 1 : 0, hierarchyLevel],
    );
    final row = (await _db.customSelect('SELECT id FROM app_roles WHERE name = ?', variables: [Variable.withString(name)]).get()).first;
    final roleId = row.data['id'] as int;
    await _db.customStatement('DELETE FROM role_permissions WHERE role_id = ?', [roleId]);
    for (final key in permissions.toSet()) {
      await _db.customStatement('INSERT OR IGNORE INTO role_permissions(role_id, permission_key) VALUES(?, ?)', [roleId, key]);
    }
    return roleId;
  }

  Future<int> _insertUser({required String fullName, required String username, required String password, required int roleId, bool isOwner = false, String? phone, String? email}) async {
    await _db.customStatement('''
      INSERT INTO app_users(full_name, username, password_hash, role_id, phone, email, is_active, is_owner)
      VALUES(?, ?, ?, ?, ?, ?, 1, ?)
    ''', [fullName, username.trim(), CryptoUtils.hashPassword(password), roleId, phone, email, isOwner ? 1 : 0]);
    final row = (await _db.customSelect('SELECT last_insert_rowid() AS id').get()).first;
    return row.data['id'] as int;
  }

  Future<int> _insertSession(AuthUser user, String status) async {
    await _db.customStatement('''
      INSERT INTO user_sessions(user_id, username_snapshot, user_full_name_snapshot, role_name_snapshot, status, device_name, app_version)
      VALUES(?, ?, ?, ?, ?, ?, ?)
    ''', [user.id, user.username, user.fullName, user.roleName, status, AppConstants.appDisplayName, '1.0.0']);
    final row = (await _db.customSelect('SELECT last_insert_rowid() AS id').get()).first;
    return row.data['id'] as int;
  }

  Future<void> _insertFailedSession(String username, String reason) async {
    await ensureReady();
    await _db.customStatement('''
      INSERT INTO user_sessions(username_snapshot, user_full_name_snapshot, role_name_snapshot, status, failed_reason, device_name, app_version)
      VALUES(?, '', '', 'failed', ?, ?, ?)
    ''', [username, reason, AppConstants.appDisplayName, '1.0.0']);
    await logAudit(
      action: 'login_failed',
      category: 'auth',
      entityType: 'user',
      entityTitle: username,
      description: reason,
      severity: 'warning',
    );
  }
}
