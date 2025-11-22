import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

class PdfService {
  final ApiClient _apiClient;

  PdfService(this._apiClient);

  Future<String> getSignedUrl(String path) async {
    try {
      // Use ApiClient's baseUrl which already handles web vs mobile correctly
      final baseUrl = _apiClient.baseUrl;
      final response = await _apiClient.dio.get(
        '/pdf/signed-url',
        queryParameters: {'path': path},
      );
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map, got ${responseData.runtimeType}');
      }
      final signedUrlValue = responseData['signedUrl'];
      final signedUrl = signedUrlValue is String ? signedUrlValue : signedUrlValue?.toString() ?? '';
      if (signedUrl.isEmpty) {
        throw Exception('Missing signedUrl in response');
      }
      // Return full URL
      if (signedUrl.startsWith('/')) {
        return '$baseUrl$signedUrl';
      }
      return signedUrl;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /**
   * Generate HTML preview for live preview feature
   */
  Future<String> generatePreview(
    String invoiceId, {
    Map<String, dynamic>? customization,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/pdf/preview',
        data: {
          'invoiceId': invoiceId,
          'customization': customization,
        },
      );
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map');
      }
      final html = responseData['html'];
      if (html is! String) {
        throw Exception('Missing or invalid HTML in response');
      }
      return html;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /**
   * Extract colors from logo using AI
   */
  Future<Map<String, String>> extractColorsFromLogo(String logoUrl) async {
    try {
      final response = await _apiClient.dio.post(
        '/pdf/extract-colors',
        data: {
          'logoUrl': logoUrl,
        },
      );
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map');
      }
      final colors = responseData['colors'];
      if (colors is! Map<String, dynamic>) {
        throw Exception('Missing or invalid colors in response');
      }
      return Map<String, String>.from(colors.map((key, value) => MapEntry(key, value.toString())));
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /**
   * Analyze reference design image and extract all design patterns
   */
  Future<Map<String, dynamic>> analyzeDesign(String imageUrl) async {
    try {
      final response = await _apiClient.dio.post(
        '/pdf/analyze-design',
        data: {
          'imageUrl': imageUrl,
        },
      );
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map');
      }
      final analysis = responseData['analysis'];
      if (analysis is! Map<String, dynamic>) {
        throw Exception('Missing or invalid analysis in response');
      }
      return Map<String, dynamic>.from(analysis);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /**
   * Upload reference design image and analyze it in one step
   */
  Future<Map<String, dynamic>> uploadAndAnalyzeDesign(dynamic image) async {
    try {
      // Handle both XFile (from image_picker) and file paths
      MultipartFile file;
      
      if (image is XFile) {
        // For web and mobile, read bytes from XFile
        final bytes = await image.readAsBytes();
        final fileName = image.name;
        final mimeType = image.mimeType ?? 'image/png';
        file = MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        );
      } else if (image is String) {
        // Fallback for file path (mobile)
        file = await MultipartFile.fromFile(image);
      } else {
        throw Exception('Invalid image type: ${image.runtimeType}');
      }
      
      final formData = FormData.fromMap({
        'file': file,
      });
      
      final response = await _apiClient.dio.post(
        '/pdf/upload-and-analyze-design',
        data: formData,
      );
      
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map');
      }
      
      // Return both the imageUrl and analysis
      return Map<String, dynamic>.from(responseData);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /**
   * Get all invoice templates
   */
  Future<Map<String, dynamic>> getTemplates() async {
    try {
      final response = await _apiClient.dio.get('/pdf/templates');
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map');
      }
      return Map<String, dynamic>.from(responseData);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /**
   * Get template by ID
   */
  Future<Map<String, dynamic>> getTemplateById(String id) async {
    try {
      final response = await _apiClient.dio.get('/pdf/templates/$id');
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map');
      }
      return Map<String, dynamic>.from(responseData);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('message')) {
        final message = data['message'];
        if (message is String) {
          return message;
        } else {
          return message?.toString() ?? 'An error occurred';
        }
      }
      return 'An error occurred: ${error.response!.statusCode}';
    }
    return error.message ?? 'Network error occurred';
  }
}

