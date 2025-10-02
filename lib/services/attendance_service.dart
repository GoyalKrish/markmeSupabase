import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AttendanceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService;

  AttendanceService(this._authService);

  Future<void> recordAttendance({
    required String lobbyId,
    required String studentSystemId,
    required String studentName,
  }) async {
    final deviceRecordId = _authService.getActiveDeviceRecordId();
    if (deviceRecordId == null) {
      throw Exception('No active device found. Please login again.');
    }

    // Insert into attendance_records using the stable device ID
    await _supabase.from('attendance_records').insert({
      'lobby_id': lobbyId,
      'recorded_by': _supabase.auth.currentUser!.id,
      'student_system_id': studentSystemId,
      'student_name': studentName,
      'device_id': deviceRecordId, // Use the stable UUID
      'recorded_at': DateTime.now().toIso8601String(),
    });
  }
}
