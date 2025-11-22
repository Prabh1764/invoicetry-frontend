import 'client.dart';
import 'invoice_item.dart';
import 'invoice_image.dart';

enum InvoiceStatus {
  draft,
  pending,
  paid,
  overdue;

  static InvoiceStatus fromString(String value) {
    return InvoiceStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => InvoiceStatus.draft,
    );
  }

  String get displayName {
    switch (this) {
      case InvoiceStatus.draft:
        return 'DRAFT';
      case InvoiceStatus.pending:
        return 'PENDING';
      case InvoiceStatus.paid:
        return 'PAID';
      case InvoiceStatus.overdue:
        return 'OVERDUE';
    }
  }
}

enum InvoiceDocumentType {
  invoice,
  estimate;

  static InvoiceDocumentType fromString(String value) {
    return InvoiceDocumentType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => InvoiceDocumentType.invoice,
    );
  }

  String get displayLabel {
    switch (this) {
      case InvoiceDocumentType.invoice:
        return 'Invoice';
      case InvoiceDocumentType.estimate:
        return 'Estimate';
    }
  }
}

class Invoice {
  final String id;
  final String clientId;
  final String number;
  final DateTime issuedAt;
  final DateTime dueAt;
  final InvoiceStatus status;
  final InvoiceDocumentType documentType;
  final String? notes;
  final double taxPct;
  final double discountPct;
  final double? totalCached;
  final String? pdfUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Client? client;
  final List<InvoiceItem>? items;
  final List<InvoiceImage>? images;

  Invoice({
    required this.id,
    required this.clientId,
    required this.number,
    required this.issuedAt,
    required this.dueAt,
    required this.status,
    required this.documentType,
    this.notes,
    required this.taxPct,
    required this.discountPct,
    this.totalCached,
    this.pdfUrl,
    required this.createdAt,
    required this.updatedAt,
    this.client,
    this.items,
    this.images,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // Safely parse all fields with type checking
    String safeString(dynamic value, String fieldName, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      if (value is String) return value;
      return value.toString();
    }

    DateTime? safeDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    double safeDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }

    return Invoice(
      id: safeString(json['id'], 'id'),
      clientId: safeString(json['clientId'], 'clientId'),
      number: safeString(json['number'], 'number'),
      issuedAt: safeDateTime(json['issuedAt']) ?? DateTime.now(),
      dueAt: safeDateTime(json['dueAt']) ?? DateTime.now(),
      status: InvoiceStatus.fromString(safeString(json['status'], 'status', 'DRAFT')),
      documentType: InvoiceDocumentType.fromString(
        safeString(json['documentType'], 'documentType', 'INVOICE'),
      ),
      notes: json['notes'] is String ? json['notes'] as String? : null,
      taxPct: safeDouble(json['taxPct']),
      discountPct: safeDouble(json['discountPct']),
      totalCached: json['totalCached'] != null ? safeDouble(json['totalCached']) : null,
      pdfUrl: json['pdfUrl'] is String ? json['pdfUrl'] as String? : null,
      createdAt: safeDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: safeDateTime(json['updatedAt']) ?? DateTime.now(),
      client: json['client'] != null && json['client'] is Map<String, dynamic>
          ? Client.fromJson(json['client'] as Map<String, dynamic>)
          : null,
      items: json['items'] != null && json['items'] is List
          ? (json['items'] as List<dynamic>)
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return InvoiceItem.fromJson(item);
                }
                return null;
          })
          .whereType<InvoiceItem>()
          .toList()
          : null,
      images: json['images'] != null && json['images'] is List
          ? (json['images'] as List<dynamic>)
              .map((image) {
                if (image is Map<String, dynamic>) {
                  return InvoiceImage.fromJson(image);
                }
                return null;
              })
              .whereType<InvoiceImage>()
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'number': number,
      'issuedAt': issuedAt.toIso8601String(),
      'dueAt': dueAt.toIso8601String(),
      'status': status.displayName,
      'documentType': documentType.name.toUpperCase(),
      'notes': notes,
      'taxPct': taxPct,
      'discountPct': discountPct,
      'totalCached': totalCached,
      'pdfUrl': pdfUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Calculate totals (mirrors backend logic)
  Map<String, double> calculateTotals() {
    if (items == null || items!.isEmpty) {
      return {
        'subtotal': 0.0,
        'taxAmount': 0.0,
        'discountAmount': 0.0,
        'total': 0.0,
      };
    }

    final subtotal =
        items!.fold(0.0, (sum, item) => sum + (item.qty * item.unitPrice));
    final taxAmount = subtotal * (taxPct / 100);
    final discountAmount = subtotal * (discountPct / 100);
    final total = subtotal + taxAmount - discountAmount;

    return {
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'total': total,
    };
  }

  bool get isEstimate => documentType == InvoiceDocumentType.estimate;
  bool get isInvoice => documentType == InvoiceDocumentType.invoice;
}

