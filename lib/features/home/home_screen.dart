import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/client.dart';
import '../../data/models/invoice.dart';
import '../../data/models/job_template.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/client_repo.dart';
import '../../data/repositories/invoice_repo.dart';
import '../../data/repositories/job_template_repo.dart';
import '../../data/repositories/settings_repo.dart' show settingsRepoProvider, SettingsRepo;
import '../../theme/app_theme.dart';
import '../../ui/widgets/billing_card.dart';
import '../../ui/widgets/metric_summary_tile.dart';
import '../../ui/widgets/status_pill.dart';
import '../../ui/widgets/primary_nav_bar.dart';
import '../auth/providers/auth_provider.dart';

final clientRepoProvider = Provider<ClientRepo>((ref) {
  return ClientRepo(ref.watch(apiClientProvider));
});

final invoiceRepoProvider = Provider<InvoiceRepo>((ref) {
  return InvoiceRepo(ref.watch(apiClientProvider));
});

final jobTemplateRepoProvider = Provider<JobTemplateRepo>((ref) {
  return JobTemplateRepo(ref.watch(apiClientProvider));
});

final userSettingsProvider = FutureProvider<UserSettings?>((ref) async {
  final settingsRepo = ref.watch(settingsRepoProvider);
  try {
    return await settingsRepo.getSettings();
  } catch (e) {
    debugPrint('❌ [HOME] Failed to fetch user settings: $e');
    return null;
  }
});

final homeStatsProvider = FutureProvider<Map<String, num>>((ref) async {
  final invoiceRepo = ref.watch(invoiceRepoProvider);
  final clientRepo = ref.watch(clientRepoProvider);
  final jobTemplateRepo = ref.watch(jobTemplateRepoProvider);

  try {
    // Fetch all invoices (both types) - use reasonable page size to avoid timeouts
    // Note: Backend filters by documentType, so we need to fetch both
    debugPrint('📊 [HOME_STATS] Starting to fetch invoices and estimates...');
    final invoicesResult = await invoiceRepo.getAll(
      page: 1,
      pageSize: 200, // Reasonable page size to avoid timeouts
      documentType: 'INVOICE',
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⏱️ [HOME_STATS] Invoices fetch timed out');
        return {'data': <Invoice>[], 'total': 0, 'page': 1, 'pageSize': 200};
      },
    );
    debugPrint('✅ [HOME_STATS] Invoices fetched');
    final estimatesResult = await invoiceRepo.getAll(
      page: 1,
      pageSize: 200,
      documentType: 'ESTIMATE',
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⏱️ [HOME_STATS] Estimates fetch timed out');
        return {'data': <Invoice>[], 'total': 0, 'page': 1, 'pageSize': 200};
      },
    );
    debugPrint('✅ [HOME_STATS] Estimates fetched');
    
    final invoicesData = invoicesResult['data'];
    final estimatesData = estimatesResult['data'];
    
    final invoiceDocuments = invoicesData is List
        ? invoicesData.whereType<Invoice>().toList()
        : <Invoice>[];
    final estimateDocuments = estimatesData is List
        ? estimatesData.whereType<Invoice>().toList()
        : <Invoice>[];
    
    final allDocuments = [...invoiceDocuments, ...estimateDocuments];

    final estimateValue = estimateDocuments.fold<double>(
      0,
      (sum, inv) => sum + (inv.totalCached ?? 0),
    );
    
    // Count unpaid invoices: any invoice that is not paid and not draft
    // (drafts haven't been sent yet, so they don't count as unpaid)
    final unpaidInvoices = invoiceDocuments.where(
      (inv) =>
          inv.status != InvoiceStatus.paid &&
          inv.status != InvoiceStatus.draft,
    ).toList();
    final unpaidCount = unpaidInvoices.length;
    
    // Debug logging to help diagnose issues
    debugPrint('📊 [HOME_STATS] Invoice counts:');
    debugPrint('   - Total invoices: ${invoiceDocuments.length}');
    debugPrint('   - Total estimates: ${estimateDocuments.length}');
    debugPrint('   - Unpaid count: $unpaidCount');
    
    // Log status breakdown
    for (final status in InvoiceStatus.values) {
      final count = invoiceDocuments.where((inv) => inv.status == status).length;
      if (count > 0) {
        debugPrint('   - ${status.name.toUpperCase()}: $count');
      }
    }
    
    // Log individual invoice details for debugging
    if (invoiceDocuments.isNotEmpty) {
      debugPrint('   - Invoice details:');
      for (final inv in invoiceDocuments) {
        debugPrint('     • ${inv.number}: status=${inv.status.name.toUpperCase()}, type=${inv.isInvoice ? "INVOICE" : "ESTIMATE"}');
      }
    } else {
      debugPrint('   ⚠️  No invoices found!');
    }
    
    if (unpaidInvoices.isNotEmpty) {
      debugPrint('   - Unpaid invoices (${unpaidInvoices.length}):');
      for (final inv in unpaidInvoices) {
        debugPrint('     • ${inv.number}: ${inv.status.name.toUpperCase()}');
      }
    } else {
      debugPrint('   ⚠️  No unpaid invoices found - all are PAID or DRAFT');
    }
    
    // Log raw data from backend to see what's actually being returned
    debugPrint('   - Raw invoices data count: ${invoicesData is List ? (invoicesData as List).length : 0}');
    if (invoicesData is List && (invoicesData as List).isNotEmpty) {
      debugPrint('   - Raw invoice statuses from backend:');
      for (final item in (invoicesData as List).take(10)) {
        if (item is Map<String, dynamic>) {
          final rawStatus = item['status'];
          final number = item['number'] ?? 'unknown';
          debugPrint('     • $number: raw_status=$rawStatus (type: ${rawStatus.runtimeType})');
        }
      }
    }

    final clients = await clientRepo.getAll().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⏱️ [HOME_STATS] Clients fetch timed out');
        return <Client>[];
      },
    ).catchError((e, stack) {
      debugPrint('❌ [HOME_STATS] Failed to fetch clients: $e');
      debugPrint('   - Stack: $stack');
      return <Client>[];
    });

    final templates = await jobTemplateRepo.getAll().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⏱️ [HOME_STATS] Templates fetch timed out');
        return <JobTemplate>[];
      },
    ).catchError((e, stack) {
      debugPrint('❌ [HOME_STATS] Failed to fetch templates: $e');
      debugPrint('   - Stack: $stack');
      return <JobTemplate>[];
    });

    return {
      'invoices': invoiceDocuments.length,
      'estimates': estimateDocuments.length,
      'estimateValue': estimateValue,
      'clients': clients.length,
      'templates': templates.length,
      'unpaid': unpaidCount,
    };
  } catch (e, stack) {
    debugPrint('❌ [HOME_STATS] Failed to build dashboard stats: $e');
    debugPrint('   - Stack: $stack');
    return const {
      'invoices': 0,
      'estimates': 0,
      'estimateValue': 0.0,
      'clients': 0,
      'templates': 0,
      'unpaid': 0,
    };
  }
});

final _countFormatter = NumberFormat.compact();
final _currencyFormatter = NumberFormat.simpleCurrency(locale: 'en_CA');

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeStatsProvider);
    final theme = Theme.of(context);
    final spacing = theme.extension<BillingSpacing>();

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(24, 12, 24, spacing?.lg ?? 24),
        child: Builder(
          builder: (context) {
            final currentRoute = GoRouterState.of(context).matchedLocation;
            final isInvoices = currentRoute == '/invoices' || currentRoute.startsWith('/invoices/');
            final isEstimates = currentRoute == '/estimates' || currentRoute.startsWith('/estimates/');
            final isClients = currentRoute == '/clients' || currentRoute.startsWith('/clients/');
            final isReports = currentRoute == '/reports' || currentRoute.startsWith('/reports/');
            
            return PrimaryNavBar(
              destinations: [
                PrimaryNavDestination(
                  icon: Icons.payments_outlined,
                  label: 'Invoices',
                  selected: isInvoices,
                  onTap: () => context.go('/invoices'),
                ),
                PrimaryNavDestination(
                  icon: Icons.description_outlined,
                  label: 'Quotes',
                  selected: isEstimates,
                  onTap: () => context.go('/estimates'),
                ),
                PrimaryNavDestination(
                  icon: Icons.person_outline,
                  label: 'Customers',
                  selected: isClients,
                  onTap: () => context.go('/clients'),
                ),
                PrimaryNavDestination(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  selected: isReports,
                  onTap: () => context.go('/reports'),
                ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(homeStatsProvider);
          },
          child: stats.when(
            data: (data) {
              final theme = Theme.of(context);
              final spacing = theme.extension<BillingSpacing>();
              final logout = () async {
                final authNotifier = ref.read(authStateProvider.notifier);
                await authNotifier.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              };

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, spacing?.xl ?? 32, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: _DashboardHeader(onLogout: logout),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, spacing?.lg ?? 24, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: _MetricSection(data: data),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      spacing?.lg ?? 24,
                      24,
                      spacing?.xl ?? 32,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _QuickActionsCard(
                        onNavigate: (route) => context.push(route),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const _HomeLoadingState(),
            error: (error, stack) => _HomeErrorState(
              message: '$error',
              onRetry: () => ref.invalidate(homeStatsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();
    final spacing = theme.extension<BillingSpacing>();
    final settingsAsync = ref.watch(userSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: spacing?.xs ?? 4),
                  settingsAsync.when(
                    data: (settings) {
                      final companyName = settings?.companyName;
                      if (companyName != null && companyName.isNotEmpty) {
                        return Text(
                          companyName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors?.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            // Right side buttons - stacked vertically
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Sign out Button (smaller)
                OutlinedButton.icon(
                  onPressed: () => onLogout(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    'Sign out',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                SizedBox(height: spacing?.xs ?? 8),
                // Settings Button (larger)
                IconButton(
                  onPressed: () => GoRouter.of(context).push('/settings'),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Business Settings',
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.all(spacing?.sm ?? 12),
                    iconSize: 26,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: spacing?.md ?? 16),
        Text(
          'Monitor invoices, clients, and quick tasks from one place.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.84),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({required this.data});

  final Map<String, num> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<BillingSpacing>();
    final invoicesCount = (data['invoices'] ?? 0).toInt();
    final estimatesCount = (data['estimates'] ?? 0).toInt();
    final clientsCount = (data['clients'] ?? 0).toInt();
    final templatesCount = (data['templates'] ?? 0).toInt();
    final unpaidCount = (data['unpaid'] ?? 0).toInt();
    final estimateValue = (data['estimateValue'] ?? 0).toDouble();

    final metrics = [
      (
        title: 'Active invoices',
        value: _countFormatter.format(invoicesCount),
        subtitle: 'Generated across all clients',
        variant: null,
        route: '/invoices',
      ),
      (
        title: 'Open quotes',
        value: _currencyFormatter.format(estimateValue),
        subtitle:
            '${_countFormatter.format(estimatesCount)} quotes awaiting approval',
        variant: StatusPillVariant.warning,
        route: '/estimates',
      ),
      (
        title: 'Clients',
        value: _countFormatter.format(clientsCount),
        subtitle: 'Relationships you manage',
        variant: null,
        route: '/clients',
      ),
      (
        title: 'Job templates',
        value: _countFormatter.format(templatesCount),
        subtitle: 'Saved descriptions & rates',
        variant: null,
        route: '/jobs',
      ),
      (
        title: 'Unpaid invoices',
        value: _countFormatter.format(unpaidCount),
        subtitle: unpaidCount == 0
            ? 'Great job – everything is collected!'
            : 'Follow up to keep cashflow healthy',
        variant:
            unpaidCount == 0 ? StatusPillVariant.success : StatusPillVariant.danger,
        route: '/invoices',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final tileWidth = isCompact
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing?.md ?? 16)) / 2;

        return Wrap(
          spacing: spacing?.md ?? 16,
          runSpacing: spacing?.md ?? 16,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: tileWidth,
                  child: MetricSummaryTile(
                    title: metric.title,
                    value: metric.value,
                    subtitle: metric.subtitle,
                    statusVariant: metric.variant,
                    onTap: () => GoRouter.of(context).push(metric.route),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();
    final spacing = theme.extension<BillingSpacing>();

    final actions = [
      _QuickActionItem(
        icon: Icons.receipt_long_outlined,
        label: 'New invoice',
        route: '/invoices/new',
      ),
      _QuickActionItem(
        icon: Icons.request_quote_outlined,
        label: 'New estimate',
        route: '/estimates/new',
      ),
      _QuickActionItem(
        icon: Icons.person_add_alt_1_outlined,
        label: 'Add client',
        route: '/clients/new',
      ),
      _QuickActionItem(
        icon: Icons.file_present_outlined,
        label: 'New template',
        route: '/jobs/new',
      ),
      _QuickActionItem(
        icon: Icons.download_outlined,
        label: 'Export data',
        route: '/invoices',
      ),
    ];

    return BillingCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.9),
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: spacing?.md ?? 16),
          Wrap(
            spacing: spacing?.sm ?? 12,
            runSpacing: spacing?.sm ?? 12,
            children: actions
                .map(
                  (action) => ActionChip(
                    avatar: Icon(action.icon, size: 18),
                    label: Text(
                      action.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.88),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => onNavigate(action.route),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'We couldn\'t load your dashboard',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.78),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}
