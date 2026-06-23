import 'package:flutter/material.dart';
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
      context.read<NewsProvider>().loadNews(refresh: true, categoryId: 'all');
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage News')),
      body: provider.isLoading && provider.news.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: provider.news.length,
              itemBuilder: (context, index) {
                final item = provider.news[index];
                return _NewsItemTile(news: item);
              },
            ),
    );
  }
}

class _NewsItemTile extends StatelessWidget {
  final NewsModel news;

  const _NewsItemTile({required this.news});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(news.title),
      subtitle: Text(news.categoryName == null || news.categoryName!.isEmpty
          ? 'General'
          : news.categoryName!),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') {
            Navigator.pushNamed(
              context,
              AppRoutes.editNews,
              arguments: news,
            ).then((_) {
              if (context.mounted) {
                context.read<NewsProvider>().loadNews(refresh: true, categoryId: 'all');
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
