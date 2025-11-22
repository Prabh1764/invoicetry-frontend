import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  late final Dio _dio;
  // Configure FlutterSecureStorage for iOS compatibility
  // Using simpler configuration - the package handles iOS Keychain automatically
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      synchronizable: false, // Prevent iCloud sync issues
    ),
    webOptions: WebOptions(
      dbName: 'FlutterSecureStorage',
      publicKey: 'FlutterSecureStoragePublicKey',
    ),
  );
  static const String _tokenKey = 'accessToken';
  final String baseUrl;

  static String _getBaseUrl() {
    // For web, use Render backend URL (production) or localhost (development)
    if (kIsWeb) {
      // Safely try to get env URL - dotenv might not be loaded in production
      String? envUrl;
      try {
        envUrl = dotenv.env['BACKEND_BASE_URL'];
      } catch (e) {
        debugPrint('⚠️ [API_CLIENT] Could not access dotenv (normal in production): $e');
      }
      
      if (envUrl != null && envUrl.isNotEmpty && !envUrl.contains('localhost')) {
        debugPrint('🌐 [API_CLIENT] Using Render backend URL from .env for web');
        return envUrl;
      }
      
      // Check if running on localhost (development) or production
      try {
        // In production (Render/Netlify), use Render backend
        // In development (localhost), use local backend
        final isLocalhost = Uri.base.host == 'localhost' || 
                          Uri.base.host == '127.0.0.1' ||
                          Uri.base.host.isEmpty;
        if (isLocalhost) {
          debugPrint('🌐 [API_CLIENT] Running locally, using localhost:3000');
          return 'http://localhost:3000';
        } else {
          debugPrint('🌐 [API_CLIENT] Running in production, using Render backend');
          return 'https://invoictry-backend.onrender.com';
        }
      } catch (e) {
        debugPrint('⚠️ [API_CLIENT] Error detecting environment, using Render backend: $e');
        return 'https://invoictry-backend.onrender.com';
      }
    }
    
    // For mobile devices:
    // 1. If env URL is set and contains 'ngrok', use it (for remote access)
    // 2. Otherwise, use local network IP (for same-network access, no rate limits)
    String? envUrl;
    try {
      envUrl = dotenv.env['BACKEND_BASE_URL'];
    } catch (e) {
      debugPrint('⚠️ [API_CLIENT] Could not access dotenv (normal in production): $e');
    }
    
    if (envUrl != null && envUrl.isNotEmpty) {
      // If ngrok URL is explicitly set, use it (for remote testing)
      if (envUrl.contains('ngrok')) {
        debugPrint('🌐 [API_CLIENT] Using ngrok URL from .env (for remote access)');
        return envUrl;
      }
      // If local IP or .local name is set in .env, use it
      if (envUrl.contains('192.168') || 
          envUrl.contains('localhost') || 
          envUrl.contains('127.0.0.1') ||
          envUrl.contains('.local')) {
        debugPrint('🌐 [API_CLIENT] Using local network URL from .env');
        return envUrl;
      }
    }
    
    // Default for mobile on same network - try Bonjour name first, then IP
    // Bonjour (.local) often works better than IP addresses
    const bonjourUrl = 'http://prabhs-macbook-pro.local:3000';
    const ipUrl = 'http://192.168.2.75:3000';
    
    debugPrint('🌐 [API_CLIENT] Using default local network URL');
    debugPrint('   - Bonjour: $bonjourUrl');
    debugPrint('   - IP fallback: $ipUrl');
    // Try Bonjour first - it's more reliable on local networks
    return bonjourUrl;
  }

  ApiClient() : baseUrl = _getBaseUrl() {
    debugPrint('🌐 [API_CLIENT] Initializing with baseUrl: $baseUrl');
    try {
      final envUrl = dotenv.env['BACKEND_BASE_URL'];
      debugPrint('   - BACKEND_BASE_URL from .env: ${envUrl ?? 'NOT SET'}');
    } catch (e) {
      debugPrint('   - BACKEND_BASE_URL from .env: NOT SET (dotenv not available)');
    }
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        // Don't set Content-Type here - let Dio set it automatically
        // For multipart/form-data, Dio will set it with boundary
        // Skip ngrok warning page for free tier
        if (baseUrl.contains('ngrok')) 'ngrok-skip-browser-warning': 'true',
      },
      // Render free tier can take 30-90 seconds to wake up, so increase timeout
      connectTimeout: const Duration(seconds: 120), // 2 minutes for Render cold starts
      receiveTimeout: const Duration(seconds: 120), // 2 minutes for large responses
      responseType: ResponseType.json, // Explicitly set JSON response type
    ));
    
    // Configure JSON decoder to handle web properly
    _dio.transformer = BackgroundTransformer()..jsonDecodeCallback = (String data) {
      try {
        // For web, ensure proper JSON parsing
        return jsonDecode(data);
      } catch (e) {
        debugPrint('❌ [API_CLIENT] JSON decode error: $e');
        debugPrint('   - Data: ${data.substring(0, data.length > 100 ? 100 : data.length)}...');
        rethrow;
      }
    };
    
    debugPrint('✅ [API_CLIENT] Dio instance created');

    // Add LogInterceptor to see full response shapes
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: false,
      responseHeader: false,
      error: true,
      logPrint: (obj) => debugPrint('📋 [DIO_LOG] $obj'),
    ));

    // Request interceptor to add auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          debugPrint('📤 [API_CLIENT] Request: ${options.method} ${options.uri}');
          debugPrint('   - Base URL: $baseUrl');
          if (!kIsWeb) {
            debugPrint('   - Platform: ${Platform.isIOS ? "iOS" : Platform.isAndroid ? "Android" : "Unknown"}');
          } else {
            debugPrint('   - Platform: Web');
          }
          
          try {
            final token = await _storage.read(key: _tokenKey);
            if (token != null && token.isNotEmpty) {
              // Ensure token doesn't have extra whitespace
              final cleanToken = token.trim();
              options.headers['Authorization'] = 'Bearer $cleanToken';
              debugPrint('   ✅ Auth token added (length: ${cleanToken.length})');
              debugPrint('   - Token preview: ${cleanToken.substring(0, cleanToken.length > 30 ? 30 : cleanToken.length)}...');
              debugPrint('   - Authorization header: Bearer ${cleanToken.substring(0, 20)}...');
            } else {
              // Check if this is a public endpoint (login, register, etc.)
              final isPublicEndpoint = options.path.contains('/auth/login') || 
                                      options.path.contains('/auth/register') ||
                                      options.path.contains('/pdf/preview') ||
                                      options.path.contains('/health');
              
              if (!isPublicEndpoint) {
                debugPrint('   ⚠️ No auth token found in storage!');
                debugPrint('   ⚠️ Token value: ${token ?? "NULL"}');
                debugPrint('   ⚠️ Storage key: $_tokenKey');
                debugPrint('   ⚠️ This request will likely fail with 401/403');
              } else {
                debugPrint('   ℹ️ No auth token needed for public endpoint: ${options.path}');
              }
            }
          } catch (e, stack) {
            debugPrint('   ❌ [API_CLIENT] Error reading token from storage: $e');
            debugPrint('   - Stack: $stack');
            debugPrint('   ⚠️ Request will proceed without auth token (will likely fail)');
          }
          // Don't override Content-Type if it's already set (e.g., for multipart/form-data)
          if (options.data is FormData) {
            // FormData will set Content-Type automatically with boundary
            options.headers.remove('Content-Type');
          } else if (!options.headers.containsKey('Content-Type')) {
            options.headers['Content-Type'] = 'application/json';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('📥 [API_CLIENT] Response: ${response.statusCode} ${response.requestOptions.uri}');
          debugPrint('   - Response type: ${response.data.runtimeType}');
          if (response.data is Map) {
            debugPrint('   - Response keys: ${(response.data as Map).keys.toList()}');
          } else if (response.data is List) {
            debugPrint('   - Response is List with ${(response.data as List).length} items');
          }
          return handler.next(response);
        },
        onError: (error, handler) async {
          debugPrint('❌ [API_CLIENT] Error: ${error.type}');
          debugPrint('   - Message: ${error.message}');
          debugPrint('   - Request: ${error.requestOptions.method} ${error.requestOptions.uri}');
          
          // Handle connection errors and retry logic for Render cold starts
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError) {
            debugPrint('⚠️ [API_CLIENT] Connection/timeout error - Backend may be waking up (Render free tier)');
            debugPrint('   - Check if backend is running at $baseUrl');
            debugPrint('   - Render free tier can take 30-90 seconds to wake up');
            
            // Retry once for Render cold starts (only for Render URLs)
            if (baseUrl.contains('onrender.com') || baseUrl.contains('render.com')) {
              final retryCount = error.requestOptions.extra['retryCount'] ?? 0;
              if (retryCount < 1) {
                debugPrint('🔄 [API_CLIENT] Retrying request (Render cold start - attempt ${retryCount + 1})');
                await Future.delayed(const Duration(seconds: 5)); // Wait 5 seconds before retry
                error.requestOptions.extra['retryCount'] = retryCount + 1;
                try {
                  final response = await _dio.fetch(error.requestOptions);
                  return handler.resolve(response);
                } catch (e) {
                  // If retry also fails, continue with error
                  debugPrint('❌ [API_CLIENT] Retry also failed: $e');
                }
              }
            }
          }
          
          if (error.response != null) {
            debugPrint('   - Response: ${error.response?.statusCode}');
            debugPrint('   - Response data: ${error.response?.data}');
          }
          if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
            // Check if this is an ngrok rate limit error (not an auth error)
            final responseData = error.response?.data;
            final responseText = responseData?.toString() ?? '';
            final isNgrokRateLimit = responseText.contains('exceeded your limit') ||
                                    responseText.contains('ERR_NGROK') ||
                                    responseText.contains('ngrok.com/billing');
            
            if (isNgrokRateLimit) {
              debugPrint('   ⚠️ [API_CLIENT] Ngrok rate limit error (not authentication)');
              debugPrint('   - This is an ngrok free tier rate limit (360 req/min)');
              debugPrint('   - Will reset in 1 minute');
              debugPrint('   - Token is valid, just wait and retry');
              // Don't clear token - this is not an auth error
              return handler.next(error);
            }
            
            debugPrint('   ❌ Authentication error (${error.response?.statusCode})');
            final token = await _storage.read(key: _tokenKey);
            final tokenExists = token != null && token.isNotEmpty;
            debugPrint('   - Current token: ${tokenExists ? "EXISTS" : "MISSING"}');
            if (tokenExists) {
              debugPrint('   - Token length: ${token!.length}');
              debugPrint('   - Token preview: ${token.substring(0, token.length > 30 ? 30 : token.length)}...');
            }
            debugPrint('   - Response data: ${error.response?.data}');
            
            // Check if it's a token expiration or invalid token error
            if (responseData is Map) {
              final message = responseData['message']?.toString().toLowerCase() ?? '';
              debugPrint('   - Error message: $message');
              
              if (message.contains('expired') || message.contains('invalid token')) {
                debugPrint('   - Token is expired or invalid - clearing token');
                await _storage.delete(key: _tokenKey);
                return handler.next(error);
              }
            }
            
            // Only clear token and redirect if it's a true auth failure
            // Don't clear on first 403 - might be a temporary issue
            if (error.response?.statusCode == 401 || 
                (error.response?.statusCode == 403 && error.requestOptions.path.contains('/auth/'))) {
              debugPrint('   - Clearing token due to ${error.response?.statusCode}');
              await _storage.delete(key: _tokenKey);
              // Note: Navigation will be handled by the router guard
            } else {
              // For 403 on other endpoints, log but don't clear token immediately
              // Might be a permission issue or temporary auth problem
              debugPrint('   - 403 error on ${error.requestOptions.path} - Keeping token, might be temporary');
              debugPrint('   - This could be:');
              debugPrint('     * Token expired');
              debugPrint('     * Invalid token format');
              debugPrint('     * Token not matching JWT_SECRET');
              debugPrint('     * User not found in database');
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }
}

