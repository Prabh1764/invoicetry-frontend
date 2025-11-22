import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repo.dart';
import '../../../data/services/api_client.dart';
import '../../../data/models/auth_token.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepoProvider = Provider<AuthRepo>((ref) {
  return AuthRepo(ref.watch(apiClientProvider));
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AuthToken?>>((ref) {
  return AuthNotifier(ref.watch(authRepoProvider), ref.watch(apiClientProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<AuthToken?>> {
  final AuthRepo _authRepo;
  final ApiClient _apiClient;
  bool _hasInitialized = false;

  AuthNotifier(this._authRepo, this._apiClient) : super(const AsyncValue.loading()) {
    // Initialize auth state by checking for existing token
    // Use unawaited to prevent blocking, but catch errors
    _initializeAuth().catchError((error, stack) {
      debugPrint('❌ [AUTH] Unhandled error in _initializeAuth: $error');
      debugPrint('   - Stack: $stack');
      // Ensure state is set even on error
      if (!_hasInitialized) {
        state = const AsyncValue.data(null);
      }
    });
  }

  Future<void> _initializeAuth() async {
    if (_hasInitialized) return;
    _hasInitialized = true;
    
    try {
      debugPrint('🔍 [AUTH] Initializing auth state...');
      
      // Check if token exists in storage (with timeout to prevent hanging)
      final tokenString = await _apiClient.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ [AUTH] getToken() timed out, assuming no token');
          return null;
        },
      );
      if (tokenString != null && tokenString.isNotEmpty) {
        debugPrint('✅ [AUTH] Found token in storage (length: ${tokenString.length})');
        debugPrint('   - Token preview: ${tokenString.substring(0, tokenString.length > 30 ? 30 : tokenString.length)}...');
        
        // Restore auth state with the token
        // Token validity will be checked on next API call
        // If invalid, the error interceptor will clear it
        debugPrint('✅ [AUTH] Restoring auth state with token');
        final token = AuthToken(
          accessToken: tokenString,
          user: null, // Will be populated on next successful API call
        );
        state = AsyncValue.data(token);
        debugPrint('✅ [AUTH] Auth state restored with token');
        debugPrint('   - Token restored: ${token.accessToken.substring(0, 20)}...');
      } else {
        debugPrint('⚠️ [AUTH] No token found in storage');
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      debugPrint('❌ [AUTH] Error initializing auth: $e');
      debugPrint('   - Stack: $stack');
      // If check fails, assume not authenticated but don't crash
      state = const AsyncValue.data(null);
    }
  }

  Future<void> _checkAuth() async {
    try {
      final isAuth = await _authRepo.isAuthenticated();
      if (!isAuth) {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      // If check fails, assume not authenticated
      state = const AsyncValue.data(null);
    }
  }

  Future<AuthToken> login(String email, String password) async {
    debugPrint('🔑 [AUTH] Starting login process...');
    state = const AsyncValue.loading();
    try {
      debugPrint('📡 [AUTH] Calling _authRepo.login()...');
      final token = await _authRepo.login(email, password).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Login request timed out. Please check your internet connection and try again.');
        },
      );
      debugPrint('✅ [AUTH] Login successful!');
      debugPrint('   - Token received: ${token.accessToken.substring(0, 30)}...');
      debugPrint('   - User: ${token.user?['email'] ?? 'N/A'}');
      state = AsyncValue.data(token);
      debugPrint('✅ [AUTH] State updated with token');
      return token; // Return the token so caller can use it
    } catch (e, stack) {
      debugPrint('❌ [AUTH] Login failed with error: $e');
      debugPrint('   - Stack: $stack');
      state = AsyncValue.error(e, stack);
      rethrow; // Re-throw so caller can handle error
    }
  }

  Future<void> register(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final token = await _authRepo.register(email, password);
      state = AsyncValue.data(token);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    await _authRepo.logout();
    state = const AsyncValue.data(null);
  }

  Future<bool> isAuthenticated() async {
    return await _authRepo.isAuthenticated();
  }
}

