import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Shared notification state so the app-bar badge and the inbox sheet never
/// disagree about the unread count.
class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  Future<({List<Map<String, dynamic>> notifications, int unreadCount})> fetch({
    int limit = 60,
  }) async {
    final result = await ApiService.instance.getNotifications(limit: limit);
    unread.value = result.unreadCount;
    return result;
  }

  Future<void> refresh() async {
    try {
      final result = await ApiService.instance.getNotifications(limit: 30);
      unread.value = result.unreadCount;
    } catch (_) {
      // Keep the last known badge rather than flashing to zero on a flaky link.
    }
  }

  Future<ApiResult> markRead(String id) async {
    final result = await ApiService.instance.markNotificationsRead(id: id);
    if (result.isSuccess) {
      final next = unread.value > 0 ? unread.value - 1 : 0;
      unread.value = next;
      final serverCount = result.data?['unread_count'];
      if (serverCount is num) unread.value = serverCount.toInt();
    }
    return result;
  }

  Future<ApiResult> markAllRead() async {
    final result = await ApiService.instance.markNotificationsRead(markAll: true);
    if (result.isSuccess) unread.value = 0;
    return result;
  }

  void reset() {
    unread.value = 0;
  }
}
