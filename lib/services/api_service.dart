import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/category_model.dart';
import '../models/news_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';

class ApiService {
  // Loaded from .env.development or .env.production via flutter_dotenv
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api';
  static String? authToken;

  Future<UserModel> login(String email, String password) async {
    final response = await _request(
      '/auth/login',
      method: 'POST',
      body: {'email': email, 'password': password},
    );
    if (response['data'] != null && response['data']['token'] != null) {
      authToken = response['data']['token'];
    }
    return UserModel.fromJson(response['data']['user']);
  }

  Future<UserModel> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    final response = await _request(
      '/auth/register',
      method: 'POST',
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );
    if (response['data'] != null && response['data']['token'] != null) {
      authToken = response['data']['token'];
    }
    return UserModel.fromJson(response['data']['user']);
  }

  Future<List<CategoryModel>> getCategories({String? lang}) async {
    final response = await _request(
      '/categories',
      queryParameters: {if (lang != null) 'lang': lang},
    );
    final list = response['data'] as List<dynamic>? ?? [];
    return list.map((e) => CategoryModel.fromJson(e)).toList();
  }

  Future<CategoryModel> createCategory(String name, String slug) async {
    final response = await _request(
      '/categories',
      method: 'POST',
      body: {'name': name, 'slug': slug},
    );
    return CategoryModel.fromJson(response['data']);
  }

  Future<CategoryModel> updateCategory(String id, String name, String slug) async {
    final response = await _request(
      '/categories/$id',
      method: 'PUT',
      body: {'name': name, 'slug': slug},
    );
    return CategoryModel.fromJson(response['data']);
  }

  Future<void> deleteCategory(String id) async {
    await _request('/categories/$id', method: 'DELETE');
  }

  Future<void> updateLanguagePreference(String lang) async {
    try {
      await _request(
        '/auth/preferences',
        method: 'PATCH',
        body: {'preferred_language': lang},
      );
    } catch (e) {
      debugPrint('Failed to update language preference on server: $e');
    }
  }

  Future<List<NewsModel>> getNews({String? categoryId, int page = 1, String? lang, DateTime? startDate, DateTime? endDate, int limit = 10}) async {
    String _fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final response = await _request(
      '/news',
      queryParameters: {
        if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') 'categoryId': categoryId,
        'page': page.toString(),
        'limit': limit.toString(),
        if (lang != null) 'lang': lang,
        if (startDate != null) 'startDate': _fmtDate(startDate),
        if (endDate != null) 'endDate': _fmtDate(endDate),
      },
    );
    final data = response['data'];
    List<dynamic> list = [];
    if (data is Map<String, dynamic> && data.containsKey('items')) {
      list = data['items'] as List<dynamic>? ?? [];
    } else if (data is List) {
      list = data;
    }
    return list.map((e) => NewsModel.fromJson(e)).toList();
  }

  Future<NewsModel> getNewsById(String id, {String? lang}) async {
    final response = await _request(
      '/news/$id',
      queryParameters: {
        if (lang != null) 'lang': lang,
      },
    );
    return NewsModel.fromJson(response['data']);
  }

  Future<bool> addNews(NewsModel news) async {
    await _request(
      '/news',
      method: 'POST',
      body: news.toJson(),
    );
    return true;
  }

  Future<bool> addNewsMultipart(NewsModel news, {File? imageFile, File? videoFile}) async {
    await _multipartRequest('/news', method: 'POST', news: news, imageFile: imageFile, videoFile: videoFile);
    return true;
  }

  Future<bool> updateNews(NewsModel news) async {
    await _request(
      '/news/${news.id}',
      method: 'PUT',
      body: news.toJson(),
    );
    return true;
  }

  Future<bool> updateNewsMultipart(NewsModel news, {File? imageFile, File? videoFile}) async {
    await _multipartRequest('/news/${news.id}', method: 'PUT', news: news, imageFile: imageFile, videoFile: videoFile);
    return true;
  }

  Future<bool> deleteNews(String id) async {
    await _request('/news/$id', method: 'DELETE');
    return true;
  }

  Future<UserModel> getProfile() async {
    final response = await _request('/auth/me');
    return UserModel.fromJson(response['data']['user']);
  }

  Future<List<NotificationModel>> getNotifications() async {
    final response = await _request('/notifications');
    final list = response['data'] as List<dynamic>? ?? [];
    return list.map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<bool> registerDeviceToken(String token) async {
    await _request(
      '/notifications/register-token',
      method: 'POST',
      body: {'token': token},
    );
    return true;
  }

  Future<UserModel> updateProfile({String? name, String? phone}) async {
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    final response = await _request('/auth/me', method: 'PUT', body: body);
    return UserModel.fromJson(response['data']['user']);
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters,
    );

    // Auth and write operations must never silently fall back to mock data
    final bool isCritical = method != 'GET' || path.startsWith('/auth');

    try {
      http.Response response;
      final requestBody = body == null ? null : jsonEncode(body);
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      switch (method) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: requestBody).timeout(const Duration(seconds: 10));
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: requestBody).timeout(const Duration(seconds: 10));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: requestBody).timeout(const Duration(seconds: 10));
          break;
        default:
          response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      }

      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Extract a clean server message if available
        final message = decoded is Map<String, dynamic>
            ? (decoded['message'] ?? 'Something went wrong. Please try again.')
            : 'Something went wrong. Please try again.';
        throw Exception(message);
      }
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } on Exception {
      // Rethrow for critical operations so errors surface to the UI correctly
      if (isCritical) rethrow;
      // For read-only requests fall back to cached/mock data
      return _fallbackResponse(path, body: body);
    } catch (e) {
      if (isCritical) throw Exception('Unable to connect to server. Please check your internet connection.');
      return _fallbackResponse(path, body: body);
    }
  }

  Future<Map<String, dynamic>> _multipartRequest(
    String path, {
    required String method,
    required NewsModel news,
    File? imageFile,
    File? videoFile,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest(method, uri);
    
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    // Add string fields
    if (news.titleEn != null) request.fields['title_en'] = news.titleEn!;
    if (news.contentEn != null) request.fields['content_en'] = news.contentEn!;
    if (news.titleHi != null) request.fields['title_hi'] = news.titleHi!;
    if (news.contentHi != null) request.fields['content_hi'] = news.contentHi!;
    if (news.titleMr != null) request.fields['title_mr'] = news.titleMr!;
    if (news.contentMr != null) request.fields['content_mr'] = news.contentMr!;
    if (news.categoryId != null) {
      request.fields['categoryId'] = news.categoryId!;
    }
    for (var catId in news.categoryIds) {
      // Backend body-parser (express) parses repeated fields as an array if named with brackets
      request.fields['categoryIds[${news.categoryIds.indexOf(catId)}]'] = catId;
    }
    request.fields['isPublished'] = news.isPublished.toString();
    if (news.imageUrl.isNotEmpty) {
      request.fields['imageUrl'] = news.imageUrl;
    }
    if (news.videoUrl != null && news.videoUrl!.isNotEmpty) {
      request.fields['videoUrl'] = news.videoUrl!;
    }
    if (news.sourceName != null) {
      request.fields['source_name'] = news.sourceName!;
    }
    if (news.sourceUrl != null) {
      request.fields['source_url'] = news.sourceUrl!;
    }

    // Add files
    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }
    if (videoFile != null) {
      request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    }

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map<String, dynamic>
            ? (decoded['message'] ?? 'Upload failed. Please try again.')
            : 'Upload failed. Please try again.';
        throw Exception(message);
      }
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } catch (e) {
      // Always rethrow for multipart (write operations)
      if (e is Exception) rethrow;
      throw Exception('Upload failed. Please check your connection.');
    }
  }

  Map<String, dynamic> _fallbackResponse(
    String path, {
    Map<String, dynamic>? body,
  }) {
    if (path == '/categories') {
      return {
        'data': [
          {'id': 'all', 'name': 'All'},
          {'id': 'world', 'name': 'World'},
          {'id': 'tech', 'name': 'Tech'},
          {'id': 'sports', 'name': 'Sports'},
        ],
      };
    }

    if (path.startsWith('/news') && !path.contains('/news/')) {
      return {
        'data': [
          {
            'id': '1',
            'title': 'AI reshapes the future of local journalism',
            'content':
                'A look into how new tools are helping newsrooms deliver faster and more insightful stories.',
            'imageUrl':
                'https://images.unsplash.com/photo-1495020689067-958852a7765e?auto=format&fit=crop&w=900&q=80',
            'category_id': 'tech',
            'category_name': 'Tech',
            'authorName': 'Avery Brooks',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': '2',
            'title': 'Weekend sports roundup',
            'content':
                'Teams across the region delivered dramatic finishes, keeping fans on the edge of their seats.',
            'imageUrl':
                'https://images.unsplash.com/photo-1517649763962-0c623066013b?auto=format&fit=crop&w=900&q=80',
            'category_id': 'sports',
            'category_name': 'Sports',
            'authorName': 'Jordan Lee',
            'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          },
        ],
      };
    }

    if (path.startsWith('/news/')) {
      return {
        'data': {
          'id': path.split('/').last,
          'title': 'Sample article preview',
          'content':
              'This preview shows how the full article card will look once the backend data is available.',
          'imageUrl':
              'https://images.unsplash.com/photo-1495020689067-958852a7765e?auto=format&fit=crop&w=900&q=80',
          'category_id': 'general',
          'category_name': 'General',
          'authorName': 'Admin',
          'created_at': DateTime.now().toIso8601String(),
        },
      };
    }

    // Auth routes are critical — no fallback allowed (handled by rethrow above)

    return {'data': []};
  }
}
