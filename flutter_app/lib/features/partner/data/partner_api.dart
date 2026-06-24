import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/partner/data/partner_models.dart';

final partnerApiProvider = Provider<PartnerApi>((ref) {
  return PartnerApi(ref.watch(dioClientProvider));
});

class PartnerApi {
  final DioClient _dioClient;

  PartnerApi(this._dioClient);

  // ─── Store ───────────────────────────────────────────────────────────

  Future<PartnerStore> getMyStore() async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiConstants.partnerStoreEndpoint,
    );
    return PartnerStore.fromJson(response.data!);
  }

  Future<PartnerStore> updateMyStore(Map<String, dynamic> data) async {
    final response = await _dioClient.patch<Map<String, dynamic>>(
      ApiConstants.partnerStoreEndpoint,
      data: data,
    );
    return PartnerStore.fromJson(response.data!);
  }

  // ─── Menu Items ──────────────────────────────────────────────────────

  Future<List<PartnerMenuItem>> getMenuItems({
    bool includeUnavailable = true,
  }) async {
    final response = await _dioClient.get<List<dynamic>>(
      ApiConstants.partnerMenuEndpoint,
      queryParameters: {
        'include_unavailable': includeUnavailable,
      },
    );
    if (response.data == null) return [];
    return response.data!
        .map((json) => PartnerMenuItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<PartnerMenuItem> createMenuItem(PartnerMenuItemCreateData data) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiConstants.partnerMenuEndpoint,
      data: data.toJson(),
    );
    return PartnerMenuItem.fromJson(response.data!);
  }

  Future<PartnerMenuItem> updateMenuItem(
    String id,
    PartnerMenuItemUpdateData data,
  ) async {
    final response = await _dioClient.patch<Map<String, dynamic>>(
      '${ApiConstants.partnerMenuEndpoint}/$id',
      data: data.toJson(),
    );
    return PartnerMenuItem.fromJson(response.data!);
  }

  Future<void> deleteMenuItem(String id) async {
    await _dioClient.delete<void>(
      '${ApiConstants.partnerMenuEndpoint}/$id',
    );
  }

  // ─── Orders ──────────────────────────────────────────────────────────

  Future<List<PartnerOrder>> getOrders({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (status != null) queryParams['status'] = status;

    final response = await _dioClient.get<List<dynamic>>(
      ApiConstants.partnerOrdersEndpoint,
      queryParameters: queryParams,
    );
    if (response.data == null) return [];
    return response.data!
        .map((json) => PartnerOrder.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<PartnerOrder> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    final response = await _dioClient.patch<Map<String, dynamic>>(
      '${ApiConstants.partnerOrdersEndpoint}/$orderId/status',
      data: {'status': status},
    );
    return PartnerOrder.fromJson(response.data!);
  }
}
