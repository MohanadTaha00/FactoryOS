import 'package:supabase_flutter/supabase_flutter.dart'
    hide UserAttributes;

import '../models/enums.dart';
import '../models/user_attributes.dart';
import '../supabase/supabase_service.dart';

class UsersRepository {
  UsersRepository();

  SupabaseClient get _c => SupabaseService.client;

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
