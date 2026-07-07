import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String url;
  final double height;

  const VideoPreviewWidget({
    super.key, 
    required this.url,
    this.height = 200,
  });

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isVisible = false;
  bool _hasStartedInitialization = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _getThumbnailUrl(String url) {
    if (url.contains('cloudinary.com')) {
      final lastDotIndex = url.lastIndexOf('.');
      if (lastDotIndex != -1) {
         // Use q_auto,f_auto for aggressive thumbnail optimization
         final splitUrl = url.split('/upload/');
         if (splitUrl.length == 2) {
           return '${splitUrl[0]}/upload/q_auto,f_auto/${splitUrl[1].substring(0, splitUrl[1].lastIndexOf('.'))}.jpg';
         }
         return '${url.substring(0, lastDotIndex)}.jpg';
      }
    }
    return '';
  }

  Future<void> _initializeVideo() async {
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(widget.url);
      
      if (fileInfo != null) {
        debugPrint('📹 [CACHE HIT] VideoPreview loading local file: ${widget.url}');
        _controller = VideoPlayerController.file(fileInfo.file);
      } else {
        debugPrint('☁️ [NETWORK] VideoPreview caching file first: ${widget.url}');
        // By downloading the file first, we prevent double bandwidth usage. 
        // The Cloudinary thumbnail provides immediate visual feedback while it downloads.
        final file = await DefaultCacheManager().getSingleFile(widget.url);
        _controller = VideoPlayerController.file(file);
      }
      
      await _controller!.initialize();
      _controller!.setVolume(0.0);
      _controller!.setLooping(true);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (_isVisible) {
          _controller!.play();
        }
      }
    } catch (e) {
      debugPrint("Error initializing preview video: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      final thumbnailUrl = _getThumbnailUrl(widget.url);
      
      return VisibilityDetector(
        key: Key('placeholder_${widget.url}'),
        onVisibilityChanged: (info) {
          if (!mounted) return;
          _isVisible = info.visibleFraction > 0.5;
          if (_isVisible && !_hasStartedInitialization) {
            _hasStartedInitialization = true;
            _initializeVideo();
          }
        },
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: thumbnailUrl.isNotEmpty 
              ? CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  height: widget.height,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildShimmer(),
                  errorWidget: (context, url, error) => _buildShimmer(),
                )
              : _buildShimmer(),
        ),
      );
    }

    return VisibilityDetector(
      key: Key(widget.url),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        _isVisible = info.visibleFraction > 0.5;
        if (_isVisible && _controller != null) {
          _controller!.play();
        } else if (_controller != null) {
          _controller!.pause();
        }
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.white,
      ),
    );
  }
}
