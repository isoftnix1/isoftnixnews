import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'kernel_model.dart';
import 'kernel_layout.dart';
import 'colors.dart';

class KernelPathCache {
  final double size;
  final Brightness brightness;
  final bool shineEnabled;
  final Color glowColor;

  late final List<KernelModel> scaledKernels;
  late final Paint imagePaint;
  late final Paint glowPaint;
  late final Paint shinePaint;

  KernelPathCache({
    required this.size,
    required this.brightness,
    required this.shineEnabled,
    required this.glowColor,
  }) {
    _initialize();
  }

  void _initialize() {
    // 1. Generate and scale paths
    final baseKernels = KernelLayout.generateKernels();
    scaledKernels = baseKernels.map((k) {
      final matrix = Matrix4.diagonal3Values(size, size, 1.0);
      final scaledPath = k.path.transform(matrix.storage);
      final scaledCenter = Offset(k.centerPoint.dx * size, k.centerPoint.dy * size);
      
      return KernelModel(
        index: k.index,
        ringIndex: k.ringIndex,
        path: scaledPath,
        centerPoint: scaledCenter,
        baseRotation: k.baseRotation,
      );
    }).toList();

    // 2. Setup Solid Paint
    imagePaint = Paint()
      ..color = CornColors.completedKernelColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 3. Setup Glow Paint
    final activeGlow = CornColors.adaptGlow(glowColor, brightness);
    glowPaint = Paint()
      ..color = activeGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12.0)
      ..isAntiAlias = true;

    // 4. Setup Shine Paint
    shinePaint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen
      ..isAntiAlias = true;
  }

  // Calculate shine shader based on progress
  void updateShine(double progress) {
    if (!shineEnabled || progress <= 0) return;
    
    // Sweep from left to right
    double xPos = size * (progress * 1.5 - 0.25); // moves from -0.25 to 1.25
    
    shinePaint.shader = ui.Gradient.linear(
      Offset(xPos - size * 0.2, 0),
      Offset(xPos + size * 0.2, 0),
      [
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.4),
        Colors.white.withValues(alpha: 0.0),
      ],
      [0.0, 0.5, 1.0],
    );
  }
}
