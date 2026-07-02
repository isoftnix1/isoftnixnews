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
  final Set<String> _selectedIds = {};

  bool get _hasSelection => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsProvider>().loadNews(refresh: true, categoryId: 'all', limit: 1000);
    });
  }

  bool _isAllSelected(List<NewsModel> items) {
    return items.isNotEmpty && _selectedIds.length == items.length;
  }

  void _toggleSelectAll(List<NewsModel> items, bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds
          ..clear()
          ..addAll(items.map((item) => item.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleItem(String id, bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $count selected news article${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<NewsProvider>();
    final ids = _selectedIds.toList();
    final deletedCount = await provider.deleteMultipleNews(ids);

    if (!mounted) return;

    _clearSelection();

    if (deletedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$deletedCount news article${deletedCount == 1 ? '' : 's'} deleted successfully.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
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
      _clearSelection();
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
    final theme = Theme.of(context);
    final allSelected = _isAllSelected(provider.news);

    return Scaffold(
      appBar: AppBar(
        title: Text(_hasSelection ? 'Selected: ${_selectedIds.length}' : 'Manage News'),
        actions: [
          if (_hasSelection)
            TextButton.icon(
              onPressed: provider.isLoading ? null : _confirmBulkDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              label: const Text(
                'Delete Selected',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
            ),
          if (provider.isDateFiltered)
            IconButton(
              tooltip: 'Clear date filter',
              icon: const Icon(Icons.filter_alt_off_outlined),
              onPressed: () {
                _clearSelection();
                provider.clearDateFilter();
              },
            ),
          IconButton(
            tooltip: 'Filter by date range',
            icon: Icon(
              Icons.date_range_outlined,
              color: provider.isDateFiltered ? theme.primaryColor : null,
            ),
            onPressed: _openDateRangePicker,
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.isDateFiltered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.primaryColor.withAlpha(20),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtered: ${_formatDateRange(provider.selectedStartDate!, provider.selectedEndDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _clearSelection();
                      provider.clearDateFilter();
                    },
                    child: Icon(Icons.close, size: 18, color: theme.primaryColor),
                  ),
                ],
              ),
            ),

          if (_hasSelection)
            Material(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _selectedIds.isEmpty
                          ? false
                          : (allSelected ? true : null),
                      tristate: true,
                      onChanged: provider.news.isEmpty
                          ? null
                          : (_) => _toggleSelectAll(provider.news, !allSelected),
                    ),
                    Text(
                      'Select All',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),

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
                          return _NewsItemTile(
                            news: item,
                            isSelected: _selectedIds.contains(item.id),
                            onSelectedChanged: (value) => _toggleItem(item.id, value),
                            onEditComplete: () {
                              if (context.mounted) {
                                context
                                    .read<NewsProvider>()
                                    .loadNews(refresh: true, categoryId: 'all', limit: 1000);
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _NewsItemTile extends StatelessWidget {
  const _NewsItemTile({
    required this.news,
    required this.isSelected,
    required this.onSelectedChanged,
    required this.onEditComplete,
  });

  final NewsModel news;
  final bool isSelected;
  final ValueChanged<bool?> onSelectedChanged;
  final VoidCallback onEditComplete;

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy, h:mm a').format(dt.toLocal());
  }

  Future<void> _confirmSingleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete this news article?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<NewsProvider>().deleteNews(news.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = (news.categoryName == null || news.categoryName!.isEmpty)
        ? 'General'
        : news.categoryName!;
    final dateTime = _formatDateTime(news.createdAt);

    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: onSelectedChanged,
      ),
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
            await Navigator.pushNamed(
              context,
              AppRoutes.editNews,
              arguments: news,
            );
            onEditComplete();
          } else if (value == 'delete') {
            await _confirmSingleDelete(context);
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
