import '../repositories/auth_repository.dart';

class PermissionService {
  final AuthUser? user;
  const PermissionService(this.user);

  bool can(String key) => user?.permissions.contains(key) ?? false;
  bool canAny(Iterable<String> keys) => keys.any(can);
  bool canAll(Iterable<String> keys) => keys.every(can);

  void require(String key) {
    if (!can(key)) {
      throw PermissionDeniedException(key);
    }
  }
}

class PermissionDeniedException implements Exception {
  final String permission;
  PermissionDeniedException(this.permission);
  @override
  String toString() => 'لا تملك صلاحية: $permission';
}
