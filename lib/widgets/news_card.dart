import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/news_model.dart';

class NewsCard extends StatelessWidget {
  final NewsModel news;
  final VoidCallback onTap;

  const NewsCard({
    super.key,
    required this.news,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final date = news.createdAt ?? DateTime.now();
    final formattedDate = DateFormat.yMMMd().format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (news.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: CachedNetworkImage(
                    imageUrl: news.imageUrl.trim(),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,

                    progressIndicatorBuilder: (context, url, progress) {
                      print("Loading Image:");
                      print(url);
                      print(progress.downloaded);

                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },

                    errorWidget: (context, url, error) {
                      return Container(
                        height: 200,
                        color: Theme.of(context).cardTheme.color?.withOpacity(0.5) ?? Colors.grey.withOpacity(0.1),
                        child: Center(
                          child: Icon(Icons.image_not_supported, color: Colors.grey.withOpacity(0.5), size: 40),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: news.categories.isNotEmpty
                                ? news.categories.map((c) {
                                    final name = c['name']?.toString() ?? 'General';
                                    return _buildCategoryChip(context, name);
                                  }).toList()
                                : [
                                    _buildCategoryChip(
                                        context,
                                        news.categoryName == null || news.categoryName!.isEmpty
                                            ? 'General'
                                            : news.categoryName!)
                                  ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            formattedDate,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                  color: Colors.white.withAlpha(128),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (news.imageUrl.isEmpty && news.sourceName != null && news.sourceName!.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.language, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            news.sourceName!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to read the complete article.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      news.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      news.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildCategoryChip(BuildContext context, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(51),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
