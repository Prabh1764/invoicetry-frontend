import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../services/google_drive_service.dart';
import '../../features/auth/providers/auth_provider.dart';

final googleDriveRepoProvider = Provider<GoogleDriveRepo>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final service = GoogleDriveService(apiClient);
  return GoogleDriveRepo(service);
});

class GoogleDriveRepo {
  final GoogleDriveService _service;

  GoogleDriveRepo(this._service);

  Future<String> getAuthUrl() => _service.getAuthUrl();

  Future<Map<String, dynamic>> exchangeCode(String code) =>
      _service.exchangeCode(code);

  Future<Map<String, dynamic>> setupFolder({
    required String refreshToken,
    String? folderName,
  }) =>
      _service.setupFolder(
        refreshToken: refreshToken,
        folderName: folderName,
      );

  Future<Map<String, dynamic>> getStatus() => _service.getStatus();

  Future<void> disconnect() => _service.disconnect();
}

