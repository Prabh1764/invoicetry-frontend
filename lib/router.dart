import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/home/home_screen.dart';
import 'features/invoices/invoice_list_screen.dart';
import 'features/invoices/invoice_details_screen.dart';
import 'features/invoices/edit_invoice_screen.dart';
import 'features/clients/clients_list_screen.dart';
import 'features/clients/edit_client_screen.dart';
import 'features/jobs/job_templates_list_screen.dart';
import 'features/jobs/edit_job_template_screen.dart';
import 'features/pdf/pdf_viewer_screen.dart';
import 'features/pdf/customize_pdf_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/reports/reports_summary_screen.dart';
import 'features/settings/settings_screen.dart';
import '../data/models/auth_token.dart';
import 'data/models/invoice.dart';

class _InvoiceRouteConfig {
  const _InvoiceRouteConfig({
    this.filter,
    this.quickView,
  });

  final InvoiceFilter? filter;
  final InvoiceQuickView? quickView;
}

_InvoiceRouteConfig _invoiceRouteConfig(
  String? view,
  InvoiceDocumentType type,
) {
  switch (view) {
    case 'upcoming':
      return const _InvoiceRouteConfig(
        filter: InvoiceFilter.unpaid,
        quickView: InvoiceQuickView.upcoming,
      );
    case 'overdue':
      return const _InvoiceRouteConfig(
        filter: InvoiceFilter.unpaid,
        quickView: InvoiceQuickView.overdue,
      );
    case 'awaiting':
      if (type == InvoiceDocumentType.estimate) {
        return const _InvoiceRouteConfig(
          quickView: InvoiceQuickView.awaitingAction,
        );
      }
      break;
  }
  return const _InvoiceRouteConfig();
}

// Create a global notifier that can be updated from anywhere
final _globalAuthNotifier = ValueNotifier<AuthToken?>(null);

// Export a function to update the auth notifier from anywhere
void updateGlobalAuthNotifier(AuthToken? token) {
  if (_globalAuthNotifier.value != token) {
    debugPrint('🔧 [ROUTER] Directly updating global auth notifier');
    _globalAuthNotifier.value = token;
    // ValueNotifier automatically notifies listeners when value changes
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  try {
    debugPrint('🔧 [ROUTER] Creating router provider...');
    
    // Try to listen to auth state changes (wrap in try-catch to handle errors)
    // Use a delayed approach to avoid initialization errors
    try {
      // Schedule listener registration after a microtask to avoid initialization issues
      Future.microtask(() {
        try {
          ref.listen<AsyncValue<AuthToken?>>(authStateProvider, (previous, next) {
            try {
              debugPrint('👂 [ROUTER] Auth state changed!');
              final prevToken = previous?.valueOrNull;
              final nextToken = next.valueOrNull;
              debugPrint('   - Previous: ${prevToken != null ? "had token" : "no token"}');
              debugPrint('   - Next: ${nextToken != null ? "has token" : "no token"}');
              
              next.when(
                data: (token) {
                  try {
                    debugPrint('   → Auth state is data, token: ${token != null ? "EXISTS" : "NULL"}');
                    if (token != null) {
                      debugPrint('   → Token accessToken length: ${token.accessToken.length}');
                    }
                    if (_globalAuthNotifier.value != token) {
                      debugPrint('   → Updating global notifier with token');
                      _globalAuthNotifier.value = token;
                      debugPrint('   → Updated notifier value: ${_globalAuthNotifier.value != null ? "SET" : "NULL"}');
                    } else {
                      debugPrint('   → Token unchanged, skipping update');
                    }
                  } catch (e, stack) {
                    debugPrint('❌ [ROUTER] Error in auth state data handler: $e');
                    debugPrint('   - Stack: $stack');
                  }
                },
                loading: () {
                  debugPrint('   → Auth state loading, keeping current value');
                },
                error: (error, stack) {
                  debugPrint('   → Auth state error: $error');
                  debugPrint('   → Setting global notifier to null');
                  try {
                    _globalAuthNotifier.value = null;
                  } catch (e) {
                    debugPrint('❌ [ROUTER] Error setting notifier to null: $e');
                  }
                },
              );
            } catch (e, stack) {
              debugPrint('❌ [ROUTER] Error in auth state listener: $e');
              debugPrint('   - Stack: $stack');
            }
          }); // Close ref.listen callback
          debugPrint('✅ [ROUTER] Auth state listener registered (delayed)');
        } catch (e, stack) {
          debugPrint('❌ [ROUTER] Failed to register auth state listener (delayed): $e');
          debugPrint('   - Error type: ${e.runtimeType}');
          debugPrint('   - Stack: $stack');
        }
      }); // Close Future.microtask callback
    } catch (e, stack) {
      debugPrint('❌ [ROUTER] Failed to schedule auth state listener: $e');
      debugPrint('   - Error type: ${e.runtimeType}');
      debugPrint('   - Stack: $stack');
      // Continue anyway - router will work without listener
    }
  
    // Initialize with current state (safely) - use read instead of watch to avoid errors
    // Don't watch during router creation - let the listener handle updates
    try {
      debugPrint('🔧 [ROUTER] Reading authStateProvider (non-reactive)...');
      // Use read instead of watch to avoid reactive dependencies during initialization
      // This prevents the minified:WR error
      final currentAuthState = ref.read(authStateProvider);
      debugPrint('✅ [ROUTER] Successfully read authStateProvider');
      
      currentAuthState.when(
        data: (token) {
          try {
            if (_globalAuthNotifier.value != token) {
              debugPrint('🔧 [ROUTER] Initializing global notifier: ${token != null ? "with token" : "null"}');
              _globalAuthNotifier.value = token;
            }
          } catch (e, stack) {
            debugPrint('❌ [ROUTER] Error in auth state data handler during init: $e');
            debugPrint('   - Stack: $stack');
          }
        },
        loading: () {
          debugPrint('🔧 [ROUTER] Auth state loading during init, keeping current value');
        },
        error: (error, stack) {
          debugPrint('🔧 [ROUTER] Auth state error during init: $error');
          debugPrint('   - Stack: $stack');
          try {
            _globalAuthNotifier.value = null;
          } catch (e) {
            debugPrint('❌ [ROUTER] Error setting notifier to null during init: $e');
          }
        },
      );
    } catch (e, stack) {
      debugPrint('❌ [ROUTER] Error reading authStateProvider: $e');
      debugPrint('   - Error type: ${e.runtimeType}');
      debugPrint('   - Stack: $stack');
      // Continue anyway - router will work without initial auth state
      // The listener will update it when auth state is ready
      debugPrint('⚠️ [ROUTER] Continuing without initial auth state - listener will update when ready');
    }

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    refreshListenable: _globalAuthNotifier,
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${state.error ?? "Unknown error"}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    ),
    redirect: (context, state) {
      try {
        // Read the latest auth state from the notifier
        final token = _globalAuthNotifier.value;
        final isAuthenticated = token != null && token.accessToken.isNotEmpty;
        final currentPath = state.matchedLocation;
        final isGoingToAuth = currentPath == '/login' || currentPath == '/register';

        debugPrint('🔄 [ROUTER] Redirect check:');
        debugPrint('   - Current path: $currentPath');
        debugPrint('   - Token exists: ${token != null}');
        debugPrint('   - Token valid: ${token != null && token.accessToken.isNotEmpty}');
        debugPrint('   - Is authenticated: $isAuthenticated');
        debugPrint('   - Is going to auth: $isGoingToAuth');

        // IMPORTANT: Check authenticated users on auth pages FIRST
        // This must come before the unauthenticated check to prevent redirect loops
        if (isAuthenticated && isGoingToAuth) {
          debugPrint('   → Redirecting to /home (authenticated user on auth page)');
          // Use a small delay to ensure state is fully updated
          Future.microtask(() {
            debugPrint('   → Executing redirect to /home');
          });
          return '/home';
        }
        
        // If not authenticated and trying to access protected route
        if (!isAuthenticated && !isGoingToAuth) {
          debugPrint('   → Redirecting to /login (not authenticated)');
          return '/login';
        }
        
        debugPrint('   → No redirect needed');
        return null; // No redirect needed
      } catch (e, stack) {
        debugPrint('❌ [ROUTER] Redirect error: $e');
        debugPrint('   - Stack: $stack');
        return '/login';
      }
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/invoices',
        builder: (context, state) {
          final config = _invoiceRouteConfig(
            state.uri.queryParameters['view'],
            InvoiceDocumentType.invoice,
          );
          return InvoiceListScreen(
            documentType: InvoiceDocumentType.invoice,
            initialFilter: config.filter,
            quickView: config.quickView,
          );
        },
      ),
      GoRoute(
        path: '/invoices/new',
        builder: (context, state) => const EditInvoiceScreen(invoiceId: 'new'),
      ),
      GoRoute(
        path: '/invoices/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InvoiceDetailsScreen(invoiceId: id);
        },
      ),
      GoRoute(
        path: '/invoices/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditInvoiceScreen(invoiceId: id);
        },
      ),
      GoRoute(
        path: '/estimates',
        builder: (context, state) {
          final config = _invoiceRouteConfig(
            state.uri.queryParameters['view'],
            InvoiceDocumentType.estimate,
          );
          return InvoiceListScreen(
            documentType: InvoiceDocumentType.estimate,
            initialFilter: config.filter,
            quickView: config.quickView,
          );
        },
      ),
      GoRoute(
        path: '/estimates/new',
        builder: (context, state) => const EditInvoiceScreen(
          invoiceId: 'new',
          documentType: InvoiceDocumentType.estimate,
        ),
      ),
      GoRoute(
        path: '/estimates/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InvoiceDetailsScreen(invoiceId: id);
        },
      ),
      GoRoute(
        path: '/estimates/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditInvoiceScreen(
            invoiceId: id,
            documentType: InvoiceDocumentType.estimate,
          );
        },
      ),
      GoRoute(
        path: '/invoices/:id/customize',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CustomizePdfScreen(invoiceId: id);
        },
      ),
      GoRoute(
        path: '/clients',
        builder: (context, state) => const ClientsListScreen(),
      ),
      GoRoute(
        path: '/clients/new',
        builder: (context, state) => const EditClientScreen(),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditClientScreen(clientId: id);
        },
      ),
      GoRoute(
        path: '/jobs',
        builder: (context, state) => const JobTemplatesListScreen(),
      ),
      GoRoute(
        path: '/jobs/new',
        builder: (context, state) => const EditJobTemplateScreen(),
      ),
      GoRoute(
        path: '/jobs/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditJobTemplateScreen(templateId: id);
        },
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/reports/summary',
        builder: (context, state) => const ReportsSummaryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/pdf/:encodedUrl',
        builder: (context, state) {
          final encodedUrl = state.pathParameters['encodedUrl'] ?? '';
          String url;
          try {
            // Decode from base64
            final decodedBytes = base64Url.decode(encodedUrl);
            url = utf8.decode(decodedBytes);
            debugPrint('🔗 [ROUTER] PDF viewer URL decoded: $url');
          } catch (e) {
            debugPrint('❌ [ROUTER] Failed to decode URL: $e');
            // Fallback: try direct decoding
            try {
              url = Uri.decodeFull(encodedUrl);
            } catch (e2) {
              debugPrint('❌ [ROUTER] Fallback decode also failed: $e2');
              url = '';
            }
          }
          if (url.isEmpty) {
            debugPrint('⚠️ [ROUTER] PDF URL is empty!');
          }
          return PdfViewerScreen(pdfUrl: url);
        },
      ),
    ],
  );
  } catch (e, stack) {
    debugPrint('❌ [ROUTER] Error creating router: $e');
    debugPrint('   - Error type: ${e.runtimeType}');
    debugPrint('   - Stack: $stack');
    
    // Return a minimal router as fallback
    return GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: Text('Router initialization error. Please reload.'),
            ),
          ),
        ),
      ],
    );
  }
});

