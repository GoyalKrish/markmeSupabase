import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase/supabase.dart';
import '../models/lobby.dart';

class LobbyProvider with ChangeNotifier {
  Map<String, dynamic>? _currentLobby;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Lobby> _activeLobbies = [];

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _lobbyChannel;

  Map<String, dynamic>? get currentLobby => _currentLobby;
  List<Map<String, dynamic>> get members => _members;
  List<Map<String, dynamic>> get attendanceRecords => _attendanceRecords;
  List<Lobby> get activeLobbies => _activeLobbies;

  Future<void> initializeRealtime(String lobbyId) async {
    _lobbyChannel = _supabase.channel('lobby-$lobbyId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'attendance_records',
        callback: (payload) => _handleNewAttendance(payload.newRecord),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'lobby_members',
        callback: (payload) => _handleNewMember(payload.newRecord),
      )
      ..subscribe();
  }

  void _handleNewAttendance(Map<String, dynamic> record) {
    _attendanceRecords = [..._attendanceRecords, record];
    notifyListeners();
  }

  void _handleNewMember(Map<String, dynamic> member) {
    _members = [..._members, member];
    notifyListeners();
  }

  void clearLobby() {
    _lobbyChannel?.unsubscribe();
    _currentLobby = null;
    _members = [];
    _attendanceRecords = [];
    notifyListeners();
  }

  Future<void> fetchActiveLobbies() async {
    final response = await _supabase
        .from('lobbies')
        .select('''
          *, 
          lobby_members(count),
          attendance_records(count)
        ''')
        .eq('active', true);
    
    _activeLobbies = (response as List<dynamic>)
        .map((lobby) => Lobby.fromJson(lobby as Map<String, dynamic>))
        .toList();
    
    notifyListeners();
  }

  Future<void> fetchAttendanceRecords(String lobbyId) async {
    try {
      final response = await _supabase
          .from('attendance_records')
          .select('''
            id,
            lobby_id,
            student_name,
            student_system_id,
            recorded_at,
            device_id
          ''')
          .eq('lobby_id', lobbyId);
      _attendanceRecords = (response as List<dynamic>).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      print('Error fetching attendance: $e');
      rethrow;
    }
  }
} 