class InvoiceItem {
  final String id;
  final String invoiceId;
  final String description;
  final double qty;
  final double unitPrice;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.description,
    required this.qty,
    required this.unitPrice,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id']?.toString() ?? '',
      invoiceId: json['invoiceId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      qty: (json['qty'] is num) ? (json['qty'] as num).toDouble() : 0.0,
      unitPrice: (json['unitPrice'] is num) ? (json['unitPrice'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'description': description,
      'qty': qty,
      'unitPrice': unitPrice,
    };
  }

  InvoiceItem copyWith({
    String? id,
    String? invoiceId,
    String? description,
    double? qty,
    double? unitPrice,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      description: description ?? this.description,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  double get lineTotal => qty * unitPrice;
}

