import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PolicyScreen extends StatelessWidget {
  final String title;
  final String mdContent;

  const PolicyScreen({
    super.key,
    required this.title,
    required this.mdContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Markdown(
          data: mdContent,
          styleSheet: MarkdownStyleSheet(
            h1: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            h2: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            listBullet: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
