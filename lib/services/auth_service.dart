import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_exceptions.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Add stream to listen for auth changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<bool> isUserBanned({String? userId}) async {
    final id = userId ?? _supabase.auth.currentUser?.id;
    if (id == null) return false;

    final response = await _supabase.rpc('is_user_banned', params: {
      'user_id': _supabase.auth.currentUser!.id,
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

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    // 1. Authenticate with Supabase
    final AuthResponse response;
    try {
      response =
          await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException {
      rethrow; // Let the UI handle "Invalid login credentials"
    }

    final user = response.user;
    if (user == null) {
      // This case should ideally not be hit if signInWithPassword throws, but as a safeguard:
      throw const AuthException('Authentication failed: No user data received.');
    }

    // 2. Check if the USER is banned
    if (await isUserBanned(userId: user.id)) {
      await signOut(); // Ensure session is cleared
      throw const AuthException('This user account has been suspended.');
    }

    // 3. Get current device ID
    final deviceId = await getDeviceId();

    // 4. Pre-login device validation
    final deviceResponse = await _supabase
        .from('devices')
        .select('user_id, banned')
        .eq('id', deviceId)
        .maybeSingle();

    if (deviceResponse != null) {
      // Case F: Device is banned
      if (deviceResponse['banned'] == true) {
        await signOut();
        throw DeviceBannedException();
      }
      // Case D: Device exists and is linked to another user
      if (deviceResponse['user_id'] != user.id) {
        await signOut();
        throw DeviceInUseException();
      }
    }

    // 5. All checks passed, register the device.
    // This handles Case A (existing device) and Case B/E (new device for this user).
    // The 'onConflict: 'user_id'' ensures this user can only have one device entry.
    // It will overwrite the previous deviceId if it's a new device for this user.
    await _supabase.from('devices').upsert({
      'user_id': user.id,
      'id': deviceId,
      'last_used_at': DateTime.now().toIso8601String(),
      'banned': false,
    }, onConflict: 'user_id');

    // 6. Return user to allow login to proceed
    return user;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
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
