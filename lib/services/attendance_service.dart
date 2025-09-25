import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AttendanceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<void> recordAttendance({
    required String lobbyId,
    required String studentSystemId,
    required String studentName,
  }) async {
    final deviceId = await _authService.getDeviceId();

    // Ensure device exists to satisfy foreign key
    await _supabase.from('devices').upsert({
      'user_id': _supabase.auth.currentUser!.id,
      'id': deviceId,
      'last_used_at': DateTime.now().toIso8601String(),
      'banned': false,
    }, onConflict: 'user_id');

    // Insert into attendance_records
    await _supabase.from('attendance_records').insert({
      'lobby_id': lobbyId,
      'recorded_by': _supabase.auth.currentUser!.id,
      'student_system_id': studentSystemId,
      'student_name': studentName,
      'device_id': deviceId,
      'recorded_at': DateTime.now().toIso8601String(),
    });
  }
}