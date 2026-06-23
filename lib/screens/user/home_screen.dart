import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/news_card.dart';
import '../../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsProvider>().loadCategories();
      context.read<NewsProvider>().loadNews(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final newsProvider = context.read<NewsProvider>();
    if (newsProvider.hasMore && !newsProvider.isLoading) {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        newsProvider.loadMoreNews();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final newsProvider = context.watch<NewsProvider>();
    context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ISoftNix News'),
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () => newsProvider.loadNews(refresh: true),
        child: newsProvider.isLoading && newsProvider.news.isEmpty
            ? const LoadingWidget()
            : Column(
                children: [
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: newsProvider.categories.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = newsProvider.categories[index];
                        return CategoryChip(
                          label: category.name,
                          isSelected: newsProvider.selectedCategoryId == category.id,
                          onTap: () {
                            newsProvider.selectCategory(category.id);
                            newsProvider.loadNews(refresh: true);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: newsProvider.news.length + 1,
                      itemBuilder: (context, index) {
                        if (index == newsProvider.news.length) {
                          if (!newsProvider.hasMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: Text('No more articles')), 
                            );
                          }
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final item = newsProvider.news[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: NewsCard(
                            news: item,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.newsDetails,
                              arguments: item,
                            ),
                          ),
                        ).animate().fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms);
                      },
                      controller: _scrollController,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
