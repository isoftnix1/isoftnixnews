import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_model.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider() {
    _initDismissedIds();
  }

  static const _dismissedKey = 'dismissed_notification_ids';

  final ApiService _apiService = ApiService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  Set<String> _dismissedIds = {};
  bool _dismissedIdsLoaded = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _initDismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    _dismissedIds = prefs.getStringList(_dismissedKey)?.toSet() ?? {};
    _dismissedIdsLoaded = true;
    notifyListeners();
  }

  Future<void> _saveDismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedKey, _dismissedIds.toList());
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!_dismissedIdsLoaded) {
        await _initDismissedIds();
      }

      final list = await _apiService.getNotifications();
      _notifications = list
          .where((item) => !_dismissedIds.contains(item.id))
          .toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<NotificationModel?> deleteNotification(String id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1) return null;

    final removed = _notifications.removeAt(index);
    _dismissedIds.add(id);
    await _saveDismissedIds();
    notifyListeners();
    return removed;
  }

  Future<void> restoreNotification(NotificationModel notification) async {
    _dismissedIds.remove(notification.id);
    await _saveDismissedIds();

    if (_notifications.any((item) => item.id == notification.id)) return;

    _notifications.add(notification);
    _notifications.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    notifyListeners();
  }
}
