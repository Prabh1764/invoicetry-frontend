class Client {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? company;
  final String? logoUrl;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.company,
    this.logoUrl,
    required this.createdAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
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

    return Client(
      id: safeString(json['id'], 'id'),
      name: safeString(json['name'], 'name'),
      email: json['email'] is String ? json['email'] as String? : null,
      phone: json['phone'] is String ? json['phone'] as String? : null,
      address: json['address'] is String ? json['address'] as String? : null,
      company: json['company'] is String ? json['company'] as String? : null,
      logoUrl: json['logoUrl'] is String ? json['logoUrl'] as String? : null,
      createdAt: safeDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'company': company,
      'logoUrl': logoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Client copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? company,
    String? logoUrl,
    DateTime? createdAt,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      company: company ?? this.company,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

