import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

/// User model
@JsonSerializable()
class User {
  final String id;
  final String phone;
  final String name;
  final String? email;
  final String role;

  const User({
    required this.id,
    required this.phone,
    required this.name,
    this.email,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    String? role,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}

/// Authentication response containing user info and JWT token
@JsonSerializable()
class AuthResponse {
  final User user;
  final String token;

  const AuthResponse({required this.user, required this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}
