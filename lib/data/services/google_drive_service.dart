import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class GoogleDriveService {
  final ApiClient _apiClient;

  GoogleDriveService(this._apiClient);

  Future<String> getAuthUrl() async {
    try {
      final response = await _apiClient.dio.get('/google-drive/auth-url');
      return response.data['authUrl'] as String;
    } on DioException catch (e) {
      String errorMessage = 'Failed to get auth URL';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          errorMessage = e.response!.data['message']?.toString() ?? errorMessage;
        } else if (e.response!.data is String) {
          errorMessage = e.response!.data as String;
        }
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> exchangeCode(String code) async {
    try {
      final response = await _apiClient.dio.post(
        '/google-drive/exchange-code',
        data: {'code': code},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      String errorMessage = 'Failed to exchange code';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          errorMessage = e.response!.data['message']?.toString() ?? errorMessage;
        } else if (e.response!.data is String) {
          errorMessage = e.response!.data as String;
        }
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> setupFolder({
    required String refreshToken,
    String? folderName,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/google-drive/setup-folder',
        data: {
          'refreshToken': refreshToken,
          if (folderName != null) 'folderName': folderName,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      String errorMessage = 'Failed to setup folder';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          errorMessage = e.response!.data['message']?.toString() ?? errorMessage;
        } else if (e.response!.data is String) {
          errorMessage = e.response!.data as String;
        }
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await _apiClient.dio.get('/google-drive/status');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {'connected': false};
      }
      throw Exception('Failed to get status: ${e.message}');
    }
  }

  Future<void> disconnect() async {
    try {
      await _apiClient.dio.post('/google-drive/disconnect');
    } on DioException catch (e) {
      throw Exception('Failed to disconnect: ${e.message}');
    }
  }
}

