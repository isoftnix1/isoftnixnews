import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _user;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;

  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      ApiService.authToken = token;
      final user = await _apiService.getProfile();
      _user = user;
      _registerFcmToken();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      // Clear token if token is invalid or request failed
      await _storage.delete(key: 'auth_token');
      ApiService.authToken = null;
      _user = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _apiService.login(email, password);
      _user = user;
      if (ApiService.authToken != null) {
        await _storage.write(key: 'auth_token', value: ApiService.authToken);
      }
      // Register FCM token to backend
      _registerFcmToken();
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _apiService.register(
        name,
        email,
        phone,
        password,
      );
      _user = user;
      if (ApiService.authToken != null) {
        await _storage.write(key: 'auth_token', value: ApiService.authToken);
      }
      // Register FCM token to backend
      _registerFcmToken();
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({String? name, String? phone}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updatedUser = await _apiService.updateProfile(name: name, phone: phone);
      _user = updatedUser;
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    _errorMessage = null;
    ApiService.authToken = null;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 5));
      if (token != null) {
        await _apiService.registerDeviceToken(token);
      }
    } catch (e) {
      // Ignore token generation failure in production
    }
  }
  /// Strips the raw Dart 'Exception:' prefix for clean UI display.
  String _cleanError(Object e) {
    return e.toString().replaceAll('Exception: ', '').trim();
  }
}


