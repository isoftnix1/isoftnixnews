import 'dart:math';
import 'package:flutter/material.dart';
import 'kernel_model.dart';

class KernelLayout {
  /// Generates the layout of kernels referencing the 22-16-10-1 structure.
  /// Generates the paths mapped to a 0.0 to 1.0 coordinate space, which is then
  /// scaled to the actual `size` during painting.
  static List<KernelModel> generateKernels() {
    final List<KernelModel> kernels = [];
    int index = 0;

    // The rings: Outer (16 seeds), Inner (8 seeds)
    final ringCounts = [16, 8];
    
    // Radii mapped to 0.0 to 1.0 coordinate space (center is 0.5)
    // Outer ring seeds will be positioned further out.
    final ringRadii = [0.35, 0.16];
    
    // Seed dimensions (relative to the 1.0 box size)
    final seedWidths = [0.08, 0.07];
    final seedHeights = [0.18, 0.15];

    for (int ringIndex = 0; ringIndex < 2; ringIndex++) {
      int count = ringCounts[ringIndex];
      double radius = ringRadii[ringIndex];
      double width = seedWidths[ringIndex];
      double height = seedHeights[ringIndex];

      double angleStep = (2 * pi) / count;
      
      for (int i = 0; i < count; i++) {
        // We draw the seed such that its tip points towards the center of the circle.
        // We calculate its position on the ring.
        double angle = i * angleStep;
        
        // Center of the seed
        Offset center = Offset(
          0.5 + radius * cos(angle),
          0.5 + radius * sin(angle)
        );

        // We build the teardrop/seed path locally around (0,0) pointing DOWN.
        // The rotation in drawTransformedPath will handle rotating it to face the center!
        // We just need to define a single standard teardrop path at (0,0).
        final path = Path();
        
        // A teardrop shape (corn seed) pointing DOWN (towards positive Y)
        path.moveTo(0, -height / 2); // Top center (wide part)
        // Top right curve
        path.quadraticBezierTo(width / 2, -height / 2, width / 2, -height / 6);
        // Bottom right tapering to a rounded tip
        path.quadraticBezierTo(width / 4, height / 2, 0, height / 2);
        // Bottom left tapering
        path.quadraticBezierTo(-width / 4, height / 2, -width / 2, -height / 6);
        // Top left curve
        path.quadraticBezierTo(-width / 2, -height / 2, 0, -height / 2);
        path.close();

        kernels.add(KernelModel(
          index: index++,
          ringIndex: 1 - ringIndex, // 1=outer, 0=inner
          path: path,
          centerPoint: center,
          baseRotation: angle + pi / 2, // Rotate teardrop (which points down) to point towards center
        ));
      }
    }

    return kernels;
  }
}
