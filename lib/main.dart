import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/category_provider.dart';
import 'providers/news_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_routes.dart';
import 'services/deep_link_service.dart';
import 'theme/app_theme.dart';

// Background message handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Global navigator key used by [DeepLinkService] to navigate
/// from outside the widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment configuration
  // For production build: change filename to '.env.production'
  await dotenv.load(fileName: '.env.development');

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permission (important for Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(ISoftNixNewsApp(navigatorKey: navigatorKey));
}

class ISoftNixNewsApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const ISoftNixNewsApp({super.key, required this.navigatorKey});

  @override
  State<ISoftNixNewsApp> createState() => _ISoftNixNewsAppState();
}

class _ISoftNixNewsAppState extends State<ISoftNixNewsApp> {
  late final DeepLinkService _deepLinkService;

  @override
  void initState() {
    super.initState();
    _deepLinkService = DeepLinkService(navigatorKey: widget.navigatorKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkService.init();
      _setupInteractedMessage();
    });
  }

  Future<void> _setupInteractedMessage() async {
    // Get any messages which caused the application to open from a terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Also handle any interaction when the app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data.containsKey('newsId')) {
      final newsId = message.data['newsId'];
      if (newsId is String && newsId.isNotEmpty) {
        _deepLinkService.handleNewsOpen(newsId);
      }
    }
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'ISoftNix News',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.themeMode,
            navigatorKey: widget.navigatorKey,
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}