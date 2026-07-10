import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/notification_card.dart';
import '../user/external_article_screen.dart';
import '../../models/notification_model.dart';
import '../../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  Future<void> _openNotification(NotificationModel item) async {
    final newsId = item.data?['newsId']?.toString();
    
    // Mark as read in the background
    if (!item.isRead) {
      context.read<NotificationProvider>().markAsRead(item.id);
    }
    
    if (newsId == null || newsId.isEmpty) return;

    try {
      final news = await ApiService().getNewsById(newsId);
      if (!mounted) return;

      final sourceUrl = news.sourceUrl;
      if (sourceUrl != null && sourceUrl.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExternalArticleScreen(
              title: news.title,
              url: sourceUrl,
            ),
          ),
        );
      } else {
        await Navigator.pushNamed(
          context,
          '${AppRoutes.newsDetailsById}/$newsId',
        );
      }
    } catch (_) {
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '${AppRoutes.newsDetailsById}/$newsId',
      );
    }
  }

  Future<void> _confirmDelete(NotificationModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteWithUndo(item, showUndo: false);
    }
  }

  Future<void> _deleteWithUndo(
    NotificationModel item, {
    bool showUndo = true,
  }) async {
    final provider = context.read<NotificationProvider>();
    final removed = await provider.deleteNotification(item.id);
    if (removed == null || !mounted) return;

    if (!showUndo) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            provider.restoreNotification(removed);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
        appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: provider.isLoading
          ? const LoadingWidget()
          : provider.notifications.isEmpty
              ? _EmptyNotificationsState()
              : RefreshIndicator(
                  onRefresh: provider.loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: provider.notifications.length,
                    itemBuilder: (context, index) {
                      final item = provider.notifications[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        onDismissed: (_) => _deleteWithUndo(item),
                        child: NotificationCard(
                          notification: item,
                          animationDelay: Duration(milliseconds: 40 * index),
                          onTap: () => _openNotification(item),
                          onDelete: () => _confirmDelete(item),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(isDark ? 60 : 100),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 28),
            Text(
              'No Notifications',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.15),
            const SizedBox(height: 10),
            Text(
              "You're all caught up!",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
          ],
        ),
      ),
    );
  }
}
