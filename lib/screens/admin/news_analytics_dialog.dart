import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/news_provider.dart';

class NewsAnalyticsDialog extends StatefulWidget {
  final NewsModel news;

  const NewsAnalyticsDialog({super.key, required this.news});

  static Future<void> show(BuildContext context, NewsModel news) {
    return showDialog(
      context: context,
      builder: (_) => NewsAnalyticsDialog(news: news),
    );
  }

  @override
  State<NewsAnalyticsDialog> createState() => _NewsAnalyticsDialogState();
}

class _NewsAnalyticsDialogState extends State<NewsAnalyticsDialog> {
  bool _isLoading = true;
  Map<String, dynamic>? _analytics;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    try {
      final data = await context.read<NewsProvider>().fetchNewsAnalytics(widget.news.id);
      if (mounted) {
        setState(() {
          _analytics = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Engagement Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            widget.news.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatCard('Total Registered Users', _analytics!['totalUsers']?.toString() ?? '0', Icons.people, Colors.blue),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard('Viewed Users', _analytics!['viewedUsers']?.toString() ?? '0', Icons.visibility, Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard('Not Viewed', _analytics!['notViewedUsers']?.toString() ?? '0', Icons.visibility_off, Colors.orange),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildStatCard('View Rate', '${_analytics!['viewPercentage'] ?? '0'}%', Icons.pie_chart, Colors.purple),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Reminder Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(height: 12),
                        _buildStatCard('Status', _analytics!['reminderStatus']?.toString().toUpperCase() ?? 'PENDING', Icons.schedule, _analytics!['reminderStatus'] == 'completed' ? Colors.green : Colors.orange),
                        const SizedBox(height: 12),
                        _buildStatCard('Reminders Sent', _analytics!['reminderSent']?.toString() ?? '0', Icons.notifications_active, Colors.teal),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
