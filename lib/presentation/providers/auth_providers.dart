import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/audit_service.dart';
import '../../data/services/permission_service.dart';
import 'app_providers.dart';

class AuthState {
  final bool initialized;
  final bool hasOwner;
  final bool isLoading;
  final AuthUser? user;
  final String? error;

  const AuthState({
    this.initialized = false,
    this.hasOwner = false,
    this.isLoading = false,
    this.user,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({bool? initialized, bool? hasOwner, bool? isLoading, AuthUser? user, bool clearUser = false, String? error, bool clearError = false}) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      hasOwner: hasOwner ?? this.hasOwner,
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : user ?? this.user,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(databaseProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(ref.watch(authControllerProvider).user);
});

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService(ref.watch(authRepositoryProvider), ref.watch(authControllerProvider).user);
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  AuthController(this._repo) : super(const AuthState(isLoading: true)) {
    bootstrap();
  }

  Future<void> bootstrap() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final hasOwner = await _repo.ownerExists();
      state = state.copyWith(initialized: true, hasOwner: hasOwner, isLoading: false, clearUser: true);
    } catch (e) {
      state = state.copyWith(initialized: true, isLoading: false, error: '$e');
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final user = await _repo.login(username: username, password: password);
    if (user == null) {
      state = state.copyWith(isLoading: false, error: 'اسم الدخول أو كلمة المرور غير صحيحة');
      return false;
    }
    state = state.copyWith(isLoading: false, hasOwner: true, user: user);
    return true;
  }


  Future<void> touchActivity() async {
    final sessionId = state.user?.sessionId;
    if (sessionId != null) {
      await _repo.touchSession(sessionId);
    }
  }

  Future<void> logout() async {
    final current = state.user;
    if (current != null) {
      await _repo.logout(current);
    }
    state = state.copyWith(clearUser: true);
  }

  Future<void> markOwnerCreated() async {
    final hasOwner = await _repo.ownerExists();
    state = state.copyWith(hasOwner: hasOwner, initialized: true, clearUser: true);
  }
}
