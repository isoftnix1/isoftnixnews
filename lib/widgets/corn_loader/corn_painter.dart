import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'kernel_path_cache.dart';
import 'kernel_animation.dart';
import 'painter_utils.dart';

class CornPainter extends CustomPainter {
  final double animationProgress;
  final KernelPathCache pathCache;
  final bool disableAnimations;
  final ui.Picture? centerPicture;

  CornPainter({
    required this.animationProgress,
    required this.pathCache,
    required this.disableAnimations,
    required this.centerPicture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (disableAnimations) {
      // Accessibility mode: show completed corn, pulse opacity slightly every 1.5s
      // The animationProgress in this mode will be driven by a slow looping controller (e.g. 0 to 1 over 1.5s)
      double pulseOpacity = 0.85 + 0.15 * (0.5 - (0.5 - animationProgress).abs()) * 2; // pulses between 0.85 and 1.0
      
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white.withValues(alpha: pulseOpacity));
      
      for (final kernel in pathCache.scaledKernels) {
        PainterUtils.drawTransformedPath(
          canvas,
          kernel.path,
          kernel.centerPoint,
          1.0, // scale
          kernel.baseRotation, // rotation
          pathCache.imagePaint,
        );
      }
      
      canvas.restore();
      return;
    }

    pathCache.updateShine(animationProgress >= 0.72 && animationProgress <= 0.80 
        ? (animationProgress - 0.72) / 0.08 
        : 0.0);

    final totalKernels = pathCache.scaledKernels.length;

    for (int i = 0; i < totalKernels; i++) {
      final kernel = pathCache.scaledKernels[i];
      
      // The center kernel is index totalKernels - 1. We might want to use the Picture for it.
      // But we mapped it as a normal kernel with a path. So we just draw it.
      
      final state = KernelAnimation.calculateState(i, totalKernels, animationProgress);

      if (!state.isVisible) {
        // If it's truly not visible (e.g. opacity 0)
        continue;
      }

      final currentPaint = Paint()
        ..color = pathCache.imagePaint.color.withValues(alpha: state.opacity)
        ..isAntiAlias = true;

      // Draw glow if active
      if (state.hasGlow) {
        // Paint glow slightly behind or along the path
        PainterUtils.drawTransformedPath(
          canvas, 
          kernel.path, 
          kernel.centerPoint, 
          state.scale, 
          kernel.baseRotation + state.rotation, 
          pathCache.glowPaint,
        );
      }

      // Draw kernel
      PainterUtils.drawTransformedPath(
        canvas, 
        kernel.path, 
        kernel.centerPoint, 
        state.scale, 
        kernel.baseRotation + state.rotation, 
        currentPaint,
      );

      // Draw shine
      if (pathCache.shineEnabled && animationProgress >= 0.72 && animationProgress <= 0.80) {
        PainterUtils.drawTransformedPath(
          canvas,
          kernel.path,
          kernel.centerPoint,
          state.scale,
          kernel.baseRotation + state.rotation,
          pathCache.shinePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CornPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
           oldDelegate.pathCache != pathCache;
  }
}
