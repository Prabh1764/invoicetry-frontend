import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  
  // Don't try to load .env in production - it's not included in assets
  // The api_client.dart will use the correct backend URL automatically
  if (kDebugMode) {
    // Only try to load .env in debug mode (local development)
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('✅ [MAIN] .env file loaded successfully');
      debugPrint('   - BACKEND_BASE_URL: ${dotenv.env['BACKEND_BASE_URL'] ?? 'NOT SET'}');
    } catch (e) {
      // If .env file doesn't exist, use defaults
      debugPrint('⚠️ [MAIN] Could not load .env file: $e');
      debugPrint('   - Using default BACKEND_BASE_URL from api_client.dart');
    }
  } else {
    // Production mode - .env is not available, use defaults from api_client.dart
    debugPrint('✅ [MAIN] Production mode - using default backend URL from api_client.dart');
  }
  
  // NO RIVERPOD - Wrap app directly in error boundary
  runApp(
    ErrorBoundary(
      child: const App(),
    ),
  );
}

// Error boundary widget to catch and display errors gracefully
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  
  const ErrorBoundary({super.key, required this.child});
  
  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;
  
  @override
  void initState() {
    super.initState();
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      // Try to extract more details from the error
      debugPrint('❌ [ERROR_BOUNDARY] Flutter Error: ${details.exception}');
      debugPrint('   - Error type: ${details.exception.runtimeType}');
      debugPrint('   - Error toString: ${details.exception.toString()}');
      debugPrint('   - Library: ${details.library}');
      debugPrint('   - Information: ${details.informationCollector?.call()}');
      debugPrint('   - Stack: ${details.stack}');
      
      // Only update state if mounted and error is not a font loading error
      if (mounted && 
          !details.exception.toString().contains('google_fonts') &&
          !details.exception.toString().contains('fonts.gstatic.com')) {
        setState(() {
          _errorDetails = details;
        });
      }
    };
  }
  
  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'App Error',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorDetails!.exception.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorDetails = null;
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return widget.child;
  }
}
