import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/notifications_repository.dart';
import '../data/supabase_notifications_repository.dart';
import '../domain/app_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => SupabaseNotificationsRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's own notifications, newest first.
///
/// `autoDispose` on purpose: the "More"/Profile tab stays mounted for the
/// rest of a session once visited (it lives inside the role shell's
/// `IndexedStack`), so a plain `FutureProvider` would cache whatever it
/// first fetched — including an empty inbox fetched before anything ever
/// notified this user — for the rest of the app's lifetime, never
/// refetching on a later visit. `autoDispose` drops that cached value once
/// nothing's watching it (e.g. across a logout, which tears down the whole
/// role shell), so the next visit fetches fresh instead of replaying a
/// stale snapshot.
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((
  ref,
) async {
  final result = await ref
      .watch(notificationsRepositoryProvider)
      .fetchNotifications();
  return result.when(ok: (v) => v, err: (failure) => throw failure);
});

/// Unread count for a "More"/Profile menu badge — a thin derived view over
/// [notificationsProvider] rather than a second query, so the two never
/// disagree. Also `autoDispose`: a non-autoDispose provider watching an
/// autoDispose one would keep it alive forever, defeating the point above.
final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value;
  if (notifications == null) return 0;
  return notifications.where((n) => n.isUnread).length;
});

void _invalidateNotifications(WidgetRef ref) {
  ref.invalidate(notificationsProvider);
}

Future<AppFailure?> markNotificationRead(
  WidgetRef ref,
  String notificationId,
) async {
  final result = await ref
      .read(notificationsRepositoryProvider)
      .markRead(notificationId);
  return result.when(
    ok: (_) {
      _invalidateNotifications(ref);
      return null;
    },
    err: (failure) => failure,
  );
}

Future<AppFailure?> markAllNotificationsRead(WidgetRef ref) async {
  final result = await ref
      .read(notificationsRepositoryProvider)
      .markAllRead();
  return result.when(
    ok: (_) {
      _invalidateNotifications(ref);
      return null;
    },
    err: (failure) => failure,
  );
}
