import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/staff_chat/data/staff_chat_models.dart';

final staffChatApiProvider = Provider<StaffChatApi>((ref) {
  return StaffChatApi(ref.watch(dioClientProvider));
});

class StaffChatApi {
  final DioClient _dioClient;

  StaffChatApi(this._dioClient);

  Future<List<StaffChatMessage>> getHistory(
    String requestId, {
    int limit = 50,
  }) async {
    final response = await _dioClient.get<List<dynamic>>(
      '${ApiConstants.staffChatEndpoint}/$requestId/history',
      queryParameters: {'limit': limit},
    );
    final data = response.data ?? const [];
    return data
        .map((e) => StaffChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyRooms() async {
    final response = await _dioClient.get<List<dynamic>>(
      '${ApiConstants.staffChatEndpoint}/rooms',
    );
    final data = response.data ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> closeRoom(String requestId) async {
    await _dioClient.post<void>(
      '${ApiConstants.staffChatEndpoint}/$requestId/close',
    );
  }
}
