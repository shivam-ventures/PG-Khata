import 'package:flutter/foundation.dart';

/// An in-app notification for the signed-in user. [kind] is a free-form,
/// open-ended string set by the backend RPC that raised it (e.g.
/// `'payment_disputed'`, `'complaint_resolved'`) — matches `notifications`'
/// own comment in the schema; the UI only needs [icon] to pick an icon per
/// kind, everything else it just displays.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.entityType,
    this.entityId,
    this.readAt,
  });

  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? entityType;
  final String? entityId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;
}
