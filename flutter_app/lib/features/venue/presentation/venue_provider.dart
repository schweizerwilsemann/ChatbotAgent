import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_api.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_models.dart';

final venueResourcesProvider =
    FutureProvider.autoDispose<List<VenueResource>>((ref) {
  return ref.watch(venueApiProvider).getResources();
});
