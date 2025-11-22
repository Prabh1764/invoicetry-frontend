import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../models/invoice_image.dart';
import 'api_client.dart';

class InvoiceImagesService {
  final Dio _dio;

  InvoiceImagesService(ApiClient apiClient) : _dio = apiClient.dio;

  Future<List<InvoiceImage>> getImages(String invoiceId) async {
    try {
      final response = await _dio.get('/invoices/$invoiceId/images');
      if (response.data is List) {
        return (response.data as List<dynamic>)
            .map((json) => InvoiceImage.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch images: ${e.message}');
    }
  }

  Future<InvoiceImage> uploadImage(String invoiceId, XFile imageFile) async {
    try {
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
        'image': file,
      });

      final response = await _dio.post(
        '/invoices/$invoiceId/images',
        data: formData,
      );

      return InvoiceImage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to upload image: ${e.message}');
    }
  }

  Future<void> deleteImage(String invoiceId, String imageId) async {
    try {
      await _dio.delete('/invoices/$invoiceId/images/$imageId');
    } on DioException catch (e) {
      throw Exception('Failed to delete image: ${e.message}');
    }
  }
}

