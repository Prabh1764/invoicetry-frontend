// Stub for path_provider on web (limited support)
import 'package:flutter/foundation.dart' show kIsWeb;

// Stub for getTemporaryDirectory on web
// Note: Directory is not available on web, so we use dynamic
Future<dynamic> getTemporaryDirectory() async {
  if (kIsWeb) {
    throw UnsupportedError('getTemporaryDirectory not available on web');
  }
  // This won't be reached on web, but needed for type checking
  throw UnsupportedError('Not available');
}
