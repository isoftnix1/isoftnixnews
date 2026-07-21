import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'deep_link_service.dart';
import 'device_service.dart';

/// Centralizes FCM + local notification setup for Android (and iOS basics).
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String channelId = 'updates_channel';
  static const String channelName = 'Updates';
  static const String channelDescription = 'News updates and breaking stories';

  /// Full-color app logo derived from [assets/icon/app_icon.png].
  static const String _colorIcon = '@drawable/ic_notification_color';
  static const String _largeIcon = '@drawable/ic_notification_large';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  DeepLinkService? _deepLinkService;
  bool _initialized = false;

  Future<void> initialize({required DeepLinkService deepLinkService}) async {
    if (_initialized) return;

    _deepLinkService = deepLinkService;

    const androidSettings = AndroidInitializationSettings(_colorIcon);
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      DeviceService().registerDevice();
    });

    _initialized = true;
  }

  /// Handles notification taps when the app was terminated or in background.
  Future<void> setupInteractedMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessageNavigation(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageNavigation);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final newsId = message.data['newsId']?.toString();
    final imageUrl = message.data['imageUrl']?.toString() ??
        (Platform.isAndroid ? notification.android?.imageUrl : notification.apple?.imageUrl);

    AndroidBitmap<Object>? thumbnailIcon;
    BigPictureStyleInformation? bigPictureStyle;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final bitmap = ByteArrayAndroidBitmap(response.bodyBytes);
          thumbnailIcon = bitmap;
          bigPictureStyle = BigPictureStyleInformation(
            bitmap,
            hideExpandedLargeIcon: true,
          );
        }
      } catch (e) {
        debugPrint('Failed to download notification image: $e');
      }
    }

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: _colorIcon,
          largeIcon: thumbnailIcon,
          color: const Color(0xFFF97316),
          colorized: true,
          styleInformation: bigPictureStyle,
        ),
      ),
      payload: newsId != null && newsId.isNotEmpty
          ? jsonEncode({'newsId': newsId})
          : null,
    );
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) {
        _openNewsFromData(data);
      }
    } catch (_) {
      _deepLinkService?.handleNewsOpen(payload);
    }
  }

  void _handleRemoteMessageNavigation(RemoteMessage message) {
    _openNewsFromData(message.data);
  }

  void _openNewsFromData(Map<String, dynamic> data) {
    final newsId = data['newsId']?.toString();
    if (newsId != null && newsId.isNotEmpty) {
      _deepLinkService?.handleNewsOpen(newsId);
    }
  }
}

/// Background FCM handler — must remain a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification payloads are rendered by the system tray when backgrounded/terminated.
}
