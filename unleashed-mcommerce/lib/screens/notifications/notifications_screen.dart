import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../chat/chat_screen.dart';
import '../orders/order_detail_screen.dart';

/// In-app notifications, delivered as Firestore documents and read in real
/// time. This is not push messaging: nothing is delivered while the app is
/// closed.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Stream<List<AppNotification>> _stream;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    final uid = AppState.instance.user?.uid;
    _stream = uid == null
        ? const Stream<List<AppNotification>>.empty()
        : NotificationService.instance.watchFor(uid);
  }

  Future<void> _refresh() async {
    setState(_bind);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _open(AppNotification notification) async {
    final uid = AppState.instance.user?.uid;
    if (uid != null && !notification.isRead) {
      await NotificationService.instance.markRead(uid, notification.id);
    }
    if (!mounted) return;
    if ((notification.orderId ?? '').isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: notification.orderId!),
        ),
      );
    } else if ((notification.chatId ?? '').isNotEmpty ||
        notification.type.startsWith('chat')) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    }
  }

  Future<void> _markAll() async {
    final uid = AppState.instance.user?.uid;
    if (uid == null) return;
    setState(() => _markingAll = true);
    try {
      await NotificationService.instance.markAllRead(uid);
      if (mounted) showAppSnack(context, 'All notifications marked as read.');
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not mark all as read.', error: true);
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _delete(AppNotification notification) async {
    final uid = AppState.instance.user?.uid;
    if (uid == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Remove notification?',
      message: 'This only removes the alert. Your order is not affected.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await NotificationService.instance.delete(uid, notification.id);
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'That notification could not be removed.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppState.instance.user?.uid;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('NOTIFICATIONS'),
        actions: [
          if (uid != null)
            TextButton(
              onPressed: _markingAll ? null : _markAll,
              child: _markingAll
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('READ ALL'),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: uid == null
          ? AppStateView.empty(
              icon: Icons.lock_outline,
              title: 'Sign in for alerts',
              message:
                  'Order updates, delivery news and store replies appear here '
                  'after you sign in.',
              actionLabel: 'Sign in',
              onAction: AppState.instance.requestSignIn,
            )
          : StreamBuilder<List<AppNotification>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppStateView.loading(
                    message: 'Loading your notifications…',
                  );
                }
                if (snapshot.hasError) {
                  return AppStateView.error(
                    title: 'Notifications are unavailable',
                    message:
                        'Alerts become available once the store publishes its '
                        'notification rules.',
                    onAction: _refresh,
                  );
                }
                final notifications =
                    snapshot.data ?? const <AppNotification>[];
                if (notifications.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        AppStateView.empty(
                          icon: Icons.notifications_none,
                          title: 'You are all caught up',
                          message:
                              'Order updates, delivery news and store replies '
                              'will appear here.',
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    children: [
                      const _NotificationsIntro(),
                      const SizedBox(height: 10),
                      for (var i = 0; i < notifications.length; i++) ...[
                        _NotificationTile(
                          notification: notifications[i],
                          onTap: () => _open(notifications[i]),
                          onDelete: () => _delete(notifications[i]),
                        ),
                        if (i != notifications.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _NotificationsIntro extends StatelessWidget {
  const _NotificationsIntro();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentMark(),
              SizedBox(width: 7),
              Eyebrow('The feed'),
              Spacer(),
              StatusDot(label: 'In-app only', color: AppColors.muted),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'YOUR ALERTS',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.3,
              height: 0.96,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Order updates, delivery news and store replies appear here in '
            'real time while the app is open.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  IconData get _icon {
    if (notification.type.startsWith('order_')) {
      switch (notification.type) {
        case 'order_requested':
        case 'order_pending_confirmation':
        case 'order_placed':
          return Icons.receipt_long_outlined;
        case 'order_confirmed':
        case 'order_processing':
        case 'order_ready_for_shipment':
          return Icons.inventory_2_outlined;
        case 'order_shipped':
        case 'order_out_for_delivery':
        case 'order_delivered':
          return Icons.local_shipping_outlined;
        case 'order_rejected':
        case 'order_cancelled':
        case 'order_refunded':
          return Icons.cancel_outlined;
        default:
          return Icons.local_shipping_outlined;
      }
    }
    switch (notification.type) {
      case 'chat':
      case 'chat_reply':
      case 'chat_message':
        return Icons.chat_bubble_outline;
      case 'review':
        return Icons.rate_review_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Material(
      color: unread ? AppColors.surface : AppColors.surfaceAlt,
      shape: Border(
        left: BorderSide(
          color: unread ? AppColors.accent : AppColors.line,
          width: unread ? 3 : 1,
        ),
        top: const BorderSide(color: AppColors.line),
        right: const BorderSide(color: AppColors.line),
        bottom: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: unread ? AppColors.ink : AppColors.subtle,
                ),
                child: Icon(
                  _icon,
                  size: 17,
                  color: unread ? Colors.white : AppColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.3,
                              letterSpacing: 0.1,
                              fontWeight: unread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 2),
                            width: 6,
                            height: 6,
                            color: AppColors.accent,
                          ),
                      ],
                    ),
                    if (notification.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      timeAgo(notification.createdAt).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove notification',
                onPressed: onDelete,
                icon: const Icon(Icons.close, size: 15),
                color: AppColors.muted,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
