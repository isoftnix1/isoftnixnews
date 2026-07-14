import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'providers/auth_provider.dart';
import 'providers/category_provider.dart';
import 'providers/news_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'routes/app_routes.dart';
import 'services/auth_service.dart';
import 'services/deep_link_service.dart';
import 'services/device_service.dart';
import 'services/keep_alive_service.dart';
import 'services/push_notification_service.dart';
import 'services/time_tracking_service.dart';
import 'services/voice_assistant_service.dart';
import 'theme/app_theme.dart';

/// Global navigator key used by [DeepLinkService] to navigate
/// from outside the widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env.development');

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Wake up the Render backend immediately so login is instant.
  KeepAliveService.instance.start();

  runApp(ISoftNixNewsApp(navigatorKey: navigatorKey));
}

class ISoftNixNewsApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const ISoftNixNewsApp({super.key, required this.navigatorKey});

  @override
  State<ISoftNixNewsApp> createState() => _ISoftNixNewsAppState();
}

class _ISoftNixNewsAppState extends State<ISoftNixNewsApp> with WidgetsBindingObserver {
  late final DeepLinkService _deepLinkService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deepLinkService = DeepLinkService(navigatorKey: widget.navigatorKey);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _deepLinkService.init();
      await PushNotificationService.instance.initialize(
        deepLinkService: _deepLinkService,
      );
      await PushNotificationService.instance.setupInteractedMessage();
      
      // Initialize Time Tracking Analytics
      await TimeTrackingService().init();
      
      // Trigger initial heartbeat
      DeviceService().sendHeartbeat();

      // Request microphone and camera permissions on startup
      await [
        Permission.microphone,
        Permission.camera,
      ].request();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DeviceService().sendHeartbeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => VoiceAssistantService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Updates',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.themeMode,
            navigatorKey: widget.navigatorKey,
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            navigatorObservers: [
              FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
            ],
          );
        },
      ),
    );
  }
}
