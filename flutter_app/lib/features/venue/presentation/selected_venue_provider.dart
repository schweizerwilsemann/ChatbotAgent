import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_api.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_model.dart';

final venuesProvider = FutureProvider<List<Venue>>((ref) async {
  final venues = await ref.watch(venueApiProvider).getVenues();
  // Auto-select first venue if none selected
  final selected = ref.read(selectedVenueProvider);
  if (selected == null && venues.isNotEmpty) {
    ref.read(selectedVenueProvider.notifier).select(venues.first);
  }
  return venues;
});

class SelectedVenueNotifier extends StateNotifier<Venue?> {
  SelectedVenueNotifier() : super(null);

  void select(Venue venue) {
    state = venue;
  }

  void clear() {
    state = null;
  }
}

final selectedVenueProvider =
    StateNotifierProvider<SelectedVenueNotifier, Venue?>((ref) {
  return SelectedVenueNotifier();
});
