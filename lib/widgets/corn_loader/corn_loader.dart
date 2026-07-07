import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'constants.dart';
import 'colors.dart';
import 'kernel_path_cache.dart';
import 'corn_painter.dart';

class CornLoader extends StatefulWidget {
  final double size;
  final Duration duration;
  final Color completedKernelColor;
  final Color pendingKernelColor;
  final Color glowColor;
  final double glowRadius;
  final Duration pauseDuration;
  final Duration fadeDuration;
  final bool repeat;
  final bool showCenterGlow;
  final double kernelSpacing;
  final bool shineEnabled;
  final CornLoaderVariant variant;

  const CornLoader({
    super.key,
    this.size = CornConstants.baseSize,
    this.duration = const Duration(milliseconds: 3600), // Entire cycle duration
    this.completedKernelColor = CornColors.completedKernelColor,
    this.pendingKernelColor = CornColors.pendingKernelColor,
    this.glowColor = CornColors.defaultGlowColor,
    this.glowRadius = CornConstants.maxGlowBlur,
    this.pauseDuration = const Duration(milliseconds: 300),
    this.fadeDuration = const Duration(milliseconds: 300),
    this.repeat = true,
    this.showCenterGlow = true,
    this.kernelSpacing = 0.03,
    this.shineEnabled = true,
    this.variant = CornLoaderVariant.news,
  });

  @override
  State<CornLoader> createState() => _CornLoaderState();
}

class _CornLoaderState extends State<CornLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  KernelPathCache? _pathCache;
  ui.Picture? _centerPicture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.repeat) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  void _initCache() {
    // Only re-initialize when dependencies change (brightness, size)
    final brightness = Theme.of(context).brightness;
    _pathCache = KernelPathCache(
      size: widget.size,
      brightness: brightness,
      shineEnabled: widget.shineEnabled,
      glowColor: widget.glowColor,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initCache();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CornLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size != widget.size || oldWidget.glowColor != widget.glowColor) {
      _initCache();
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (widget.repeat) {
        _controller.repeat();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle accessibility - reduced motion
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;
    
    if (disableAnimations && _controller.isAnimating) {
      // In reduced motion, we still want the pulse effect, so we slow down the controller immensely
      _controller.duration = const Duration(milliseconds: 1500);
      _controller.repeat(reverse: true);
    } else if (!disableAnimations && _controller.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (widget.repeat) _controller.repeat();
    }

    return Semantics(
      label: 'Loading agricultural news',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _pathCache != null
            ? RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: CornPainter(
                        animationProgress: _controller.value,
                        pathCache: _pathCache!,
                        disableAnimations: disableAnimations,
                        centerPicture: _centerPicture,
                      ),
                      size: Size(widget.size, widget.size),
                    );
                  },
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
