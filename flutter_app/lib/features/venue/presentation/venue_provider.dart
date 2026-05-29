import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_api.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_models.dart';
import 'package:sports_venue_chatbot/features/venue/presentation/selected_venue_provider.dart';

final venueResourcesProvider =
    FutureProvider.autoDispose<List<VenueResource>>((ref) {
  final selectedVenue = ref.watch(selectedVenueProvider);
  return ref.watch(venueApiProvider).getResources(venueId: selectedVenue?.id);
});
