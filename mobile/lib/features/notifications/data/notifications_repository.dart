import '../../../core/errors/result.dart';
import '../domain/app_notification.dart';

/// The signed-in user's own notification inbox — RLS scopes every read/write
/// to `recipient_user_id = auth.uid()`, so there's no per-role or per-property
/// parameter here, unlike most other repositories in this app.
abstract interface class NotificationsRepository {
  Future<Result<List<AppNotification>>> fetchNotifications();

  Future<Result<void>> markRead(String notificationId);

  Future<Result<void>> markAllRead();
}
