import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student.dart';
import '../services/auth_service.dart';

class LobbyService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService;

  LobbyService(this._authService);

  // Create new lobby using the atomic RPC function
  Future<Map<String, dynamic>> createLobby(String name) async {
    final result = await _supabase.rpc(
      'create_lobby_and_join',
      params: {'lobby_name': name},
    );
    return result as Map<String, dynamic>;
  }

  // Join existing lobby
  Future<void> joinLobby(String entryCode, String lobbyId) async {
    final lobby = await _supabase
        .from('lobbies')
        .select('id')
        .eq('entry_code', entryCode)
        .eq('id', lobbyId)
        .eq('active', true)
        .single();
    await _joinLobby(lobby['id'] as String);
  }

  Future<void> _joinLobby(String lobbyId) async {
    final deviceRecordId = _authService.getActiveDeviceRecordId();
    if (deviceRecordId == null) {
      throw Exception('No active device found. Please login again.');
    }

    // Insert into lobby_members using the stable device ID
    await _supabase.from('lobby_members').insert({
      'lobby_id': lobbyId,
      'user_id': _supabase.auth.currentUser!.id,
      'device_id': deviceRecordId,
    });
  }

  Future<void> leaveLobby(String lobbyId) async {
    await _supabase
        .from('lobby_members')
        .delete()
        .eq('lobby_id', lobbyId)
        .eq('user_id', _supabase.auth.currentUser!.id);
  }

  Future<bool> isUserMember(String lobbyId) async {
    final response = await _supabase
        .from('lobby_members')
        .select()
        .eq('lobby_id', lobbyId)
        .eq('user_id', _supabase.auth.currentUser!.id)
        .limit(1);

    return response.isNotEmpty;
  }

  Future<void> addAttendanceRecord(String lobbyId, Student student) async {
    final deviceRecordId = _authService.getActiveDeviceRecordId();
    if (deviceRecordId == null) {
      throw Exception('No active device found. Please login again.');
    }

    final existing = await _supabase
        .from('attendance_records')
        .select()
        .eq('lobby_id', lobbyId)
        .eq('student_system_id', student.id)
        .maybeSingle();

    if (existing != null) {
      throw Exception(
          'Student with ID ${student.id} already exists in this lobby');
    }

    await _supabase.from('attendance_records').insert({
      'lobby_id': lobbyId,
      'student_system_id': student.id,
      'student_name': student.name,
      'recorded_by': _supabase.auth.currentUser!.id,
      'device_id': deviceRecordId, // Use stable UUID
    });
  }

  Future<void> deleteLobby(String lobbyId) async {
    // The RLS policies and CASCADE constraints now handle the logic for deletion.
    // We just need to delete the lobby row itself.
    await _supabase.from('lobbies').delete().eq('id', lobbyId);
  }
}