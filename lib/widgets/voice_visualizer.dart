import 'package:flutter/material.dart';

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

    Color color;
    IconData icon;

    if (isListening) {
      color = Colors.redAccent;
      icon = Icons.mic;
    } else if (isProcessing) {
      color = Colors.orangeAccent;
      icon = Icons.hourglass_empty;
    } else {
      color = Colors.blueAccent;
      icon = Icons.graphic_eq;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
          ),
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.4),
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0.8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
