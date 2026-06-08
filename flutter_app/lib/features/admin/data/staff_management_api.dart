import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/admin/data/staff_management_models.dart';

final staffManagementApiProvider = Provider<StaffManagementApi>((ref) {
  return StaffManagementApi(ref.watch(dioClientProvider));
});

class StaffManagementApi {
  final DioClient _dioClient;

  StaffManagementApi(this._dioClient);

  // ─── Staff CRUD ────────────────────────────────────────────────────────

  Future<List<StaffUser>> getStaffList() async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiConstants.adminStaffEndpoint,
    );
    final data = response.data!;
    final list = data['staff'] as List<dynamic>? ?? [];
    return list
        .map((json) => StaffUser.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<StaffUser> createStaff(StaffCreateRequest data) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiConstants.adminStaffEndpoint,
      data: data.toJson(),
    );
    return StaffUser.fromJson(response.data!);
  }

  Future<StaffUser> updateStaff(String staffId, StaffUpdateRequest data) async {
    final response = await _dioClient.put<Map<String, dynamic>>(
      '${ApiConstants.adminStaffEndpoint}/$staffId',
      data: data.toJson(),
    );
    return StaffUser.fromJson(response.data!);
  }

  Future<void> deleteStaff(String staffId) async {
    await _dioClient.delete<void>(
      '${ApiConstants.adminStaffEndpoint}/$staffId',
    );
  }

  // ─── Staff Assignments ─────────────────────────────────────────────────

  Future<List<StaffAssignment>> getAllAssignments() async {
    final response = await _dioClient.get<List<dynamic>>(
      ApiConstants.adminStaffAssignmentsAllEndpoint,
    );
    if (response.data == null) return [];
    return response.data!
        .map((json) => StaffAssignment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<StaffAssignment> createAssignment(
    StaffAssignmentCreateRequest data,
  ) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiConstants.adminStaffAssignmentsEndpoint,
      data: data.toJson(),
    );
    return StaffAssignment.fromJson(response.data!);
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _dioClient.delete<void>(
      '${ApiConstants.adminStaffAssignmentsEndpoint}/$assignmentId',
    );
  }
}
