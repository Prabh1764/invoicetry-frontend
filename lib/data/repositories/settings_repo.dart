import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../services/api_client.dart';
import '../models/user_settings.dart';
import '../../features/auth/providers/auth_provider.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.read(apiClientProvider));
});

final settingsProvider = FutureProvider<UserSettings>((ref) async {
  final service = ref.read(settingsServiceProvider);
  return service.getSettings();
});

final settingsRepoProvider = Provider<SettingsRepo>((ref) {
  return SettingsRepo(ref);
});

class SettingsRepo {
  SettingsRepo(this._ref);

  final Ref _ref;

  SettingsService get _service => _ref.read(settingsServiceProvider);

  Future<UserSettings> getSettings() {
    return _service.getSettings();
  }

  Future<UserSettings> updateSettings(Map<String, dynamic> data) {
    return _service.updateSettings(data);
  }

  Future<Map<String, dynamic>> uploadLogo(dynamic imageFile) {
    return _service.uploadLogo(imageFile);
  }

  String? getLogoUrl(String? logoUrl) {
    return _service.getLogoUrl(logoUrl);
  }
}

