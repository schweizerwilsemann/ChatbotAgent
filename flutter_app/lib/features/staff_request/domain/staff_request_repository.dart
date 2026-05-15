import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/staff_request/data/staff_request_api.dart';
import 'package:sports_venue_chatbot/features/staff_request/data/staff_request_models.dart';

final staffRequestRepositoryProvider = Provider<StaffRequestRepository>((ref) {
  return StaffRequestRepository(ref.watch(staffRequestApiProvider));
});

class StaffRequestRepository {
  final StaffRequestApi _api;

  StaffRequestRepository(this._api);

  Future<StaffRequest> createRequest({
    required StaffRequestType requestType,
    String? description,
    int? tableNumber,
  }) async {
    if (requestType == StaffRequestType.other &&
        (description == null || description.trim().isEmpty)) {
      throw ValidationException(
        message: 'Vui lòng mô tả yêu cầu của bạn',
      );
    }

    try {
      return await _api.createRequest(StaffRequestCreate(
        requestType: requestType,
        description: description?.trim(),
        tableNumber: tableNumber,
      ));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể gửi yêu cầu. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }

  Future<List<StaffRequest>> getMyRequests() async {
    try {
      return await _api.getMyRequests();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tải danh sách yêu cầu.',
        statusCode: 500,
      );
    }
  }

  Future<StaffRequest> acceptRequest(String requestId) async {
    try {
      return await _api.acceptRequest(requestId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tiếp nhận yêu cầu.',
        statusCode: 500,
      );
    }
  }

  Future<StaffRequest> completeRequest(String requestId) async {
    try {
      return await _api.completeRequest(requestId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể hoàn thành yêu cầu.',
        statusCode: 500,
      );
    }
  }

  Future<StaffRequest> cancelRequest(String requestId) async {
    try {
      return await _api.cancelRequest(requestId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể hủy yêu cầu.',
        statusCode: 500,
      );
    }
  }
}
