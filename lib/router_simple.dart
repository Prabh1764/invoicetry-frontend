import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
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
import 'data/services/api_client.dart';
import 'dart:convert';

// Simple auth state - just a ValueNotifier, no Riverpod
final _authTokenNotifier = ValueNotifier<AuthToken?>(null);

// Update auth token (called after login/register)
void setAuthToken(AuthToken? token) {
  _authTokenNotifier.value = token;
}

// Check if authenticated by reading token from storage directly
Future<bool> _checkAuthFromStorage() async {
  try {
    final apiClient = ApiClient();
    final tokenString = await apiClient.getToken();
    return tokenString != null && tokenString.isNotEmpty;
  } catch (e) {
    return false;
  }
}

// Simple router - no Riverpod, no providers, just direct checks
GoRouter createSimpleRouter() {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _authTokenNotifier,
    redirect: (context, state) async {
      final currentPath = state.matchedLocation;
      final isAuthPage = currentPath == '/login' || currentPath == '/register';
      
      // Check auth by reading token directly from storage (no providers!)
      final hasToken = await _checkAuthFromStorage();
      
      // If has token and on auth page, go to home
      if (hasToken && isAuthPage) {
        return '/home';
      }
      
      // If no token and not on auth page, go to login
      if (!hasToken && !isAuthPage) {
        return '/login';
      }
      
      // Otherwise, allow navigation
      return null;
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
            final decodedBytes = base64Url.decode(encodedUrl);
            url = utf8.decode(decodedBytes);
          } catch (e) {
            try {
              url = Uri.decodeFull(encodedUrl);
            } catch (e2) {
              url = '';
            }
          }
          return PdfViewerScreen(pdfUrl: url);
        },
      ),
    ],
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
  );
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

class _InvoiceRouteConfig {
  const _InvoiceRouteConfig({
    this.filter,
    this.quickView,
  });

  final InvoiceFilter? filter;
  final InvoiceQuickView? quickView;
}

