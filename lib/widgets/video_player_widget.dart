import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(widget.url);
      
      if (fileInfo != null) {
        debugPrint('📹 [CACHE HIT] VideoPlayer loading local file: ${widget.url}');
        _controller = VideoPlayerController.file(fileInfo.file);
      } else {
        debugPrint('☁️ [NETWORK] VideoPlayer streaming (no background download): ${widget.url}');
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
        // Removed downloadFile() here to prevent double bandwidth usage.
        // It relies on ExoPlayer/AVPlayer's internal stream buffer.
      }
      
      await _controller!.initialize();
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint("Error initializing video: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _toggleFullscreen(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller!),
                  _buildControls(isFullscreen: true),
                ],
              ),
            ),
          ),
        ),
      );
    }));
  }

  Widget _buildControls({bool isFullscreen = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_controller!.value.isBuffering)
          const CircularProgressIndicator(color: Colors.white),
        if (!_controller!.value.isBuffering)
          GestureDetector(
            onTap: () {
              _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(128),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(
                _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Row(
            children: [
              IconButton(
                icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                onPressed: _toggleMute,
              ),
              IconButton(
                icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                onPressed: () {
                  if (isFullscreen) {
                    Navigator.pop(context);
                  } else {
                    _toggleFullscreen(context);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller!),
                _buildControls(isFullscreen: false),
              ],
            ),
          ),
          VideoProgressIndicator(
            _controller!,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
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
