import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_token.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<AuthToken> register(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
        },
      );
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map, got ${responseData.runtimeType}');
      }
      final token = AuthToken.fromJson(responseData);
      await _apiClient.setToken(token.accessToken);
      return token;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthToken> login(String email, String password) async {
    try {
      debugPrint('🌐 [AUTH_SERVICE] Making POST request to /auth/login');
      debugPrint('   - Email: $email');
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      debugPrint('✅ [AUTH_SERVICE] Response received: ${response.statusCode}');
      debugPrint('   - Response data type: ${response.data.runtimeType}');
      debugPrint('   - Response data: ${response.data}');
      
      // Safely handle response.data - it might be a Map or dynamic
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        debugPrint('❌ [AUTH_SERVICE] Invalid response format: ${responseData.runtimeType}');
        throw Exception('Invalid response format: expected Map, got ${responseData.runtimeType}');
      }
      
      final token = AuthToken.fromJson(responseData);
      debugPrint('✅ [AUTH_SERVICE] Token parsed successfully');
      
      await _apiClient.setToken(token.accessToken);
      debugPrint('✅ [AUTH_SERVICE] Token saved to secure storage');
      
      return token;
    } on DioException catch (e) {
      debugPrint('❌ [AUTH_SERVICE] DioException: ${e.response?.statusCode}');
      debugPrint('   - Error: ${e.message}');
      debugPrint('   - Response: ${e.response?.data}');
      throw _handleError(e);
    } catch (e, stack) {
      debugPrint('❌ [AUTH_SERVICE] Unexpected error: $e');
      debugPrint('   - Stack: $stack');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _apiClient.clearToken();
  }

  Future<bool> isAuthenticated() async {
    final token = await _apiClient.getToken();
    return token != null && token.isNotEmpty;
  }

  String _handleError(DioException error) {
    // Handle connection timeout (Render cold start)
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Backend is waking up (this can take 30-90 seconds on free tier). Please wait and try again.';
    }
    
    // Handle connection errors (502 Bad Gateway, service down)
    if (error.type == DioExceptionType.connectionError ||
        (error.response != null && error.response!.statusCode == 502)) {
      return 'Backend service is unavailable. Please check if the backend is running on Render.';
    }
    
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('message')) {
        final message = data['message'];
        if (message is String) {
          return message;
        } else {
          return message?.toString() ?? 'An error occurred';
        }
      }
      return 'An error occurred: ${error.response!.statusCode}';
    }
    return error.message ?? 'Network error occurred';
  }
}

