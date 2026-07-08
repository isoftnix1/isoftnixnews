import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../routes/app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/news_card.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/corn_loader/corn_loader.dart';
import 'external_article_screen.dart';

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
      final lang = context.read<LanguageProvider>().currentLanguage;
      context.read<NewsProvider>().loadCategories(lang: lang);
      context.read<NewsProvider>().loadNews(refresh: true, lang: lang);
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

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer<LanguageProvider>(
          builder: (context, provider, _) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Language',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('English'),
                    trailing: provider.currentLanguage == 'en'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      provider.changeLanguage(context, 'en');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('हिंदी'),
                    trailing: provider.currentLanguage == 'hi'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      provider.changeLanguage(context, 'hi');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('मराठी'),
                    trailing: provider.currentLanguage == 'mr'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      provider.changeLanguage(context, 'mr');
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final newsProvider = context.watch<NewsProvider>();
    context.watch<AuthProvider>();

    return Scaffold(
        appBar: AppBar(

        leadingWidth: 96,
        leading: Builder(
          builder: (context) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),

                const SizedBox(width: 10), // 👈 ADD THIS

                GestureDetector(
                  onTap: () => _showLanguageBottomSheet(context),
                  child: Row(
                    children: [
                      const Icon(Icons.language, size: 20),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        title: Text(
          AppLocalizations.of(context, 'app_title'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
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
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(child: Text(AppLocalizations.of(context, 'no_more_articles'))), 
                            );
                          }
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CornLoader(size: 48)),
                          );
                        }

                        final item = newsProvider.news[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: NewsCard(
                            news: item,
                            onTap: () {
                              final sourceUrl = item.sourceUrl;
                              if (sourceUrl != null && sourceUrl.isNotEmpty) {
                                // External article → in-app WebView
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExternalArticleScreen(
                                      title: item.title,
                                      url: sourceUrl,
                                      newsId: item.id,
                                    ),
                                  ),
                                );
                              } else {
                                // Internal article → NewsDetailsScreen
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.newsDetails,
                                  arguments: item.id,
                                );
                              }
                            },

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
