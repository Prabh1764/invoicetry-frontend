import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../ui/widgets/billing_card.dart';
import 'reports_screen.dart';

class ReportsSummaryScreen extends ConsumerStatefulWidget {
  const ReportsSummaryScreen({super.key});

  @override
  ConsumerState<ReportsSummaryScreen> createState() => _ReportsSummaryScreenState();
}

class _ReportsSummaryScreenState extends ConsumerState<ReportsSummaryScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day);
    _startDate = DateTime(now.year, now.month - 5, 1);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _exportSummary(BuildContext context, ReportInsights insights) async {
    setState(() => _exporting = true);
    try {
      final currency = NumberFormat.simpleCurrency();
      final dateFormatter = DateFormat('MMM d, yyyy');
      final doc = pw.Document();

      pw.Widget metricCard({
        required String title,
        required String value,
        String? subtitle,
      }) {
        return pw.Container(
          width: 180,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                  letterSpacing: 0.2,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              if (subtitle != null) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ],
          ),
        );
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Revenue Summary',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Period: ${dateFormatter.format(insights.rangeStart)} – ${dateFormatter.format(insights.rangeEnd)}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 18),
                pw.Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    metricCard(
                      title: 'Total collected',
                      value: currency.format(insights.totalCollected),
                      subtitle: '${insights.paidInvoiceCount} invoices paid',
                    ),
                    metricCard(
                      title: 'Outstanding balance',
                      value: currency.format(insights.totalOutstanding),
                      subtitle: insights.outstandingNarrative,
                    ),
                    metricCard(
                      title: 'Average collection time',
                      value: insights.averageCollectionDays != null
                          ? '${insights.averageCollectionDays!.toStringAsFixed(1)} days'
                          : 'Not enough data',
                      subtitle: 'From issued to payment date',
                    ),
                    metricCard(
                      title: 'Estimate pipeline',
                      value: currency.format(insights.estimateValue),
                      subtitle: insights.pipelineNarrative,
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Text(
                  'Monthly revenue',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                if (insights.monthlyRevenue.isEmpty)
                  pw.Text(
                    'No paid invoices recorded for the selected period.',
                    style: pw.TextStyle(color: PdfColors.grey600, fontSize: 11),
                  )
                else
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                    data: [
                      ['Month', 'Collected'],
                      ...insights.monthlyRevenue.map(
                        (row) => [
                          row.label,
                          currency.format(row.amount),
                        ],
                      ),
                    ],
                  ),
                pw.SizedBox(height: 24),
                pw.Text(
                  'Top clients',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                if (insights.topClients.isEmpty)
                  pw.Text(
                    'Bill clients during this period to surface performance insights.',
                    style: pw.TextStyle(color: PdfColors.grey600, fontSize: 11),
                  )
                else
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                    data: [
                      ['Client', 'Collected', 'Outstanding'],
                      ...insights.topClients.map(
                        (client) => [
                          client.name,
                          currency.format(client.collected),
                          currency.format(client.outstanding),
                        ],
                      ),
                    ],
                  ),
                pw.SizedBox(height: 24),
                pw.Text(
                  'Action checklist',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Bullet(
                      text: insights.overdueCount == 0
                          ? 'No overdue invoices remain.'
                          : '${insights.overdueCount} invoice(s) overdue.',
                    ),
                    pw.Bullet(
                      text: insights.estimatesAwaitingAction == 0
                          ? 'All estimates have received responses.'
                          : '${insights.estimatesAwaitingAction} estimate(s) awaiting client action.',
                    ),
                    pw.Bullet(text: insights.recentConversionLabel),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (error, stack) {
      debugPrint('❌ [REPORTS_SUMMARY] Failed to export summary: $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export summary: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(reportInsightsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue summary'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
      ),
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: insightsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _SummaryError(error: error, stack: stack),
          data: (bundle) {
            final summary = bundle.forRange(_startDate, _endDate);
            return _SummaryBody(
              data: summary,
              startDate: _startDate,
              endDate: _endDate,
              exporting: _exporting,
              onPickStart: _pickStartDate,
              onPickEnd: _pickEndDate,
              onExport: () => _exportSummary(context, summary),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.data,
    required this.startDate,
    required this.endDate,
    required this.exporting,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onExport,
  });

  final ReportInsights data;
  final DateTime startDate;
  final DateTime endDate;
  final bool exporting;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BillingCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customize summary range',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pick the start and end dates that best fit the story you want to tell. All figures below update instantly, and the PDF export reflects the same window.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.72),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _DateField(label: 'From', value: startDate, onTap: onPickStart),
                      _DateField(label: 'To', value: endDate, onTap: onPickEnd),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Showing data for ${data.rangeLabel}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Revenue overview',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _SummaryTile(
                  title: 'Total collected',
                  value: currency.format(data.totalCollected),
                  description: '${data.paidInvoiceCount} invoices paid in this range.',
                ),
                _SummaryTile(
                  title: 'Outstanding balance',
                  value: currency.format(data.totalOutstanding),
                  description: data.outstandingNarrative,
                ),
                _SummaryTile(
                  title: 'Average collection time',
                  value: data.averageCollectionDays != null
                      ? '${data.averageCollectionDays!.toStringAsFixed(1)} days'
                      : 'Not enough data',
                  description: 'Measured from issued date to payment date.',
                ),
                _SummaryTile(
                  title: 'Estimate pipeline',
                  value: currency.format(data.estimateValue),
                  description: data.pipelineNarrative,
                ),
              ],
            ),
            const SizedBox(height: 24),
            BillingCard(
              padding: const EdgeInsets.all(20),
              child: _SummaryRevenueTable(data: data),
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
                    const Text('Bill a few clients to see top contributors.')
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
                    'Action checklist',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _ChecklistRow(
                    checked: data.overdueCount == 0,
                    label: data.overdueCount == 0
                        ? 'No overdue invoices remain.'
                        : '${data.overdueCount} invoice(s) are overdue.',
                  ),
                  _ChecklistRow(
                    checked: data.estimatesAwaitingAction == 0,
                    label: data.estimatesAwaitingAction == 0
                        ? 'All estimates have been responded to.'
                        : '${data.estimatesAwaitingAction} estimate(s) await client action.',
                  ),
                  _ChecklistRow(
                    checked: true,
                    label: data.recentConversionLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: exporting ? null : onExport,
              icon: exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(exporting ? 'Generating…' : 'Export summary'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        const Text('Unable to load summary'),
        const SizedBox(height: 8),
        Text('$error', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.title, required this.value, required this.description});

  final String title;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width - 32,
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
              description,
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

class _SummaryRevenueTable extends StatelessWidget {
  const _SummaryRevenueTable({required this.data});

  final ReportInsights data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly revenue',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...data.monthlyRevenue.map(
          (snapshot) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(snapshot.label),
                Text(currency.format(snapshot.amount)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.checked, required this.label});

  final bool checked;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: checked ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.4),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final fieldWidth = math.min(260.0, math.max(200.0, width - 32));
    final formatted = DateFormat('MMM d, yyyy').format(value);

    return SizedBox(
      width: fieldWidth,
      height: 52,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              formatted,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}

