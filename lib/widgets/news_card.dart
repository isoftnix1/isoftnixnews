import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:share_plus/share_plus.dart';
import '../models/news_model.dart';
import 'video_preview_widget.dart';

class NewsCard extends StatelessWidget {
  final NewsModel news;
  final VoidCallback onTap;

  const NewsCard({
    super.key,
    required this.news,
    required this.onTap,
  });

  /// Returns a human-friendly relative time string — like BBC News / Twitter.
  /// e.g. "Just now", "5 min ago", "2 hours ago", "Yesterday", "3 days ago", "5 Jul 2026"
  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      return diff.inMinutes == 1 ? '1 min ago' : '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('d MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final date = news.publishedAt ?? news.createdAt ?? DateTime.now();
    final timeAgoText = _timeAgo(date);

    // Responsive checks
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;


    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black, // Fallback background
        ),
        child: Column(
          children: [
            // ── 1. Top Half: Image ────────
            Expanded(
              // Image takes all remaining space after the text claims what it needs
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (news.imageUrl.isNotEmpty)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: CachedNetworkImage(
                        imageUrl: _optimizeCloudinaryUrl(news.imageUrl.trim()),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.black),
                        errorWidget: (context, url, error) => Container(color: Colors.black),
                      ),
                    ),
                    
                  if (news.videoUrl != null && news.videoUrl!.isNotEmpty)
                    VideoPreviewWidget(url: news.videoUrl!)
                  else if (news.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: _optimizeCloudinaryUrl(news.imageUrl.trim()),
                      fit: BoxFit.contain, // Prevents cropping
                    )
                  else
                    const Center(
                      child: Icon(Icons.article, size: 60, color: Colors.white24),
                    ),

                  // Small gradient at the bottom to blend with the text section smoothly
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 1.0),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // ── 2. Bottom Half: Text Content ────────
            Container(
                color: Colors.black, // Solid background so text is perfectly readable
                width: double.infinity,
                child: SafeArea(
                  bottom: true,
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, isTablet ? 60 : 70), // Reduced bottom padding slightly
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isTablet ? 700 : double.infinity),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  // Title
                  Text(
                    news.title,
                    style: TextStyle(
                      fontSize: isTablet ? 32 : 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Content Preview
                  Text(
                    news.content,
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                
                  const SizedBox(height: 24),
                  
                  // ── Footer: Categories & Meta ────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
                                      : news.categoryName!,
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Relative time
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeAgoText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                if (news.imageUrl.isEmpty && news.sourceName != null && news.sourceName!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.language, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text(
                        news.sourceName!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          final deepLink = 'https://api.krrishi.co.in/news/${news.id}';
                          Share.share('${news.title}\n\nRead more on the Krrishi app: $deepLink');
                        },
                        icon: const Icon(Icons.share_outlined, size: 20),
                        color: Colors.white.withValues(alpha: 0.8),
                        padding: const EdgeInsets.only(right: 12),
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        'Tap to read more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          final deepLink = 'https://api.krrishi.co.in/news/${news.id}';
                          Share.share('${news.title}\n\nRead more on the Krrishi app: $deepLink');
                        },
                        icon: const Icon(Icons.share_outlined, size: 20),
                        color: Colors.white.withValues(alpha: 0.8),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        'Tap to read full article',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ]
                          ],
                        ), // Column
                      ), // ConstrainedBox
                  ), // Padding
                ), // SafeArea
              ), // Container
          ],
        ), // Column
      ), // Container
    );
  }

  String _optimizeCloudinaryUrl(String url) {
    if (url.contains('cloudinary.com') && !url.contains('q_auto')) {
      final split = url.split('/upload/');
      if (split.length == 2) {
        return '${split[0]}/upload/q_auto,f_auto,w_800/${split[1]}';
      }
    }
    return url;
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
