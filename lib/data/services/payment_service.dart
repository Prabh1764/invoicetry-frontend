import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class PaymentService {
  final ApiClient _apiClient;

  PaymentService(this._apiClient);

  /// Generate payment link for an invoice
  Future<Map<String, dynamic>> generatePaymentLink(String invoiceId) async {
    try {
      debugPrint('💳 [PAYMENT_SERVICE] Generating payment link for invoice: $invoiceId');
      
      final response = await _apiClient.dio.post(
        '/payments/invoices/$invoiceId/generate-link',
      );

      debugPrint('✅ [PAYMENT_SERVICE] Payment link generated successfully');
      debugPrint('   - Response: ${response.data}');

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('❌ [PAYMENT_SERVICE] Error generating payment link: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Get existing payment link for an invoice
  Future<Map<String, dynamic>?> getPaymentLink(String invoiceId) async {
    try {
      debugPrint('💳 [PAYMENT_SERVICE] Getting payment link for invoice: $invoiceId');
      
      final response = await _apiClient.dio.get(
        '/payments/invoices/$invoiceId/payment-link',
      );

      debugPrint('✅ [PAYMENT_SERVICE] Payment link retrieved');
      debugPrint('   - Response: ${response.data}');

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] == false) {
        return null; // Payment link not generated yet
      }

      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // Payment link not found
      }
      debugPrint('❌ [PAYMENT_SERVICE] Error getting payment link: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Get payment status for an invoice
  Future<Map<String, dynamic>> getPaymentStatus(String invoiceId) async {
    try {
      debugPrint('💳 [PAYMENT_SERVICE] Getting payment status for invoice: $invoiceId');
      
      final response = await _apiClient.dio.get(
        '/payments/invoices/$invoiceId/status',
      );

      debugPrint('✅ [PAYMENT_SERVICE] Payment status retrieved');
      debugPrint('   - Response: ${response.data}');

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('❌ [PAYMENT_SERVICE] Error getting payment status: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Get payment fees information
  Future<Map<String, dynamic>> getPaymentFees() async {
    try {
      debugPrint('💳 [PAYMENT_SERVICE] Getting payment fees info');
      
      final response = await _apiClient.dio.get('/payments/fees');

      debugPrint('✅ [PAYMENT_SERVICE] Payment fees retrieved');
      debugPrint('   - Response: ${response.data}');

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('❌ [PAYMENT_SERVICE] Error getting payment fees: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Create Stripe Connect account
  Future<Map<String, dynamic>> createConnectAccount() async {
    try {
      debugPrint('💳 [PAYMENT_SERVICE] Creating Stripe Connect account');
      
      final response = await _apiClient.dio.post('/payments/connect/create-account');

      debugPrint('✅ [PAYMENT_SERVICE] Connect account created');
      debugPrint('   - Response: ${response.data}');

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('❌ [PAYMENT_SERVICE] Error creating Connect account: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Get Stripe Connect account status
  Future<Map<String, dynamic>> getConnectStatus() async {
    try {
      debugPrint('💳 [PAYMENT_SERVICE] Getting Stripe Connect status');
      
      final response = await _apiClient.dio.get('/payments/connect/status');

      debugPrint('✅ [PAYMENT_SERVICE] Connect status retrieved');
      debugPrint('   - Response: ${response.data}');

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {'success': false, 'status': null};
      }
      debugPrint('❌ [PAYMENT_SERVICE] Error getting Connect status: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Get Stripe onboarding link
  Future<Map<String, dynamic>> getOnboardingLink() async {
    try {
      debugPrint('💳 [PAYMENT_SERVICE] Getting Stripe onboarding link');
      
      final response = await _apiClient.dio.post('/payments/connect/onboarding-link');

      debugPrint('✅ [PAYMENT_SERVICE] Onboarding link retrieved');
      debugPrint('   - Response: ${response.data}');

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('❌ [PAYMENT_SERVICE] Error getting onboarding link: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Send reminder for an invoice
  Future<Map<String, dynamic>> sendReminder(String invoiceId) async {
    try {
      debugPrint('📧 [PAYMENT_SERVICE] Sending reminder for invoice: $invoiceId');
      
      final response = await _apiClient.dio.post(
        '/payments/invoices/$invoiceId/send-reminder',
      );

      debugPrint('✅ [PAYMENT_SERVICE] Reminder sent successfully');
      debugPrint('   - Response: ${response.data}');

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('❌ [PAYMENT_SERVICE] Error sending reminder: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response?.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'] as String;
      }
      return 'Server error: ${error.response?.statusCode}';
    }
    return error.message ?? 'Network error occurred';
  }
}

