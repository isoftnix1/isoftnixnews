import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareFingerprintService {
  static final HardwareFingerprintService _instance = HardwareFingerprintService._internal();
  factory HardwareFingerprintService() => _instance;
  HardwareFingerprintService._internal();

  // In-memory cache for the lifecycle of the app
  String? _cachedFingerprint;

  Future<String> getHardwareFingerprint() async {
    if (_cachedFingerprint != null) {
      return _cachedFingerprint!;
    }

    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    final Map<String, dynamic> hardwareData = {};

    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        hardwareData['id'] = androidInfo.id; // Android ID
        hardwareData['manufacturer'] = androidInfo.manufacturer;
        hardwareData['brand'] = androidInfo.brand;
        hardwareData['model'] = androidInfo.model;
        hardwareData['device'] = androidInfo.device;
        hardwareData['version'] = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        hardwareData['id'] = iosInfo.identifierForVendor; // IDFV
        hardwareData['model'] = iosInfo.model;
        hardwareData['name'] = iosInfo.name;
        hardwareData['version'] = iosInfo.systemVersion;
      }
    } catch (e) {
      // Fallback if device info fails
      hardwareData['fallback'] = 'unknown_hardware';
    }

    // Sort keys to ensure consistent hashing
    final sortedKeys = hardwareData.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      buffer.write('$key:${hardwareData[key]}|');
    }

    final rawString = buffer.toString();
    final bytes = utf8.encode(rawString);
    final digest = sha256.convert(bytes);
    
    _cachedFingerprint = digest.toString();
    return _cachedFingerprint!;
  }

  /// Optional utility if you want the raw info for the backend replacement payload
  Future<Map<String, dynamic>> getRawDeviceInformation() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
      return {
        'deviceName': info.device,
        'manufacturer': info.manufacturer,
        'model': info.model,
        'platform': 'Android',
        'osVersion': info.version.release,
      };
    } else if (Platform.isIOS) {
      final IosDeviceInfo info = await deviceInfoPlugin.iosInfo;
      return {
        'deviceName': info.name,
        'manufacturer': 'Apple',
        'model': info.model,
        'platform': 'iOS',
        'osVersion': info.systemVersion,
      };
    }
    return {
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
    };
  }
}
