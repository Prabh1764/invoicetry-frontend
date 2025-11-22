import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/app_theme.dart';

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
      debugPrint('Error building app: $e');
      debugPrint('Stack: $stack');
      return MaterialApp(
        title: 'ProBilling',
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Error loading app'),
                Text('$e'),
                ElevatedButton(
                  onPressed: () {
                    // Try to rebuild
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

