import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Add stream to listen for auth changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    await _supabase.auth.signUp(email: email, password: password);
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
} 