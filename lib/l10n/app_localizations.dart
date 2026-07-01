import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class AppLocalizations {
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'language': 'Language',
      'notifications': 'Notifications',
      'profile': 'Profile',
      'settings': 'Settings',
      'logout': 'Logout',
      'no_more_articles': 'No More Articles',
      'loading': 'Loading...',
      'business': 'Business',
      'technology': 'Technology',
      'entertainment': 'Entertainment',
      'admin_dashboard': 'Admin Dashboard',
      'manage_news': 'Manage News',
      'add_news': 'Add News',
      'manage_categories': 'Manage Categories',
      'welcome_back': 'Welcome back,',
      'quick_actions': 'Quick Actions',
      'home': 'Home',
      'latest_news': 'Latest News',
      'dark_mode': 'Dark Mode',
      'no_photo_video': 'No photo or video available',
      'app_title': 'Updates',
      'splash_subtitle': 'Latest stories, every day',
    },
    'hi': {
      'language': 'भाषा',
      'notifications': 'सूचनाएँ',
      'profile': 'प्रोफ़ाइल',
      'settings': 'सेटिंग्स',
      'logout': 'लॉग आउट',
      'no_more_articles': 'कोई और समाचार नहीं',
      'loading': 'लोड हो रहा है...',
      'business': 'व्यापार',
      'technology': 'प्रौद्योगिकी',
      'entertainment': 'मनोरंजन',
      'admin_dashboard': 'व्यवस्थापक डैशबोर्ड',
      'manage_news': 'समाचार प्रबंधित करें',
      'add_news': 'समाचार जोड़ें',
      'manage_categories': 'श्रेणियाँ प्रबंधित करें',
      'welcome_back': 'वापसी पर स्वागत है,',
      'quick_actions': 'त्वरित कार्रवाई',
      'home': 'होम',
      'latest_news': 'नवीनतम समाचार',
      'dark_mode': 'डार्क मोड',
      'no_photo_video': 'कोई फोटो या वीडियो उपलब्ध नहीं',
      'app_title': 'अपडेट्स',
      'splash_subtitle': 'हर दिन नवीनतम कहानियाँ',
    },
    'mr': {
      'language': 'भाषा',
      'notifications': 'सूचना',
      'profile': 'प्रोफाइल',
      'settings': 'सेटिंग्ज',
      'logout': 'बाहेर पडा',
      'no_more_articles': 'आणखी बातम्या नाहीत',
      'loading': 'लोड होत आहे...',
      'business': 'व्यवसाय',
      'technology': 'तंत्रज्ञान',
      'entertainment': 'मनोरंजन',
      'admin_dashboard': 'प्रशासक डॅशबोर्ड',
      'manage_news': 'बातम्या व्यवस्थापित करा',
      'add_news': 'बातम्या जोडा',
      'manage_categories': 'श्रेण्या व्यवस्थापित करा',
      'welcome_back': 'पुन्हा स्वागत आहे,',
      'quick_actions': 'त्वरित कृती',
      'home': 'मुख्यपृष्ठ',
      'latest_news': 'ताज्या बातम्या',
      'dark_mode': 'डार्क मोड',
      'no_photo_video': 'कोणताही फोटो किंवा व्हिडिओ उपलब्ध नाही',
      'app_title': 'अपडेट्स',
      'splash_subtitle': 'रोजच्या ताज्या बातम्या',
    },
  };

  static String of(BuildContext context, String key) {
    final languageCode = context.watch<LanguageProvider>().currentLanguage;
    final dict = _localizedValues[languageCode] ?? _localizedValues['en']!;
    return dict[key] ?? _localizedValues['en']![key] ?? key;
  }
}
