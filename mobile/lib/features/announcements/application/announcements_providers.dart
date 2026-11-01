import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/announcements_repository.dart';
import '../data/supabase_announcements_repository.dart';
import '../domain/announcement.dart';

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>(
  (ref) => SupabaseAnnouncementsRepository(ref.watch(supabaseClientProvider)),
);

/// Full history for one property — the Owner/Manager management screen.
final announcementsProvider = FutureProvider.family<List<Announcement>, String>(
  (ref, propertyId) async {
    final result = await ref
        .watch(announcementsRepositoryProvider)
        .fetchAnnouncements(propertyId: propertyId);
    return result.when(ok: (v) => v, err: (failure) => throw failure);
  },
);

/// The single current announcement for a property, or `null` — what a
/// tenant's Home screen shows.
final currentAnnouncementProvider =
    FutureProvider.family<Announcement?, String>((ref, propertyId) async {
      final result = await ref
          .watch(announcementsRepositoryProvider)
          .fetchCurrentAnnouncement(propertyId: propertyId);
      return result.when(ok: (v) => v, err: (failure) => throw failure);
    });

void _invalidateAnnouncements(WidgetRef ref, String propertyId) {
  ref.invalidate(announcementsProvider(propertyId));
  ref.invalidate(currentAnnouncementProvider(propertyId));
}

Future<AppFailure?> createAnnouncement(
  WidgetRef ref, {
  required String propertyId,
  required String title,
  required String body,
  DateTime? expiresAt,
}) async {
  final result = await ref
      .read(announcementsRepositoryProvider)
      .createAnnouncement(
        propertyId: propertyId,
        title: title,
        body: body,
        expiresAt: expiresAt,
      );
  return result.when(
    ok: (_) {
      _invalidateAnnouncements(ref, propertyId);
      return null;
    },
    err: (failure) => failure,
  );
}

Future<AppFailure?> deleteAnnouncement(
  WidgetRef ref,
  String announcementId, {
  required String propertyId,
}) async {
  final result = await ref
      .read(announcementsRepositoryProvider)
      .deleteAnnouncement(announcementId);
  return result.when(
    ok: (_) {
      _invalidateAnnouncements(ref, propertyId);
      return null;
    },
    err: (failure) => failure,
  );
}
