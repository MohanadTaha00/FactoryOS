import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../supabase/supabase_service.dart';

class NotificationsRepository {
  NotificationsRepository();

  SupabaseClient get _c => SupabaseService.client;

  Future<List<AppNotification>> fetchFor(String userId) async {
    final rows = await _c
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromMap)
        .toList();
  }

  Stream<List<AppNotification>> watchFor(String userId) {
    return _c
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows.map(AppNotification.fromMap).toList());
  }

  Future<void> markRead(String id) async {
    await _c
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<void> markAllRead(String userId) async {
    await _c
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('recipient_id', userId)
        .isFilter('read_at', null);
  }
}
