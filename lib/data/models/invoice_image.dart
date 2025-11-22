class InvoiceImage {
  final String id;
  final String invoiceId;
  final String url;
  final String filename;
  final int order;
  final DateTime createdAt;

  InvoiceImage({
    required this.id,
    required this.invoiceId,
    required this.url,
    required this.filename,
    required this.order,
    required this.createdAt,
  });

  factory InvoiceImage.fromJson(Map<String, dynamic> json) {
    return InvoiceImage(
      id: json['id'] as String? ?? '',
      invoiceId: json['invoiceId'] as String? ?? '',
      url: json['url'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'url': url,
      'filename': filename,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Get full image URL from backend
  String getImageUrl(String baseUrl) {
    if (url.startsWith('http')) {
      return url;
    }
    // Remove leading slash if present
    final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanUrl';
  }
}

