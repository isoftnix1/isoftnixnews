import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'api_service.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final ApiService _api = ApiService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  DateTime? _lastHeartbeat;
  static const int _heartbeatThrottleMinutes = 5;

  String? _cachedDeviceId;
  String? _cachedAppVersion;
  String? _cachedOsVersion;

  /// Call this when the app starts or resumes from background
  Future<void> sendHeartbeat({bool force = false}) async {
    // Only logged-in users can send heartbeats
    if (ApiService.authToken == null) return;

    if (!force && _lastHeartbeat != null) {
      final diff = DateTime.now().difference(_lastHeartbeat!);
      if (diff.inMinutes < _heartbeatThrottleMinutes) {
        return;
      }
    }

    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();
      final osVersion = await _getOsVersion();
      final location = await _getSilentLocation();
      String? locationName;
      if (location != null) {
        try {
          final geocoding = Geocoding();
          List<Placemark> placemarks = await geocoding.placemarkFromCoordinates(location.latitude, location.longitude);
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final parts = <String>[];
            if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
            if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) parts.add(place.administrativeArea!);
            if (place.country != null && place.country!.isNotEmpty) parts.add(place.country!);
            if (parts.isNotEmpty) {
              locationName = parts.join(', ');
            }
          }
        } catch (_) {}
      }

      await _api.heartbeat(
        deviceId, 
        appVersion, 
        osVersion,
        latitude: location?.latitude,
        longitude: location?.longitude,
        locationName: locationName,
      );
      _lastHeartbeat = DateTime.now();
      
      if (kDebugMode) {
        debugPrint('[DeviceService] Heartbeat sent at $_lastHeartbeat');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceService] Heartbeat error: $e');
      }
    }
  }

  /// Call this on login or when the FCM token refreshes
  Future<void> registerDevice() async {
    // Only logged-in users can register a device
    if (ApiService.authToken == null) return;

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        if (kDebugMode) debugPrint('[DeviceService] Cannot register: FCM token is null');
        return;
      }
      if (kDebugMode) debugPrint('\n\n=== FCM TOKEN FOR TESTING ===\n$fcmToken\n=============================\n\n');

      final data = <String, dynamic>{
        'fcm_token': fcmToken,
        'device_id': await _getDeviceId(),
        'platform': Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'web',
        'os_version': await _getOsVersion(),
        'app_version': await _getAppVersion(),
      };

      final location = await _getSilentLocation();
      if (location != null) {
        data['latitude'] = location.latitude;
        data['longitude'] = location.longitude;
        try {
          final geocoding = Geocoding();
          List<Placemark> placemarks = await geocoding.placemarkFromCoordinates(location.latitude, location.longitude);
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final parts = <String>[];
            if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
            if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) parts.add(place.administrativeArea!);
            if (place.country != null && place.country!.isNotEmpty) parts.add(place.country!);
            if (parts.isNotEmpty) {
              data['location_name'] = parts.join(', ');
            }
          }
        } catch (_) {}
      }

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        data['device_name'] = androidInfo.model;
        data['manufacturer'] = androidInfo.manufacturer;
        data['model'] = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        data['device_name'] = iosInfo.name;
        data['manufacturer'] = 'Apple';
        data['model'] = iosInfo.model;
      }

      await _api.registerDevice(data);
      _lastHeartbeat = DateTime.now(); // Registering counts as a heartbeat
      
      if (kDebugMode) {
        debugPrint('[DeviceService] Device registered successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceService] Registration error: $e');
      }
    }
  }

  Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      _cachedDeviceId = info.id; // Unique ID on Android
    } else if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      _cachedDeviceId = info.identifierForVendor ?? 'unknown_ios_device';
    } else {
      _cachedDeviceId = 'unknown_device';
    }
    return _cachedDeviceId!;
  }

  Future<String> _getAppVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      _cachedAppVersion = 'unknown';
    }
    return _cachedAppVersion!;
  }

  Future<String> _getOsVersion() async {
    if (_cachedOsVersion != null) return _cachedOsVersion!;
    
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      _cachedOsVersion = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
    } else if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      _cachedOsVersion = 'iOS ${info.systemVersion}';
    } else {
      _cachedOsVersion = Platform.operatingSystemVersion;
    }
    return _cachedOsVersion!;
  }

  /// Attempts to get location silently (only if permission was already granted)
  Future<Position?> _getSilentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        return await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      }
    } catch (_) {
      // Ignore
    }
    return null;
  }

  /// Explicitly requests location permission from the user
  Future<void> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }
}
