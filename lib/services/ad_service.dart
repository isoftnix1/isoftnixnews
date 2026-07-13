import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/ad_model.dart';
import 'api_service.dart';

class AdService {
  static final Set<String> _viewedAds = {};

  Future<List<AdModel>> getActiveAds() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/ads/active');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] as List<dynamic>? ?? [];
        return data.map((e) => AdModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> addAd({
    required String companyName,
    required String title,
    required String description,
    required String targetUrl,
    File? imageFile,
    File? videoFile,
  }) async {
    final token = ApiService.authToken;
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('${ApiConfig.baseUrl}/ads/admin/ads');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['company_name'] = companyName
      ..fields['title'] = title
      ..fields['description'] = description
      ..fields['target_url'] = targetUrl;

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }
    if (videoFile != null) {
      request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    }

    final response = await request.send();
    if (response.statusCode != 201 && response.statusCode != 200) {
      final responseBody = await response.stream.bytesToString();
      throw Exception('Failed to add ad: $responseBody');
    }
  }

  Future<void> deleteAd(String id) async {
    final token = ApiService.authToken;
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('${ApiConfig.baseUrl}/ads/admin/ads/$id');
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete ad: ${response.body}');
    }
  }

  Future<void> recordAdView(String id) async {
    final token = ApiService.authToken;
    if (token == null) return; // Only track logged-in users
    
    if (_viewedAds.contains(id)) return;
    
    try {
      _viewedAds.add(id);
      final uri = Uri.parse('${ApiConfig.baseUrl}/ads/$id/view');
      await http.post(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Fail silently to not disrupt UX
      _viewedAds.remove(id); // Retry next time if it failed
    }
  }

  Future<void> recordAdClick(String id) async {
    final token = ApiService.authToken;
    if (token == null) return; // Only track logged-in users

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/ads/$id/click');
      await http.post(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Fail silently
    }
  }
}
