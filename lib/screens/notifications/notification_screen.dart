import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';

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
      context.read<NotificationProvider>().loadNotifications();
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
        return AppColors.accentCoral;
      case NotificationType.mention:
        return AppColors.accentCoral;
      case NotificationType.badgeEarned:
        return Colors.amber;
      case NotificationType.system:
        return AppColors.textGrey;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => provider.markAllAsRead(),
                child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: provider.notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = provider.notifications[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _colorForType(n.type).withOpacity(0.1),
                  child: Icon(_iconForType(n.type), color: _colorForType(n.type), size: 20),
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(_timeAgo(n.timestamp), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                trailing: n.isRead
                    ? null
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                onTap: () {
                  if (!n.isRead) provider.markAsRead(n.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}

