import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'corn_loader/corn_loader.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CornLoader(size: 80),
          const SizedBox(height: 16),
          Text(message ?? AppLocalizations.of(context, 'loading')),
        ],
      ),
    );
  }
}
