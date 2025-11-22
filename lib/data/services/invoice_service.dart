import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/invoice.dart';
import 'api_client.dart';

class InvoiceService {
  final ApiClient _apiClient;

  InvoiceService(this._apiClient);

  Future<Map<String, dynamic>> getAll({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? search,
    String? documentType,
  }) async {
    try {
      debugPrint('📡 [INVOICE_SERVICE] getAll called with: page=$page, pageSize=$pageSize, status=$status, search=$search');
      
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (status != null) queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (documentType != null && documentType.isNotEmpty) {
        queryParams['documentType'] = documentType;
      }

      debugPrint('📡 [INVOICE_SERVICE] Making GET request to /invoices with query: $queryParams');
      final response = await _apiClient.dio.get(
        '/invoices',
        queryParameters: queryParams,
      );
      debugPrint('📡 [INVOICE_SERVICE] Response status: ${response.statusCode}');
      debugPrint('📡 [INVOICE_SERVICE] Response data type: ${response.data.runtimeType}');
      
      // Handle both wrapped response { data: [...], pagination: {...} } and plain array [...]
      final resData = response.data;
      List<dynamic> invoiceList;
      Map<String, dynamic>? pagination;
      
      if (resData is List) {
        // Plain array response
        invoiceList = resData;
        pagination = null;
      } else if (resData is Map<String, dynamic>) {
        // Wrapped response { data: [...], pagination: {...} }
        final dataField = resData['data'];
        if (dataField is List) {
          invoiceList = dataField;
        } else {
          invoiceList = [];
        }
        pagination = resData['pagination'] is Map<String, dynamic>
            ? resData['pagination'] as Map<String, dynamic>
            : null;
      } else {
        invoiceList = [];
        pagination = null;
      }
      
      // Safely parse each invoice
      debugPrint('🔍 [INVOICE_SERVICE] Parsing ${invoiceList.length} invoices...');
      final invoices = invoiceList
          .whereType<Map<String, dynamic>>()
          .map((json) {
            try {
              final invoice = Invoice.fromJson(json);
              debugPrint('   ✅ Parsed invoice: ${invoice.number}');
              return invoice;
            } catch (e, stack) {
              debugPrint('❌ [INVOICE_SERVICE] Error parsing invoice: $e');
              debugPrint('   - JSON keys: ${json.keys.toList()}');
              debugPrint('   - Stack: $stack');
              return null;
            }
          })
          .whereType<Invoice>()
          .toList();
      
      debugPrint('✅ [INVOICE_SERVICE] Successfully parsed ${invoices.length} invoices');
      debugPrint('   - First invoice: ${invoices.isNotEmpty ? invoices.first.number : "none"}');
      debugPrint('   - Returning data with ${invoices.length} invoices and pagination: ${pagination != null}');
      
      final result = {
        'data': invoices,
        'pagination': pagination,
      };
      
      debugPrint('✅ [INVOICE_SERVICE] Returning result: data length=${(result['data'] as List).length}');
      
      return result;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Invoice> getById(String id) async {
    try {
      debugPrint('📡 [INVOICE_SERVICE] getById called for invoice: $id');
      final response = await _apiClient.dio.get('/invoices/$id');
      debugPrint('📡 [INVOICE_SERVICE] Response status: ${response.statusCode}');
      debugPrint('📡 [INVOICE_SERVICE] Response data type: ${response.data.runtimeType}');
      
      final data = response.data;
      if (data is Map<String, dynamic>) {
        debugPrint('📡 [INVOICE_SERVICE] Parsing invoice from JSON...');
        final invoice = Invoice.fromJson(data);
        debugPrint('✅ [INVOICE_SERVICE] Invoice parsed: ${invoice.number}');
        return invoice;
      } else {
        debugPrint('❌ [INVOICE_SERVICE] Invalid response format: ${data.runtimeType}');
        throw Exception('Invalid response format: expected Map, got ${data.runtimeType}');
      }
    } on DioException catch (e) {
      debugPrint('❌ [INVOICE_SERVICE] DioException: ${e.response?.statusCode}');
      debugPrint('   - Error: ${e.message}');
      throw _handleError(e);
    } catch (e, stack) {
      debugPrint('❌ [INVOICE_SERVICE] Unexpected error: $e');
      debugPrint('   - Stack: $stack');
      rethrow;
    }
  }

  Future<Invoice> create({
    required String clientId,
    required DateTime issuedAt,
    required DateTime dueAt,
    double taxPct = 0,
    double discountPct = 0,
    String? notes,
    required List<Map<String, dynamic>> items,
    String? documentType,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/invoices',
        data: {
          'clientId': clientId,
          'issuedAt': issuedAt.toIso8601String(),
          'dueAt': dueAt.toIso8601String(),
          'taxPct': taxPct,
          'discountPct': discountPct,
          'notes': notes,
          'items': items,
          if (documentType != null) 'documentType': documentType,
        },
      );
      return Invoice.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Invoice> update(
    String id, {
    String? clientId,
    DateTime? issuedAt,
    DateTime? dueAt,
    double? taxPct,
    double? discountPct,
    String? notes,
    List<Map<String, dynamic>>? items,
    String? status,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (clientId != null) data['clientId'] = clientId;
      if (issuedAt != null) data['issuedAt'] = issuedAt.toIso8601String();
      if (dueAt != null) data['dueAt'] = dueAt.toIso8601String();
      if (taxPct != null) data['taxPct'] = taxPct;
      if (discountPct != null) data['discountPct'] = discountPct;
      if (notes != null) data['notes'] = notes;
      if (items != null) data['items'] = items;
      if (status != null) data['status'] = status;

      final response = await _apiClient.dio.patch(
        '/invoices/$id',
        data: data,
      );
      return Invoice.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Invoice> markPaid(String id) async {
    try {
      final response = await _apiClient.dio.post('/invoices/$id/mark-paid');
      return Invoice.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> generatePdf(String id) async {
    try {
      final response = await _apiClient.dio.post('/invoices/$id/pdf');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _apiClient.dio.delete('/invoices/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Invoice> convertEstimateToInvoice(
    String id, {
    DateTime? issuedAt,
    DateTime? dueAt,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (issuedAt != null) {
        payload['issuedAt'] = issuedAt.toIso8601String();
      }
      if (dueAt != null) {
        payload['dueAt'] = dueAt.toIso8601String();
      }

      final response = await _apiClient.dio.post(
        '/invoices/$id/convert-to-invoice',
        data: payload,
      );

      return Invoice.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getItemTemplates({String? query}) async {
    try {
      debugPrint('🔍 [FRONTEND] Fetching item templates, query: ${query ?? "(empty - most used)"}');
      debugPrint('   - URL: ${_apiClient.dio.options.baseUrl}/invoices/item-templates');
      debugPrint('   - Query params: ${query != null && query.isNotEmpty ? {'q': query} : null}');
      
      final response = await _apiClient.dio.get(
        '/invoices/item-templates',
        queryParameters: query != null && query.isNotEmpty ? {'q': query} : null,
      );
      
      debugPrint('✅ [FRONTEND] Got response from /invoices/item-templates, status: ${response.statusCode}');
      debugPrint('   - Response type: ${response.data.runtimeType}');
      debugPrint('   - Response data: ${response.data}');
      
      final resData = response.data;
      
      List<Map<String, dynamic>> templates;
      if (resData is List) {
        templates = resData.cast<Map<String, dynamic>>();
        debugPrint('✅ [FRONTEND] Response is List with ${templates.length} items');
      } else if (resData is Map<String, dynamic> && resData.containsKey('data')) {
        templates = (resData['data'] as List).cast<Map<String, dynamic>>();
        debugPrint('✅ [FRONTEND] Response is Map with data key containing ${templates.length} items');
      } else {
        debugPrint('⚠️ [FRONTEND] Unexpected response format: ${resData.runtimeType}');
        templates = [];
      }
      
      debugPrint('✅ [FRONTEND] Parsed ${templates.length} templates: ${templates.map((t) => t['description']).join(", ")}');
      return templates;
    } on DioException catch (e) {
      debugPrint('❌ [FRONTEND] Error fetching templates: ${e.message}');
      debugPrint('   - Error type: ${e.type}');
      debugPrint('   - Status code: ${e.response?.statusCode}');
      debugPrint('   - Response data: ${e.response?.data}');
      debugPrint('   - Request path: ${e.requestOptions.path}');
      throw _handleError(e);
    } catch (e, stack) {
      debugPrint('❌ [FRONTEND] Unexpected error fetching templates: $e');
      debugPrint('   - Stack: $stack');
      rethrow;
    }
  }

  Future<void> deleteItemTemplate(String templateId) async {
    try {
      await _apiClient.dio.delete('/invoices/item-templates/$templateId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> enhanceDescription({
    required String description,
    String? clientName,
    List<Map<String, dynamic>>? existingItems,
    String? invoiceType,
  }) async {
    try {
      debugPrint('✨ [FRONTEND] Enhancing description: "$description"');
      
      final response = await _apiClient.dio.post(
        '/invoices/enhance-description',
        data: {
          'description': description,
          if (clientName != null) 'clientName': clientName,
          if (existingItems != null) 'existingItems': existingItems,
          if (invoiceType != null) 'invoiceType': invoiceType,
        },
      );
      
      debugPrint('✅ [FRONTEND] Enhanced description response: ${response.statusCode}');
      
      final resData = response.data;
      if (resData is Map<String, dynamic> && resData.containsKey('enhancedDescription')) {
        final enhanced = resData['enhancedDescription'] as String;
        debugPrint('✅ [FRONTEND] Enhanced: "$description" -> "$enhanced"');
        return enhanced;
      }
      
      final errorMsg = 'Unexpected response format from server';
      debugPrint('❌ [FRONTEND] $errorMsg: ${resData.runtimeType}');
      throw Exception(errorMsg);
    } on DioException catch (e) {
      debugPrint('❌ [FRONTEND] DioException enhancing description: ${e.message}');
      debugPrint('   - Error type: ${e.type}');
      debugPrint('   - Status code: ${e.response?.statusCode}');
      debugPrint('   - Response data: ${e.response?.data}');
      debugPrint('   - Request path: ${e.requestOptions.path}');
      
      // Create a more informative error message
      String errorMessage = _handleError(e);
      
      // Check if this is an ngrok rate limit error (not an auth error)
      final responseData = e.response?.data;
      final responseText = responseData?.toString() ?? '';
      final isNgrokRateLimit = responseText.contains('exceeded your limit') ||
                              responseText.contains('ERR_NGROK') ||
                              responseText.contains('ngrok.com/billing');
      
      // Include status code in error message for better debugging
      if (e.response?.statusCode != null) {
        if (isNgrokRateLimit) {
          // This is an ngrok rate limit, not an auth error
          errorMessage = 'Rate limit exceeded: Too many requests to the server. Please wait a minute and try again.';
        } else if (e.response!.statusCode == 403) {
          errorMessage = '403 Forbidden: Authentication failed. Please try again.';
        } else if (e.response!.statusCode == 401) {
          errorMessage = '401 Unauthorized: Please log in again.';
        } else if (e.response!.statusCode == 429) {
          errorMessage = '429 Too Many Requests: Rate limit exceeded. Please wait.';
        }
      }
      
      throw Exception(errorMessage);
    } catch (e, stack) {
      debugPrint('❌ [FRONTEND] Unexpected error enhancing description: $e');
      debugPrint('   - Error type: ${e.runtimeType}');
      debugPrint('   - Stack: $stack');
      
      // Ensure we always throw an Exception, not a raw String or other type
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception(e.toString());
      }
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

