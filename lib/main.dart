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
    // If .env file doesn't exist, use defaults (this is normal in production)
    debugPrint('⚠️ [MAIN] Could not load .env file: $e');
    debugPrint('   - This is normal in production builds');
    debugPrint('   - Using default BACKEND_BASE_URL from api_client.dart');
  }
  
  // Wrap app in error boundary to catch any initialization errors
  runApp(
    ProviderScope(
      child: ErrorBoundary(
        child: const App(),
      ),
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
      if (mounted) {
        setState(() {
          _errorDetails = details;
        });
      }
      debugPrint('❌ [ERROR_BOUNDARY] Flutter Error: ${details.exception}');
      debugPrint('   Stack: ${details.stack}');
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
