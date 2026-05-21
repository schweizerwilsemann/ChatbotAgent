import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_models.dart';

final venueApiProvider = Provider<VenueApi>((ref) {
  return VenueApi(ref.watch(dioClientProvider));
});

class VenueApi {
  final DioClient _dioClient;

  VenueApi(this._dioClient);

  Future<List<VenueResource>> getResources({String? sportType}) async {
    final response = await _dioClient.get<List<dynamic>>(
      ApiConstants.venueResourcesEndpoint,
      queryParameters: {
        if (sportType != null) 'sport_type': sportType,
        'status': 'active',
      },
    );
    return (response.data ?? const [])
        .map((item) => VenueResource.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
