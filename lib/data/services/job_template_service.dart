import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/job_template.dart';
import 'api_client.dart';

class JobTemplateService {
  final ApiClient _apiClient;

  JobTemplateService(this._apiClient);

  Future<List<JobTemplate>> getAll() async {
    try {
      final response = await _apiClient.dio.get('/job-templates');
      
      // Handle both plain array response and wrapped response
      final resData = response.data;
      List<dynamic> templateList;
      
      if (resData is List) {
        // Plain array response
        templateList = resData;
      } else if (resData is Map<String, dynamic>) {
        // Wrapped response { data: [...] }
        final dataField = resData['data'];
        if (dataField is List) {
          templateList = dataField;
        } else {
          templateList = [];
        }
      } else {
        templateList = [];
      }
      
      // Safely parse each template
      return templateList
          .whereType<Map<String, dynamic>>()
          .map((json) {
            try {
              return JobTemplate.fromJson(json);
            } catch (e) {
              debugPrint('❌ [JOB_TEMPLATE_SERVICE] Error parsing template: $e');
              debugPrint('   - JSON: $json');
              return null;
            }
          })
          .whereType<JobTemplate>()
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<JobTemplate> getById(String id) async {
    try {
      final response = await _apiClient.dio.get('/job-templates/$id');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return JobTemplate.fromJson(data);
      } else {
        throw Exception('Invalid response format: expected Map, got ${data.runtimeType}');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<JobTemplate> create(JobTemplate template) async {
    try {
      final response = await _apiClient.dio.post(
        '/job-templates',
        data: {
          'description': template.description,
          'defaultPrice': template.defaultPrice,
          'defaultTaxPct': template.defaultTaxPct,
          'defaultNotes': template.defaultNotes,
        },
      );
      return JobTemplate.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<JobTemplate> update(String id, JobTemplate template) async {
    try {
      final response = await _apiClient.dio.patch(
        '/job-templates/$id',
        data: {
          'description': template.description,
          'defaultPrice': template.defaultPrice,
          'defaultTaxPct': template.defaultTaxPct,
          'defaultNotes': template.defaultNotes,
        },
      );
      return JobTemplate.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _apiClient.dio.delete('/job-templates/$id');
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

