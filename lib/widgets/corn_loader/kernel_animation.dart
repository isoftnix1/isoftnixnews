import 'dart:math';
import 'package:flutter/material.dart';
import 'constants.dart';

class KernelAnimationState {
  final double opacity;
  final double scale;
  final double rotation;
  final bool hasGlow;
  final bool isVisible;

  const KernelAnimationState({
    required this.opacity,
    required this.scale,
    required this.rotation,
    required this.hasGlow,
    required this.isVisible,
  });
}

class KernelAnimation {
  /// Calculates the visual state for a single kernel at a given global animation progress.
  /// 
  /// The global progress [0.0 - 1.0] is split into:
  /// 0.0 - 0.72 : Reveal phase (Seed 1 to Center)
  /// 0.72 - 0.80 : Shine phase (no kernel animation changes here, handled in painter)
  /// 0.80 - 0.90 : Pause phase
  /// 0.90 - 1.00 : Fade out phase
  static KernelAnimationState calculateState(int index, int totalKernels, double globalProgress) {
    if (globalProgress >= 0.90) {
      // Fade out phase
      double fadeProgress = (globalProgress - 0.90) / 0.10;
      double opacity = lerpDouble(CornConstants.maxOpacity, CornConstants.minOpacity, fadeProgress);
      return KernelAnimationState(
        opacity: opacity,
        scale: 1.0,
        rotation: 0.0,
        hasGlow: false,
        isVisible: true,
      );
    } else if (globalProgress >= 0.72) {
      // Completed, Shine, and Pause phases
      return const KernelAnimationState(
        opacity: CornConstants.maxOpacity,
        scale: 1.0,
        rotation: 0.0,
        hasGlow: false,
        isVisible: true,
      );
    }

    // Reveal phase (0.0 to 0.72)
    // We allocate a small window for each kernel to animate in.
    final double revealDuration = 0.72;
    // We want the last kernel to finish its animation right at 0.72.
    // The animation for a single kernel takes a fraction of the total reveal time.
    final double singleKernelDuration = 0.08; // 8% of total animation time
    
    // Calculate start time for this specific kernel
    // Index 0 starts at 0.0. Index N-1 ends at 0.72.
    final double startTime = (index / (totalKernels - 1)) * (revealDuration - singleKernelDuration);
    final double endTime = startTime + singleKernelDuration;

    if (globalProgress < startTime) {
      // Not yet revealed
      return const KernelAnimationState(
        opacity: CornConstants.minOpacity,
        scale: CornConstants.minScale,
        rotation: -5.0 * (pi / 180.0), // -5 degrees in radians
        hasGlow: false,
        isVisible: false, // For seed 0 logic, we might need to handle this differently
      );
    } else if (globalProgress > endTime) {
      // Fully revealed
      return const KernelAnimationState(
        opacity: CornConstants.maxOpacity,
        scale: 1.0,
        rotation: 0.0,
        hasGlow: false,
        isVisible: true,
      );
    }

    // Actively revealing
    double localProgress = (globalProgress - startTime) / singleKernelDuration;
    
    // Scale: easeOutBack 0.45 -> 1.15 -> 1.0
    double scale = CornConstants.minScale + 
                  (1.0 - CornConstants.minScale) * Curves.easeOutBack.transform(localProgress);
    
    // Opacity: 0.2 -> 1.0
    double opacity = CornConstants.minOpacity + 
                    (CornConstants.maxOpacity - CornConstants.minOpacity) * Curves.easeOut.transform(localProgress);
    
    // Rotation: -5 deg -> 0
    double rotation = (-5.0 * (pi / 180.0)) * (1.0 - Curves.easeOut.transform(localProgress));

    return KernelAnimationState(
      opacity: opacity,
      scale: scale,
      rotation: rotation,
      hasGlow: true, // It has glow while it is actively animating
      isVisible: true,
    );
  }

  static double lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}
