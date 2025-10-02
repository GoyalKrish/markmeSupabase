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

  // Completer to signal when async initialization is done.
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get isInitialized => _initCompleter.future;

  // Cached values
  String? _deviceIdentifier;
  String? _activeDeviceRecordId; // This is the stable UUID PK from the devices table

  AuthService() {
    _authSubscription = authStateChanges.listen((data) async {
      final session = data.session;
      if (session != null) {
        _deviceIdentifier = await getDeviceId();
        await _fetchAndCacheActiveDeviceRecord(session.user.id, _deviceIdentifier!);
        _listenForSessionInvalidation(session.user.id);
      } else {
        _userChannel?.unsubscribe();
        _deviceIdentifier = null;
        _activeDeviceRecordId = null;
      }

      // Signal that initialization is complete, whether logged in or not.
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    });
  }

  Future<void> _fetchAndCacheActiveDeviceRecord(String userId, String deviceIdentifier) async {
    try {
      final response = await _supabase
          .from('devices')
          .select('id')
          .eq('user_id', userId)
          .eq('device_identifier', deviceIdentifier)
          .maybeSingle();

      if (response != null) {
        _activeDeviceRecordId = response['id'] as String;
        print('Active device ID $_activeDeviceRecordId cached on startup.');
      } else {
        _activeDeviceRecordId = null;
        print('No active device record found on startup for device: $deviceIdentifier');
      }
    } catch (e) {
      print('Error fetching active device record: $e');
      _activeDeviceRecordId = null;
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _userChannel?.unsubscribe();
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
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
  }

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
                print('Session invalidated remotely for device $_deviceIdentifier. Logging out.');

                final context = navigatorKey.currentContext;
                if (context != null && context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Text("Session Expired"),
                      content: const Text("You have been logged out because you signed in on another device."),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            signOut();
                          },
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );
                } else {
                  signOut();
                }
              }
            })
        .subscribe();
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<bool> isUserBanned({String? userId}) async {
    final id = userId ?? _supabase.auth.currentUser?.id;
    if (id == null) return false;

    final response = await _supabase.rpc('is_user_banned', params: {
      'user_id': id,
    });

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