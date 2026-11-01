import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/announcement.dart';
import 'announcements_repository.dart';

class SupabaseAnnouncementsRepository implements AnnouncementsRepository {
  SupabaseAnnouncementsRepository(this._client);

  final SupabaseClient _client;

  static const _selectColumns =
      'id, property_id, title, body, created_at, expires_at, '
      'author:profiles!announcements_created_by_fkey(full_name)';

  @override
  Future<Result<List<Announcement>>> fetchAnnouncements({
    required String propertyId,
  }) async {
    if (propertyId == '') return const Ok([]);
    try {
      final rows = await _client
          .from('announcements')
          .select(_selectColumns)
          .eq('property_id', propertyId)
          .order('created_at', ascending: false);
      return Ok([for (final row in rows) _toAnnouncement(row)]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<Announcement?>> fetchCurrentAnnouncement({
    required String propertyId,
  }) async {
    if (propertyId == '') return const Ok(null);
    try {
      final rows = await _client
          .from('announcements')
          .select(_selectColumns)
          .eq('property_id', propertyId)
          .or('expires_at.is.null,expires_at.gt.${DateTime.now().toUtc().toIso8601String()}')
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return const Ok(null);
      return Ok(_toAnnouncement(rows.first));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<Announcement>> createAnnouncement({
    required String propertyId,
    required String title,
    required String body,
    DateTime? expiresAt,
  }) async {
    try {
      final created = await _client.rpc(
        'create_announcement',
        params: {
          'p_property_id': propertyId,
          'p_title': title,
          'p_body': body,
          if (expiresAt != null)
            'p_expires_at': expiresAt.toUtc().toIso8601String(),
        },
      );
      final id = (created as Map<String, dynamic>)['id'] as String;
      final row = await _client
          .from('announcements')
          .select(_selectColumns)
          .eq('id', id)
          .single();
      return Ok(_toAnnouncement(row));
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> deleteAnnouncement(String announcementId) async {
    try {
      await _client.from('announcements').delete().eq('id', announcementId);
      return const Ok(null);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  Announcement _toAnnouncement(Map<String, dynamic> row) {
    final author = row['author'] as Map<String, dynamic>?;
    final expiresAt = row['expires_at'] as String?;
    return Announcement(
      id: row['id'] as String,
      propertyId: row['property_id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      createdByName: author?['full_name'] as String? ?? 'Staff',
      createdAt: DateTime.parse(row['created_at'] as String),
      expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt),
    );
  }
}
