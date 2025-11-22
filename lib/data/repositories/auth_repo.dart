import '../models/auth_token.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthRepo {
  final AuthService _authService;

  AuthRepo(ApiClient apiClient) : _authService = AuthService(apiClient);

  Future<AuthToken> register(String email, String password) {
    return _authService.register(email, password);
  }

  Future<AuthToken> login(String email, String password) {
    return _authService.login(email, password);
  }

  Future<void> logout() {
    return _authService.logout();
  }

  Future<bool> isAuthenticated() {
    return _authService.isAuthenticated();
  }
}

