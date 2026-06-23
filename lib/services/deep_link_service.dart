import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

/// Service responsible for handling all deep links in the ISoftNix News app.
///
/// Deep link format: isoftnixnews://news/{uuid}
///
/// This service is designed to be forward-compatible with:
/// - Android App Links (https://isoftnixnews.com/news/{uuid})
/// - iOS Universal Links (https://isoftnixnews.com/news/{uuid})
///
/// To upgrade to App Links/Universal Links in the future, simply add an
/// https-scheme data tag to the AndroidManifest intent filter and handle
/// the https URI in [_handleUri] — the business logic below stays the same.
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> navigatorKey;

  DeepLinkService({required this.navigatorKey});

  /// Initializes the deep link service.
  ///
  /// 1. Checks for an initial link (app launched cold from a deep link).
  /// 2. Subscribes to the stream for links received while the app is running.
  Future<void> init() async {
    // Handle initial link (cold start from deep link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      // Ignore initial link error
    }

    // Handle incoming links while app is in foreground/background
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (err) {
        // Ignore stream error
      },
    );
  }

  /// Parses the incoming URI and routes to the correct screen.
  ///
  /// Supports:
  /// - isoftnixnews://news/{uuid}
  void _handleUri(Uri uri) {
    // Validate scheme
    if (uri.scheme != 'isoftnixnews') {
      return;
    }

    // Parse path segments: ['news', '{uuid}']
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'news') {
      final newsId = segments[1];
      if (newsId.isNotEmpty) {
        handleNewsOpen(newsId);
        return;
      }
    }
  }

  /// Pushes to the NewsDetailsScreen using the named route with the newsId.
  ///
  /// Uses the Navigator key to navigate from outside the widget tree.
  void handleNewsOpen(String newsId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      // Retry after the first frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamed(
          '${AppRoutes.newsDetailsById}/$newsId',
        );
      });
      return;
    }

    navigator.pushNamed('${AppRoutes.newsDetailsById}/$newsId');
  }

  /// Disposes the link subscription. Call this in the app's dispose method.
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
