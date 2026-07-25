import '../repositories/auth_repository.dart';

class AuditService {
  final AuthRepository repository;
  final AuthUser? currentUser;
  const AuditService(this.repository, this.currentUser);

  Future<void> log({
    required String action,
    required String category,
    String entityType = '',
    String entityId = '',
    String entityTitle = '',
    String description = '',
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    String severity = 'info',
  }) {
    return repository.logAudit(
      user: currentUser,
      action: action,
      category: category,
      entityType: entityType,
      entityId: entityId,
      entityTitle: entityTitle,
      description: description,
      before: before,
      after: after,
      severity: severity,
    );
  }
}
