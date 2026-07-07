import 'dart:async';
import 'dart:io';

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
      _registerFcmToken();
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
      final user = await _apiService.login(email, password);
      _user = user;
      if (ApiService.authToken != null) {
        await _storage.write(key: 'auth_token', value: ApiService.authToken);
      }
      await _refreshUserProfile();
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
      await _refreshUserProfile();
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
    _user = null;
    _errorMessage = null;
    ApiService.authToken = null;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
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


