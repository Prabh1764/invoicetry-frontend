import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/invoice.dart';
import '../../data/models/invoice_item.dart';
import '../../data/models/client.dart';
import '../../ui/widgets/billing_card.dart';
import '../home/home_screen.dart';
import 'invoice_list_screen.dart';
import '../../data/repositories/settings_repo.dart' show settingsRepoProvider;
import '../../data/repositories/invoice_repo.dart' show InvoiceRepo;

const double _kSpacingXs = 8;
const double _kSpacingSm = 12;
const double _kSpacingMd = 16;
const double _kSpacingLg = 24;
const double _kFieldHeight = 52;
const double _kCardPadding = 20;
const double _kFieldRadius = 16;
const double _kMaxContentWidth = 1180;
const double _kMinFieldWidth = 340;
const double _kCompactFieldWidth = 200;
const double _kGridSpacing = _kSpacingMd;
const double _kSectionSpacing = _kSpacingLg;

final invoiceForEditProvider = FutureProvider.family<Invoice?, String>((ref, id) async {
  if (id == 'new') return null;
  final repo = ref.watch(invoiceRepoProvider);
  return repo.getById(id);
});

final clientsListProvider = FutureProvider<List<Client>>((ref) async {
  final repo = ref.watch(clientRepoProvider);
  return repo.getAll();
});

class EditInvoiceScreen extends ConsumerStatefulWidget {
  final String? invoiceId;
  final InvoiceDocumentType documentType;

  const EditInvoiceScreen({
    super.key,
    this.invoiceId,
    this.documentType = InvoiceDocumentType.invoice,
  });

  @override
  ConsumerState<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends ConsumerState<EditInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late String? _selectedClientId;
  late DateTime _issuedAt;
  late DateTime _dueAt;
  late double _taxPct;
  late double _discountPct;
  late String? _notes;
  late List<InvoiceItem> _items;

  @override
  void initState() {
    super.initState();
    _selectedClientId = null;
    _issuedAt = DateTime.now();
    _dueAt = DateTime.now().add(const Duration(days: 30));
    _taxPct = 0;
    _discountPct = 0;
    _notes = null;
    _items = [InvoiceItem(id: '', invoiceId: '', description: '', qty: 1, unitPrice: 0)];
    
    // Load settings defaults when creating new invoice
    if (widget.invoiceId == null || widget.invoiceId == 'new') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSettingsDefaults();
      });
    }
  }

  Future<void> _loadSettingsDefaults() async {
    try {
      final settingsRepo = ref.read(settingsRepoProvider);
      final settings = await settingsRepo.getSettings();
      
      if (mounted) {
        setState(() {
          // Set default tax rate
          if (settings.defaultTaxRate != null) {
            _taxPct = settings.defaultTaxRate!;
          }
          
          // Calculate due date from payment terms
          if (settings.defaultPaymentTerms != null) {
            final paymentTerms = settings.defaultPaymentTerms!;
            final issuedAt = _issuedAt;
            
            // Parse payment terms (e.g., "Net 30" = 30 days, "Due on receipt" = 0 days)
            int daysToAdd = 30; // Default
            final netMatch = RegExp(r'Net\s+(\d+)', caseSensitive: false).firstMatch(paymentTerms);
            if (netMatch != null) {
              daysToAdd = int.parse(netMatch.group(1)!);
            } else if (paymentTerms.toLowerCase().contains('due on receipt') || 
                       paymentTerms.toLowerCase().contains('due immediately')) {
              daysToAdd = 0;
            }
            
            _dueAt = issuedAt.add(Duration(days: daysToAdd));
          }
          
          // Set default notes
          if (settings.defaultInvoiceNotes != null && settings.defaultInvoiceNotes!.isNotEmpty) {
            _notes = settings.defaultInvoiceNotes;
          }
        });
      }
    } catch (e) {
      debugPrint('Could not load settings defaults: $e');
      // Continue with hardcoded defaults
    }
  }

  Map<String, double> _calculateTotals() {
    final subtotal = _items.fold(0.0, (sum, item) => sum + (item.qty * item.unitPrice));
    final taxAmount = subtotal * (_taxPct / 100);
    final discountAmount = subtotal * (_discountPct / 100);
    final total = subtotal + taxAmount - discountAmount;
    return {'subtotal': subtotal, 'taxAmount': taxAmount, 'discountAmount': discountAmount, 'total': total};
  }

  String _labelForDocument(InvoiceDocumentType type) {
    return type == InvoiceDocumentType.estimate ? 'Quote' : 'Invoice';
  }

  Future<void> _save(InvoiceDocumentType documentType) async {
    if (!_formKey.currentState!.validate() || _selectedClientId == null) return;
    try {
      final repo = ref.read(invoiceRepoProvider);
      final itemsData = _items.map((item) => {
        'description': item.description,
        'qty': item.qty,
        'unitPrice': item.unitPrice,
      }).toList();

      Invoice result;

      if (widget.invoiceId == null || widget.invoiceId == 'new') {
        debugPrint('📝 [EDIT_INVOICE] Creating new ${_labelForDocument(documentType)}...');
        result = await repo.create(
          clientId: _selectedClientId!,
          issuedAt: _issuedAt,
          dueAt: _dueAt,
          taxPct: _taxPct,
          discountPct: _discountPct,
          notes: _notes,
          items: itemsData,
          documentType: documentType.name.toUpperCase(),
        );
        debugPrint('✅ [EDIT_INVOICE] ${_labelForDocument(documentType)} created successfully');
      } else {
        debugPrint('📝 [EDIT_INVOICE] Updating ${_labelForDocument(documentType)} ${widget.invoiceId}...');
        result = await repo.update(
          widget.invoiceId!,
          clientId: _selectedClientId,
          issuedAt: _issuedAt,
          dueAt: _dueAt,
          taxPct: _taxPct,
          discountPct: _discountPct,
          notes: _notes,
          items: itemsData,
        );
        debugPrint('✅ [EDIT_INVOICE] ${_labelForDocument(documentType)} updated successfully');
      }
      if (mounted) {
        ref.invalidate(invoiceListProvider);
        ref.invalidate(homeStatsProvider);
        debugPrint('✅ [EDIT_INVOICE] Document saved, list/providers invalidated');
        context.pop(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_labelForDocument(documentType)} saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ [EDIT_INVOICE] Error saving invoice: $e');
      debugPrint('   - Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving ${_labelForDocument(documentType).toLowerCase()}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildContent(context);
    } catch (e, stack) {
      debugPrint('❌ [EDIT_INVOICE] Error in build: $e');
      debugPrint('   - Stack: $stack');
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Invoice'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading invoice editor',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Try to rebuild
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    final invoice = widget.invoiceId != null && widget.invoiceId != 'new'
        ? ref.watch(invoiceForEditProvider(widget.invoiceId!))
        : null;
    final clients = ref.watch(clientsListProvider);
    final totals = _calculateTotals();
    // Use valueOrNull instead of maybeWhen to avoid dependency tracking issues
    final existingInvoice = invoice?.valueOrNull;
    final effectiveDocumentType =
        existingInvoice?.documentType ?? widget.documentType;
    final documentLabel = _labelForDocument(effectiveDocumentType);
    final dueFieldLabel =
        effectiveDocumentType == InvoiceDocumentType.estimate
            ? 'Valid until'
            : 'Due';
    final notesFieldLabel =
        effectiveDocumentType == InvoiceDocumentType.estimate
            ? 'Notes & follow-up'
            : 'Notes';
    final totalLabel =
        effectiveDocumentType == InvoiceDocumentType.estimate
            ? 'Quote total'
            : 'Total';

    // Extract client name at top level to avoid watching providers inside buildTextField
    String? clientName;
    if (existingInvoice?.client?.name != null) {
      clientName = existingInvoice!.client!.name;
    } else if (_selectedClientId != null) {
      // Safely extract client name without using maybeWhen during build
      final clientsData = clients.valueOrNull;
      if (clientsData != null) {
        try {
          final client = clientsData.firstWhere((c) => c.id == _selectedClientId);
          clientName = client.name;
        } catch (e) {
          clientName = null;
        }
      }
    }

    // Load invoice data into state (only once)
    if (existingInvoice != null && _selectedClientId == null) {
      // Use a post-frame callback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedClientId == null) {
          setState(() {
            _selectedClientId = existingInvoice.clientId;
            _issuedAt = existingInvoice.issuedAt;
            _dueAt = existingInvoice.dueAt;
            _taxPct = existingInvoice.taxPct;
            _discountPct = existingInvoice.discountPct;
            _notes = existingInvoice.notes;
            _items = existingInvoice.items ??
                [
                  InvoiceItem(
                    id: '',
                    invoiceId: '',
                    description: '',
                    qty: 1,
                    unitPrice: 0,
                  ),
                ];
          });
        }
      });
    }

    final theme = Theme.of(context);

    String formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

    InputDecoration inputDecoration(String label) => InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kFieldRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kFieldRadius),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kFieldRadius),
          ),
        );

    Widget buildTextField({
      required String label,
      String? initialValue,
      TextInputType? keyboardType,
      ValueChanged<String>? onChanged,
      int? maxLines,
      bool enableAutocomplete = false,
      int? itemIndex,
      String? clientName, // Pass client name as parameter instead of watching inside
    }) {
      final decoration = inputDecoration(label);
      final textStyle = theme.textTheme.bodyMedium;

      // Use autocomplete for description fields
      if (enableAutocomplete && itemIndex != null) {
        debugPrint('🎯 [BUILDFIELD] Creating autocomplete widget for description field at index $itemIndex');
        debugPrint('   - Initial value: "${initialValue ?? ""}"');
        final repo = ref.read(invoiceRepoProvider);
        debugPrint('   - Repo obtained: $repo');
        
        // Use the client name passed as parameter (extracted at top level)
        return SizedBox(
          height: _kFieldHeight,
          child: _DescriptionAutocomplete(
            key: ValueKey('desc_${widget.invoiceId}_$itemIndex'),
            initialValue: initialValue ?? '',
            decoration: decoration,
            textStyle: textStyle,
            onChanged: onChanged ?? (value) {},
            itemIndex: itemIndex,
            repo: repo,
            clientName: clientName,
            allItems: _items,
            documentType: widget.documentType,
          ),
        );
      }
      
      debugPrint('⚠️ [BUILDFIELD] NOT using autocomplete - enableAutocomplete: $enableAutocomplete, itemIndex: $itemIndex');

      if (maxLines != null && maxLines > 1) {
        return TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          onChanged: onChanged,
          maxLines: maxLines,
          minLines: maxLines,
          style: textStyle,
          decoration: decoration,
        );
      }

      return SizedBox(
        height: _kFieldHeight,
        child: TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: textStyle,
          decoration: decoration,
        ),
      );
    }

    Widget buildDropdown(List<Client> clientsList) {
      if (clientsList.isEmpty) {
        return const Text(
          'No clients available. Please add a client first.',
        );
      }

      return SizedBox(
        height: _kFieldHeight,
        child: DropdownButtonFormField<String>(
          value: _selectedClientId,
          decoration: inputDecoration('Client *'),
          menuMaxHeight: 320,
          style: theme.textTheme.bodyMedium,
          items: clientsList
              .map(
                (client) => DropdownMenuItem<String>(
                  value: client.id,
                  child: Text(client.name),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedClientId = value),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a client';
            }
            return null;
          },
        ),
      );
    }


    Widget buildDateField({
      required String label,
      required DateTime value,
      required ValueChanged<DateTime> onChanged,
    }) {
      return SizedBox(
        height: _kFieldHeight,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kFieldRadius),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: InputDecorator(
            decoration: inputDecoration(label).copyWith(
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            isEmpty: false,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                formatDate(value),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      );
    }

    Widget buildNumberField({
      required String label,
      required double value,
      required ValueChanged<double> onChanged,
    }) {
      return buildTextField(
        label: label,
        initialValue: value == value.roundToDouble()
            ? value.toStringAsFixed(0)
            : value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (input) =>
            onChanged(double.tryParse(input.trim()) ?? 0.0),
      );
    }

    Widget buildLineItemRow(int index, InvoiceItem item) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: index == _items.length - 1 ? 0 : _kSpacingMd,
        ),
        child: FormRow(
          children: [
                                        FormFieldTile(
                                          span: 2,
                                          child: buildTextField(
                                            label: 'Description',
                                            initialValue: item.description,
                                            enableAutocomplete: true,
                                            itemIndex: index,
                                            clientName: clientName,
                                            onChanged: (value) => setState(
                                              () => _items[index] = item.copyWith(description: value),
                                            ),
                                          ),
                                        ),
            FormFieldTile(
              compact: true,
              child: buildTextField(
                label: 'Qty',
                initialValue: item.qty == item.qty.roundToDouble()
                    ? item.qty.toStringAsFixed(0)
                    : item.qty.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => setState(
                  () => _items[index] = item.copyWith(
                    qty: double.tryParse(value.trim()) ?? 0,
                  ),
                ),
              ),
            ),
            FormFieldTile(
              compact: true,
              child: buildTextField(
                label: 'Price',
                initialValue: item.unitPrice == item.unitPrice.roundToDouble()
                    ? item.unitPrice.toStringAsFixed(0)
                    : item.unitPrice.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => setState(
                  () => _items[index] = item.copyWith(
                    unitPrice: double.tryParse(value.trim()) ?? 0,
                  ),
                ),
              ),
            ),
            FormFieldTile(
              compact: true,
              child: SizedBox(
                height: _kFieldHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove item',
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.invoiceId == null || widget.invoiceId == 'new'
              ? 'New $documentLabel'
              : 'Edit $documentLabel',
        ),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ListView(
                children: [
                  FormSectionCard(
                    title: 'Document details',
                    child: FormRow(
                      children: [
                        FormFieldTile(
                          child: clients.when(
                            data: buildDropdown,
                            loading: () => const SizedBox(
                              height: _kFieldHeight,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (error, _) => SizedBox(
                              height: _kFieldHeight,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Error loading clients: $error',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        ref.invalidate(clientsListProvider),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        FormFieldTile(
                          child: buildDateField(
                            label: 'Issued',
                            value: _issuedAt,
                            onChanged: (date) =>
                                setState(() => _issuedAt = date),
                          ),
                        ),
                        FormFieldTile(
                          child: buildDateField(
                            label: dueFieldLabel,
                            value: _dueAt,
                            onChanged: (date) =>
                                setState(() => _dueAt = date),
                          ),
                        ),
                        FormFieldTile(
                          compact: true,
                          child: buildNumberField(
                            label: 'Tax %',
                            value: _taxPct,
                            onChanged: (value) =>
                                setState(() => _taxPct = value),
                          ),
                        ),
                        FormFieldTile(
                          compact: true,
                          child: buildNumberField(
                            label: 'Discount %',
                            value: _discountPct,
                            onChanged: (value) =>
                                setState(() => _discountPct = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _kSectionSpacing),
                  FormSectionCard(
                    title: notesFieldLabel,
                    child: FormRow(
                      children: [
                        FormFieldTile(
                          span: 2,
                          child: buildTextField(
                            label: notesFieldLabel,
                            initialValue: _notes,
                            maxLines: 4,
                            onChanged: (value) =>
                                setState(() => _notes = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _kSectionSpacing),
                  FormSectionCard(
                    title: 'Line items',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_items.isEmpty)
                          const Text(
                            'No line items yet. Add your first service or product.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ..._items
                            .asMap()
                            .entries
                            .map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == _items.length - 1
                                      ? 0
                                      : _kSpacingMd,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FormRow(
                                      children: [
                                        FormFieldTile(
                                          span: 2,
                                          child: buildTextField(
                                            label: 'Description',
                                            initialValue: item.description,
                                            enableAutocomplete: true,
                                            itemIndex: index,
                                            clientName: clientName,
                                            onChanged: (value) => setState(
                                              () => _items[index] =
                                                  item.copyWith(description: value),
                                            ),
                                          ),
                                        ),
                                        FormFieldTile(
                                          compact: true,
                                          child: buildTextField(
                                            label: 'Qty',
                                            initialValue: item.qty ==
                                                    item.qty.roundToDouble()
                                                ? item.qty.toStringAsFixed(0)
                                                : item.qty.toString(),
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            onChanged: (value) => setState(
                                              () => _items[index] =
                                                  item.copyWith(
                                                      qty: double.tryParse(
                                                              value.trim()) ??
                                                          0),
                                            ),
                                          ),
                                        ),
                                        FormFieldTile(
                                          compact: true,
                                          child: buildTextField(
                                            label: 'Price',
                                            initialValue: item.unitPrice ==
                                                    item.unitPrice
                                                        .roundToDouble()
                                                ? item.unitPrice
                                                    .toStringAsFixed(0)
                                                : item.unitPrice.toString(),
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            onChanged: (value) => setState(
                                              () => _items[index] =
                                                  item.copyWith(
                                                      unitPrice: double
                                                              .tryParse(value
                                                                  .trim()) ??
                                                          0),
                                            ),
                                          ),
                                        ),
                                        FormFieldTile(
                                          compact: true,
                                          child: SizedBox(
                                            height: _kFieldHeight,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline),
                                                tooltip: 'Remove item',
                                                onPressed: () => setState(
                                                  () => _items.removeAt(index),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            })
                            .toList(),
                        if (_items.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: _kSpacingSm),
                            child: Text(
                              'Tip: Provide delivery or payment specifics in the description for each line item.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        if (_items.isNotEmpty) const SizedBox(height: _kSpacingMd),
                        FilledButton.icon(
                          onPressed: () => setState(
                            () => _items.add(
                              InvoiceItem(
                                id: '',
                                invoiceId: '',
                                description: '',
                                qty: 1,
                                unitPrice: 0,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add item'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _kSectionSpacing),
                  FormSectionCard(
                    title: 'Summary',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryRow(label: 'Subtotal', value: totals['subtotal']!),
                        _SummaryRow(label: 'Tax', value: totals['taxAmount']!),
                        _SummaryRow(
                          label: 'Discount',
                          value: -totals['discountAmount']!,
                        ),
                        const Divider(height: _kSpacingLg),
                        _SummaryRow(
                          label: totalLabel,
                          value: totals['total']!,
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _kSectionSpacing),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _save(effectiveDocumentType),
                      icon: const Icon(Icons.save_rounded),
                      label: Text('Save ${documentLabel.toLowerCase()}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FormSectionCard extends StatelessWidget {
  const FormSectionCard({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BillingCard(
      padding: const EdgeInsets.all(_kCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _kSpacingSm),
          child,
        ],
      ),
    );
  }
}

class FormRow extends StatelessWidget {
  const FormRow({required this.children, super.key});

  final List<FormFieldTile> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int columns = 1;

        if (width >= 900) {
          columns = 2;
        } else if (width >= 600 &&
            (width - _kGridSpacing) / 2 >= _kMinFieldWidth) {
          columns = 2;
        }

        final double itemWidth = columns == 1
            ? width
            : (width - _kGridSpacing * (columns - 1)) / columns;

        return Wrap(
          spacing: _kGridSpacing,
          runSpacing: _kGridSpacing,
          children: children.map((tile) {
            double tileWidth;

            if (columns == 1) {
              tileWidth = width;
            } else if (tile.span >= columns) {
              tileWidth = width;
            } else {
              final multiColumnWidth = itemWidth * tile.span +
                  _kGridSpacing * (tile.span - 1);
              tileWidth = tile.compact
                  ? math.min(_kCompactFieldWidth, multiColumnWidth)
                  : multiColumnWidth;
            }

            if (columns > 1 && tile.compact) {
              tileWidth = math.min(_kCompactFieldWidth, tileWidth);
            }

            tileWidth = tileWidth.clamp(0, width);

            return SizedBox(
              width: tileWidth,
              child: tile.child,
            );
          }).toList(),
        );
      },
    );
  }
}

class FormFieldTile {
  const FormFieldTile({
    required this.child,
    this.compact = false,
    this.span = 1,
  });

  final Widget child;
  final bool compact;
  final int span;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.simpleCurrency();
    final textStyle = emphasized
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withOpacity(0.95),
          )
        : theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withOpacity(0.78),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textStyle)),
          Text(
            formatter.format(value),
            style: textStyle,
          ),
        ],
      ),
    );
  }
}


// Autocomplete widget for invoice item descriptions - using custom overlay approach
class _DescriptionAutocomplete extends StatefulWidget {
  final String initialValue;
  final InputDecoration decoration;
  final TextStyle? textStyle;
  final ValueChanged<String> onChanged;
  final int itemIndex;
  final InvoiceRepo repo;
  final String? clientName;
  final List<InvoiceItem>? allItems;
  final InvoiceDocumentType documentType;

  const _DescriptionAutocomplete({
    super.key,
    required this.initialValue,
    required this.decoration,
    this.textStyle,
    required this.onChanged,
    required this.itemIndex,
    required this.repo,
    this.clientName,
    this.allItems,
    this.documentType = InvoiceDocumentType.invoice,
  });

  @override
  State<_DescriptionAutocomplete> createState() => _DescriptionAutocompleteState();
}

class _DescriptionAutocompleteState extends State<_DescriptionAutocomplete> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  List<String> _filteredSuggestions = [];
  List<String> _allSuggestions = [];
  bool _isLoading = false;
  bool _isEnhancing = false;
  bool _isOnCooldown = false; // Simple boolean flag for cooldown
  DateTime? _lastEnhancementTime;
  Timer? _cooldownTimer;
  static const Duration _enhancementCooldown = Duration(seconds: 5); // 5 second cooldown between requests
  bool _showSuggestions = false;
  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  int _buildCount = 0; // Track build count to throttle logging

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
    debugPrint('🚀 [AUTOCOMPLETE] initState - Initial value: "${widget.initialValue}"');
    // Don't load on init - wait for focus
  }

  @override
  void dispose() {
    debugPrint('🗑️ [DISPOSE] Disposing autocomplete widget');
    // Cancel any pending timers
    _debounceTimer?.cancel();
    _cooldownTimer?.cancel();
    // Remove listeners
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChanged);
    // Remove overlay if it exists
    _removeOverlay();
    // Dispose controllers
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    debugPrint('👁️ [FOCUS] Focus changed - hasFocus: ${_focusNode.hasFocus}, mounted: $mounted');
    if (_focusNode.hasFocus) {
      debugPrint('👁️ [FOCUS] Field focused, loading suggestions and showing overlay');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          debugPrint('👁️ [FOCUS] Post-frame callback - showing overlay and loading');
          _showSuggestionsOverlay(); // Show overlay first (will show loading)
          _loadSuggestions('').then((_) {
            // After loading, update overlay with results
            if (mounted && _focusNode.hasFocus) {
              debugPrint('🔄 [FOCUS] Suggestions loaded, updating overlay');
              _updateOverlay();
            }
          }).catchError((error) {
            debugPrint('❌ [FOCUS] Error loading suggestions: $error');
          });
        }
      });
    } else {
      debugPrint('👁️ [FOCUS] Field unfocused, hiding overlay');
      // Delay hiding to allow tap on suggestion
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideSuggestionsOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    widget.onChanged(_controller.text);
    final query = _controller.text.toLowerCase();
    _filterSuggestions(query);
    
    // Update button visibility when text changes
    setState(() {});
    
    // Debounce loading new suggestions
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _controller.text.isNotEmpty) {
        _loadSuggestions(_controller.text);
      }
    });
    
    if (mounted && _showSuggestions) {
      _updateOverlay();
    }
  }

  void _filterSuggestions(String query) {
    if (query.isEmpty) {
      _filteredSuggestions = _allSuggestions.take(10).toList();
    } else {
      _filteredSuggestions = _allSuggestions
          .where((desc) => desc.toLowerCase().contains(query))
          .take(10)
          .toList();
    }
  }

  Future<void> _loadSuggestions(String query) async {
    if (_isLoading) {
      debugPrint('⚠️ [AUTOCOMPLETE] Already loading, skipping');
      return;
    }
    
    setState(() => _isLoading = true);
    
    // Update overlay immediately to show loading state
    if (_showSuggestions) {
      _updateOverlay();
    }
    
    try {
      debugPrint('🔍 [AUTOCOMPLETE] Loading suggestions for query: "${query.isEmpty ? "(empty - most used)" : query}"');
      debugPrint('   - Repo: ${widget.repo}');
      debugPrint('   - Calling repo.getItemTemplates...');
      
      final templates = await widget.repo.getItemTemplates(
        query: query.isEmpty ? null : query,
      );
      
      debugPrint('✅ [AUTOCOMPLETE] Got response from repo.getItemTemplates');
      debugPrint('✅ [AUTOCOMPLETE] Loaded ${templates.length} suggestions: ${templates.map((t) => t['description']).join(", ")}');
      
      if (mounted) {
        final descriptions = templates.map((t) => t['description'] as String).toList();
        debugPrint('✅ [AUTOCOMPLETE] Got ${descriptions.length} descriptions: $descriptions');
        setState(() {
          _allSuggestions = descriptions;
          _isLoading = false;
        });
        _filterSuggestions(_controller.text.toLowerCase());
        debugPrint('✅ [AUTOCOMPLETE] State updated - all: ${_allSuggestions.length}, filtered: ${_filteredSuggestions.length}');
        debugPrint('✅ [AUTOCOMPLETE] Filtered suggestions: $_filteredSuggestions');
        debugPrint('✅ [AUTOCOMPLETE] _showSuggestions: $_showSuggestions, hasFocus: ${_focusNode.hasFocus}');
        
        // Always update overlay if we have focus and suggestions
        if (_showSuggestions && _focusNode.hasFocus) {
          debugPrint('🔄 [AUTOCOMPLETE] Updating overlay with results...');
          _updateOverlay();
        }
      }
    } catch (e, stack) {
      debugPrint('❌ [AUTOCOMPLETE] Error loading suggestions: $e');
      debugPrint('   - Stack: $stack');
      if (mounted) {
        setState(() {
          _allSuggestions = [];
          _isLoading = false;
        });
        if (_showSuggestions) {
          _updateOverlay();
        }
      }
    }
  }

  void _showSuggestionsOverlay() {
    debugPrint('👁️ [OVERLAY] Showing overlay - current entry: ${_overlayEntry != null}');
    if (_overlayEntry != null) {
      debugPrint('⚠️ [OVERLAY] Overlay already exists, removing first');
      _removeOverlay();
    }
    
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showSuggestions = true);
    debugPrint('✅ [OVERLAY] Overlay inserted, _showSuggestions: $_showSuggestions');
  }

  void _hideSuggestionsOverlay() {
    _removeOverlay();
    setState(() => _showSuggestions = false);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    debugPrint('🔄 [UPDATE_OVERLAY] Updating overlay - _showSuggestions: $_showSuggestions, hasFocus: ${_focusNode.hasFocus}');
    _removeOverlay();
    if (_showSuggestions && _focusNode.hasFocus) {
      debugPrint('🔄 [UPDATE_OVERLAY] Creating new overlay entry');
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      debugPrint('✅ [UPDATE_OVERLAY] Overlay updated and inserted');
    } else {
      debugPrint('⚠️ [UPDATE_OVERLAY] Not updating - showSuggestions: $_showSuggestions, hasFocus: ${_focusNode.hasFocus}');
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;
    
    debugPrint('🎨 [OVERLAY] Creating overlay - isLoading: $_isLoading, suggestions: ${_filteredSuggestions.length}');
    
    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _filteredSuggestions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No suggestions',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _filteredSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _filteredSuggestions[index];
                            debugPrint('🎨 [OVERLAY] Building suggestion $index: "$suggestion"');
                            return InkWell(
                              onTap: () {
                                debugPrint('✅ [OVERLAY] Selected suggestion: "$suggestion"');
                                _controller.text = suggestion;
                                widget.onChanged(suggestion);
                                _focusNode.unfocus();
                                _hideSuggestionsOverlay();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                child: Text(
                                  suggestion,
                                  style: widget.textStyle ?? Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _enhanceDescription() async {
    // Wrap entire function in try-catch to prevent crashes
    try {
      // Check if widget is still mounted before starting
      if (!mounted) {
        debugPrint('⚠️ [ENHANCE] Widget unmounted before enhancement');
        return;
      }
      
      final currentDescription = _controller.text.trim();
      if (currentDescription.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a description first')),
          );
        }
        return;
      }

      // Prevent concurrent requests - if already enhancing, ignore
      if (_isEnhancing) {
        debugPrint('⚠️ [ENHANCE] Already enhancing, ignoring duplicate request');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait for the current enhancement to complete'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // Check cooldown - use simple boolean
      if (_isOnCooldown) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait 5 seconds before enhancing again'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Set state safely - use simple boolean flag
      try {
        _isEnhancing = true;
        _isOnCooldown = true;
        _lastEnhancementTime = DateTime.now();
        
        // Cancel existing timer
        _cooldownTimer?.cancel();
        
        // Start cooldown timer - simpler approach
        _cooldownTimer = Timer(_enhancementCooldown, () {
          try {
            if (mounted) {
              _isOnCooldown = false;
              setState(() {}); // Simple state update
              debugPrint('✅ [COOLDOWN] Cooldown expired, button re-enabled');
            }
          } catch (e) {
            debugPrint('❌ [COOLDOWN] Error in timer: $e');
            // Even if error, reset cooldown to prevent stuck state
            _isOnCooldown = false;
          }
        });
        
        if (mounted) {
          setState(() {}); // Update UI immediately
        } else {
          _isEnhancing = false;
          _isOnCooldown = false;
          _cooldownTimer?.cancel();
          return;
        }
      } catch (stateError) {
        debugPrint('❌ [ENHANCE] Error: $stateError');
        _isEnhancing = false;
        _isOnCooldown = false;
        _cooldownTimer?.cancel();
        return;
      }

      try {
        // Build context for enhancement
        final existingItems = <Map<String, dynamic>>[];
        if (widget.allItems != null) {
          for (int i = 0; i < widget.allItems!.length; i++) {
            if (i != widget.itemIndex) {
              final item = widget.allItems![i];
              if (item.description.trim().isNotEmpty) {
                existingItems.add({
                  'description': item.description,
                  'qty': item.qty,
                  'unitPrice': item.unitPrice,
                });
              }
            }
          }
        }

        debugPrint('✨ [ENHANCE] Enhancing description: "$currentDescription"');
        debugPrint('   - Client: ${widget.clientName ?? "none"}');
        debugPrint('   - Existing items: ${existingItems.length}');

        final enhanced = await widget.repo.enhanceDescription(
          description: currentDescription,
          clientName: widget.clientName,
          existingItems: existingItems.isNotEmpty ? existingItems : null,
          invoiceType: widget.documentType == InvoiceDocumentType.estimate ? 'ESTIMATE' : 'INVOICE',
        );

        // Note: _lastEnhancementTime already set before API call
        // Safely update the text controller and trigger onChange
        if (mounted) {
          try {
            // Update controller safely
            _controller.text = enhanced;
            // Trigger onChange callback safely
            widget.onChanged(enhanced);
            
            // Show success message safely
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✨ Description enhanced with AI'),
                duration: Duration(seconds: 2),
              ),
            );
          } catch (updateError) {
            debugPrint('❌ [ENHANCE] Error updating UI after enhancement: $updateError');
            // Even if UI update fails, log but don't crash
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Description enhanced, but there was an error: ${updateError.toString()}'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      } catch (e, stack) {
        // Ensure we catch ALL types of errors (String, Exception, DioException, etc.)
        debugPrint('❌ [ENHANCE] Error: $e');
        debugPrint('   - Stack: $stack');
        debugPrint('   - Error type: ${e.runtimeType}');
        
        try {
          if (mounted) {
            // Convert error to string safely
            String errorMessage;
            if (e is String) {
              errorMessage = e;
            } else {
              errorMessage = e.toString();
            }
            
            String userMessage;
            Duration duration = const Duration(seconds: 3);
            
            // Handle specific error types
            final lowerError = errorMessage.toLowerCase();
            if (lowerError.contains('403') || lowerError.contains('401') || 
                lowerError.contains('unauthorized') || lowerError.contains('forbidden')) {
              userMessage = 'Authentication error. Please try again.';
            } else if (lowerError.contains('rate limit') || lowerError.contains('429')) {
              userMessage = 'Too many requests. Please wait a moment and try again.';
              duration = const Duration(seconds: 5);
            } else if (lowerError.contains('timeout') || lowerError.contains('timed out')) {
              userMessage = 'Request timed out. Please check your connection and try again.';
            } else if (lowerError.contains('network') || lowerError.contains('connection')) {
              userMessage = 'Network error. Please check your connection and try again.';
            } else {
              // Extract a clean error message
              userMessage = 'Failed to enhance description. Please try again.';
              // Log the actual error for debugging
              debugPrint('   - Actual error: $errorMessage');
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(userMessage),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: duration,
              ),
            );
          }
        } catch (innerError) {
          // Even error handling can fail, so catch that too
          debugPrint('❌ [ENHANCE] Error in error handler: $innerError');
          // Try to show a generic error message
          try {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('An error occurred. Please try again.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } catch (finalError) {
            debugPrint('❌ [ENHANCE] Failed to show error message: $finalError');
          }
        }
      }
    } catch (e, stack) {
      // Catch ALL errors including those outside inner try-catch
      debugPrint('❌ [ENHANCE] Unexpected error: $e');
      debugPrint('   - Stack: $stack');
      
      // Ensure we always reset state
      _isEnhancing = false;
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('An error occurred. Please try again.'),
              duration: Duration(seconds: 3),
            ),
          );
        } catch (_) {
          // Ignore if context invalid
        }
      }
    } finally {
      // Reset enhancing flag - cooldown stays active
      try {
        _isEnhancing = false;
        
        if (mounted) {
          setState(() {}); // Simple update
        }
      } catch (stateError) {
        debugPrint('❌ [ENHANCE] Error in finally: $stateError');
        _isEnhancing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Throttle debug logging - only log every 10th build to avoid spam
    if (_buildCount % 10 == 0) {
      debugPrint('🎨 [BUILD] Building autocomplete widget (build #$_buildCount)');
      debugPrint('   - _isEnhancing: $_isEnhancing');
      debugPrint('   - _isOnCooldown: $_isOnCooldown');
      debugPrint('   - _lastEnhancementTime: $_lastEnhancementTime');
    }
    _buildCount++;
    
    // Add smart button - use simple boolean flag
    final canEnhance = !_isEnhancing && !_isOnCooldown;
    
    // Calculate remaining seconds for feedback
    int? remainingSeconds;
    if (_isOnCooldown && _lastEnhancementTime != null) {
      final now = DateTime.now();
      final remaining = _enhancementCooldown - now.difference(_lastEnhancementTime!);
      remainingSeconds = remaining.inSeconds + 1;
    }
    
    final decorationWithButton = widget.decoration.copyWith(
      suffixIcon: _controller.text.trim().isNotEmpty
          ? AnimatedOpacity(
              opacity: canEnhance ? 1.0 : 0.4, // Simple opacity animation
              duration: const Duration(milliseconds: 200),
              child: IconButton(
                icon: _isEnhancing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 20),
                onPressed: canEnhance ? _enhanceDescription : () {
                  // Show feedback when disabled
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isOnCooldown && remainingSeconds != null
                          ? 'Please wait ${remainingSeconds} second${remainingSeconds > 1 ? 's' : ''} before enhancing again'
                          : 'Please wait...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: canEnhance 
                    ? 'Enhance description with AI' 
                    : (_isOnCooldown && remainingSeconds != null
                        ? 'Please wait ${remainingSeconds} second${remainingSeconds > 1 ? 's' : ''}'
                        : 'Please wait...'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            )
          : null,
    );

    // TextField with maxLines: 1 automatically scrolls horizontally for long text
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        maxLines: 1,
        style: widget.textStyle,
        decoration: decorationWithButton,
        enableInteractiveSelection: true,
        onTap: () {
          debugPrint('👆 [TAP] Description field tapped!');
          debugPrint('   - isLoading: $_isLoading, allSuggestions: ${_allSuggestions.length}, filtered: ${_filteredSuggestions.length}');
          // Always load suggestions on tap
          debugPrint('👆 [TAP] Loading suggestions on tap...');
          _showSuggestionsOverlay();
          _loadSuggestions('');
        },
      ),
    );
  }
}
