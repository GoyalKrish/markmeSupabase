import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../main.dart'; // Import main.dart to get the navigatorKey
import 'auth_exceptions.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  RealtimeChannel? _userChannel;
  StreamSubscription<AuthState>? _authSubscription;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get isInitialized => _initCompleter.future;

  // NEW: Completer to signal when a new login has fully processed.
  Completer<void> _loginCompleter = Completer<void>();

  String? _deviceIdentifier;
  String? _activeDeviceRecordId;

  AuthService() {
    _authSubscription = authStateChanges.listen((data) async {
      final session = data.session;
      if (session != null) {
        _deviceIdentifier = await getDeviceId();
        final isValid = await _validateAndCacheActiveDevice(session.user.id, _deviceIdentifier!);
        if (isValid) {
          _listenForSessionInvalidation(session.user.id);
        } else {
          await _performLocalSignOut();
        }
      } else {
        _clearLocalState();
      }

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
        print('Active device ID $_activeDeviceRecordId validated and cached.');
        return true;
      }

      print('Device validation failed. No active record found for device: $deviceIdentifier');
      _clearLocalState();
      return false;
    } catch (e) {
      print('Error validating device: $e');
      _clearLocalState();
      return false;
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _userChannel?.unsubscribe();
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    // Reset the completer for the new login attempt.
    if (_loginCompleter.isCompleted) {
      _loginCompleter = Completer<void>();
    }

    try {
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw const AuthException('Authentication failed.');

      if (await isUserBanned(userId: user.id)) {
        await signOut();
        throw const AuthException('This user account has been suspended.');
      }

      final deviceIdentifier = await getDeviceId();
      _deviceIdentifier = deviceIdentifier;

      final result = await _supabase.rpc('register_device_and_deactivate_others', params: {
        'p_user_id': user.id,
        'p_device_identifier': deviceIdentifier,
      });

      if (result == null) {
        await signOut();
        throw const AuthException('Failed to register device.');
      }
      _activeDeviceRecordId = result.toString();
      print('Active device ID $_activeDeviceRecordId set on login.');

      return user;
    } finally {
      // Signal that the login process (including RPC) is complete.
      _loginCompleter.complete();
    }
  }

  // NEW: Expose the login future.
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
            callback: (payload) {
              final updatedRecord = payload.newRecord;
              final wasDeactivated = !(updatedRecord['is_active'] as bool);
              final updatedDeviceIdentifier = updatedRecord['device_identifier'] as String;

              if (updatedDeviceIdentifier == _deviceIdentifier && wasDeactivated) {
                print('Session invalidated remotely for device $_deviceIdentifier. Forcing local logout.');
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
      print('Error during forced logout: $e');
      // As a fallback, ensure navigation to login happens.
      await _performLocalSignOut();
    }
  }

  Future<void> _performLocalSignOut() async {
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      print('Error during local sign out: $e');
    } finally {
      _clearLocalState();
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _clearLocalState() {
    _userChannel?.unsubscribe();
    _deviceIdentifier = null;
    _activeDeviceRecordId = null;
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('Error during global sign out: $e');
    } finally {
      _clearLocalState();
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
