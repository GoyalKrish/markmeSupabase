import 'dart:math';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LobbyService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

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
    
    if (lobby == null) throw Exception('Invalid entry code');
    await _joinLobby(lobbyId);
  }

  Future<void> _joinLobby(String lobbyId) async {
    await _supabase.from('lobby_members').insert({
      'lobby_id': lobbyId,
      'user_id': _supabase.auth.currentUser!.id,
      'device_id': await _getDeviceId(),
    });
  }

  String _generateEntryCode() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(9)).join();
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? _uuid.v4();
    }
    return _uuid.v4();
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
} 