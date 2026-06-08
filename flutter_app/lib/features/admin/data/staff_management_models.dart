DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isEmpty) return null;
  return DateTime.parse(v as String);
}

class StaffUser {
  final String id;
  final String phone;
  final String name;
  final String? email;
  final String role;
  final String? defaultVenueId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StaffUser({
    required this.id,
    required this.phone,
    required this.name,
    this.email,
    required this.role,
    this.defaultVenueId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      defaultVenueId: json['default_venue_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'email': email,
      'role': role,
      'default_venue_id': defaultVenueId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class StaffCreateRequest {
  final String phone;
  final String name;
  final String? email;
  final String password;

  const StaffCreateRequest({
    required this.phone,
    required this.name,
    this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'name': name,
      if (email != null) 'email': email,
      'password': password,
    };
  }
}

class StaffUpdateRequest {
  final String? name;
  final String? email;
  final String? defaultVenueId;

  const StaffUpdateRequest({this.name, this.email, this.defaultVenueId});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (email != null) map['email'] = email;
    if (defaultVenueId != null) map['default_venue_id'] = defaultVenueId;
    return map;
  }
}

class StaffAssignment {
  final String id;
  final String staffId;
  final String staffName;
  final String venueId;
  final String venueName;
  final String? areaId;
  final String? areaName;
  final String? resourceId;
  final String? resourceLabel;
  final String scope;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;

  const StaffAssignment({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.venueId,
    required this.venueName,
    this.areaId,
    this.areaName,
    this.resourceId,
    this.resourceLabel,
    required this.scope,
    this.startsAt,
    this.endsAt,
    required this.isActive,
  });

  factory StaffAssignment.fromJson(Map<String, dynamic> json) {
    return StaffAssignment(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      staffName: json['staff_name'] as String? ?? '',
      venueId: json['venue_id'] as String,
      venueName: json['venue_name'] as String? ?? '',
      areaId: json['area_id'] as String?,
      areaName: json['area_name'] as String?,
      resourceId: json['resource_id'] as String?,
      resourceLabel: json['resource_label'] as String?,
      scope: json['scope'] as String,
      startsAt: _parseDateTime(json['starts_at']),
      endsAt: _parseDateTime(json['ends_at']),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get scopeDisplayName {
    switch (scope) {
      case 'venue':
        return 'Toàn sân';
      case 'area':
        return 'Khu vực';
      case 'resource':
        return 'Sân/Bàn';
      default:
        return scope;
    }
  }

  String get targetDisplayName {
    if (resourceLabel != null && resourceLabel!.isNotEmpty) {
      return resourceLabel!;
    }
    if (areaName != null && areaName!.isNotEmpty) {
      return areaName!;
    }
    return venueName;
  }
}

class StaffAssignmentCreateRequest {
  final String staffId;
  final String venueId;
  final String? areaId;
  final String? resourceId;
  final String scope;

  const StaffAssignmentCreateRequest({
    required this.staffId,
    required this.venueId,
    this.areaId,
    this.resourceId,
    this.scope = 'venue',
  });

  Map<String, dynamic> toJson() {
    return {
      'staff_id': staffId,
      'venue_id': venueId,
      if (areaId != null) 'area_id': areaId,
      if (resourceId != null) 'resource_id': resourceId,
      'scope': scope,
    };
  }
}
