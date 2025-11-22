import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../models/user_settings.dart';
import 'api_client.dart';

class SettingsService {
  SettingsService(this._apiClient);

  final ApiClient _apiClient;

  Future<UserSettings> getSettings() async {
    final response = await _apiClient.dio.get('/settings');
    return UserSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserSettings> updateSettings(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.patch('/settings', data: data);
    return UserSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> uploadLogo(XFile imageFile) async {
    MultipartFile file;
    
    if (kIsWeb) {
      // For web, read bytes from XFile
      final bytes = await imageFile.readAsBytes();
      final fileName = imageFile.name.split('/').last;
      file = MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType.parse(imageFile.mimeType ?? 'image/png'),
      );
    } else {
      // For mobile/desktop, use file path
      file = await MultipartFile.fromFile(imageFile.path);
    }
    
    final formData = FormData.fromMap({
      'file': file,
    });
    final response = await _apiClient.dio.post('/settings/logo', data: formData);
    return response.data as Map<String, dynamic>;
  }

  String? getLogoUrl(String? logoUrl) {
    if (logoUrl == null) return null;
    final baseUrl = _apiClient.baseUrl;
    if (logoUrl.startsWith('http')) return logoUrl;
    return '$baseUrl$logoUrl';
  }
}

