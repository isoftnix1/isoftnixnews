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
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;

    // Adjust image height based on device type to prevent overlap with text on tall screens
    final double imageHeightFactor = isTablet ? 0.60 : 0.45;

    // Adjust gradient stops so it doesn't consume the whole tablet screen
    final List<double> gradientStops = isTablet
        ? const [0.0, 0.3, 0.55, 1.0]  // Tighter gradient on tablet
        : const [0.0, 0.45, 0.65, 1.0]; // Taller gradient on phone

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black, // Fallback background
        ),
        child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Blurred Background (Eliminates empty space) ────────
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
            
          // ── 2. Foreground Image (Uncropped, perfect aspect ratio) ────────
          if (news.videoUrl != null && news.videoUrl!.isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: 0.5,
                child: VideoPreviewWidget(url: news.videoUrl!),
              ),
            )
          else if (news.imageUrl.isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: imageHeightFactor,
                child: CachedNetworkImage(
                  imageUrl: _optimizeCloudinaryUrl(news.imageUrl.trim()),
                  fit: BoxFit.contain, // Prevents cropping, maintains framing
                ),
              ),
            )
          else
            const Center(
              child: Icon(Icons.article, size: 60, color: Colors.white24),
            ),

          // ── 3. Cinematic Gradient Overlay ────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 1.0), // Solid black at very bottom
                  Colors.black.withValues(alpha: 0.85), // Dark over text
                  Colors.black.withValues(alpha: 0.5), // Blend zone
                  Colors.transparent,            // Transparent at very top
                ],
                stops: gradientStops,
              ),
            ),
          ),
          
          // ── 4. Content at Bottom ────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, isTablet ? 40 : 24),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isTablet ? 700 : double.infinity),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Title
                  Text(
                    news.title,
                    style: TextStyle(
                      fontSize: isTablet ? 32 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 4,
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
                    maxLines: 8,
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
        ), // Align
      ), // Padding
        ],
      ),
    ));
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
