import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VoiceVisualizer extends StatelessWidget {
  final bool isListening;
  final bool isSpeaking;
  final bool isProcessing;

  const VoiceVisualizer({
    super.key,
    this.isListening = false,
    this.isSpeaking = false,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isListening && !isSpeaking && !isProcessing) {
      return const SizedBox.shrink();
    }

    Duration duration = isListening ? 600.ms : (isProcessing ? 1200.ms : 1000.ms);
    double scale = isListening ? 1.4 : (isProcessing ? 1.1 : 1.2);
    Color glowColor = isListening ? Colors.pinkAccent : (isProcessing ? Colors.orangeAccent : Colors.blueAccent);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      height: 120,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base glowing background
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.8),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(end: scale * 0.9, duration: duration, curve: Curves.easeInOutSine),

          // First Orb Layer
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.purpleAccent, Colors.transparent],
                stops: [0.3, 1.0],
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(end: scale, duration: duration * 1.2, curve: Curves.easeInOutSine),

          // Second Orb Layer
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.blueAccent, Colors.transparent],
                stops: [0.2, 1.0],
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(end: scale * 1.3, duration: duration * 0.9, curve: Curves.easeInOutSine),

          // Third Orb Layer (Core)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [isListening ? Colors.redAccent : Colors.cyanAccent, Colors.transparent],
                stops: [0.1, 1.0],
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(end: scale * 1.5, duration: duration * 0.7, curve: Curves.easeInOutSine),

          // Center Icon
          Icon(
            isListening ? Icons.mic : (isProcessing ? Icons.hourglass_empty : Icons.graphic_eq),
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }
}


