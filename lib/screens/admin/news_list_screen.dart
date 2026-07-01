import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/news_provider.dart';
import '../../routes/app_routes.dart';

class NewsListScreen extends StatefulWidget {
  const NewsListScreen({super.key});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load without any date filter on first open
      context.read<NewsProvider>().loadNews(refresh: true, categoryId: 'all', limit: 1000);
    });
  }

  Future<void> _openDateRangePicker() async {
    final provider = context.read<NewsProvider>();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: provider.isDateFiltered
          ? DateTimeRange(
              start: provider.selectedStartDate!,
              end: provider.selectedEndDate!,
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await provider.setDateFilter(picked.start, picked.end);
    }
  }

  String _formatDateRange(DateTime start, DateTime end) {
    String fmt(DateTime d) {
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    }
    return '${fmt(start)} – ${fmt(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage News'),
        actions: [
          // Clear filter button — visible only when a date range is active
          if (provider.isDateFiltered)
            IconButton(
              tooltip: 'Clear date filter',
              icon: const Icon(Icons.filter_alt_off_outlined),
              onPressed: () => provider.clearDateFilter(),
            ),
          // Filter / calendar icon
          IconButton(
            tooltip: 'Filter by date range',
            icon: Icon(
              Icons.date_range_outlined,
              color: provider.isDateFiltered
                  ? Theme.of(context).primaryColor
                  : null,
            ),
            onPressed: _openDateRangePicker,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active filter banner
          if (provider.isDateFiltered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).primaryColor.withAlpha(20),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtered: ${_formatDateRange(provider.selectedStartDate!, provider.selectedEndDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => provider.clearDateFilter(),
                    child: Icon(Icons.close, size: 18, color: Theme.of(context).primaryColor),
                  ),
                ],
              ),
            ),

          // News list
          Expanded(
            child: provider.isLoading && provider.news.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.news.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.article_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              provider.isDateFiltered
                                  ? 'No news in the selected date range.'
                                  : 'No news articles found.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.news.length,
                        itemBuilder: (context, index) {
                          final item = provider.news[index];
                          return _NewsItemTile(news: item);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _NewsItemTile extends StatelessWidget {
  final NewsModel news;

  const _NewsItemTile({required this.news});

  /// Format: dd MMM yyyy, h:mm a — in local timezone
  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Raw createdAt: ${news.createdAt}');
    debugPrint('Is UTC: ${news.createdAt?.isUtc}');
    debugPrint('Local: ${news.createdAt?.toLocal()}');
    
    final category = (news.categoryName == null || news.categoryName!.isEmpty)
        ? 'General'
        : news.categoryName!;
    final dateTime = _formatDateTime(news.createdAt);

    return ListTile(
      title: Text(
        news.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Row(
            children: [
              // Category chips
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: news.categories.isNotEmpty
                      ? news.categories.map((c) {
                          final name = c['name']?.toString() ?? 'General';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList()
                      : [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        ],
                ),
              ),
              if (dateTime.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.schedule, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(
                  dateTime,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ],
      ),
      isThreeLine: dateTime.isNotEmpty,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') {
            Navigator.pushNamed(
              context,
              AppRoutes.editNews,
              arguments: news,
            ).then((_) {
              if (context.mounted) {
                context.read<NewsProvider>().loadNews(refresh: true, categoryId: 'all', limit: 1000);
              }
            });
          } else if (value == 'delete') {
            await context.read<NewsProvider>().deleteNews(news.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
