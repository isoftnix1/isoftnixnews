import 'package:flutter/material.dart';

class CornColors {
  static const Color completedKernelColor = Color(0xFFFFD54F); // Amber 300
  static const Color pendingKernelColor = Color(0x33FFD54F); // 20% opacity
  static const Color defaultGlowColor = Color(0xFFFFE082); // Amber 200
  static const Color defaultShineColor = Color(0x99FFFFFF); // Semi-transparent white
  
  static Color adaptGlow(Color baseGlow, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return baseGlow.withValues(alpha: 0.5); // Dimmer glow for dark mode
    }
    return baseGlow;
  }
}
