import 'package:image_picker/image_picker.dart';
import '../models/invoice_image.dart';
import '../services/invoice_images_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final invoiceImagesServiceProvider = Provider<InvoiceImagesService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InvoiceImagesService(apiClient);
});

class InvoiceImagesRepo {
  final InvoiceImagesService _service;

  InvoiceImagesRepo(this._service);

  Future<List<InvoiceImage>> getImages(String invoiceId) {
    return _service.getImages(invoiceId);
  }

  Future<InvoiceImage> uploadImage(String invoiceId, XFile imageFile) {
    return _service.uploadImage(invoiceId, imageFile);
  }

  Future<void> deleteImage(String invoiceId, String imageId) {
    return _service.deleteImage(invoiceId, imageId);
  }
}

final invoiceImagesRepoProvider = Provider<InvoiceImagesRepo>((ref) {
  final service = ref.watch(invoiceImagesServiceProvider);
  return InvoiceImagesRepo(service);
});

