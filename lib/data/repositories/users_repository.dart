import 'package:supabase_flutter/supabase_flutter.dart'
    hide UserAttributes;

import '../models/enums.dart';
import '../models/user_attributes.dart';
import '../supabase/supabase_service.dart';

class UsersRepository {
  UsersRepository();

  SupabaseClient get _c => SupabaseService.client;

  /// Manager/Admin account provisioning via Supabase Edge Function.
  /// The function is expected to enforce role checks server-side.
  Future<void> createUserByManager({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (role != UserRole.worker && role != UserRole.qa) {
      throw StateError('Managers can only create worker or QA accounts.');
    }
    await _c.functions.invoke(
      'manager-create-user',
      body: {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'role': role.wire,
      },
    );
  }

  Future<List<UserAttributes>> fetchByRole(UserRole role) async {
    final rows = await _c
        .from('user_profiles')
        .select()
        .eq('role', role.wire)
        .order('full_name', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(UserAttributes.fromMap)
        .toList();
  }

  Future<List<UserAttributes>> fetchAll() async {
    final rows = await _c
        .from('user_profiles')
        .select()
        .order('full_name', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(UserAttributes.fromMap)
        .toList();
  }
}
