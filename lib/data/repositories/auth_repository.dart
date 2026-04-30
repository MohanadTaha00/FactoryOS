import 'package:supabase_flutter/supabase_flutter.dart'
    hide UserAttributes;

import '../models/enums.dart';
import '../models/user_attributes.dart';
import '../supabase/supabase_service.dart';

/// Encapsulates everything Supabase-Auth related: sign in, sign out,
/// and resolving the `UserAttributes` row attached to the session.
class AuthRepository {
  AuthRepository();

  SupabaseClient get _client => SupabaseService.client;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  Session? get session => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    UserRole role = UserRole.worker,
  }) =>
      _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName, 'role': role.wire},
      );

  Future<void> signOut() => _client.auth.signOut();

  Future<UserAttributes?> fetchProfile(String userId) async {
    final row = await _client
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserAttributes.fromMap(row);
  }
}
