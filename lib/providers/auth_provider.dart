import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';

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
      FirebaseAnalytics.instance.setUserId(id: user.id);
      _registerFcmToken();
      DeviceService().requestLocationPermission();
      return true;
    } on SocketException {
      // Network is unreachable — the stored token is still valid.
      // Do NOT delete it; the user will auto-login successfully next launch.
      ApiService.authToken = null;
      _user = null;
      return false;
    } on TimeoutException {
      // Server took too long — same treatment as no network.
      // Token is preserved for the next attempt.
      ApiService.authToken = null;
      _user = null;
      return false;
    } catch (e) {
      // Any other error (401 expired, 403 deactivated, malformed response)
      // means the token is genuinely invalid — delete it.
      _errorMessage = e.toString();
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
      final responseData = await _apiService.login(email, password);
      _user = responseData['user'];
      
      final accessToken = responseData['accessToken'];
      final refreshToken = responseData['refreshToken'];
      
      if (accessToken != null) {
        ApiService.authToken = accessToken;
        await _storage.write(key: 'auth_token', value: accessToken);
      }
      if (refreshToken != null) {
        await _storage.write(key: 'refresh_token', value: refreshToken);
      }
      
      await _refreshUserProfile();
      if (_user != null) {
        FirebaseAnalytics.instance.setUserId(id: _user!.id);
      }
      // Register FCM token to backend
      _registerFcmToken();
      DeviceService().requestLocationPermission();
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
      final responseData = await _apiService.register(
        name,
        email,
        phone,
        password,
      );
      _user = responseData['user'];
      
      final accessToken = responseData['accessToken'];
      final refreshToken = responseData['refreshToken'];
      
      if (accessToken != null) {
        ApiService.authToken = accessToken;
        await _storage.write(key: 'auth_token', value: accessToken);
      }
      if (refreshToken != null) {
        await _storage.write(key: 'refresh_token', value: refreshToken);
      }
      
      await _refreshUserProfile();
      if (_user != null) {
        FirebaseAnalytics.instance.setUserId(id: _user!.id);
      }
      // Register FCM token to backend
      _registerFcmToken();
      DeviceService().requestLocationPermission();
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> forgotPassword({required String email}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.forgotPassword(email);
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _apiService.verifyResetOtp(email: email, otp: otp);
    } catch (e) {
      _errorMessage = _cleanError(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.resetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );
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
    await _apiService.logout();
    _user = null;
    FirebaseAnalytics.instance.setUserId(id: null);
    _errorMessage = null;
    ApiService.authToken = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
    notifyListeners();
  }

  Future<void> logoutAll() async {
    await _apiService.logoutAll();
    _user = null;
    FirebaseAnalytics.instance.setUserId(id: null);
    _errorMessage = null;
    ApiService.authToken = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.deleteAccount();
      
      // Clear all local session data
      _user = null;
      FirebaseAnalytics.instance.setUserId(id: null);
      ApiService.authToken = null;
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'refresh_token');
      
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    try {
      _user = await _apiService.getProfile();
      notifyListeners();
    } catch (e) {
      // Keep existing profile data if refresh fails
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      await DeviceService().registerDevice();
    } catch (e) {
      // Ignore token generation failure in production
    }
  }

  Future<void> _refreshUserProfile() async {
    try {
      _user = await _apiService.getProfile();
    } catch (e) {
      // Keep login/register user payload if profile refresh fails
    }
  }

  /// Strips the raw Dart 'Exception:' prefix for clean UI display.
  String _cleanError(Object e) {
    return e.toString().replaceAll('Exception: ', '').trim();
  }
}


