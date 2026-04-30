import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

import '../local/app_database.dart';
import '../supabase/supabase_service.dart';

/// Drains the offline mutation queue when connectivity returns and exposes
/// a simple `isOnline` stream so the UI can show the connection indicator.
class SyncRepository {
  SyncRepository(this._db) {
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  final AppDatabase _db;
  final Connectivity _connectivity = Connectivity();
  final Logger _log = Logger();

  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();
  Stream<bool> get onlineStream => _onlineController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final online = results.any((r) => r != ConnectivityResult.none);
    _isOnline = online;
    _onlineController.add(online);
    if (online) {
      await drainQueue();
    }
  }

  Future<void> drainQueue() async {
    final pending = await _db.pendingMutationsList();
    for (final m in pending) {
      try {
        final args = jsonDecode(m.payload) as Map<String, dynamic>;
        await SupabaseService.client.rpc(m.kind, params: args);
        await _db.markMutationDone(m.id);
      } catch (e) {
        _log.w('mutation ${m.id}/${m.kind} failed: $e');
        await _db.bumpMutationFailure(m.id, e.toString());
      }
    }
  }

  Future<int> pendingCount() async =>
      (await _db.pendingMutationsList()).length;

  void dispose() {
    _onlineController.close();
  }
}
