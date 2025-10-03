import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../main.dart'; // Import main.dart to get the navigatorKey
import '../providers/lobby_provider.dart';
import 'auth_exceptions.dart';
import 'folder_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FolderService _folderService;
  final LobbyProvider _lobbyProvider;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  RealtimeChannel? _userChannel;
  StreamSubscription<AuthState>? _authSubscription;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get isInitialized => _initCompleter.future;

  Completer<void> _loginCompleter = Completer<void>();

  String? _deviceIdentifier;
  String? _activeDeviceRecordId;
  bool _isLoggingIn = false;

  AuthService(this._folderService, this._lobbyProvider) {
    _authSubscription = authStateChanges.listen((data) async {
      // If a manual login is in progress, let signInWithEmailAndPassword handle everything.
      // We just complete the initializer if needed and exit.
      if (_isLoggingIn) {
        if (!_initCompleter.isCompleted) {
          _initCompleter.complete();
        }
        return;
      }

      final session = data.session;
      if (session != null) {
        // This path is for when the app starts with an existing, valid session.
        _deviceIdentifier = await getDeviceId();
        final isValid = await _validateAndCacheActiveDevice(session.user.id, _deviceIdentifier!);
        if (isValid) {
          _listenForSessionInvalidation(session.user.id);
        } else {
          // This will be called if the session from storage is no longer valid in the DB.
          await _performLocalSignOut();
        }
      } else {
        // This is for a logout event.
        await _clearLocalState();
      }

      // Ensure the completer is always completed.
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    });
  }

  Future<bool> _validateAndCacheActiveDevice(String userId, String deviceIdentifier) async {
    try {
      final response = await _supabase
          .from('devices')
          .select('id, is_active')
          .eq('user_id', userId)
          .eq('device_identifier', deviceIdentifier)
          .maybeSingle();

      if (response != null && response['is_active'] == true) {
        _activeDeviceRecordId = response['id'] as String;
        return true;
      }

      // Don't clear local state here, as it might be a temporary mismatch during login.
      // Let the calling function decide.
      return false;
    } catch (e) {
      // Don't clear state on a mere exception, could be a network blip.
      return false;
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _userChannel?.unsubscribe();
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    _loginCompleter = Completer<void>();
    _isLoggingIn = true;

    try {
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw const AuthException('Authentication failed.');

      if (await isUserBanned(userId: user.id)) {
        await signOut();
        throw const AuthException('This user account has been suspended.');
      }

      final deviceIdentifier = await getDeviceId();

      final result = await _supabase.rpc('register_device_and_deactivate_others', params: {
        'p_user_id': user.id,
        'p_device_identifier': deviceIdentifier,
      });

      if (result == null) {
        await signOut();
        throw const AuthException('Failed to register device.');
      }
      
      // Set state AFTER RPC is successful
      _activeDeviceRecordId = result.toString();
      _deviceIdentifier = deviceIdentifier;

      // Manually start the listener since onAuthStateChange is now bypassed during login
      _listenForSessionInvalidation(user.id);

      return user;
    } finally {
      _loginCompleter.complete();
      _isLoggingIn = false;
    }
  }

  Future<void> get onLoginComplete => _loginCompleter.future;

  String? getActiveDeviceRecordId() => _activeDeviceRecordId;

  void _listenForSessionInvalidation(String userId) {
    _userChannel?.unsubscribe();
    _userChannel = _supabase.channel('devices-listener-for-$userId');
    _userChannel!
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'devices',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) async {
              // This check is still a good secondary safety measure.
              if (_isLoggingIn) return;
              
              await onLoginComplete;

              final updatedRecord = payload.newRecord;
              final wasDeactivated = !(updatedRecord['is_active'] as bool);
              final updatedDeviceIdentifier = updatedRecord['device_identifier'] as String;

              if (updatedDeviceIdentifier == _deviceIdentifier && wasDeactivated) {
                _handleForcedLogout();
              }
            })
        .subscribe();
  }

  Future<void> _handleForcedLogout() async {
    try {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Session Expired"),
            content: const Text("You have been logged out because you signed in on another device."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
      await _performLocalSignOut();
    } catch (e) {
      await _performLocalSignOut();
    }
  }

  Future<void> _performLocalSignOut() async {
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      // Log error but continue cleanup
    } finally {
      await _clearLocalState();
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _clearLocalState() async {
    await _folderService.clearAllData();
    _lobbyProvider.clearLobby(); // Clear lobby provider state
    _userChannel?.unsubscribe();
    _deviceIdentifier = null;
    _activeDeviceRecordId = null;
  }

  Future<void> signOut() async {
    try {
      // We don't need to call the deactivation RPC on signout,
      // as the new login on another device will handle it.
      // Just sign out from supabase.
      await _supabase.auth.signOut();
    } catch (e) {
      // Log error but continue cleanup
    } finally {
      await _clearLocalState();
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<bool> isUserBanned({String? userId}) async {
    final id = userId ?? _supabase.auth.currentUser?.id;
    if (id == null) return false;
    final response = await _supabase.rpc('is_user_banned', params: {'user_id': id});
    return response as bool? ?? false;
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    await _supabase.auth.signUp(email: email, password: password);
    if (await isUserBanned(userId: _supabase.auth.currentUser?.id)) {
      await signOut();
      throw AuthException('This account has been banned');
    }
  }

  User? get currentUser => _supabase.auth.currentUser;

  final Uuid _uuid = const Uuid();

  Future<String> getDeviceId() async {
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
}