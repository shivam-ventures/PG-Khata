import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/app_notification.dart';
import 'notifications_repository.dart';

class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<AppNotification>>> fetchNotifications() async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return Ok([for (final row in rows) _toNotification(row)]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> markRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
      return const Ok(null);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> markAllRead() async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .filter('read_at', 'is', null);
      return const Ok(null);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  AppNotification _toNotification(Map<String, dynamic> row) {
    final readAt = row['read_at'] as String?;
    return AppNotification(
      id: row['id'] as String,
      kind: row['kind'] as String,
      title: row['title'] as String,
      body: row['body'] as String?,
      entityType: row['entity_type'] as String?,
      entityId: row['entity_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      readAt: readAt == null ? null : DateTime.parse(readAt),
    );
  }
}
