import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/news_model.dart';
import '../../providers/language_provider.dart';
import '../../providers/news_provider.dart';
import '../../widgets/video_player_widget.dart';
import 'external_article_screen.dart';

class NewsDetailsScreen extends StatefulWidget {
  final String? newsId;
  final NewsModel? news;

  const NewsDetailsScreen({super.key, this.newsId, this.news});

  @override
  State<NewsDetailsScreen> createState() => _NewsDetailsScreenState();
}

class _NewsDetailsScreenState extends State<NewsDetailsScreen> {
  NewsModel? _news;

  String _optimizeCloudinaryUrl(String url) {
    if (url.contains('cloudinary.com') && !url.contains('q_auto')) {
      final split = url.split('/upload/');
      if (split.length == 2) {
        return '${split[0]}/upload/q_auto,f_auto,w_1024/${split[1]}';
      }
    }
    return url;
  }
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.news != null) {
      _news = widget.news;
    } else if (widget.newsId != null) {
      _loadNewsById(widget.newsId!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_news == null && widget.newsId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        // ID passed as string — always fetch from API for full translated content
        _loadNewsById(args);
      } else if (args is NewsModel) {
        // Fallback: if a full NewsModel is still passed (e.g. from deep links)
        // fetch by ID to guarantee full translated content
        _loadNewsById(args.id);
      }
    }
  }

  Future<void> _loadNewsById(String id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lang = context.read<LanguageProvider>().currentLanguage;
      final news = await context.read<NewsProvider>().getNewsById(id, lang: lang);
      if (mounted) {
        setState(() {
          _news = news;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load article. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  String _buildDeepLink(String newsId) => 'isoftnixnews://news/$newsId';

  String _buildShareText(NewsModel news) {
    final preview = news.content.length > 150
        ? '${news.content.substring(0, 150).trimRight()}...'
        : news.content;
    final deepLink = _buildDeepLink(news.id);
    return '${news.title}\n\n$preview\n\nOpen in Updates:\n$deepLink';
  }

  void _shareArticle(NewsModel news) {
    Share.share(
      _buildShareText(news),
      subject: news.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Article...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Article')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _loadNewsById(widget.newsId!),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_news == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('News Details')),
        body: const Center(child: Text('Article not found.')),
      );
    }

    final news = _news!;
    final date = news.createdAt ?? DateTime.now();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: news.imageUrl.isNotEmpty ? 400 : null,
            pinned: true,
            stretch: news.imageUrl.isNotEmpty,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: news.imageUrl.isNotEmpty
                ? FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: _optimizeCloudinaryUrl(news.imageUrl),
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              Center(child: Icon(Icons.image_not_supported, color: Colors.grey.withValues(alpha: 0.5), size: 40)),
                        ),
                        // Gradient overlay for better text readability and seamless transition
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Theme.of(context).scaffoldBackgroundColor.withAlpha(128),
                                Theme.of(context).scaffoldBackgroundColor,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(128),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  tooltip: 'Share Article',
                  onPressed: () => _shareArticle(news),
                ),
              ).animate().fade(delay: 200.ms),
            ],
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(128),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ).animate().fade(delay: 200.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (news.categoryName == null || news.categoryName!.isEmpty)
                          ? 'General'
                          : news.categoryName!,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ).animate().slideY(begin: 0.2).fade(),
                  const SizedBox(height: 16),
                  Text(
                    news.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                  ).animate().slideY(begin: 0.2).fade(delay: 100.ms),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        child: Text(
                          (news.authorName?.isNotEmpty == true) ? news.authorName![0].toUpperCase() : 'A',
                          style: TextStyle(color: Theme.of(context).primaryColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            news.authorName ?? 'Admin',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            DateFormat.yMMMMd().format(date),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ).animate().slideY(begin: 0.2).fade(delay: 200.ms),
                  const SizedBox(height: 32),
                  Text(
                    news.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.8,
                        ),
                  ).animate().slideY(begin: 0.2).fade(delay: 300.ms),
                  const SizedBox(height: 32),
                  if (news.videoUrl != null && news.videoUrl!.isNotEmpty)
                    VideoPlayerWidget(url: news.videoUrl!)
                        .animate()
                        .slideY(begin: 0.2)
                        .fade(delay: 400.ms),
                  if (news.sourceUrl != null && news.sourceUrl!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExternalArticleScreen(
                                title: news.title,
                                url: news.sourceUrl!,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Read Full Article'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ).animate().slideY(begin: 0.2).fade(delay: 500.ms),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
