import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/client.dart';
import 'api_client.dart';

class ClientService {
  final ApiClient _apiClient;

  ClientService(this._apiClient);

  Future<List<Client>> getAll({String? search}) async {
    try {
      final response = await _apiClient.dio.get(
        '/clients',
        queryParameters: search != null ? {'search': search} : null,
      );
      
      // Handle both plain array response and wrapped response
      final resData = response.data;
      List<dynamic> clientList;
      
      if (resData is List) {
        // Plain array response
        clientList = resData;
      } else if (resData is Map<String, dynamic>) {
        // Wrapped response { data: [...] }
        final dataField = resData['data'];
        if (dataField is List) {
          clientList = dataField;
        } else {
          clientList = [];
        }
      } else {
        clientList = [];
      }
      
      // Safely parse each client
      return clientList
          .whereType<Map<String, dynamic>>()
          .map((json) {
            try {
              return Client.fromJson(json);
            } catch (e) {
              debugPrint('❌ [CLIENT_SERVICE] Error parsing client: $e');
              debugPrint('   - JSON: $json');
              return null;
            }
          })
          .whereType<Client>()
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Client> getById(String id) async {
    try {
      final response = await _apiClient.dio.get('/clients/$id');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Client.fromJson(data);
      } else {
        throw Exception('Invalid response format: expected Map, got ${data.runtimeType}');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Client> create(Client client) async {
    try {
      final response = await _apiClient.dio.post(
        '/clients',
        data: {
          'name': client.name,
          'email': client.email,
          'phone': client.phone,
          'address': client.address,
          'company': client.company,
          'logoUrl': client.logoUrl,
        },
      );
      return Client.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Client> update(String id, Client client) async {
    try {
      final response = await _apiClient.dio.patch(
        '/clients/$id',
        data: {
          'name': client.name,
          'email': client.email,
          'phone': client.phone,
          'address': client.address,
          'company': client.company,
          'logoUrl': client.logoUrl,
        },
      );
      return Client.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _apiClient.dio.delete('/clients/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
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

