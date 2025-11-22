import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Handle errors gracefully, especially font loading errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // Suppress font loading errors - they're not critical
    if (details.exception.toString().contains('google_fonts') ||
        details.exception.toString().contains('fonts.gstatic.com')) {
      // Just log, don't crash
      debugPrint('Font loading error (non-critical): ${details.exception}');
      return;
    }
    // Log other errors but don't crash
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };
  
  // Handle async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error.toString().contains('google_fonts') ||
        error.toString().contains('fonts.gstatic.com')) {
      debugPrint('Font loading error (non-critical): $error');
      return true; // Error handled
    }
    debugPrint('Async Error: $error');
    return true; // Prevent crashes
  };
  
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ [MAIN] .env file loaded successfully');
    debugPrint('   - BACKEND_BASE_URL: ${dotenv.env['BACKEND_BASE_URL'] ?? 'NOT SET'}');
  } catch (e) {
    // If .env file doesn't exist, use defaults
    debugPrint('⚠️ [MAIN] Could not load .env file: $e');
    debugPrint('   - Using default BACKEND_BASE_URL: http://localhost:3000');
  }
  
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
