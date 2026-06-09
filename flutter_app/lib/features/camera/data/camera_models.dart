class CameraInfo {
  final String id;
  final String venueId;
  final String? resourceId;
  final String? resourceLabel;
  final String name;
  final String ipAddress;
  final int port;
  final String username;
  final String cameraBrand;
  final String rtspUrl;
  final bool isActive;

  const CameraInfo({
    required this.id,
    required this.venueId,
    this.resourceId,
    this.resourceLabel,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.username,
    required this.cameraBrand,
    required this.rtspUrl,
    this.isActive = true,
  });

  factory CameraInfo.fromJson(Map<String, dynamic> json) {
    return CameraInfo(
      id: json['id'] as String,
      venueId: json['venue_id'] as String,
      resourceId: json['resource_id'] as String?,
      resourceLabel: json['resource_label'] as String?,
      name: json['name'] as String,
      ipAddress: json['ip_address'] as String,
      port: json['port'] as int? ?? 554,
      username: json['username'] as String? ?? 'admin',
      cameraBrand: json['camera_brand'] as String? ?? 'custom',
      rtspUrl: json['rtsp_url'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get brandDisplayName {
    switch (cameraBrand) {
      case 'hik':
        return 'Hikvision';
      case 'dahua':
        return 'Dahua';
      case 'seetong':
        return 'Seetong';
      case 'fpt':
        return 'FPT';
      default:
        return 'Tùy chỉnh';
    }
  }
}

class CameraCreateRequest {
  final String? venueId;
  final String? resourceId;
  final String name;
  final String ipAddress;
  final int port;
  final String username;
  final String password;
  final String cameraBrand;
  final String? rtspUrlOverride;

  const CameraCreateRequest({
    this.venueId,
    this.resourceId,
    required this.name,
    required this.ipAddress,
    this.port = 554,
    this.username = 'admin',
    this.password = '',
    this.cameraBrand = 'custom',
    this.rtspUrlOverride,
  });

  Map<String, dynamic> toJson() {
    return {
      if (venueId != null) 'venue_id': venueId,
      if (resourceId != null) 'resource_id': resourceId,
      'name': name,
      'ip_address': ipAddress,
      'port': port,
      'username': username,
      'password': password,
      'camera_brand': cameraBrand,
      if (rtspUrlOverride != null) 'rtsp_url_override': rtspUrlOverride,
    };
  }
}

class CameraUpdateRequest {
  final String? resourceId;
  final String? name;
  final String? ipAddress;
  final int? port;
  final String? username;
  final String? password;
  final String? cameraBrand;
  final String? rtspUrlOverride;
  final bool? isActive;

  const CameraUpdateRequest({
    this.resourceId,
    this.name,
    this.ipAddress,
    this.port,
    this.username,
    this.password,
    this.cameraBrand,
    this.rtspUrlOverride,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (resourceId != null) map['resource_id'] = resourceId;
    if (name != null) map['name'] = name;
    if (ipAddress != null) map['ip_address'] = ipAddress;
    if (port != null) map['port'] = port;
    if (username != null) map['username'] = username;
    if (password != null) map['password'] = password;
    if (cameraBrand != null) map['camera_brand'] = cameraBrand;
    if (rtspUrlOverride != null) map['rtsp_url_override'] = rtspUrlOverride;
    if (isActive != null) map['is_active'] = isActive;
    return map;
  }
}
