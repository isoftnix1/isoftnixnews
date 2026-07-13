import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Pings the backend every 10 minutes so Render never goes to sleep.
/// This eliminates the 20-30 second cold-start delay on login.
class KeepAliveService {
  KeepAliveService._();
  static final KeepAliveService instance = KeepAliveService._();

  Timer? _timer;

  void start() {
    // Ping immediately on start so first login is always fast.
    _ping();
    // Ping every 5 minutes for a safe buffer against Render's 15-minute idle sleep.
    // This means even if one ping fails (e.g., brief network drop), the next one
    // arrives well before the 15-minute sleep window closes.
    _timer ??= Timer.periodic(const Duration(minutes: 5), (_) => _ping());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ping() async {
    try {
      await ApiService().ping();
      if (kDebugMode) debugPrint('[KEEP-ALIVE] Backend pinged successfully.');
    } catch (e) {
      if (kDebugMode) debugPrint('[KEEP-ALIVE] Ping failed (OK if offline): $e');
    }
  }
}
