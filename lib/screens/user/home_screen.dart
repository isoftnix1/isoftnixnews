import 'dart:ui';
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
import '../../widgets/voice_visualizer.dart';

import 'external_article_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = context.read<LanguageProvider>().currentLanguage;
      context.read<NewsProvider>().loadCategories(lang: lang);
      context.read<NewsProvider>().loadNews(refresh: true, lang: lang);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    final newsProvider = context.read<NewsProvider>();
    // Load more when we are 3 items away from the end
    if (newsProvider.hasMore && !newsProvider.isLoading) {
      if (index >= newsProvider.feedItems.length - 3) {
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
                      context.read<VoiceAssistantService>().updateLanguage('en');
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
                      context.read<VoiceAssistantService>().updateLanguage('hi');
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
                      context.read<VoiceAssistantService>().updateLanguage('mr');
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
            return GestureDetector(
              onTap: () async {
                if (voiceService.isSpeaking) {
                  await voiceService.stopSpeaking();
                } else if (voiceService.isListening) {
                  voiceService.stopListening();
                }
              },
              child: VoiceVisualizer(
                isListening: voiceService.isListening,
                isProcessing: voiceService.isProcessing,
                isSpeaking: voiceService.isSpeaking,
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
                child: const Icon(Icons.mic, color: Colors.white),
                backgroundColor: Colors.green,
                label: 'Tap to Speak',
                onTap: () async {
                  final currentLang = context.read<LanguageProvider>().currentLanguage;
                  await voiceService.startListening(currentLang);
                },
              ),
              SpeedDialChild(
                child: const Icon(Icons.person, color: Colors.white),
                backgroundColor: Colors.blue,
                label: 'Appa',
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
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      onPageChanged: _onPageChanged,
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
                          return VisibilityDetector(
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
                                decoration: const BoxDecoration(
                                  color: Colors.black, // Fallback background
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // ── 1. Blurred Background ────────
                                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                                      ImageFiltered(
                                        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                                        child: CachedNetworkImage(
                                          imageUrl: item.imageUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(color: Colors.black),
                                          errorWidget: (context, url, error) => Container(color: Colors.black),
                                        ),
                                      ),

                                    // ── 2. Foreground Image ────────
                                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: FractionallySizedBox(
                                          heightFactor: 0.55,
                                          child: CachedNetworkImage(
                                            imageUrl: item.imageUrl!,
                                            fit: BoxFit.contain, // Prevents cropping
                                          ),
                                        ),
                                      ),

                                    // ── 3. Cinematic Gradient Overlay ────────
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(1.0),
                                            Colors.black.withOpacity(0.85),
                                            Colors.black.withOpacity(0.5),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.45, 0.65, 1.0],
                                        ),
                                      ),
                                    ),

                                    // ── 4. Ad Content ────────
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                                                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.title,
                                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 16),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white24,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('Sponsored', style: TextStyle(color: Colors.white, fontSize: 11)),
                                              ),
                                              const SizedBox(height: 16),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  borderRadius: BorderRadius.circular(24),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('Learn More', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                                    SizedBox(width: 6),
                                                    Icon(Icons.open_in_new, color: Colors.white, size: 16),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                      }

                        if (item is NewsModel) {
                          return NewsCard(
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
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
