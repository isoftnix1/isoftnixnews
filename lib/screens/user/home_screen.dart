import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../chat/personal_chat_screen.dart';
import '../chat/community_chat_screen.dart';

import '../../providers/auth_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/ad_model.dart';
import '../../models/news_model.dart';
import '../../providers/language_provider.dart';
import '../../routes/app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ad_service.dart';
import '../../services/voice_assistant_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
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

                const SizedBox(width: 10),

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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Consumer<VoiceAssistantService>(
        builder: (context, voiceService, _) {
          if (voiceService.isListening || voiceService.isProcessing || voiceService.isSpeaking) {
            return FloatingActionButton(
              onPressed: () async {
                if (voiceService.isSpeaking) {
                  await voiceService.stopSpeaking();
                } else if (voiceService.isListening) {
                  voiceService.stopListening();
                }
              },
              backgroundColor: voiceService.isListening ? Colors.red : Colors.orange,
              child: Icon(
                voiceService.isListening ? Icons.mic : (voiceService.isProcessing ? Icons.hourglass_empty : Icons.stop),
                color: Colors.white,
              ),
            );
          }

          return SpeedDial(
            icon: Icons.auto_awesome,
            activeIcon: Icons.close,
            spacing: 3,
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.yellowAccent,
            activeBackgroundColor: Colors.red,
            activeForegroundColor: Colors.white,
            elevation: 8.0,
            animationCurve: Curves.elasticInOut,
            isOpenOnStart: false,
            children: [
              SpeedDialChild(
                child: const Icon(Icons.mic_none, color: Colors.white),
                backgroundColor: Colors.green,
                label: 'Voice Assistant',
                onTap: () async {
                  final currentLang = context.read<LanguageProvider>().currentLanguage;
                  await voiceService.startListening(currentLang);
                },
              ),
              SpeedDialChild(
                child: const Icon(Icons.person, color: Colors.white),
                backgroundColor: Colors.blue,
                label: 'Personal Agri-Bot',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PersonalChatScreen()),
                  );
                },
              ),
              SpeedDialChild(
                child: const Icon(Icons.people, color: Colors.white),
                backgroundColor: Colors.purple,
                label: 'Community Chat',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CommunityChatScreen()),
                  );
                },
              ),
            ],
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: () => newsProvider.loadNews(refresh: true),
        child: newsProvider.isLoading && newsProvider.feedItems.isEmpty
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
                      itemCount: newsProvider.feedItems.length + 1,
                      itemBuilder: (context, index) {
                        if (index == newsProvider.feedItems.length) {
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

                        final item = newsProvider.feedItems[index];

                        if (item is AdModel) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: VisibilityDetector(
                              key: Key('ad_${item.id}'),
                              onVisibilityChanged: (info) {
                                // Only record a view if at least 50% of the ad is visible
                                if (info.visibleFraction >= 0.5) {
                                  AdService().recordAdView(item.id);
                                }
                              },
                              child: GestureDetector(
                                onTap: () async {
                                final uri = Uri.parse(item.targetUrl);
                                if (await canLaunchUrl(uri)) {
                                  // Record the click
                                  AdService().recordAdClick(item.id);
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey.shade900,
                                  image: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(item.imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      colors: [Colors.transparent, Colors.black87],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: [0.5, 1.0],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.bottomLeft,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.companyName,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              item.title,
                                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('Sponsored', style: TextStyle(color: Colors.white, fontSize: 10)),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('Learn More', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                SizedBox(width: 4),
                                                Icon(Icons.open_in_new, color: Colors.white, size: 14),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                        if (item is NewsModel) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: NewsCard(
                              news: item,
                              onTap: () {
                                final sourceUrl = item.sourceUrl;
                                if (sourceUrl != null && sourceUrl.isNotEmpty) {
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
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.newsDetails,
                                    arguments: item.id,
                                  );
                                }
                              },
                            ),
                          ).animate().fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms);
                        }
                        return const SizedBox.shrink();
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
