class AuthToken {
  final String accessToken;
  final Map<String, dynamic>? user;

  AuthToken({
    required this.accessToken,
    this.user,
  });

  factory AuthToken.fromJson(dynamic json) {
    // Handle both Map and dynamic types safely
    if (json is! Map<String, dynamic>) {
      throw Exception('Invalid JSON format: expected Map, got ${json.runtimeType}');
    }
    
    // Safely extract accessToken
    final accessTokenValue = json['accessToken'];
    if (accessTokenValue == null) {
      throw Exception('Missing accessToken in response');
    }
    
    String accessToken;
    if (accessTokenValue is String) {
      accessToken = accessTokenValue;
    } else {
      // Try to convert to string
      accessToken = accessTokenValue.toString();
    }
    
    // Safely extract user
    Map<String, dynamic>? user;
    final userValue = json['user'];
    if (userValue != null && userValue is Map<String, dynamic>) {
      user = userValue;
    }
    
    return AuthToken(
      accessToken: accessToken,
      user: user,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'user': user,
    };
  }
}

