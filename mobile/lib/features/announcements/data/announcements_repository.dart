import '../../../core/errors/result.dart';
import '../domain/announcement.dart';

/// Per-property broadcasts from Owner/Manager to that property's current
/// tenants. RLS scopes every read to the caller's own relationship with the
/// property (staff of it, or a current tenant there), and every write to
/// staff — see `announcements`' RLS policies.
abstract interface class AnnouncementsRepository {
  /// Full history for one property, newest first — the Owner/Manager
  /// management view.
  Future<Result<List<Announcement>>> fetchAnnouncements({
    required String propertyId,
  });

  /// The single most recent, not-yet-expired announcement for a property —
  /// what a tenant's Home screen shows, or `null` if there isn't one.
  Future<Result<Announcement?>> fetchCurrentAnnouncement({
    required String propertyId,
  });

  Future<Result<Announcement>> createAnnouncement({
    required String propertyId,
    required String title,
    required String body,
    DateTime? expiresAt,
  });

  /// Ends an announcement early.
  Future<Result<void>> deleteAnnouncement(String announcementId);
}
