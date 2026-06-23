import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import 'news_details_screen.dart';

class NewsPagerScreen extends StatefulWidget {
  final int initialIndex;

  const NewsPagerScreen({super.key, required this.initialIndex});

  @override
  State<NewsPagerScreen> createState() => _NewsPagerScreenState();
}

class _NewsPagerScreenState extends State<NewsPagerScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, NewsProvider provider) {
    // If the user is getting close to the end of the loaded news list (within 3 items)
    // and we are not already loading more, trigger a load.
    if (index >= provider.news.length - 3 && provider.hasMore && !provider.isLoading) {
      provider.loadMoreNews();
    }
  }

  @override
  Widget build(BuildContext context) {
    final newsProvider = context.watch<NewsProvider>();

    if (newsProvider.news.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No articles found.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: (index) => _onPageChanged(index, newsProvider),
        itemCount: newsProvider.news.length,
        itemBuilder: (context, index) {
          final news = newsProvider.news[index];
          return NewsDetailsScreen(news: news);
        },
      ),
    );
  }
}
