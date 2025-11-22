import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/payment_service.dart';
import '../services/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentService(apiClient);
});

final paymentRepoProvider = Provider<PaymentRepository>((ref) {
  final service = ref.watch(paymentServiceProvider);
  return PaymentRepository(service);
});

class PaymentRepository {
  final PaymentService _service;

  PaymentRepository(this._service);

  /// Generate payment link for an invoice
  Future<Map<String, dynamic>> generatePaymentLink(String invoiceId) {
    return _service.generatePaymentLink(invoiceId);
  }

  /// Get existing payment link for an invoice
  Future<Map<String, dynamic>?> getPaymentLink(String invoiceId) {
    return _service.getPaymentLink(invoiceId);
  }

  /// Get payment status for an invoice
  Future<Map<String, dynamic>> getPaymentStatus(String invoiceId) {
    return _service.getPaymentStatus(invoiceId);
  }

  /// Get payment fees information
  Future<Map<String, dynamic>> getPaymentFees() {
    return _service.getPaymentFees();
  }

  /// Create Stripe Connect account
  Future<Map<String, dynamic>> createConnectAccount() {
    return _service.createConnectAccount();
  }

  /// Get Stripe Connect account status
  Future<Map<String, dynamic>> getConnectStatus() {
    return _service.getConnectStatus();
  }

  /// Get Stripe onboarding link
  Future<Map<String, dynamic>> getOnboardingLink() {
    return _service.getOnboardingLink();
  }

  /// Send reminder for an invoice
  Future<Map<String, dynamic>> sendReminder(String invoiceId) {
    return _service.sendReminder(invoiceId);
  }
}

