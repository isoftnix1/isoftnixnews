import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../widgets/loading_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: provider.isLoading
          ? const LoadingWidget()
          : provider.notifications.isEmpty
              ? const Center(
                  child: Text('No notifications yet.'),
                )
              : ListView.separated(
                  itemCount: provider.notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = provider.notifications[index];
                    final date = item.createdAt ?? DateTime.now();
                    final formattedDate = DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());

                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.notifications_active_outlined),
                      ),
                      title: Text(item.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(item.body),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}