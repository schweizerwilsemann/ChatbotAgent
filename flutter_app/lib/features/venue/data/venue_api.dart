import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_model.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_models.dart';

final venueApiProvider = Provider<VenueApi>((ref) {
  return VenueApi(ref.watch(dioClientProvider));
});

class VenueApi {
  final DioClient _dioClient;

  VenueApi(this._dioClient);

  Future<List<Venue>> getVenues() async {
    final response = await _dioClient.get<List<dynamic>>(
      ApiConstants.venuesEndpoint,
    );
    return (response.data ?? const [])
        .map((item) => Venue.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<VenueResource>> getResources({
    String? sportType,
    String? venueId,
  }) async {
    final response = await _dioClient.get<List<dynamic>>(
      ApiConstants.venueResourcesEndpoint,
      queryParameters: {
        if (sportType != null) 'sport_type': sportType,
        if (venueId != null) 'venue_id': venueId,
        'status': 'active',
      },
    );
    return (response.data ?? const [])
        .map((item) => VenueResource.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
