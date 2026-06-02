double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class VenueResource {
  final String id;
  final String venueId;
  final String? areaId;
  final String? areaName;
  final String code;
  final String name;
  final String label;
  final String resourceType;
  final String? sportType;
  final int number;
  final int? capacity;
  final String status;
  final double? hourlyRate;

  const VenueResource({
    required this.id,
    required this.venueId,
    this.areaId,
    this.areaName,
    required this.code,
    required this.name,
    required this.label,
    required this.resourceType,
    this.sportType,
    required this.number,
    this.capacity,
    required this.status,
    this.hourlyRate,
  });

  factory VenueResource.fromJson(Map<String, dynamic> json) {
    return VenueResource(
      id: json['id']?.toString() ?? '',
      venueId: json['venue_id']?.toString() ?? '',
      areaId: json['area_id']?.toString(),
      areaName: json['area_name']?.toString(),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
      resourceType: json['resource_type']?.toString() ?? 'other',
      sportType: json['sport_type']?.toString(),
      number: (json['number'] as num?)?.toInt() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt(),
      status: json['status']?.toString() ?? 'active',
      hourlyRate: _toDouble(json['hourly_rate']),
    );
  }

  String get displayLabel => code.isEmpty ? label : '$label ($code)';
}
