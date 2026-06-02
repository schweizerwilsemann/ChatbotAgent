import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_api.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_model.dart';

final venuesProvider = FutureProvider<List<Venue>>((ref) async {
  final venues = await ref.watch(venueApiProvider).getVenues();
  await ref.read(selectedVenueProvider.notifier).restore(venues);
  return venues;
});

class SelectedVenueNotifier extends StateNotifier<Venue?> {
  SelectedVenueNotifier(this._storage) : super(null);

  static const _selectedVenueIdKey = 'selected_venue_id';

  final FlutterSecureStorage _storage;

  Future<void> restore(List<Venue> venues) async {
    if (venues.isEmpty) {
      state = null;
      return;
    }

    final current = state;
    if (current != null && venues.any((venue) => venue.id == current.id)) {
      return;
    }

    final storedId = await _storage.read(key: _selectedVenueIdKey);
    final selected = venues.cast<Venue?>().firstWhere(
          (venue) => venue?.id == storedId,
          orElse: () => venues.first,
        );
    if (selected == null) return;

    state = selected;
    await _storage.write(key: _selectedVenueIdKey, value: selected.id);
  }

  Future<void> select(Venue venue) async {
    state = venue;
    await _storage.write(key: _selectedVenueIdKey, value: venue.id);
  }

  Future<void> clear() async {
    state = null;
    await _storage.delete(key: _selectedVenueIdKey);
  }
}

final selectedVenueProvider =
    StateNotifierProvider<SelectedVenueNotifier, Venue?>((ref) {
  return SelectedVenueNotifier(ref.watch(secureStorageProvider));
});
