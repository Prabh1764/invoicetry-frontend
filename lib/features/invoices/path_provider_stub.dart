// Stub for path_provider on web (limited support)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) 'dart:html' as html;

// Stub for getTemporaryDirectory on web
Future<Directory> getTemporaryDirectory() async {
  if (kIsWeb) {
    throw UnsupportedError('getTemporaryDirectory not available on web');
  }
  // This won't be reached on web, but needed for type checking
  throw UnsupportedError('Not available');
}
