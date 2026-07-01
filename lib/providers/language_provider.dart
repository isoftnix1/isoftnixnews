import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/api_service.dart';
import 'news_provider.dart';

class LanguageProvider extends ChangeNotifier {
  final LanguageService _languageService = LanguageService();
  // Direct instance — ApiService is not a registered Provider
  final ApiService _apiService = ApiService();
  String _currentLanguage = 'en';

  late Future<void> _initFuture;
  Future<void> get initializationDone => _initFuture;

  String get currentLanguage => _currentLanguage;

  LanguageProvider() {
    _initFuture = loadLanguage();
  }

  Future<void> loadLanguage() async {
    _currentLanguage = await _languageService.getLanguage();
    notifyListeners();
  }

  Future<void> changeLanguage(BuildContext context, String languageCode) async {
    if (_currentLanguage == languageCode) return;
    _currentLanguage = languageCode;
    await _languageService.setLanguage(languageCode);
    notifyListeners();

    // Asynchronously update backend preference without blocking UI
    _apiService.updateLanguagePreference(languageCode);

    // Reload both categories and news concurrently in the new language
    final newsProvider = Provider.of<NewsProvider>(context, listen: false);
    await Future.wait([
      newsProvider.loadCategories(lang: languageCode),
      newsProvider.loadNews(refresh: true, lang: languageCode),
    ]);
  }
}
