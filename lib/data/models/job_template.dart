class JobTemplate {
  final String id;
  final String description;
  final double defaultPrice;
  final double defaultTaxPct;
  final String? defaultNotes;

  JobTemplate({
    required this.id,
    required this.description,
    required this.defaultPrice,
    required this.defaultTaxPct,
    this.defaultNotes,
  });

  factory JobTemplate.fromJson(Map<String, dynamic> json) {
    // Safely parse all fields with type checking
    String safeString(dynamic value, String fieldName, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      if (value is String) return value;
      return value.toString();
    }

    double safeDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }

    return JobTemplate(
      id: safeString(json['id'], 'id'),
      description: safeString(json['description'], 'description'),
      defaultPrice: safeDouble(json['defaultPrice']),
      defaultTaxPct: safeDouble(json['defaultTaxPct']),
      defaultNotes: json['defaultNotes'] is String ? json['defaultNotes'] as String? : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'defaultPrice': defaultPrice,
      'defaultTaxPct': defaultTaxPct,
      'defaultNotes': defaultNotes,
    };
  }

  JobTemplate copyWith({
    String? id,
    String? description,
    double? defaultPrice,
    double? defaultTaxPct,
    String? defaultNotes,
  }) {
    return JobTemplate(
      id: id ?? this.id,
      description: description ?? this.description,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      defaultTaxPct: defaultTaxPct ?? this.defaultTaxPct,
      defaultNotes: defaultNotes ?? this.defaultNotes,
    );
  }
}

