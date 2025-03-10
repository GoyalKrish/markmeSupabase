import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase/supabase.dart';

class LobbyProvider with ChangeNotifier {
  Map<String, dynamic>? _currentLobby;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _activeLobbies = [];

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _lobbyChannel;

  Map<String, dynamic>? get currentLobby => _currentLobby;
  List<Map<String, dynamic>> get members => _members;
  List<Map<String, dynamic>> get attendanceRecords => _attendanceRecords;
  List<Map<String, dynamic>> get activeLobbies => _activeLobbies;

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
        .select('*, lobby_members!inner(*), attendance_records(count)')
        .eq('active', true)
        .eq('lobby_members.user_id', _supabase.auth.currentUser!.id);

    if (response is List<dynamic>) {
      _activeLobbies = response.cast<Map<String, dynamic>>();
      notifyListeners();
    }
  }
} 