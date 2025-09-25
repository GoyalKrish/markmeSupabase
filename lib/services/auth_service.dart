import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Add stream to listen for auth changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<bool> isUserBanned() async {
    if (_supabase.auth.currentUser == null) return false;
    
    final response = await _supabase.rpc('is_user_banned', params: {
      'user_id': _supabase.auth.currentUser!.id,
    });
    
    return response as bool? ?? false;
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    await _supabase.auth.signUp(email: email, password: password);
    if (await isUserBanned()) {
      await signOut();
      throw AuthException('This account has been banned');
    }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(email: email, password: password);
    final user = response.user;

    if (user != null) {
      final deviceId = await getDeviceId();

      // Upsert device for first login or update last_used_at
      await _supabase.from('devices').upsert({
        'user_id': user.id,
        'id': deviceId,
        'last_used_at': DateTime.now().toIso8601String(),
        'banned': false,
      }, onConflict: 'user_id');
    }

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