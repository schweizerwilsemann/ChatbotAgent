import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_api.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_model.dart';

final venuesProvider = FutureProvider<List<Venue>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return const <Venue>[];
  }

  return ref.watch(venueApiProvider).getVenues();
});

class SelectedVenueNotifier extends StateNotifier<Venue?> {
  SelectedVenueNotifier(this._storage) : super(null);

  static const _selectedVenueIdKey = 'selected_venue_id';

  final FlutterSecureStorage _storage;

  Future<void> restore(List<Venue> venues) async {
    if (venues.isEmpty) {
      await _storage.delete(key: _selectedVenueIdKey);
      if (!mounted) return;
      state = null;
      return;
    }

    final current = state;
    if (current != null && venues.any((venue) => venue.id == current.id)) {
      return;
    }

    final storedId = await _storage.read(key: _selectedVenueIdKey);
    if (!mounted) return;
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
    await _storage.delete(key: _selectedVenueIdKey);
    if (!mounted) return;
    state = null;
  }
}

final selectedVenueProvider =
    StateNotifierProvider<SelectedVenueNotifier, Venue?>((ref) {
  final notifier = SelectedVenueNotifier(ref.watch(secureStorageProvider));

  ref.listen<AsyncValue<List<Venue>>>(
    venuesProvider,
    (_, next) {
      final venues = next.valueOrNull;
      if (venues != null) {
        unawaited(notifier.restore(venues));
      }
    },
    fireImmediately: true,
  );

  return notifier;
});
