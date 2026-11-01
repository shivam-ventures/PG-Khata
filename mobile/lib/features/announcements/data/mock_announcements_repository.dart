import '../../../core/errors/result.dart';
import '../domain/announcement.dart';
import 'announcements_repository.dart';

class MockAnnouncementsRepository implements AnnouncementsRepository {
  final List<Announcement> _announcements = [];

  @override
  Future<Result<List<Announcement>>> fetchAnnouncements({
    required String propertyId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Ok(
      _announcements.where((a) => a.propertyId == propertyId).toList(),
    );
  }

  @override
  Future<Result<Announcement?>> fetchCurrentAnnouncement({
    required String propertyId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final matches = _announcements
        .where((a) => a.propertyId == propertyId && !a.isExpired)
        .toList();
    return Ok(matches.isEmpty ? null : matches.first);
  }

  @override
  Future<Result<Announcement>> createAnnouncement({
    required String propertyId,
    required String title,
    required String body,
    DateTime? expiresAt,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final announcement = Announcement(
      id: 'a${DateTime.now().microsecondsSinceEpoch}',
      propertyId: propertyId,
      title: title,
      body: body,
      createdByName: 'Staff',
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );
    _announcements.insert(0, announcement);
    return Ok(announcement);
  }

  @override
  Future<Result<void>> deleteAnnouncement(String announcementId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _announcements.removeWhere((a) => a.id == announcementId);
    return const Ok(null);
  }
}
