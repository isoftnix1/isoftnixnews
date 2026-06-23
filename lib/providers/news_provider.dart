import 'dart:io';

import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../models/news_model.dart';
import '../services/api_service.dart';

class NewsProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<NewsModel> _news = [];
  List<CategoryModel> _categories = [];
  bool _isLoadingNews = false;
  bool _isLoadingCategories = false;
  bool _hasMore = true;
  String? _errorMessage;
  String _selectedCategoryId = 'all';
  int _page = 1;

  List<NewsModel> get news => _news;
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoadingNews || _isLoadingCategories;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String get selectedCategoryId => _selectedCategoryId;

  Future<void> loadCategories() async {
    _isLoadingCategories = true;
    notifyListeners();

    try {
      final categories = await _apiService.getCategories();
      _categories = [
        const CategoryModel(id: 'all', name: 'All', slug: 'all'),
        ...categories,
      ];
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> loadNews({bool refresh = false, String? categoryId}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _news = [];
    }

    if (!_hasMore || _isLoadingNews) return;

    _isLoadingNews = true;
    notifyListeners();

    try {
      if (categoryId != null) {
        _selectedCategoryId = categoryId;
      }

      final items = await _apiService.getNews(
        categoryId: _selectedCategoryId == 'all' ? null : _selectedCategoryId,
        page: _page,
      );

      if (refresh || _page == 1) {
        _news = items;
      } else {
        _news.addAll(items);
      }

      _hasMore = items.length >= 10;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingNews = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreNews() async {
    if (_hasMore && !_isLoadingNews) {
      _page++;
      await loadNews();
    }
  }

  Future<NewsModel> getNewsById(String id) async {
    return _apiService.getNewsById(id);
  }

  Future<void> addNews(NewsModel news, {File? imageFile, File? videoFile}) async {
    _isLoadingNews = true;
    notifyListeners();

    try {
      if (imageFile != null || videoFile != null) {
        await _apiService.addNewsMultipart(news, imageFile: imageFile, videoFile: videoFile);
      } else {
        await _apiService.addNews(news);
      }
      await loadNews(refresh: true);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingNews = false;
      notifyListeners();
    }
  }

  Future<void> updateNews(NewsModel news, {File? imageFile, File? videoFile}) async {
    _isLoadingNews = true;
    notifyListeners();

    try {
      if (imageFile != null || videoFile != null) {
        await _apiService.updateNewsMultipart(news, imageFile: imageFile, videoFile: videoFile);
      } else {
        await _apiService.updateNews(news);
      }
      await loadNews(refresh: true);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingNews = false;
      notifyListeners();
    }
  }

  Future<void> deleteNews(String id) async {
    _isLoadingNews = true;
    notifyListeners();

    try {
      await _apiService.deleteNews(id);
      _news.removeWhere((item) => item.id == id);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingNews = false;
      notifyListeners();
    }
  }

  void selectCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    _page = 1;
    _hasMore = true;
    notifyListeners();
  }
}
