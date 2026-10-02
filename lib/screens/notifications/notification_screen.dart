import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().loadNotifications();
    });
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.reportUpdate:
        return Icons.assignment_outlined;
      case NotificationType.projectUpdate:
        return Icons.nature_outlined;
      case NotificationType.comment:
        return Icons.comment_outlined;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.badgeEarned:
        return Icons.emoji_events_outlined;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.reportUpdate:
        return AppColors.statusVerified;
      case NotificationType.projectUpdate:
        return AppColors.primary;
      case NotificationType.comment:
      case NotificationType.mention:
        return AppColors.accentCoral;
      case NotificationType.badgeEarned:
        return Colors.amber.shade800;
      case NotificationType.system:
        return AppColors.textGrey;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) {
      return '${date.day}/${date.month}/${date.year}';
    }
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildBody(NotificationProvider provider) {
    final items = provider.notifications;

    if (provider.isLoading && items.isEmpty) {
      return const SkeletonList(count: 6);
    }

    if (items.isEmpty) {
      final Widget empty;
      if (provider.error != null) {
        empty = EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load notifications',
          subtitle: 'Check your connection and try again.',
          actionLabel: 'Retry',
          actionIcon: Icons.refresh,
          onAction: provider.loadNotifications,
        );
      } else {
        empty = EmptyState(
          icon: provider.notificationsEnabled
              ? Icons.notifications_none_outlined
              : Icons.notifications_off_outlined,
          title: provider.notificationsEnabled
              ? 'No notifications yet'
              : 'In-app notifications are turned off',
          subtitle: provider.notificationsEnabled
              ? 'Updates on your reports, permits and projects will show up here.'
              : 'You can turn them back on in Settings.',
        );
      }
      // Scrollable so pull-to-refresh also works on the empty state.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: empty,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final n = items[index];
        final color = _colorForType(n.type);
        return Semantics(
          label: '${n.isRead ? '' : 'Unread. '}${n.title}. ${n.body}',
          excludeSemantics: true,
          button: !n.isRead,
          child: Material(
            color: n.isRead
                ? AppColors.cardWhite
                : AppColors.primary.fade(0.06),
            borderRadius: AppRadius.mdAll,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: n.isRead ? null : () => provider.markAsRead(n.id),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: color.fade(0.12),
                      child: Icon(_iconForType(n.type), color: color, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _timeAgo(n.timestamp),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!n.isRead) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Selector<NotificationProvider, int>(
            selector: (_, p) => p.unreadCount,
            builder: (context, unread, _) {
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: context.read<NotificationProvider>().markAllAsRead,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) => RefreshIndicator(
          onRefresh: provider.loadNotifications,
          child: _buildBody(provider),
        ),
      ),
    );
  }
}
