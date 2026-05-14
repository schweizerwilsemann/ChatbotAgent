class StaffNotification {
  final String id;
  final String eventType;
  final String title;
  final String message;
  final String source;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? readAt;

  const StaffNotification({
    required this.id,
    required this.eventType,
    required this.title,
    required this.message,
    required this.source,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory StaffNotification.fromJson(Map<String, dynamic> json) {
    return StaffNotification(
      id: json['id']?.toString() ?? json['notification_id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? 'staff.requested',
      title: json['title']?.toString() ?? 'Thông báo mới',
      message: json['message']?.toString() ?? '',
      source: json['source']?.toString() ?? 'system',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : <String, dynamic>{},
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ??
                json['timestamp']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
    );
  }

  StaffNotification copyWith({DateTime? readAt}) {
    return StaffNotification(
      id: id,
      eventType: eventType,
      title: title,
      message: message,
      source: source,
      payload: payload,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
