class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
}

/// What register and login return: the access token plus the signed-in user.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;

  /// Seconds until the token expires.
  final int expiresIn;
  final User user;
}
