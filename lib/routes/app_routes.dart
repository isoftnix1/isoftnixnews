import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/admin/add_news_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_login_screen.dart';
import '../screens/admin/category_management_screen.dart';
import '../screens/admin/device_management_screen.dart';
import '../screens/admin/edit_news_screen.dart';
import '../screens/admin/news_list_screen.dart';
import '../screens/admin/drafts_list_screen.dart';
import '../screens/admin/hardware_lock_screen.dart';
import '../screens/admin/ad_management_screen.dart';
import '../providers/news_provider.dart';
import '../screens/admin/analytics_dashboard_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/user/external_article_screen.dart';
import '../screens/user/home_screen.dart';
import '../screens/user/news_details_screen.dart';
import '../screens/user/notifications_screen.dart';
import '../screens/user/profile_screen.dart';
import '../screens/user/settings_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String verifyOtp = '/verify-otp';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  // Used for navigation with a full NewsModel object (normal in-app navigation)
  static const String newsDetails = '/news-details';
  // Used for deep-link / onGenerateRoute navigation with a newsId string
  static const String newsDetailsById = '/news';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String notifications = '/notifications';

  static const String adminLogin = '/admin-login';
  static const String adminDashboard = '/admin-dashboard';
  static const String adminNewsList = '/admin-news-list';
  static const String adminDraftsList = '/admin-drafts-list';
  static const String addNews = '/add-news';
  static const String editNews = '/edit-news';
  static const String manageCategories = '/manage-categories';
  static const String deviceManagement = '/device-management';
  static const String hardwareLock = '/hardware-lock';
  static const String adminAnalytics = '/admin-analytics';
  static const String adminAds = '/admin-ads';
  static const String externalArticle = '/external-article';

  /// Static routes for simple navigation without arguments.
  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    home: (context) => const HomeScreen(),
    // newsDetails is handled here for backward-compat (arg = NewsModel)
    newsDetails: (context) => const NewsDetailsScreen(),
    profile: (context) => const ProfileScreen(),
    settings: (context) => const SettingsScreen(),
    notifications: (context) => const NotificationsScreen(),
    adminLogin: (context) => const AdminLoginScreen(),
    adminDashboard: (context) => const AdminDashboardScreen(),
    adminNewsList: (context) => const NewsListScreen(),
    adminDraftsList: (context) => ChangeNotifierProvider(
      create: (_) => NewsProvider(),
      child: const DraftsListScreen(),
    ),
    addNews: (context) => const AddNewsScreen(),
    editNews: (context) => const EditNewsScreen(),
    manageCategories: (context) => const CategoryManagementScreen(),
    deviceManagement: (context) => const DeviceManagementScreen(),
    hardwareLock: (context) => const HardwareLockScreen(),
    adminAnalytics: (context) => const AnalyticsDashboardScreen(),
    adminAds: (context) => const AdManagementScreen(),
  };

  /// Dynamic route generator to handle:
  /// - /news/{uuid}  →  NewsDetailsScreen loaded by ID (deep links)
  ///
  /// Falls back to a 404 screen for unrecognised routes.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';

    // Handle /news/{uuid} — produced by DeepLinkService and share intents
    if (name.startsWith('/news/')) {
      final newsId = name.replaceFirst('/news/', '');
      if (newsId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => NewsDetailsScreen(newsId: newsId),
        );
      }
    }

    // Handle /external-article — produced by DeepLinkService for external URLs
    if (name == externalArticle) {
      final args = settings.arguments;
      if (args is Map<String, String>) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ExternalArticleScreen(
            title: args['title'] ?? '',
            url: args['url'] ?? '',
          ),
        );
      }
    }

    if (name == verifyOtp) {
      final email = settings.arguments;
      if (email is String && email.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => VerifyOtpScreen(email: email),
        );
      }
    }

    if (name == resetPassword) {
      final resetToken = settings.arguments;
      if (resetToken is String && resetToken.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ResetPasswordScreen(resetToken: resetToken),
        );
      }
    }

    // Unknown route — show a safe error screen
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Text('Route not found: $name'),
        ),
      ),
    );
  }
}
