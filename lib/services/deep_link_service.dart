import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import 'api_service.dart';

/// Service responsible for handling all deep links in the Updates app.
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

  /// Navigates to the appropriate screen based on whether the article is
  /// internal or external.
  ///
  /// - External (has source_url) → ExternalArticleScreen (in-app WebView)
  /// - Internal                  → NewsDetailsScreen
  void handleNewsOpen(String newsId) async {
    // Attempt to fetch the article to check for an external sourceUrl.
    try {
      final news = await ApiService().getNewsById(newsId);
      if (news.sourceUrl != null && news.sourceUrl!.isNotEmpty) {
        // External article → in-app WebView
        _push(
          AppRoutes.externalArticle,
          arguments: <String, String>{
            'title': news.title,
            'url': news.sourceUrl!,
          },
        );
        return;
      }
    } catch (_) {
      // If the fetch fails, fall through to NewsDetailsScreen which will
      // handle its own error/loading state.
    }

    // Internal article (or fetch failed) → NewsDetailsScreen
    _push('${AppRoutes.newsDetailsById}/$newsId');
  }

  /// Helper: push a named route, retrying after the first frame if the
  /// navigator is not yet available (e.g. cold-start deep link).
  void _push(String routeName, {Object? arguments}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamed(routeName, arguments: arguments);
      });
      return;
    }
    navigator.pushNamed(routeName, arguments: arguments);
  }

  /// Disposes the link subscription. Call this in the app's dispose method.
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
