import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/camera/data/camera_models.dart';

final cameraApiProvider = Provider<CameraApi>((ref) {
  return CameraApi(ref.watch(dioClientProvider));
});

class CameraApi {
  final DioClient _dioClient;

  CameraApi(this._dioClient);

  Future<List<CameraInfo>> listAdminCameras({String? venueId}) async {
    final queryParams = <String, dynamic>{};
    if (venueId != null) queryParams['venue_id'] = venueId;
    final response = await _dioClient.get<List<dynamic>>(
      ApiConstants.adminCamerasEndpoint,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    if (response.data == null) return [];
    return response.data!
        .map((json) => CameraInfo.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CameraInfo> createCamera(CameraCreateRequest data) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiConstants.adminCamerasEndpoint,
      data: data.toJson(),
    );
    return CameraInfo.fromJson(response.data!);
  }

  Future<CameraInfo> updateCamera(
      String cameraId, CameraUpdateRequest data) async {
    final response = await _dioClient.patch<Map<String, dynamic>>(
      '${ApiConstants.adminCamerasEndpoint}/$cameraId',
      data: data.toJson(),
    );
    return CameraInfo.fromJson(response.data!);
  }

  Future<void> deleteCamera(String cameraId) async {
    await _dioClient.delete<void>(
      '${ApiConstants.adminCamerasEndpoint}/$cameraId',
    );
  }

  Future<List<CameraInfo>> listStaffCameras() async {
    final response = await _dioClient.get<List<dynamic>>(
      ApiConstants.staffCamerasEndpoint,
    );
    if (response.data == null) return [];
    return response.data!
        .map((json) => CameraInfo.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
