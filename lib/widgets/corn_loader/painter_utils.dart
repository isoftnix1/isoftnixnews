import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class PainterUtils {
  /// Records a static picture of the center texture.
  /// This is drawn once and cached as a ui.Picture to avoid expensive 
  /// procedural drawing calls every frame.
  static ui.Picture createCenterTexturePicture(double size, Paint imagePaint, Path centerPath) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // We just fill the center path with the image paint.
    // The image paint has an ImageShader which aligns perfectly with the center.
    // Since the center path is organically shaped, it looks like real fibers.
    canvas.drawPath(centerPath, imagePaint);
    
    return recorder.endRecording();
  }

  /// Helper to draw a path with scaling and rotation around its own center point
  static void drawTransformedPath(
    Canvas canvas, 
    Path path, 
    Offset centerPoint, 
    double scale, 
    double rotation, 
    Paint paint
  ) {
    // The path is defined at local origin (0,0).
    // We scale it, rotate it, and then translate it to its centerPoint.
    final matrix = Matrix4.translationValues(centerPoint.dx, centerPoint.dy, 0.0)
      ..rotateZ(rotation)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
      
    final transformedPath = path.transform(matrix.storage);
    canvas.drawPath(transformedPath, paint);
  }
}
