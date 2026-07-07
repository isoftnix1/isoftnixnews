import 'package:flutter/material.dart';

class KernelModel {
  final int index;
  final int ringIndex;
  final Path path; // The handcrafted vector path referencing the organic shape
  final Offset centerPoint; // Used for scaling/rotating the individual kernel
  final double baseRotation; // The angle pointing towards the center

  const KernelModel({
    required this.index,
    required this.ringIndex,
    required this.path,
    required this.centerPoint,
    required this.baseRotation,
  });
}
