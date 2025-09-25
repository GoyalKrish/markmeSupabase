import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student.dart';
import '../services/auth_service.dart';

class LobbyService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Create new lobby
  Future<Map<String, dynamic>> createLobby(String name) async {
    final entryCode = _generateEntryCode();
    final lobby = await _supabase
        .from('lobbies')
        .insert({
          'name': name,
          'entry_code': entryCode,
          'host_id': _supabase.auth.currentUser!.id,
          'active': true,
        })
        .select()
        .single();

    await _joinLobby(lobby['id'] as String);
    return lobby;
  }

  // Join existing lobby
  Future<void> joinLobby(String entryCode, String lobbyId) async {
    final lobby = await _supabase
        .from('lobbies')
        .select()
        .eq('entry_code', entryCode)
        .eq('id', lobbyId)
        .eq('active', true)
        .single();
    await _joinLobby(lobbyId);
  }

  Future<void> _joinLobby(String lobbyId) async {
    final deviceId = await _authService.getDeviceId();

    // Ensure device exists to satisfy foreign key
    await _supabase.from('devices').upsert({
      'user_id': _supabase.auth.currentUser!.id,
      'id': deviceId,
      'last_used_at': DateTime.now().toIso8601String(),
      'banned': false,
    }, onConflict: 'user_id');

    // Insert into lobby_members
    await _supabase.from('lobby_members').insert({
      'lobby_id': lobbyId,
      'user_id': _supabase.auth.currentUser!.id,
      'device_id': deviceId,
    });
  }

  String _generateEntryCode() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(9)).join();
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
        .eq('user_id', _supabase.auth.currentUser!.id);

    return (response as List).isNotEmpty;
  }

  Future<void> addAttendanceRecord(String lobbyId, Student student) async {
    // Check for existing record first
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
      'user_id': _supabase.auth.currentUser!.id,
      'device_id': await _authService.getDeviceId(),
    });
  }

  Future<void> syncAttendance(String lobbyId, List<Student> students) async {
    final attendanceRecords = await Future.wait(students.map((student) async {
      return {
        'lobby_id': lobbyId,
        'student_system_id': student.id,
        'student_name': student.name,
        'user_id': _supabase.auth.currentUser!.id,
        'device_id': await _authService.getDeviceId(),
        'synced_at': DateTime.now().toIso8601String(),
      };
    }));

    await _supabase.from('attendance_records').insert(attendanceRecords);
  }

  // Add a new deleteLobby method
  Future<void> deleteLobby(String lobbyId) async {
    // Check if the user is the host of the lobby
    final lobby = await _supabase
        .from('lobbies')
        .select()
        .eq('id', lobbyId)
        .eq('host_id', _supabase.auth.currentUser!.id)
        .maybeSingle();

    if (lobby == null) {
      throw Exception('You can only delete lobbies that you have created');
    }

    // Delete attendance records associated with this lobby
    await _supabase.from('attendance_records').delete().eq('lobby_id', lobbyId);

    // Delete lobby members associated with this lobby
    await _supabase.from('lobby_members').delete().eq('lobby_id', lobbyId);

    // Delete the lobby itself
    await _supabase.from('lobbies').delete().eq('id', lobbyId);
  }
}
