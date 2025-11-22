import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/client.dart';
import '../../data/models/invoice.dart';
import '../../theme/app_theme.dart';
import '../../ui/widgets/billing_card.dart';
import '../home/home_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsBundle = ref.watch(reportInsightsProvider);
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);
    final canPop = navigator.canPop();

    void handleBack() {
      if (canPop) {
        navigator.pop();
      } else {
        context.go('/home');
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: handleBack,
        ),
        title: const Text('Reports'),
      ),
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: insightsBundle.when(
                data: (data) => _ReportsBody(data: data.current),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _ReportsError(error: error, stack: stack),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.data});

  final ReportInsights data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency();

    return ListView(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricTile(
              title: 'Collected',
              value: currency.format(data.totalCollected),
              subtitle: '${data.paidInvoiceCount} invoices paid',
            ),
            _MetricTile(
              title: 'Outstanding',
              value: currency.format(data.totalOutstanding),
              subtitle: data.overdueCount > 0
                  ? '${data.overdueCount} overdue invoices • ${currency.format(data.totalOverdue)} overdue'
                  : 'All caught up',
            ),
            _MetricTile(
              title: 'Average collection time',
              value: data.averageCollectionDays != null
                  ? '${data.averageCollectionDays!.toStringAsFixed(1)} days'
                  : 'Not enough data',
              subtitle: 'From issued to payment',
            ),
            _MetricTile(
              title: 'Estimate pipeline',
              value: currency.format(data.estimateValue),
              subtitle:
                  '${data.estimatesAwaitingAction} awaiting action • ${data.recentConversionLabel}',
            ),
          ],
        ),
        const SizedBox(height: 24),
        BillingCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revenue trend',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (data.monthlyRevenue.isEmpty)
                const Text('No paid invoices yet for the selected window.')
              else ...[
                for (final snapshot in data.monthlyRevenue)
                  _MonthlyRevenueRow(snapshot: snapshot, maxValue: data.monthlyRevenueMax),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        BillingCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top clients',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (data.topClients.isEmpty)
                const Text('Bill a few clients to see who your top performers are.')
              else
                ...data.topClients.map(
                  (client) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 22,
                      child: Text(client.initials),
                    ),
                    title: Text(client.name),
                    subtitle: Text(
                      'Collected ${currency.format(client.collected)} · Outstanding ${currency.format(client.outstanding)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Open client',
                      onPressed: () => context.push('/clients/${client.id}/edit'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BillingCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimate pipeline',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _PipelineTile(
                    title: 'Sent last 90 days',
                    value: data.recentEstimates.toString(),
                    caption: 'Total estimates shared',
                  ),
                  _PipelineTile(
                    title: 'Converted',
                    value: data.recentInvoices.toString(),
                    caption: data.recentConversionLabel,
                  ),
                  _PipelineTile(
                    title: 'Awaiting action',
                    value: data.estimatesAwaitingAction.toString(),
                    caption: 'Follow up to keep momentum',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BillingCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick actions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _ActionRow(
                icon: Icons.schedule_send,
                title: 'Review upcoming due invoices',
                subtitle: 'Keep cashflow healthy by nudging clients before due dates.',
                onTap: () => context.go('/invoices?view=upcoming'),
              ),
              _ActionRow(
                icon: Icons.warning_amber_rounded,
                title: 'Overdue follow up',
                subtitle: data.overdueCount > 0
                    ? '${data.overdueCount} invoice(s) need attention.'
                    : 'No overdue invoices right now. Great work!',
                onTap: () => context.go('/invoices?view=overdue'),
              ),
              _ActionRow(
                icon: Icons.campaign_outlined,
                title: 'Send estimate reminders',
                subtitle:
                    data.estimatesAwaitingAction > 0 ? 'Convert approvals into invoices faster.' : 'All estimates are up to date.',
                onTap: () => context.go('/estimates?view=awaiting'),
              ),
              _ActionRow(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Download a revenue summary',
                subtitle: 'View a printable summary before exporting to PDF.',
                onTap: () => context.push('/reports/summary'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ReportsError extends StatelessWidget {
  const _ReportsError({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.trending_down, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text('Unable to load reports', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('$error', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/home'),
          child: const Text('Back to home'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = math.min(260.0, math.max(200.0, screenWidth - 32));

    return SizedBox(
      width: tileWidth,
      child: BillingCard(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyRevenueRow extends StatelessWidget {
  const _MonthlyRevenueRow({required this.snapshot, required this.maxValue});

  final MonthlyRevenue snapshot;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency();
    final ratio = maxValue == 0 ? 0.0 : snapshot.amount / maxValue;
    final progress = ratio.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(snapshot.label, style: theme.textTheme.bodyMedium),
              Text(currency.format(snapshot.amount), style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 8,
              backgroundColor: theme.colorScheme.onSurface.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineTile extends StatelessWidget {
  const _PipelineTile({
    required this.title,
    required this.value,
    required this.caption,
  });

  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = math.min(260.0, math.max(200.0, screenWidth - 32));

    return SizedBox(
      width: tileWidth,
      child: BillingCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

final reportInsightsProvider = FutureProvider<ReportInsightsBundle>((ref) async {
  final invoiceRepo = ref.watch(invoiceRepoProvider);
  final clientRepo = ref.watch(clientRepoProvider);

  try {
    final invoicesResponse = await invoiceRepo.getAll(
      page: 1,
      pageSize: 200,
      documentType: InvoiceDocumentType.invoice.name.toUpperCase(),
    );
    final estimatesResponse = await invoiceRepo.getAll(
      page: 1,
      pageSize: 200,
      documentType: InvoiceDocumentType.estimate.name.toUpperCase(),
    );

    final invoicesRaw = invoicesResponse['data'];
    final estimatesRaw = estimatesResponse['data'];

    final invoices = invoicesRaw is List
        ? invoicesRaw.whereType<Invoice>().toList()
        : <Invoice>[];
    final estimates = estimatesRaw is List
        ? estimatesRaw.whereType<Invoice>().toList()
        : <Invoice>[];

    final clients = await clientRepo.getAll();
    final clientById = {for (final c in clients) c.id: c};

    final now = DateTime.now();
    final defaultStart = DateTime(now.year, now.month - 5, 1);
    final defaultEnd = DateTime(now.year, now.month, now.day);

    final currentInsights = _buildInsights(
      invoices: invoices,
      estimates: estimates,
      clientById: clientById,
      rangeStart: defaultStart,
      rangeEnd: defaultEnd,
    );

    return ReportInsightsBundle(
      current: currentInsights,
      invoices: invoices,
      estimates: estimates,
      clientById: clientById,
    );
  } catch (error, stack) {
    debugPrint('❌ [REPORTS] Failed to compute insights: $error');
    debugPrintStack(stackTrace: stack);
    rethrow;
  }
});

DateTime _normalizeStart(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _normalizeEnd(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

Iterable<DateTime> _monthSequence(DateTime start, DateTime end) sync* {
  var cursor = DateTime(start.year, start.month, 1);
  final limit = DateTime(end.year, end.month, 1);
  while (!cursor.isAfter(limit)) {
    yield cursor;
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
}

double _invoiceTotal(Invoice invoice) {
  if (invoice.totalCached != null) {
    return invoice.totalCached!;
  }
  final calculated = invoice.calculateTotals();
  return calculated['total'] ?? 0;
}

ReportInsights _buildInsights({
  required List<Invoice> invoices,
  required List<Invoice> estimates,
  required Map<String, Client> clientById,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  var normalizedStart = _normalizeStart(rangeStart);
  var normalizedEnd = _normalizeEnd(rangeEnd);

  if (normalizedEnd.isBefore(normalizedStart)) {
    final tmp = normalizedStart;
    normalizedStart = _normalizeStart(rangeEnd);
    normalizedEnd = _normalizeEnd(tmp);
  }

  bool invoiceInRange(Invoice invoice) {
    final issued = invoice.issuedAt;
    return !issued.isBefore(normalizedStart) && !issued.isAfter(normalizedEnd);
  }

  bool estimateInRange(Invoice invoice) {
    final created = invoice.createdAt;
    return !created.isBefore(normalizedStart) && !created.isAfter(normalizedEnd);
  }

  final invoicesInRange = invoices.where(invoiceInRange).toList();
  final estimatesInRange = estimates.where(estimateInRange).toList();

  final paidInvoices =
      invoicesInRange.where((invoice) => invoice.status == InvoiceStatus.paid).toList();
  final outstandingInvoices = invoicesInRange
      .where((invoice) =>
          invoice.status == InvoiceStatus.pending || invoice.status == InvoiceStatus.draft)
      .toList();
  final overdueInvoices = invoicesInRange
      .where((invoice) => invoice.status == InvoiceStatus.overdue)
      .toList();

  final totalCollected =
      paidInvoices.fold<double>(0, (sum, invoice) => sum + _invoiceTotal(invoice));
  final totalOutstanding =
      outstandingInvoices.fold<double>(0, (sum, invoice) => sum + _invoiceTotal(invoice));
  final totalOverdue =
      overdueInvoices.fold<double>(0, (sum, invoice) => sum + _invoiceTotal(invoice));

  double? averageCollectionDays;
  if (paidInvoices.isNotEmpty) {
    final totalDays = paidInvoices.fold<double>(0, (sum, invoice) {
      final completedAt = invoice.updatedAt ?? invoice.issuedAt;
      final collection = completedAt.difference(invoice.issuedAt).inDays;
      return sum + collection.clamp(0, 365);
    });
    averageCollectionDays = totalDays / paidInvoices.length;
  }

  final months = _monthSequence(normalizedStart, normalizedEnd).toList();
  final monthlyRevenue = months
      .map((month) {
        final nextMonth = DateTime(month.year, month.month + 1, 1);
        final amount = paidInvoices
            .where((invoice) =>
                !invoice.issuedAt.isBefore(month) && invoice.issuedAt.isBefore(nextMonth))
            .fold<double>(0, (sum, invoice) => sum + _invoiceTotal(invoice));
        final label = DateFormat('MMM yyyy').format(month);
        return MonthlyRevenue(label: label, amount: amount);
      })
      .toList();
  final monthlyRevenueMax =
      monthlyRevenue.fold<double>(0, (max, item) => math.max(max, item.amount));

  final groupedClients = <String, ClientPerformance>{};
  for (final invoice in invoicesInRange) {
    final client = clientById[invoice.clientId];
    final clientId = client?.id ?? invoice.clientId;
    final clientName = client?.name ?? invoice.client?.name ?? 'Unknown client';
    if (clientId == null || clientName.isEmpty) continue;
    groupedClients.putIfAbsent(
      clientId,
      () => ClientPerformance(
        id: clientId,
        name: clientName,
        collected: 0,
        outstanding: 0,
      ),
    );
    final performance = groupedClients[clientId]!;
    final total = _invoiceTotal(invoice);
    switch (invoice.status) {
      case InvoiceStatus.paid:
        performance.collected += total;
        break;
      case InvoiceStatus.pending:
      case InvoiceStatus.overdue:
      case InvoiceStatus.draft:
        performance.outstanding += total;
        break;
    }
  }
  final topClients = groupedClients.values.toList()
    ..sort((a, b) => b.collected.compareTo(a.collected));

  final estimatesAwaitingAction = estimatesInRange
      .where((estimate) =>
          estimate.status == InvoiceStatus.pending || estimate.status == InvoiceStatus.draft)
      .length;

  final estimateValue =
      estimatesInRange.fold<double>(0, (sum, estimate) => sum + _invoiceTotal(estimate));

  final windowStart = normalizedEnd.subtract(const Duration(days: 90));
  final rollingStart = windowStart.isBefore(normalizedStart) ? normalizedStart : windowStart;

  final recentEstimates = estimatesInRange
      .where((estimate) => !estimate.createdAt.isBefore(rollingStart))
      .length;
  final recentInvoices = invoicesInRange
      .where((invoice) => !invoice.createdAt.isBefore(rollingStart))
      .length;
  final double? conversionRate =
      recentEstimates == 0 ? null : recentInvoices / recentEstimates;

  return ReportInsights(
    rangeStart: normalizedStart,
    rangeEnd: normalizedEnd,
    totalCollected: totalCollected,
    totalOutstanding: totalOutstanding,
    totalOverdue: totalOverdue,
    outstandingInvoiceCount: outstandingInvoices.length,
    overdueCount: overdueInvoices.length,
    paidInvoiceCount: paidInvoices.length,
    averageCollectionDays: averageCollectionDays,
    monthlyRevenue: monthlyRevenue,
    monthlyRevenueMax: monthlyRevenueMax,
    topClients: topClients.take(5).toList(),
    estimateValue: estimateValue,
    estimatesAwaitingAction: estimatesAwaitingAction,
    recentEstimates: recentEstimates,
    recentInvoices: recentInvoices,
    conversionRate: conversionRate,
  );
}

class ReportInsightsBundle {
  ReportInsightsBundle({
    required this.current,
    required this.invoices,
    required this.estimates,
    required this.clientById,
  });

  final ReportInsights current;
  final List<Invoice> invoices;
  final List<Invoice> estimates;
  final Map<String, Client> clientById;

  ReportInsights forRange(DateTime start, DateTime end) => _buildInsights(
        invoices: invoices,
        estimates: estimates,
        clientById: clientById,
        rangeStart: start,
        rangeEnd: end,
      );
}

class ReportInsights {
  ReportInsights({
    required this.rangeStart,
    required this.rangeEnd,
    required this.totalCollected,
    required this.totalOutstanding,
    required this.totalOverdue,
    required this.outstandingInvoiceCount,
    required this.overdueCount,
    required this.paidInvoiceCount,
    required this.averageCollectionDays,
    required this.monthlyRevenue,
    required this.monthlyRevenueMax,
    required this.topClients,
    required this.estimateValue,
    required this.estimatesAwaitingAction,
    required this.recentEstimates,
    required this.recentInvoices,
    required this.conversionRate,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final double totalCollected;
  final double totalOutstanding;
  final double totalOverdue;
  final int outstandingInvoiceCount;
  final int overdueCount;
  final int paidInvoiceCount;
  final double? averageCollectionDays;
  final List<MonthlyRevenue> monthlyRevenue;
  final double monthlyRevenueMax;
  final List<ClientPerformance> topClients;
  final double estimateValue;
  final int estimatesAwaitingAction;
  final int recentEstimates;
  final int recentInvoices;
  final double? conversionRate;

  String get rangeLabel =>
      '${DateFormat('MMM d, yyyy').format(rangeStart)} – ${DateFormat('MMM d, yyyy').format(rangeEnd)}';

  String get recentConversionLabel {
    if (conversionRate == null) return 'No recent estimates to compare';
    return '${(conversionRate! * 100).clamp(0, 999).toStringAsFixed(1)}% conversion in the last 90 days';
  }

  String get outstandingNarrative {
    if (totalOutstanding <= 0 || outstandingInvoiceCount == 0) {
      return 'All invoices are settled.';
    }
    return '$outstandingInvoiceCount invoice(s) remain unpaid.';
  }

  String get pipelineNarrative {
    if (recentEstimates == 0) {
      return 'Send estimates to fill the pipeline.';
    }
    if (conversionRate == null) {
      return 'Keep nurturing estimates to close more deals.';
    }
    return '${(conversionRate! * 100).clamp(0, 999).toStringAsFixed(0)}% conversion of recent estimates.';
  }
}

class MonthlyRevenue {
  MonthlyRevenue({required this.label, required this.amount});

  final String label;
  final double amount;
}

class ClientPerformance {
  ClientPerformance({
    required this.id,
    required this.name,
    required this.collected,
    required this.outstanding,
  });

  final String id;
  final String name;
  double collected;
  double outstanding;

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first;
      final len = word.length;
      if (len == 1) return word.toUpperCase();
      return (word.substring(0, len >= 2 ? 2 : len)).toUpperCase();
    }
    final first = parts.first;
    final last = parts.last;
    final firstInitial = first.isNotEmpty ? first[0] : '?';
    final lastInitial = last.isNotEmpty ? last[0] : '?';
    return (firstInitial + lastInitial).toUpperCase();
  }
}
