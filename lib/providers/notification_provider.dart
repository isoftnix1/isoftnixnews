import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _apiService.getNotifications();
      _notifications = list
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
    notifyListeners();

    try {
      await _apiService.deleteNotification(id);
    } catch (e) {
      debugPrint('Failed to delete notification from server: $e');
      // If server delete fails, you could optionally add it back here
      // restoreNotification(removed); 
    }

    return removed;
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1 || _notifications[index].isRead) return;

    // Optimistic UI update
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    notifyListeners();

    try {
      await _apiService.markAsRead(id);
    } catch (e) {
      debugPrint('Failed to mark notification as read on server: $e');
    }
  }

  Future<void> restoreNotification(NotificationModel notification) async {
    // Note: Since we permanently delete from the backend, 'Undo' might fail 
    // if the backend already processed the DELETE. 
    // For now, we just add it back locally if they press undo.
    // In a production app, you might delay the API call for 3 seconds to allow for an Undo.
    
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

