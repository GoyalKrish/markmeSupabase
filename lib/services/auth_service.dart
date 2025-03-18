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

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
    if (await isUserBanned()) {
      await signOut();
      throw AuthException('This account has been banned');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
} 