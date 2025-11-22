import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/app_theme.dart';

// Conditional import for web
import 'dart:html' as html show window; // ignore: avoid_web_libraries_in_flutter

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      // Watch router - it will rebuild when auth state changes
      final router = ref.watch(routerProvider);

      return MaterialApp.router(
        title: 'ProBilling',
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      );
    } catch (e, stack) {
      // Fallback if router fails
      debugPrint('❌ [APP] Error building app: $e');
      debugPrint('   - Error type: ${e.runtimeType}');
      debugPrint('   - Error toString: ${e.toString()}');
      debugPrint('   - Stack: $stack');
      
      // Try to extract more details
      String errorMessage = 'Unknown error';
      if (e is Error) {
        errorMessage = e.toString();
      } else if (e is Exception) {
        errorMessage = e.toString();
      } else {
        errorMessage = '$e';
      }
      
      return MaterialApp(
        title: 'ProBilling',
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
                    'App Initialization Error',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  if (kIsWeb)
                    ElevatedButton(
                      onPressed: () {
                        // Reload the page on web
                        // ignore: avoid_web_libraries_in_flutter
                        html.window.location.reload();
                      },
                      child: const Text('Reload Page'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
