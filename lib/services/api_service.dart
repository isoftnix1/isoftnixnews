import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/category_model.dart';
import '../models/news_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import 'hardware_fingerprint_service.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;
  static String? authToken;
  static const _storage = FlutterSecureStorage();
  static bool _isRefreshing = false;
  static Completer<bool>? _refreshCompleter;

  /// Lightweight health-check — wakes the Render backend so login is instant.
  Future<void> ping() async {
    try {
      final baseUri = Uri.parse(baseUrl);
      final uri = baseUri.replace(path: '/health');
      await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Silently ignore — ping is best-effort only.
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final fingerprintService = HardwareFingerprintService();
    final fingerprint = await fingerprintService.getHardwareFingerprint();
    final rawInfo = await fingerprintService.getRawDeviceInformation();

    final response = await _request(
      '/auth/login',
      method: 'POST',
      body: {
        'email': email, 
        'password': password,
        'hardwareFingerprint': fingerprint,
        'deviceInformation': rawInfo,
      },
    );
    final data = response['data'];
    return {
      'user': UserModel.fromJson(data['user']),
      'accessToken': data['accessToken'],
      'refreshToken': data['refreshToken'],
    };
  }

  Future<Map<String, dynamic>> register(
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
    final data = response['data'];
    return {
      'user': UserModel.fromJson(data['user']),
      'accessToken': data['accessToken'],
      'refreshToken': data['refreshToken'],
    };
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken != null) {
      try {
        await _request(
          '/auth/logout',
          method: 'POST',
          body: {'refreshToken': refreshToken},
        );
      } catch (e) {
        debugPrint('Logout backend call failed: $e');
      }
    }
  }

  Future<void> logoutAll() async {
    try {
      await _request('/auth/logout-all', method: 'POST');
    } catch (e) {
      debugPrint('Logout-all backend call failed: $e');
    }
  }

  Future<List<CategoryModel>> getCategories({String? lang}) async {
    final response = await _request(
      '/categories',
      queryParameters: {'lang': ?lang},
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
    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final response = await _request(
      '/news',
      queryParameters: {
        if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') 'categoryId': categoryId,
        'page': page.toString(),
        'limit': limit.toString(),
        'lang': ?lang,
        if (startDate != null) 'startDate': fmtDate(startDate),
        if (endDate != null) 'endDate': fmtDate(endDate),
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
        'lang': ?lang,
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

  Future<bool> recordNewsView(String id) async {
    try {
      await _request('/news/$id/view', method: 'POST');
      return true;
    } catch (e) {
      debugPrint('Failed to record news view: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getNewsAnalytics(String id) async {
    final response = await _request('/news/$id/analytics');
    return response['data'] as Map<String, dynamic>? ?? {};
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

  // ---------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------

  Future<void> registerDeviceToken(String token) async {
    try {
      await _request(
        '/notifications/register-token',
        method: 'POST',
        body: {'token': token},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to register device token: $e');
      }
    }
  }

  // ---------------------------------------------------------
  // Device Lifecycle
  // ---------------------------------------------------------

  Future<void> registerDevice(Map<String, dynamic> deviceData) async {
    try {
      await _request(
        '/device/register',
        method: 'POST',
        body: deviceData,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to register device: $e');
      }
    }
  }

  Future<void> heartbeat(String deviceId, String? appVersion, String? osVersion) async {
    try {
      final body = <String, dynamic>{'device_id': deviceId};
      if (appVersion != null) body['app_version'] = appVersion;
      if (osVersion != null) body['os_version'] = osVersion;

      await _request(
        '/device/heartbeat',
        method: 'POST',
        body: body,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to send heartbeat: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAdminDeviceList({String? status, String? platform}) async {
    final queryParams = <String>[];
    if (status != null && status != 'All') queryParams.add('status=$status');
    if (platform != null && platform != 'All') queryParams.add('platform=$platform');
    
    final queryStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final response = await _request('/device/list$queryStr');
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  Future<Map<String, dynamic>> getAdminDeviceAnalytics() async {
    final response = await _request('/device/analytics');
    return response['data'] as Map<String, dynamic>;
  }

  // ---------------------------------------------------------
  // Admin Hardware Lock
  // ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAdminHardwareSlots() async {
    final response = await _request('/admin/hardware-lock');
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  Future<void> requestAdminHardwareReplacement(String password) async {
    await _request(
      '/admin/hardware-lock/request-otp',
      method: 'POST',
      body: {'password': password},
    );
  }

  Future<void> replaceAdminHardwareSlot({
    required int slotNumber,
    required String password,
    required String otp,
  }) async {
    final fingerprintService = HardwareFingerprintService();
    final fingerprint = await fingerprintService.getHardwareFingerprint();
    final rawInfo = await fingerprintService.getRawDeviceInformation();

    await _request(
      '/admin/hardware-lock/replace',
      method: 'POST',
      body: {
        'slotNumber': slotNumber,
        'hardwareFingerprint': fingerprint,
        'deviceInformation': rawInfo,
        'password': password,
        'otp': otp,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getPendingDevices() async {
    final response = await _request('/admin/hardware-lock/pending');
    final List<dynamic> rawPending = response['data'] ?? [];
    return rawPending.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> authorizePendingDevice({
    required String attemptId,
    required int slotNumber,
    required String password,
  }) async {
    await _request(
      '/admin/hardware-lock/authorize-pending',
      method: 'POST',
      body: {
        'attemptId': attemptId,
        'slotNumber': slotNumber,
        'password': password,
      },
    );
  }

  // ---------------------------------------------------------
  // Analytics
  // ---------------------------------------------------------
  Future<void> syncUsageTime(String date, int seconds) async {
    try {
      await _request(
        '/analytics/usage-time',
        method: 'POST',
        body: {
          'usage_date': date,
          'seconds_used': seconds,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to sync usage time: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getGlobalAnalytics() async {
    final response = await _request('/analytics/global-usage', method: 'GET');
    if (response['success'] == true) {
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    }
    return [];
  }

  // ---------------------------------------------------------
  // Internal request helpers
  // ---------------------------------------------------------

  Future<UserModel> updateProfile({String? name, String? phone}) async {
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    final response = await _request('/auth/me', method: 'PUT', body: body);
    return UserModel.fromJson(response['data']['user']);
  }

  Future<void> forgotPassword(String email) async {
    await _request(
      '/auth/forgot-password',
      method: 'POST',
      body: {'email': email},
    );
  }

  Future<String> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _request(
      '/auth/verify-reset-otp',
      method: 'POST',
      body: {'email': email, 'otp': otp},
    );
    final token = response['data']?['resetToken'];
    if (token is! String || token.isEmpty) {
      throw Exception('Invalid server response. Please try again.');
    }
    return token;
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _request(
      '/auth/reset-password',
      method: 'POST',
      body: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
  }

  Future<bool> _refreshToken() async {
    if (_isRefreshing) {
      if (_refreshCompleter != null) return _refreshCompleter!.future;
      return false;
    }
    
    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();
    
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        _isRefreshing = false;
        _refreshCompleter?.complete(false);
        return false;
      }

      final uri = Uri.parse('$baseUrl/auth/refresh');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'];
        
        final newAccess = data['accessToken'];
        final newRefresh = data['refreshToken'];
        
        if (newAccess != null) {
          authToken = newAccess;
          await _storage.write(key: 'auth_token', value: newAccess);
        }
        if (newRefresh != null) {
          await _storage.write(key: 'refresh_token', value: newRefresh);
        }
        
        _isRefreshing = false;
        _refreshCompleter?.complete(true);
        return true;
      }
      
      // Token rejected
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'auth_token');
      authToken = null;
      _isRefreshing = false;
      _refreshCompleter?.complete(false);
      return false;
      
    } catch (e) {
      _isRefreshing = false;
      _refreshCompleter?.complete(false);
      return false;
    }
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters,
    );

    // Auth and write operations must never silently fall back to mock data

    try {
      if (kDebugMode) {
        debugPrint('[API REQUEST] $method $uri');
        if (body != null) {
          final logBody = Map<String, dynamic>.from(body);
          if (logBody.containsKey('password')) logBody['password'] = '***';
          debugPrint('[API REQUEST BODY] $logBody');
        }
      }

      http.Response response;
      final requestBody = body == null ? null : jsonEncode(body);
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      final timeoutDuration = const Duration(seconds: 15);
      final startTime = DateTime.now();

      switch (method) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: requestBody).timeout(timeoutDuration);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: requestBody).timeout(timeoutDuration);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(timeoutDuration);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: requestBody).timeout(timeoutDuration);
          break;
        default:
          response = await http.get(uri, headers: headers).timeout(timeoutDuration);
      }

      final endTime = DateTime.now();
      
      if (kDebugMode) {
        debugPrint('[API RESPONSE] $method $uri');
        debugPrint('[API STATUS CODE] ${response.statusCode}');
        debugPrint('[API TIME] ${endTime.difference(startTime).inMilliseconds}ms');
        if (response.body.length < 1000) {
          debugPrint('[API RESPONSE BODY] ${response.body}');
        }
      }

      final decoded = jsonDecode(response.body);
      
      if (response.statusCode == 401 && !isRetry) {
        // Token might be expired, attempt to refresh
        if (authToken != null) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry original request
            return _request(path, method: method, queryParameters: queryParameters, body: body, isRetry: true);
          }
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Extract a clean server message if available
        final message = decoded is Map<String, dynamic>
            ? (decoded['message'] ?? 'Something went wrong. Please try again.')
            : 'Something went wrong. Please try again.';
        throw Exception(message);
      }
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } on TimeoutException catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[API ERROR] TimeoutException for $uri: $e\n$stack');
      }
      throw Exception('The server took too long to respond. Please try again.');
    } on SocketException catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[API ERROR] SocketException for $uri: $e\n$stack');
      }
      throw Exception('Unable to connect to server. Please check your internet connection.');
    } on Exception catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[API ERROR] Exception for $uri: $e\n$stack');
      }
      rethrow;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[API ERROR] Unknown error for $uri: $e\n$stack');
      }
      throw Exception('An unexpected network error occurred.');
    }
  }

  Future<Map<String, dynamic>> _multipartRequest(
    String path, {
    required String method,
    required NewsModel news,
    File? imageFile,
    File? videoFile,
    bool isRetry = false,
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
      
      if (response.statusCode == 401 && !isRetry) {
        if (authToken != null) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            return _multipartRequest(
              path,
              method: method,
              news: news,
              imageFile: imageFile,
              videoFile: videoFile,
              isRetry: true,
            );
          }
        }
      }

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

}
