import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/staff_request/data/staff_request_models.dart';

final staffRequestApiProvider = Provider<StaffRequestApi>((ref) {
  return StaffRequestApi(ref.watch(dioClientProvider));
});

class StaffRequestApi {
  final DioClient _dioClient;

  StaffRequestApi(this._dioClient);

  Future<StaffRequest> createRequest(StaffRequestCreate request) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiConstants.staffRequestEndpoint,
      data: request.toJson(),
    );
    return StaffRequest.fromJson(response.data!);
  }

  Future<List<StaffRequest>> getMyRequests() async {
    final response = await _dioClient.get<List<dynamic>>(
      '${ApiConstants.staffRequestEndpoint}/mine',
    );
    return (response.data ?? const [])
        .map((item) => StaffRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StaffRequest> acceptRequest(String requestId) async {
    final response = await _dioClient.patch<Map<String, dynamic>>(
      '${ApiConstants.staffRequestEndpoint}/$requestId/accept',
    );
    return StaffRequest.fromJson(response.data!);
  }

  Future<StaffRequest> completeRequest(String requestId) async {
    final response = await _dioClient.patch<Map<String, dynamic>>(
      '${ApiConstants.staffRequestEndpoint}/$requestId/complete',
    );
    return StaffRequest.fromJson(response.data!);
  }

  Future<StaffRequest> cancelRequest(String requestId) async {
    final response = await _dioClient.patch<Map<String, dynamic>>(
      '${ApiConstants.staffRequestEndpoint}/$requestId/cancel',
    );
    return StaffRequest.fromJson(response.data!);
  }

  Future<List<StaffRequest>> getPendingRequests() async {
    final response = await _dioClient.get<List<dynamic>>(
      '${ApiConstants.staffRequestEndpoint}/pending',
    );
    return (response.data ?? const [])
        .map((item) => StaffRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
