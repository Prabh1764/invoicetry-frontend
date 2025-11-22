import '../models/invoice.dart';
import '../services/api_client.dart';
import '../services/invoice_service.dart';

class InvoiceRepo {
  final InvoiceService _invoiceService;

  InvoiceRepo(ApiClient apiClient)
      : _invoiceService = InvoiceService(apiClient);

  Future<Map<String, dynamic>> getAll({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? search,
    String? documentType,
  }) {
    return _invoiceService.getAll(
      page: page,
      pageSize: pageSize,
      status: status,
      search: search,
      documentType: documentType,
    );
  }

  Future<Invoice> getById(String id) {
    return _invoiceService.getById(id);
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
  }) {
    return _invoiceService.create(
      clientId: clientId,
      issuedAt: issuedAt,
      dueAt: dueAt,
      taxPct: taxPct,
      discountPct: discountPct,
      notes: notes,
      items: items,
      documentType: documentType,
    );
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
  }) {
    return _invoiceService.update(
      id,
      clientId: clientId,
      issuedAt: issuedAt,
      dueAt: dueAt,
      taxPct: taxPct,
      discountPct: discountPct,
      notes: notes,
      items: items,
      status: status,
    );
  }

  Future<Invoice> updateStatus(String id, InvoiceStatus status) {
    return _invoiceService.update(
      id,
      status: status.name.toUpperCase(),
    );
  }

  Future<Invoice> markPaid(String id) {
    return _invoiceService.markPaid(id);
  }

  Future<Invoice> convertEstimateToInvoice(
    String id, {
    DateTime? issuedAt,
    DateTime? dueAt,
  }) {
    return _invoiceService.convertEstimateToInvoice(
      id,
      issuedAt: issuedAt,
      dueAt: dueAt,
    );
  }

  Future<Map<String, dynamic>> generatePdf(String id) {
    return _invoiceService.generatePdf(id);
  }

  Future<void> delete(String id) {
    return _invoiceService.delete(id);
  }

  Future<List<Map<String, dynamic>>> getItemTemplates({String? query}) {
    return _invoiceService.getItemTemplates(query: query);
  }

  Future<String> enhanceDescription({
    required String description,
    String? clientName,
    List<Map<String, dynamic>>? existingItems,
    String? invoiceType,
  }) {
    return _invoiceService.enhanceDescription(
      description: description,
      clientName: clientName,
      existingItems: existingItems,
      invoiceType: invoiceType,
    );
  }

  Future<void> deleteItemTemplate(String templateId) {
    return _invoiceService.deleteItemTemplate(templateId);
  }
}

