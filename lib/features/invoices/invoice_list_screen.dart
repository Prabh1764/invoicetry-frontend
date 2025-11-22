import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/invoice.dart';
import '../home/home_screen.dart';
import '../../theme/app_theme.dart';
import '../../ui/widgets/billing_card.dart';
import '../../ui/widgets/metric_summary_tile.dart';
import '../../ui/widgets/status_pill.dart';

// Use a simpler approach - create provider with auto-dispose
final invoiceListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, InvoiceListParams>((ref, params) async {
      final repo = ref.watch(invoiceRepoProvider);
      final result = await repo.getAll(
        page: params.page,
        pageSize: params.pageSize,
        search: params.search,
        documentType: params.documentType.name.toUpperCase(),
      );
      return result;
    });

// Simple parameter class for the provider
class InvoiceListParams {
  final int page;
  final int pageSize;
  final String? status;
  final String? search;
  final InvoiceDocumentType documentType;

  InvoiceListParams({
    this.page = 1,
    this.pageSize = 20,
    this.status,
    this.search,
    this.documentType = InvoiceDocumentType.invoice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceListParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          pageSize == other.pageSize &&
          status == other.status &&
          search == other.search &&
          documentType == other.documentType;

  @override
  int get hashCode => Object.hash(page, pageSize, status, search, documentType);
}

enum InvoiceFilter { all, unpaid, paid }

enum InvoiceQuickView { upcoming, overdue, awaitingAction }

class _HeaderMetric {
  const _HeaderMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    this.variant,
  });

  final String title;
  final String value;
  final String subtitle;
  final StatusPillVariant? variant;
}

final _currencyFormatter = NumberFormat.simpleCurrency(locale: 'en_CA');
final _dateFormatter = DateFormat('MMM d, yyyy');
final _countFormatter = NumberFormat.compact();

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({
    super.key,
    this.documentType = InvoiceDocumentType.invoice,
    this.initialFilter,
    this.quickView,
  });

  final InvoiceDocumentType documentType;
  final InvoiceFilter? initialFilter;
  final InvoiceQuickView? quickView;

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  final _searchController = TextEditingController();
  int _page = 1;
  late InvoiceFilter _filter;
  InvoiceQuickView? _quickView;
  String? _convertingId;

  bool get _isEstimate =>
      widget.documentType == InvoiceDocumentType.estimate;
  String get _documentLabelSingular =>
      _isEstimate ? 'Quote' : 'Invoice';
  String get _documentLabelPlural =>
      _isEstimate ? 'Quotes' : 'Invoices';
  String get _documentLabelLower =>
      _isEstimate ? 'quote' : 'invoice';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? InvoiceFilter.all;
    _quickView = _normalizeQuickView(widget.quickView);
  }

  @override
  void didUpdateWidget(covariant InvoiceListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldUpdate = false;
    var nextFilter = _filter;
    if (widget.initialFilter != null &&
        widget.initialFilter != oldWidget.initialFilter &&
        widget.initialFilter != _filter) {
      nextFilter = widget.initialFilter!;
      shouldUpdate = true;
    }
    final nextQuickView = _normalizeQuickView(widget.quickView);
    if (nextQuickView != _quickView ||
        widget.quickView != oldWidget.quickView) {
      _quickView = nextQuickView;
      shouldUpdate = true;
    }
    if (shouldUpdate) {
      setState(() {
        _filter = nextFilter;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  InvoiceQuickView? _normalizeQuickView(InvoiceQuickView? input) {
    if (input == null) return null;
    if (input == InvoiceQuickView.awaitingAction && !_isEstimate) {
      return null;
    }
    return input;
  }

  void _clearQuickView({bool refreshRoute = true}) {
    if (_quickView == null) return;
    setState(() {
      _quickView = null;
    });
    if (refreshRoute) {
      final baseRoute = _isEstimate ? '/estimates' : '/invoices';
      if (mounted) {
        context.go(baseRoute);
      }
    }
  }

  Future<void> _convertEstimate(Invoice estimate) async {
    if (_convertingId != null) return;
    setState(() {
      _convertingId = estimate.id;
    });
    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(invoiceRepoProvider);
      final converted = await repo.convertEstimateToInvoice(estimate.id);
      ref.invalidate(invoiceListProvider);
      ref.invalidate(homeStatsProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Quote converted to invoice ${converted.number}',
          ),
          action: SnackBarAction(
            label: 'View invoice',
            onPressed: () {
              if (mounted) {
                context.push('/invoices/${converted.id}');
              }
            },
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not convert quote: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _convertingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = InvoiceListParams(
      page: _page,
      pageSize: 20,
      search: _searchController.text.isEmpty ? null : _searchController.text,
      documentType: widget.documentType,
    );
    final invoices = ref.watch(invoiceListProvider(params));

    final theme = Theme.of(context);
    final spacing = theme.extension<BillingSpacing>();
    final createRoute = _isEstimate ? '/estimates/new' : '/invoices/new';
    final createLabel = 'Create ${_documentLabelLower}';
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
        title: Text(_documentLabelPlural),
      ),
      backgroundColor: theme.colorScheme.background,
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(24, 12, 24, spacing?.lg ?? 24),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.push(createRoute),
            child: Text(
              createLabel[0].toUpperCase() + createLabel.substring(1),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: invoices.when(
          data: (data) {
            final rawData = data['data'];
            final invoicesList = _parseInvoices(rawData);
            final baseList = invoicesList
                .where(
                  (inv) => _isEstimate ? inv.isEstimate : inv.isInvoice,
                )
                .toList();
            final filteredInvoices = _applyFilters(baseList);
            List<Invoice> visibleInvoices = filteredInvoices;
            String? quickViewTitle;
            String? quickViewDescription;
            String? quickViewEmptyMessage;

            if (_quickView != null) {
              switch (_quickView!) {
                case InvoiceQuickView.upcoming:
                  final now = DateTime.now();
                  final upcomingThreshold =
                      now.add(const Duration(days: 7));
                  visibleInvoices = filteredInvoices.where((inv) {
                    final dueAt = inv.dueAt;
                    if (dueAt == null) return false;
                    if (inv.status != InvoiceStatus.pending &&
                        inv.status != InvoiceStatus.draft) {
                      return false;
                    }
                    return !dueAt.isBefore(now) &&
                        !dueAt.isAfter(upcomingThreshold);
                  }).toList();
                  quickViewTitle = 'Due soon';
                  quickViewDescription =
                      'Invoices due within the next 7 days.';
                  quickViewEmptyMessage =
                      'No invoices are due in the next 7 days.';
                  break;
                case InvoiceQuickView.overdue:
                  visibleInvoices = filteredInvoices
                      .where((inv) => inv.status == InvoiceStatus.overdue)
                      .toList();
                  quickViewTitle = 'Overdue invoices';
                  quickViewDescription =
                      'Follow up on invoices that are past their due date.';
                  quickViewEmptyMessage =
                      'No overdue invoices remaining. Great work!';
                  break;
                case InvoiceQuickView.awaitingAction:
                  if (_isEstimate) {
                    visibleInvoices = filteredInvoices
                        .where(
                          (inv) =>
                              inv.status == InvoiceStatus.pending ||
                              inv.status == InvoiceStatus.draft,
                        )
                        .toList();
                    quickViewTitle = 'Awaiting client response';
                    quickViewDescription =
                        'Quotes waiting on client approval or sign-off.';
                    quickViewEmptyMessage =
                        'All quotes have been responded to.';
                  }
                  break;
              }
            }
            final totalAmount = baseList.fold<double>(
              0,
              (sum, inv) => sum + (inv.totalCached ?? 0),
            );
            final receivedAmount = baseList
                .where((inv) => inv.status == InvoiceStatus.paid)
                .fold<double>(0, (sum, inv) => sum + (inv.totalCached ?? 0));
            final now = DateTime.now();
            final expiringSoonCount = _isEstimate
                ? baseList.where((inv) {
                    final diff = inv.dueAt.difference(now).inDays;
                    return diff >= 0 && diff <= 7;
                  }).length
                : 0;

            final headerMetrics = _isEstimate
                ? [
                    _HeaderMetric(
                      title: 'Total quoted',
                      value: _currencyFormatter.format(totalAmount),
                      subtitle:
                          'Potential revenue awaiting approval or signature',
                      variant: StatusPillVariant.neutral,
                    ),
                    _HeaderMetric(
                      title: 'Quotes created',
                      value: _countFormatter.format(baseList.length),
                      subtitle: 'Quotes ready to send or awaiting response',
                      variant: StatusPillVariant.neutral,
                    ),
                  ]
                : [
                    _HeaderMetric(
                      title: 'Total billed',
                      value: _currencyFormatter.format(totalAmount),
                      subtitle: 'Gross invoices generated this period',
                      variant: StatusPillVariant.neutral,
                    ),
                    _HeaderMetric(
                      title: 'Received',
                      value: _currencyFormatter.format(receivedAmount),
                      subtitle: 'Payments collected so far',
                      variant: StatusPillVariant.success,
                    ),
                  ];

            final headerSubtitle = _isEstimate
                ? 'Draft, send, and convert polished quotes into paid work.'
                : 'Keep track of every invoice and stay on top of payments.';
            final searchHint = _isEstimate
                ? 'Search by client, quote number or notes'
                : 'Search by client, invoice number or notes';
            final detailRouteBase =
                _isEstimate ? '/estimates' : '/invoices';

            if (baseList.isEmpty) {
              return _EmptyState(
                icon: _isEstimate
                    ? Icons.request_quote_outlined
                    : Icons.receipt_long_outlined,
                headline: 'No ${_documentLabelLower}s yet',
                description: _isEstimate
                    ? 'Create your first quote to show clients exactly what they can expect.'
                    : 'Create your first invoice to start tracking payments and keeping customers up to date.',
                actionLabel: 'Create ${_documentLabelLower}',
                onAction: () => context.push(createRoute),
              );
            }

            return RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: () async {
                ref.invalidate(invoiceListProvider(params));
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    sliver: SliverToBoxAdapter(
                      child: _HeaderSection(
                        title: _documentLabelPlural,
                        metrics: headerMetrics,
                        searchController: _searchController,
                        onSearchChanged: (value) {
                          setState(() {});
                        },
                        subtitle: headerSubtitle,
                        searchHint: searchHint,
                      ),
                    ),
                  ),
                  if (_isEstimate)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                      sliver: SliverToBoxAdapter(
                        child: _EstimateConversionBanner(
                          expiringSoon: expiringSoonCount,
                          onViewInvoices: () => context.go('/invoices'),
                          onCreateInvoice: () => context.push('/invoices/new'),
                        ),
                      ),
                    ),
                  if (!_isEstimate)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverToBoxAdapter(
                        child: _FilterBar(
                          filter: _filter,
                          onFilterChanged: (value) {
                            final hadQuickView = _quickView != null;
                            setState(() {
                              _filter = value;
                              if (hadQuickView) {
                                _quickView = null;
                              }
                            });
                            if (hadQuickView) {
                              final baseRoute =
                                  _isEstimate ? '/estimates' : '/invoices';
                              if (mounted) {
                                context.go(baseRoute);
                              }
                            }
                          },
                          totalCount: baseList.length,
                          filteredCount: visibleInvoices.length,
                          totalAmount: totalAmount,
                          receivedAmount: receivedAmount,
                        ),
                      ),
                    ),
                  if (quickViewTitle != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      sliver: SliverToBoxAdapter(
                        child: BillingCard(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.filter_alt_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quickViewTitle!,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (quickViewDescription != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        quickViewDescription,
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.72),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _clearQuickView(),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (visibleInvoices.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _FilteredEmptyState(
                        documentLabelPlural:
                            _documentLabelPlural.toLowerCase(),
                        message: quickViewEmptyMessage,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 140, top: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final invoice = visibleInvoices[index];
                          final bottomPadding =
                              index == visibleInvoices.length - 1 ? 0.0 : 12.0;
                          return Padding(
                            padding: EdgeInsets.only(bottom: bottomPadding),
                            child: _InvoiceTile(
                              invoice: invoice,
                              onTap: () =>
                                  context.push('$detailRouteBase/${invoice.id}'),
                              documentLabel: _documentLabelSingular,
                              isConverting: _convertingId == invoice.id,
                              onConvert:
                                  _isEstimate ? () => _convertEstimate(invoice) : null,
                            ),
                          );
                        }, childCount: visibleInvoices.length),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const _LoadingState(),
          error: (error, stack) => _ErrorState(
            message: '$error',
            documentLabelPlural: _documentLabelPlural,
            onRetry: () => ref.invalidate(invoiceListProvider(params)),
          ),
        ),
      ),
    );
  }

  List<Invoice> _parseInvoices(dynamic raw) {
    final invoices = <Invoice>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Invoice) {
          invoices.add(item);
        } else if (item is Map<String, dynamic>) {
          try {
            invoices.add(Invoice.fromJson(item));
          } catch (_) {
            // Ignore malformed entries
          }
        }
      }
    }
    return invoices;
  }

  List<Invoice> _applyFilters(List<Invoice> invoices) {
    Iterable<Invoice> filtered = invoices;

    if (!_isEstimate) {
      switch (_filter) {
        case InvoiceFilter.all:
          break;
        case InvoiceFilter.unpaid:
          filtered = filtered.where(
            (inv) =>
                inv.status == InvoiceStatus.pending ||
                inv.status == InvoiceStatus.overdue,
          );
          break;
        case InvoiceFilter.paid:
          filtered = filtered.where((inv) => inv.status == InvoiceStatus.paid);
          break;
      }
    }

    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      filtered = filtered.where((invoice) {
        final clientName = invoice.client?.name?.toLowerCase() ?? '';
        final number = invoice.number.toLowerCase();
        return clientName.contains(search) || number.contains(search);
      });
    }

    return filtered.toList();
  }
}

class _HeaderSection extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String title;
  final String subtitle;
  final List<_HeaderMetric> metrics;
  final String searchHint;

  const _HeaderSection({
    required this.searchController,
    required this.onSearchChanged,
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.searchHint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();
    final spacing = theme.extension<BillingSpacing>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors?.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.9),
          ),
        ),
        SizedBox(height: spacing?.lg ?? 24),
        if (metrics.isNotEmpty) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 720;
              final tileWidth = isCompact
                  ? double.infinity
                  : constraints.maxWidth * 0.45;
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
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          SizedBox(height: spacing?.lg ?? 24),
        ],
        BillingCard(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search & filter',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: searchHint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EstimateConversionBanner extends StatelessWidget {
  const _EstimateConversionBanner({
    required this.expiringSoon,
    required this.onViewInvoices,
    required this.onCreateInvoice,
  });

  final int expiringSoon;
  final VoidCallback onViewInvoices;
  final VoidCallback onCreateInvoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();
    final statusVariant = expiringSoon > 0
        ? StatusPillVariant.warning
        : StatusPillVariant.success;
    final statusLabel = expiringSoon > 0
        ? '$expiringSoon ${expiringSoon == 1 ? "quote" : "quotes"} expiring soon'
        : 'All quotes are still valid';

    return BillingCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Convert approvals in one click',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors?.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'When a client signs off, tap “Convert to invoice” to carry every line item forward automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.84),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          StatusPill(
            label: statusLabel,
            variant: statusVariant,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onViewInvoices,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Go to invoices'),
              ),
              OutlinedButton.icon(
                onPressed: onCreateInvoice,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create manual invoice'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final InvoiceFilter filter;
  final ValueChanged<InvoiceFilter> onFilterChanged;
  final int totalCount;
  final int filteredCount;
  final double totalAmount;
  final double receivedAmount;

  const _FilterBar({
    required this.filter,
    required this.onFilterChanged,
    required this.totalCount,
    required this.filteredCount,
    required this.totalAmount,
    required this.receivedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();
    final spacing = theme.extension<BillingSpacing>();
    final currencyTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.9),
    );

    return BillingCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter invoices',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.9),
              letterSpacing: 0.25,
            ),
          ),
          SizedBox(height: spacing?.sm ?? 12),
          SegmentedButton<InvoiceFilter>(
            segments: const [
              ButtonSegment(value: InvoiceFilter.all, label: Text('All')),
              ButtonSegment(value: InvoiceFilter.unpaid, label: Text('Unpaid')),
              ButtonSegment(value: InvoiceFilter.paid, label: Text('Paid')),
            ],
            showSelectedIcon: false,
            style: ButtonStyle(
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
            selected: <InvoiceFilter>{filter},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                onFilterChanged(selection.first);
              }
            },
          ),
          SizedBox(height: spacing?.md ?? 16),
          Row(
            children: [
              Text(
                'total: ${_currencyFormatter.format(totalAmount)}',
                style: currencyTextStyle,
              ),
              SizedBox(width: spacing?.sm ?? 12),
              Text(
                'received: ${_currencyFormatter.format(receivedAmount)}',
                style: currencyTextStyle,
              ),
              const Spacer(),
              Text('${filteredCount} of $totalCount', style: currencyTextStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceTile extends ConsumerStatefulWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final String documentLabel;
  final bool isConverting;
  final VoidCallback? onConvert;

  const _InvoiceTile({
    required this.invoice,
    required this.onTap,
    required this.documentLabel,
    this.isConverting = false,
    this.onConvert,
  });

  @override
  ConsumerState<_InvoiceTile> createState() => _InvoiceTileState();
}

class _InvoiceTileState extends ConsumerState<_InvoiceTile> {
  bool _isUpdatingStatus = false;
  bool _isDeleting = false;
  Invoice? _optimisticInvoice; // Store optimistic update

  Invoice get _displayInvoice => _optimisticInvoice ?? widget.invoice;

  Future<void> _updateStatus(InvoiceStatus newStatus) async {
    if (_isUpdatingStatus) return;
    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      // Optimistically update UI immediately
      if (mounted) {
        setState(() {
          _optimisticInvoice = Invoice(
            id: widget.invoice.id,
            clientId: widget.invoice.clientId,
            number: widget.invoice.number,
            issuedAt: widget.invoice.issuedAt,
            dueAt: widget.invoice.dueAt,
            status: newStatus, // Update status immediately
            documentType: widget.invoice.documentType,
            notes: widget.invoice.notes,
            taxPct: widget.invoice.taxPct,
            discountPct: widget.invoice.discountPct,
            totalCached: widget.invoice.totalCached,
            pdfUrl: widget.invoice.pdfUrl,
            createdAt: widget.invoice.createdAt,
            updatedAt: widget.invoice.updatedAt,
            client: widget.invoice.client,
            items: widget.invoice.items,
          );
        });
      }

      final repo = ref.read(invoiceRepoProvider);
      await repo.updateStatus(widget.invoice.id, newStatus);
      
      // Clear optimistic update after successful API call
      _optimisticInvoice = null;
      
      // Invalidate providers to refresh the entire list
      ref.invalidate(invoiceListProvider);
      ref.invalidate(homeStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.displayName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _deleteInvoice() async {
    if (_isDeleting) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.documentLabel}?'),
        content: Text(
          'Are you sure you want to delete ${widget.documentLabel.toLowerCase()} #${widget.invoice.number}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final repo = ref.read(invoiceRepoProvider);
      await repo.delete(widget.invoice.id);

      // Invalidate providers to refresh the list
      ref.invalidate(invoiceListProvider);
      ref.invalidate(homeStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.documentLabel} deleted successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete ${widget.documentLabel.toLowerCase()}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();
    final invoice = _displayInvoice; // Use optimistic or actual invoice
    final amount = _currencyFormatter.format(invoice.totalCached ?? 0);
    final issuedAtText = _dateFormatter.format(invoice.issuedAt);
    final dueInfo = _DueInfo.fromInvoice(invoice);
    final pillLabel = invoice.isEstimate
        ? widget.documentLabel.toUpperCase()
        : invoice.status.displayName;
    final pillVariant = invoice.isEstimate
        ? StatusPillVariant.neutral
        : _mapStatusToVariant(invoice.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: BillingCard(
        onTap: widget.onTap,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Column(
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
                        invoice.client?.name ?? 'Unknown client',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors?.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '#${invoice.number} · $issuedAtText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.86),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isDeleting)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            iconSize: 20,
                            color: theme.colorScheme.error.withOpacity(0.7),
                            onPressed: _deleteInvoice,
                            tooltip: 'Delete ${widget.documentLabel.toLowerCase()}',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          amount,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: 22,
                            color: colors?.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    StatusPill(
                      label: pillLabel,
                      variant: pillVariant,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status dropdown for invoices (not estimates)
            if (!invoice.isEstimate) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.label_outline,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<InvoiceStatus>(
                        value: _displayInvoice.status,
                        isExpanded: true,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        icon: _isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.arrow_drop_down,
                                size: 20,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                        items: InvoiceStatus.values
                            .where((status) => status != InvoiceStatus.draft || _displayInvoice.status == InvoiceStatus.draft)
                            .map((status) {
                          return DropdownMenuItem<InvoiceStatus>(
                            value: status,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      _mapStatusToVariant(status),
                                      context,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  status.displayName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: status == _displayInvoice.status
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _isUpdatingStatus
                            ? null
                            : (InvoiceStatus? newStatus) {
                                if (newStatus != null && newStatus != _displayInvoice.status) {
                                  _updateStatus(newStatus);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: dueInfo.color,
                ),
                const SizedBox(width: 8),
                Text(
                  dueInfo.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dueInfo.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: colors?.textMuted,
                ),
              ],
            ),
            if (invoice.isEstimate && widget.onConvert != null) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: widget.isConverting ? null : widget.onConvert,
                  icon: widget.isConverting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz_rounded),
                  label: Text(widget.isConverting ? 'Converting...' : 'Convert to invoice'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

StatusPillVariant _mapStatusToVariant(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.paid:
      return StatusPillVariant.success;
    case InvoiceStatus.overdue:
      return StatusPillVariant.danger;
    case InvoiceStatus.pending:
      return StatusPillVariant.warning;
    case InvoiceStatus.draft:
    default:
      return StatusPillVariant.neutral;
  }
}

Color _getStatusColor(StatusPillVariant variant, BuildContext context) {
  final theme = Theme.of(context);
  final colors = theme.extension<BillingColors>();
  
  switch (variant) {
    case StatusPillVariant.success:
      return colors?.success ?? const Color(0xFF0FA47F);
    case StatusPillVariant.warning:
      return colors?.warning ?? const Color(0xFFF59E0B);
    case StatusPillVariant.danger:
      return colors?.danger ?? const Color(0xFFEF4444);
    case StatusPillVariant.neutral:
    default:
      return colors?.pillForeground ?? theme.colorScheme.primary;
  }
}

class _DueInfo {
  final String label;
  final Color color;

  _DueInfo(this.label, this.color);

  factory _DueInfo.fromInvoice(Invoice invoice) {
    final now = DateTime.now();
    final dueAt = invoice.dueAt;
    final difference = dueAt.difference(now).inDays;

    if (invoice.isEstimate) {
      final formattedDate = _dateFormatter.format(dueAt);
      if (difference < 0) {
        return _DueInfo('expired on $formattedDate', const Color(0xFFE11D48));
      }
      if (difference == 0) {
        return _DueInfo('expires today', const Color(0xFFF97316));
      }
      return _DueInfo('valid until $formattedDate', const Color(0xFF2563EB));
    }

    if (invoice.status == InvoiceStatus.paid) {
      return _DueInfo('paid', const Color(0xFF047857));
    }
    if (difference < 0 || invoice.status == InvoiceStatus.overdue) {
      return _DueInfo('overdue ${difference.abs()}d', const Color(0xFFE11D48));
    }
    if (difference == 0) {
      return _DueInfo('due today', const Color(0xFFF97316));
    }
    return _DueInfo('due in ${difference}d', const Color(0xFF2563EB));
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.headline,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

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
            Icon(icon, size: 56, color: colors?.pillForeground ?? theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              headline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.88),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  final String documentLabelPlural;
  final String? message;

  const _FilteredEmptyState({
    required this.documentLabelPlural,
    this.message,
  });

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
            Icon(
              Icons.filter_list_off,
              size: 48,
              color: colors?.textMuted ?? theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No $documentLabelPlural match your filters',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message ??
                  'Try changing your filter or clearing the search to see more results.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String documentLabelPlural;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.documentLabelPlural,
  });

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
              'We couldn\'t load $documentLabelPlural',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.88),
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
