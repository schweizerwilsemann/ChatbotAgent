class Venue {
  final String id;
  final String businessId;
  final String name;
  final String? address;
  final String timezone;
  final bool isActive;

  const Venue({
    required this.id,
    required this.businessId,
    required this.name,
    this.address,
    required this.timezone,
    required this.isActive,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      timezone: json['timezone']?.toString() ?? 'Asia/Ho_Chi_Minh',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'address': address,
      'timezone': timezone,
      'is_active': isActive,
    };
  }
}
