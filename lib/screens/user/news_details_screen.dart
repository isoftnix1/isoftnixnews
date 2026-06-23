import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/news_model.dart';
import '../../providers/news_provider.dart';

class NewsDetailsScreen extends StatefulWidget {
  final String? newsId;
  final NewsModel? news;

  const NewsDetailsScreen({super.key, this.newsId, this.news});

  @override
  State<NewsDetailsScreen> createState() => _NewsDetailsScreenState();
}

class _NewsDetailsScreenState extends State<NewsDetailsScreen> {
  NewsModel? _news;
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
      if (args is NewsModel) {
        setState(() => _news = args);
      }
    }
  }

  Future<void> _loadNewsById(String id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final news = await context.read<NewsProvider>().getNewsById(id);
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
    return '${news.title}\n\n$preview\n\nOpen in ISoftNix News:\n$deepLink';
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
            expandedHeight: 400,
            pinned: true,
            stretch: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: news.imageUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: news.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              const Center(child: Icon(Icons.broken_image)),
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
                    )
                  : Container(color: Theme.of(context).colorScheme.surface),
            ),
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

// ---------------------------------------------------------------------------
// VideoPlayerWidget
// ---------------------------------------------------------------------------

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 48,
                    color: Colors.white,
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Theme.of(context).primaryColor,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}
