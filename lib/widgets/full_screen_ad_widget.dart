import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_model.dart';
import '../services/ad_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'video_player_widget.dart';

class FullScreenAdWidget extends StatefulWidget {
  final AdModel ad;

  const FullScreenAdWidget({super.key, required this.ad});

  @override
  State<FullScreenAdWidget> createState() => _FullScreenAdWidgetState();
}

class _FullScreenAdWidgetState extends State<FullScreenAdWidget> {
  final AdService _adService = AdService();

  @override
  void initState() {
    super.initState();
    // Record impression
    _adService.recordAdView(widget.ad.id);
  }

  Future<void> _launchUrl() async {
    // Record click
    await _adService.recordAdClick(widget.ad.id);
    
    final uri = Uri.parse(widget.ad.targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Media
          if (widget.ad.videoUrl != null && widget.ad.videoUrl!.isNotEmpty)
            VideoPlayerWidget(
              url: widget.ad.videoUrl!,
              autoPlay: true,
            )
          else if (widget.ad.imageUrl != null && widget.ad.imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.ad.imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (ctx, url, err) => Container(
                color: Colors.grey.shade900,
                child: const Icon(Icons.broken_image, color: Colors.white, size: 50),
              ),
              placeholder: (ctx, url) => Container(
                color: Colors.grey.shade900,
              ),
            )
          else
            Container(color: Colors.grey.shade900),

          // Gradient overlay for text readability
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black87],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 1.0],
              ),
            ),
          ),

          // Sponsored Badge
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Sponsored',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Content
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ad.companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.ad.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.ad.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.ad.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _launchUrl,
                    child: const Text(
                      'Learn More',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
