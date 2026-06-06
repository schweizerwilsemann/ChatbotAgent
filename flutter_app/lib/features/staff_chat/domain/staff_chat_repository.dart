import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/features/staff_chat/data/staff_chat_api.dart';
import 'package:sports_venue_chatbot/features/staff_chat/data/staff_chat_models.dart';

final staffChatRepositoryProvider = Provider<StaffChatRepository>((ref) {
  return StaffChatRepository(ref.watch(staffChatApiProvider));
});

class StaffChatRepository {
  final StaffChatApi _api;

  StaffChatRepository(this._api);

  Future<List<StaffChatMessage>> getHistory(
    String requestId, {
    int limit = 50,
  }) =>
      _api.getHistory(requestId, limit: limit);

  Future<void> closeRoom(String requestId) => _api.closeRoom(requestId);
}
