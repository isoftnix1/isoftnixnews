import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves the API base URL for the current build mode.
///
/// Release builds require [API_BASE_URL] to be set and to use HTTPS.
/// Debug/profile builds may fall back to the Android emulator loopback URL.
class ApiConfig {
  ApiConfig._();

  static String? _cachedBaseUrl;

  static String get baseUrl {
    _cachedBaseUrl ??= _resolveBaseUrl();
    return _cachedBaseUrl!;
  }

  static String _resolveBaseUrl() {
    final envUrl = dotenv.env['API_BASE_URL']?.trim();

    if (kReleaseMode) {
      if (envUrl == null || envUrl.isEmpty) {
        throw StateError(
          'API_BASE_URL is required in production builds. '
          'Set it in .env.production or pass --dart-define=API_BASE_URL=...',
        );
      }
      if (!envUrl.startsWith('https://')) {
        throw StateError(
          'API_BASE_URL must use HTTPS in production builds. Got: $envUrl',
        );
      }
      return envUrl;
    }

    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    return 'http://10.0.2.2:5000/api';
  }
}
