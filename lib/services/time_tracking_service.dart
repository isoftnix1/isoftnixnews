import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';

class TimeTrackingService with WidgetsBindingObserver {
  static final TimeTrackingService _instance = TimeTrackingService._internal();
  factory TimeTrackingService() => _instance;
  TimeTrackingService._internal();

  Stopwatch? _stopwatch;
  final ApiService _apiService = ApiService();
  
  // Storage keys
  static const String _kCachedSeconds = 'cached_usage_seconds';
  static const String _kCachedDate = 'cached_usage_date';

  /// Call this when the app starts
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    // If the app started in the foreground, start the stopwatch
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _startTracking();
    }
    // Attempt a sync on startup if there's leftover data
    await _syncCachedData();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTrackingAndCache();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to the foreground
      _startTracking();
      // Try to sync any cached data we might have built up
      _syncCachedData();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App went to the background
      _stopTrackingAndCache();
    }
  }

  void _startTracking() {
    if (_stopwatch == null || !_stopwatch!.isRunning) {
      _stopwatch = Stopwatch()..start();
    }
  }

  Future<void> _stopTrackingAndCache() async {
    if (_stopwatch != null && _stopwatch!.isRunning) {
      _stopwatch!.stop();
      final elapsedSeconds = _stopwatch!.elapsed.inSeconds;
      _stopwatch!.reset();

      if (elapsedSeconds > 0) {
        await _addSecondsToCache(elapsedSeconds);
      }
    }
  }

  Future<void> _addSecondsToCache(int newSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final cachedDate = prefs.getString(_kCachedDate);
    int currentCachedSeconds = prefs.getInt(_kCachedSeconds) ?? 0;

    if (cachedDate != todayStr) {
      // If the day rolled over, sync the old data first (if any)
      if (currentCachedSeconds > 0 && cachedDate != null) {
        await _apiService.syncUsageTime(cachedDate, currentCachedSeconds);
      }
      // Reset for the new day
      currentCachedSeconds = 0;
      await prefs.setString(_kCachedDate, todayStr);
    }

    await prefs.setInt(_kCachedSeconds, currentCachedSeconds + newSeconds);
  }

  /// Syncs the local cache to the backend and clears it if successful
  Future<void> _syncCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedSeconds = prefs.getInt(_kCachedSeconds) ?? 0;
    final cachedDate = prefs.getString(_kCachedDate);

    // Only sync if we have at least 15 seconds of usage to report
    if (cachedSeconds > 15 && cachedDate != null && ApiService.authToken != null) {
      try {
        await _apiService.syncUsageTime(cachedDate, cachedSeconds);
        // Clear cache after successful sync
        await prefs.setInt(_kCachedSeconds, 0);
      } catch (e) {
        debugPrint('[TimeTrackingService] Sync failed, keeping data in cache.');
      }
    }
  }
}
