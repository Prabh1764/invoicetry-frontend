import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/client.dart';
import '../../data/models/invoice.dart';
import '../../data/services/ai_service.dart';
import '../home/home_screen.dart';
import '../invoices/invoice_list_screen.dart';

enum AssistantRole { assistant, user }

class AssistantMessage {
  AssistantMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final AssistantRole role;
  final String content;
  final DateTime timestamp;
}

class InvoiceLineDraft {
  InvoiceLineDraft({
    required this.description,
    this.quantity = 0,
    this.unitPrice = 0,
  });

  final String description;
  final double quantity;
  final double unitPrice;

  InvoiceLineDraft copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
  }) {
    return InvoiceLineDraft(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  double get total => quantity * unitPrice;

  bool get hasQuantity => quantity > 0;

  bool get hasPrice => unitPrice > 0;
}

enum VoicePromptType {
  quantity,
  price,
  clientConfirmation,
}

class PendingPrompt {
  const PendingPrompt({
    required this.type,
    this.lineIndex,
    required this.prompt,
  });

  final VoicePromptType type;
  final int? lineIndex;
  final String prompt;
}

class VoiceAssistantState {
  VoiceAssistantState({
    required this.history,
    required this.documentType,
    required this.client,
    required this.items,
    required this.issuedAt,
    required this.dueAt,
    required this.taxPct,
    required this.discountPct,
    required this.notes,
    required this.pendingPrompt,
    required this.isProcessing,
    required this.creationInProgress,
    required this.lastCreatedInvoiceId,
    required this.lastCreatedDocumentType,
    required this.error,
  });

  factory VoiceAssistantState.initial() {
    return VoiceAssistantState(
      history: [
        AssistantMessage(
          role: AssistantRole.assistant,
          content:
              'Hi! I can draft invoices or estimates from your voice commands. Try saying "Create invoice for Acme Corp" or "Add item drywall installation quantity 50 at 12.5 each."',
        ),
      ],
      documentType: null,
      client: null,
      items: const [],
      issuedAt: DateTime.now(),
      dueAt: DateTime.now().add(const Duration(days: 30)),
      taxPct: 0,
      discountPct: 0,
      notes: null,
      pendingPrompt: null,
      isProcessing: false,
      creationInProgress: false,
      lastCreatedInvoiceId: null,
      lastCreatedDocumentType: null,
      error: null,
    );
  }

  final List<AssistantMessage> history;
  final InvoiceDocumentType? documentType;
  final Client? client;
  final List<InvoiceLineDraft> items;
  final DateTime issuedAt;
  final DateTime dueAt;
  final double taxPct;
  final double discountPct;
  final String? notes;
  final PendingPrompt? pendingPrompt;
  final bool isProcessing;
  final bool creationInProgress;
  final String? lastCreatedInvoiceId;
  final InvoiceDocumentType? lastCreatedDocumentType;
  final String? error;

  VoiceAssistantState copyWith({
    List<AssistantMessage>? history,
    InvoiceDocumentType? documentType,
    bool documentTypeReset = false,
    Client? client,
    bool clientReset = false,
    List<InvoiceLineDraft>? items,
    DateTime? issuedAt,
    DateTime? dueAt,
    double? taxPct,
    double? discountPct,
    String? notes,
    bool notesReset = false,
    PendingPrompt? pendingPrompt,
    bool clearPendingPrompt = false,
    bool? isProcessing,
    bool? creationInProgress,
    String? lastCreatedInvoiceId,
    bool clearLastCreatedId = false,
    InvoiceDocumentType? lastCreatedDocumentType,
    bool clearLastCreatedType = false,
    String? error,
  }) {
    return VoiceAssistantState(
      history: history ?? this.history,
      documentType: documentTypeReset ? null : (documentType ?? this.documentType),
      client: clientReset ? null : (client ?? this.client),
      items: items ?? this.items,
      issuedAt: issuedAt ?? this.issuedAt,
      dueAt: dueAt ?? this.dueAt,
      taxPct: taxPct ?? this.taxPct,
      discountPct: discountPct ?? this.discountPct,
      notes: notesReset ? null : (notes ?? this.notes),
      pendingPrompt: clearPendingPrompt ? null : (pendingPrompt ?? this.pendingPrompt),
      isProcessing: isProcessing ?? this.isProcessing,
      creationInProgress: creationInProgress ?? this.creationInProgress,
      lastCreatedInvoiceId:
          clearLastCreatedId ? null : (lastCreatedInvoiceId ?? this.lastCreatedInvoiceId),
      lastCreatedDocumentType: clearLastCreatedType
          ? null
          : (lastCreatedDocumentType ?? this.lastCreatedDocumentType),
      error: error,
    );
  }

  bool get hasDraft =>
      documentType != null || client != null || items.isNotEmpty || (notes?.isNotEmpty ?? false);

  bool get canCreate =>
      documentType != null && client != null && items.isNotEmpty && !creationInProgress;

  double get subtotal => items.fold(0, (sum, line) => sum + line.total);

  double get taxAmount => subtotal * (taxPct / 100);

  double get discountAmount => subtotal * (discountPct / 100);

  double get total => subtotal + taxAmount - discountAmount;
}

final voiceAssistantControllerProvider =
    StateNotifierProvider<VoiceAssistantController, VoiceAssistantState>(
  (ref) => VoiceAssistantController(ref),
);

class VoiceAssistantController extends StateNotifier<VoiceAssistantState> {
  VoiceAssistantController(this._ref) : super(VoiceAssistantState.initial());

  final Ref _ref;
  AiService? _aiService;
  final bool _useAiInterpreter = true;

  List<Client> _clients = const [];
  bool _clientsLoaded = false;
  bool _isLoadingClients = false;

  Future<void> resetSession() async {
    state = VoiceAssistantState.initial();
  }

  Future<void> processUserInput(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) {
      return;
    }

    _appendUserMessage(input);
    state = state.copyWith(error: null, isProcessing: true);

    try {
      if (state.pendingPrompt != null) {
        await _handlePendingPrompt(input);
      } else {
        await _handleCommand(input);
      }
    } catch (e, stack) {
      debugPrint('❌ [VOICE_ASSISTANT] Error processing input: $e');
      debugPrint('$stack');
      _appendAssistantMessage(
        'I ran into a problem understanding that. Could you rephrase?',
      );
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<void> createDocument() async {
    if (!state.canCreate) {
      _appendAssistantMessage(
        'I still need a client, at least one line item, and whether this is an invoice or estimate before I can create it.',
      );
      return;
    }

    final invoiceRepo = _ref.read(invoiceRepoProvider);
    state = state.copyWith(creationInProgress: true, error: null);

    try {
      final docType = state.documentType ?? InvoiceDocumentType.invoice;
      final result = await invoiceRepo.create(
        clientId: state.client!.id,
        issuedAt: state.issuedAt,
        dueAt: state.dueAt,
        taxPct: state.taxPct,
        discountPct: state.discountPct,
        notes: state.notes,
        documentType: docType.name.toUpperCase(),
        items: state.items
            .map(
              (item) => {
                'description': item.description,
                'qty': item.quantity,
                'unitPrice': item.unitPrice,
              },
            )
            .toList(),
      );

      _appendAssistantMessage(
        '${docType == InvoiceDocumentType.invoice ? 'Invoice' : 'Estimate'} "${result.number}" '
        'is ready. You can review it now.',
      );

      state = state.copyWith(
        creationInProgress: false,
        lastCreatedInvoiceId: result.id,
        lastCreatedDocumentType: docType,
      );

      // Refresh downstream dashboards/lists
      _ref.invalidate(invoiceListProvider);
      _ref.invalidate(homeStatsProvider);
    } catch (e, stack) {
      debugPrint('❌ [VOICE_ASSISTANT] Failed to create document: $e');
      debugPrint('$stack');
      _appendAssistantMessage(
        'Something went wrong while creating the document: $e',
      );
      state = state.copyWith(creationInProgress: false, error: '$e');
    }
  }

  void clearCreationSuccess() {
    state = state.copyWith(
      clearLastCreatedId: true,
      clearLastCreatedType: true,
    );
  }

  Future<void> _handlePendingPrompt(String input) async {
    final prompt = state.pendingPrompt!;
    switch (prompt.type) {
      case VoicePromptType.quantity:
        final qty = _extractNumber(input);
        if (qty == null || qty <= 0) {
          _appendAssistantMessage('I need a numeric quantity greater than zero.');
          return;
        }
        if (prompt.lineIndex == null ||
            prompt.lineIndex! < 0 ||
            prompt.lineIndex! >= state.items.length) {
          _appendAssistantMessage('I lost track of that line item. Let’s add it again.');
          state = state.copyWith(clearPendingPrompt: true);
          return;
        }
        final updatedItems = [...state.items];
        updatedItems[prompt.lineIndex!] =
            updatedItems[prompt.lineIndex!].copyWith(quantity: qty);
        state = state.copyWith(items: updatedItems, clearPendingPrompt: true);
        _appendAssistantMessage(
          'Quantity set to ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}. '
          'Anything else?',
        );
        break;
      case VoicePromptType.price:
        final price = _extractNumber(input);
        if (price == null || price < 0) {
          _appendAssistantMessage('I need a numeric price for that item.');
          return;
        }
        if (prompt.lineIndex == null ||
            prompt.lineIndex! < 0 ||
            prompt.lineIndex! >= state.items.length) {
          _appendAssistantMessage('I lost track of that line item. Let’s add it again.');
          state = state.copyWith(clearPendingPrompt: true);
          return;
        }
        final updatedItems = [...state.items];
        updatedItems[prompt.lineIndex!] =
            updatedItems[prompt.lineIndex!].copyWith(unitPrice: price);
        state = state.copyWith(items: updatedItems, clearPendingPrompt: true);
        _appendAssistantMessage(
          'Unit price set to ${_formatCurrency(price)}.',
        );
        break;
      case VoicePromptType.clientConfirmation:
        final client = _matchClientByName(input);
        if (client == null) {
          _appendAssistantMessage(
            'I still couldn’t find that client. Say "create invoice for" followed by the exact client name.',
          );
          return;
        }
        final docType = state.documentType ?? InvoiceDocumentType.invoice;
        state = state.copyWith(client: client, clearPendingPrompt: true);
        _appendAssistantMessage(
          'Great, I\'ll use ${client.name} for this ${docType.displayLabel.toLowerCase()}.',
        );
        break;
    }
  }

  Future<void> _handleCommand(String rawInput) async {
    final input = rawInput.trim();
    if (_useAiInterpreter) {
      final handledByAi = await _tryHandleWithAi(input);
      if (handledByAi) {
        state = state.copyWith(isProcessing: false);
        return;
      }
    }
    final lower = input.toLowerCase();

    if (lower.contains('reset session') || lower.contains('start over') || lower == 'reset') {
      await resetSession();
      _appendAssistantMessage('Starting fresh. Who is this invoice or estimate for?');
      return;
    }

    if (lower.startsWith('create invoice') || lower.startsWith('start invoice')) {
      await _setDocumentType(InvoiceDocumentType.invoice, input);
      return;
    }
    if (lower.startsWith('create estimate') || lower.startsWith('start estimate')) {
      await _setDocumentType(InvoiceDocumentType.estimate, input);
      return;
    }

    if (lower.startsWith('set client') || lower.startsWith('client is')) {
      await _handleClientAssignment(input);
      return;
    }

    if (_maybeHandleLineItem(input)) {
      return;
    }

    if (_maybeHandleTax(input)) {
      return;
    }

    if (_maybeHandleDiscount(input)) {
      return;
    }

    if (lower.startsWith('set due date') || lower.contains('due date')) {
      if (_handleDueDate(input)) {
        return;
      }
    }

    if (lower.startsWith('set issue date') || lower.startsWith('set issued date')) {
      if (_handleIssuedDate(input)) {
        return;
      }
    }

    if (lower.startsWith('add note') || lower.startsWith('set note') || lower.contains('notes')) {
      final note = input.replaceFirst(RegExp(r'add(ing)? note(s)?', caseSensitive: false), '');
      final clean = note.replaceFirst(RegExp(r'set note(s)? to', caseSensitive: false), '').trim();
      if (clean.isNotEmpty) {
        state = state.copyWith(notes: clean);
        _appendAssistantMessage('Noted. I\'ll include that in the ${_currentDocLabel()}.');
      } else {
        _appendAssistantMessage('Tell me the note you want me to add when you\'re ready.');
      }
      return;
    }

    if (input.contains('ready to send') ||
        input.contains('finish') ||
        input.contains('create it') ||
        input.contains('generate')) {
      await createDocument();
      return;
    }

    if (input.contains('summary') || input.contains('recap')) {
      _appendAssistantMessage(_buildDraftSummary());
      return;
    }

    if (input.contains('what next') || input.contains('help')) {
      _appendAssistantMessage(
        'You can say things like "Create invoice for Acme Corp", "Add item interior painting quantity 1 at 3200", '
        '"Set sales tax to 8 percent", or "Finish and send it".',
      );
      return;
    }

    _appendAssistantMessage(
      'I\'m not sure what to do with that. You can ask for help if you need ideas.',
    );
  }

  Future<void> _setDocumentType(InvoiceDocumentType type, String rawInput) async {
    await _ensureClientsLoaded();
    final nameMatch =
        rawInput.replaceFirst(RegExp('create ${type.name}', caseSensitive: false), '').trim();

    DateTime dueDate = state.dueAt;
    if (type == InvoiceDocumentType.estimate) {
      dueDate = DateTime.now().add(const Duration(days: 14));
    } else {
      dueDate = DateTime.now().add(const Duration(days: 30));
    }

    state = state.copyWith(
      documentType: type,
      dueAt: dueDate,
      clearPendingPrompt: true,
    );

    if (nameMatch.isNotEmpty) {
      final client = _matchClientByName(nameMatch);
      if (client != null) {
        state = state.copyWith(client: client);
        _appendAssistantMessage(
          'Starting a ${type.displayLabel.toLowerCase()} for ${client.name}. Add a line item when you\'re ready.',
        );
        return;
      } else {
        _appendAssistantMessage(
          'I couldn\'t find "$nameMatch" in your client list. You can say "Set client to [name]" or try another name.',
        );
        state = state.copyWith(
          pendingPrompt: const PendingPrompt(
            type: VoicePromptType.clientConfirmation,
            prompt: 'Which client should I use?',
          ),
        );
        return;
      }
    }

    _appendAssistantMessage(
      'Okay, let\'s build a ${type.displayLabel.toLowerCase()}. Which client is this for?',
    );
  }

  Future<void> _handleClientAssignment(String rawInput) async {
    await _ensureClientsLoaded();
    final cleaned = rawInput
        .replaceFirst(RegExp(r'set client (?:to|as)?', caseSensitive: false), '')
        .replaceFirst(RegExp(r'client is', caseSensitive: false), '')
        .trim();

    if (cleaned.isEmpty) {
      _appendAssistantMessage('Tell me the client name you want to use.');
      return;
    }

    final client = _matchClientByName(cleaned);
    if (client == null) {
      _appendAssistantMessage(
        'I couldn\'t find "$cleaned". Could you say the name exactly as it appears in your client list?',
      );
      state = state.copyWith(
        pendingPrompt: const PendingPrompt(
          type: VoicePromptType.clientConfirmation,
          prompt: 'Which client should I pick?',
        ),
      );
      return;
    }

    state = state.copyWith(client: client, clearPendingPrompt: true);
    _appendAssistantMessage('Using ${client.name}. Add a line item or tell me what else to update.');
  }

  bool _maybeHandleLineItem(String rawInput) {
    final lower = rawInput.toLowerCase();
    if (!lower.startsWith('add item') &&
        !lower.startsWith('add line item') &&
        !lower.startsWith('line item')) {
      return false;
    }

    final item = _parseLineItem(rawInput);
    if (item == null) {
      _appendAssistantMessage(
        'I didn\'t understand that line item. Try "Add item electrical rough-in quantity 3 at 250 each."',
      );
      return true;
    }

    final List<InvoiceLineDraft> updatedItems = [...state.items, item.item];
    state = state.copyWith(items: updatedItems, clearPendingPrompt: true);

    if (!item.item.hasQuantity) {
      state = state.copyWith(
        pendingPrompt: PendingPrompt(
          type: VoicePromptType.quantity,
          lineIndex: updatedItems.length - 1,
          prompt: 'How many units for ${item.item.description}?',
        ),
      );
      _appendAssistantMessage('How many units for ${item.item.description}?');
      return true;
    }

    if (!item.item.hasPrice) {
      state = state.copyWith(
        pendingPrompt: PendingPrompt(
          type: VoicePromptType.price,
          lineIndex: updatedItems.length - 1,
          prompt: 'What unit price should I use for ${item.item.description}?',
        ),
      );
      _appendAssistantMessage('What unit price should I use for ${item.item.description}?');
      return true;
    }

    _appendAssistantMessage(
      'Added ${item.item.description} (${item.item.quantity} × ${_formatCurrency(item.item.unitPrice)}).',
    );
    return true;
  }

  bool _maybeHandleTax(String rawInput) {
    final match = RegExp(r'(?:tax|sales tax).{0,10}?(\d+(?:\.\d+)?)')
        .firstMatch(rawInput.toLowerCase());
    if (match == null) {
      return false;
    }
    final value = double.tryParse(match.group(1)!);
    if (value == null) {
      _appendAssistantMessage('I couldn\'t read that tax rate. Try saying "Set tax to 8 percent."');
      return true;
    }
    state = state.copyWith(taxPct: value);
    _appendAssistantMessage('Sales tax set to ${value.toStringAsFixed(2)}%.');
    return true;
  }

  bool _maybeHandleDiscount(String rawInput) {
    final match = RegExp(r'(?:discount|markdown).{0,10}?(\d+(?:\.\d+)?)')
        .firstMatch(rawInput.toLowerCase());
    if (match == null) {
      return false;
    }
    final value = double.tryParse(match.group(1)!);
    if (value == null) {
      _appendAssistantMessage(
        'I couldn\'t read that discount. Try saying "Apply discount 5 percent."',
      );
      return true;
    }
    state = state.copyWith(discountPct: value);
    _appendAssistantMessage('Discount set to ${value.toStringAsFixed(2)}%.');
    return true;
  }

  bool _handleDueDate(String rawInput) {
    final cleaned = rawInput
        .replaceFirst(RegExp(r'set due date to', caseSensitive: false), '')
        .replaceFirst(RegExp(r'due date is', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) {
      _appendAssistantMessage('What date should I use for the due date?');
      return true;
    }
    final parsed = _parseDate(cleaned);
    if (parsed == null) {
      _appendAssistantMessage('I couldn\'t parse that date. Try "Set due date to April 15".');
      return true;
    }
    state = state.copyWith(dueAt: parsed);
    _appendAssistantMessage('Due date set to ${DateFormat.yMMMMd().format(parsed)}.');
    return true;
  }

  bool _handleIssuedDate(String rawInput) {
    final cleaned = rawInput
        .replaceFirst(RegExp(r'set (?:issued|issue) date to', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) {
      _appendAssistantMessage('What issue date should I use?');
      return true;
    }
    final parsed = _parseDate(cleaned);
    if (parsed == null) {
      _appendAssistantMessage('I couldn\'t parse that date. Try "Set issue date to March 3".');
      return true;
    }
    state = state.copyWith(issuedAt: parsed);
    _appendAssistantMessage('Issue date set to ${DateFormat.yMMMMd().format(parsed)}.');
    return true;
  }

  Future<void> _ensureClientsLoaded() async {
    if (_clientsLoaded || _isLoadingClients) {
      return;
    }
    _isLoadingClients = true;
    try {
      final repo = _ref.read(clientRepoProvider);
      _clients = await repo.getAll();
      _clientsLoaded = true;
    } catch (e) {
      debugPrint('❌ [VOICE_ASSISTANT] Failed to load clients: $e');
      _appendAssistantMessage('I had trouble fetching your client list. You can still continue.');
    } finally {
      _isLoadingClients = false;
    }
  }

  Client? _matchClientByName(String input) {
    if (!_clientsLoaded) {
      return null;
    }
    final normalized = input.toLowerCase().trim();
    if (normalized.isEmpty) return null;

    Client? bestMatch;
    var bestScore = 0.0;

    for (final client in _clients) {
      final candidate = client.name.toLowerCase();
      if (candidate == normalized) {
        return client;
      }
      final score = _stringSimilarity(normalized, candidate);
      if (score > bestScore && score > 0.55) {
        bestScore = score;
        bestMatch = client;
      }
    }
    return bestMatch;
  }

  _LineItemParseResult? _parseLineItem(String rawInput) {
    final commandPattern = RegExp(r'^(add|line) (?:a )?(?:line )?item', caseSensitive: false);
    final cleaned = rawInput.replaceFirst(commandPattern, '').trim();
    if (cleaned.isEmpty) {
      return null;
    }

    var description = cleaned;
    double? quantity;
    double? price;

    final quantityRegex =
        RegExp(r'(?:quantity|qty|units?|pieces?)\s*(\d+(?:\.\d+)?)', caseSensitive: false);
    final qtyMatch = quantityRegex.firstMatch(description);
    if (qtyMatch != null) {
      quantity = double.tryParse(qtyMatch.group(1)!);
      description =
          description.replaceRange(qtyMatch.start, qtyMatch.end, '').replaceAll('  ', ' ').trim();
    }

    final priceRegex = RegExp(
      r'(?:at|price|rate|unit price|each|per)\s*\$?(\d+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final priceMatch = priceRegex.firstMatch(description);
    if (priceMatch != null) {
      price = double.tryParse(priceMatch.group(1)!);
      description =
          description.replaceRange(priceMatch.start, priceMatch.end, '').replaceAll('  ', ' ').trim();
    }

    if (description.isEmpty) {
      return null;
    }

    return _LineItemParseResult(
      item: InvoiceLineDraft(
        description: _capitalize(description),
        quantity: quantity ?? 0,
        unitPrice: price ?? 0,
      ),
    );
  }

  Future<bool> _tryHandleWithAi(String input) async {
    try {
      await _ensureClientsLoaded();
      _aiService ??= AiService();
      final draftState = _buildDraftSnapshot();
      final response = await _aiService!.interpretCommand(
        transcript: input,
        draftState: draftState,
      );
      final handled = await _applyAiResponse(response);
      if (!handled) {
        _appendAssistantMessage(
          response['message'] as String? ??
              'I\'m not sure how to act on that. Could you try a different phrasing?',
        );
      }
      return true;
    } catch (e, stack) {
      debugPrint('❌ [VOICE_ASSISTANT] AI interpretation failed: $e');
      debugPrint('$stack');
      _appendAssistantMessage(
        'I had trouble understanding that. Could you say it another way?',
      );
      return false;
    }
  }

  Map<String, dynamic> _buildDraftSnapshot() {
    return {
      'documentType': state.documentType?.name,
      'client': state.client?.name,
      'items': state.items
          .map(
            (e) => {
              'description': e.description,
              'quantity': e.quantity,
              'unitPrice': e.unitPrice,
            },
          )
          .toList(),
      'taxPct': state.taxPct,
      'discountPct': state.discountPct,
      'issuedAt': state.issuedAt.toIso8601String(),
      'dueAt': state.dueAt.toIso8601String(),
      'notes': state.notes,
      'total': state.total,
    };
  }

  Future<bool> _applyAiResponse(Map<String, dynamic> response) async {
    final actions = response['actions'];
    if (actions is List) {
      var handled = false;
      for (final action in actions) {
        if (action is Map<String, dynamic>) {
          handled = await _applyAiAction(action) || handled;
        }
      }
      return handled;
    }
    if (response.containsKey('action')) {
      return await _applyAiAction(Map<String, dynamic>.from(response));
    }
    return false;
  }

  Future<bool> _applyAiAction(Map<String, dynamic> action) async {
    final type = action['action'] as String?;
    if (type == null) return false;
    switch (type) {
      case 'set_type':
        final value = (action['value'] as String?)?.toLowerCase();
        if (value == 'invoice') {
          await _setDocumentType(InvoiceDocumentType.invoice, '');
          return true;
        } else if (value == 'estimate') {
          await _setDocumentType(InvoiceDocumentType.estimate, '');
          return true;
        }
        return false;
      case 'set_client':
        final value = action['value'] as String?;
        if (value == null) return false;
        final client = _matchClientByName(value);
        if (client != null) {
          state = state.copyWith(client: client, clearPendingPrompt: true);
          final confidence = action['confidence'];
          if (confidence is num && confidence < 0.6) {
            _appendAssistantMessage(
              'I chose ${client.name}, but if that’s wrong let me know.',
            );
          } else {
            _appendAssistantMessage('Using ${client.name}.');
          }
          return true;
        }
        _appendAssistantMessage(
          'I couldn\'t find "$value" in your client list.',
        );
        return true;
      case 'add_item':
        final description = action['description'] as String?;
        if (description == null || description.trim().isEmpty) return false;
        final quantity = action['quantity'];
        final unitPrice = action['unit_price'];
        final draft = InvoiceLineDraft(
          description: _capitalize(description),
          quantity: quantity is num ? quantity.toDouble() : 0,
          unitPrice: unitPrice is num ? unitPrice.toDouble() : 0,
        );
        final updatedItems = [...state.items, draft];
        state = state.copyWith(items: updatedItems, clearPendingPrompt: true);
        if (!draft.hasQuantity) {
          state = state.copyWith(
            pendingPrompt: PendingPrompt(
              type: VoicePromptType.quantity,
              lineIndex: updatedItems.length - 1,
              prompt: 'How many units for ${draft.description}?',
            ),
          );
          _appendAssistantMessage('How many units for ${draft.description}?');
        } else if (!draft.hasPrice) {
          state = state.copyWith(
            pendingPrompt: PendingPrompt(
              type: VoicePromptType.price,
              lineIndex: updatedItems.length - 1,
              prompt: 'What unit price should I use for ${draft.description}?',
            ),
          );
          _appendAssistantMessage('What unit price should I use for ${draft.description}?');
        } else {
          _appendAssistantMessage(
            'Added ${draft.description} (${draft.quantity} × ${_formatCurrency(draft.unitPrice)}).',
          );
        }
        return true;
      case 'set_tax':
        final value = action['value'];
        if (value is num) {
          state = state.copyWith(taxPct: value.toDouble());
          _appendAssistantMessage('Sales tax set to ${value.toStringAsFixed(2)}%.');
          return true;
        }
        return false;
      case 'set_discount':
        final value = action['value'];
        if (value is num) {
          state = state.copyWith(discountPct: value.toDouble());
          _appendAssistantMessage('Discount set to ${value.toStringAsFixed(2)}%.');
          return true;
        }
        return false;
      case 'set_issue_date':
        final value = action['value'] as String?;
        final parsedIssue = value != null ? DateTime.tryParse(value) : null;
        if (parsedIssue != null) {
          state = state.copyWith(issuedAt: parsedIssue);
          _appendAssistantMessage(
            'Issue date set to ${DateFormat.yMMMMd().format(parsedIssue)}.',
          );
          return true;
        }
        return false;
      case 'set_due_date':
        final value = action['value'] as String?;
        final parsedDue = value != null ? DateTime.tryParse(value) : null;
        if (parsedDue != null) {
          state = state.copyWith(dueAt: parsedDue);
          _appendAssistantMessage(
            'Due date set to ${DateFormat.yMMMMd().format(parsedDue)}.',
          );
          return true;
        }
        return false;
      case 'set_notes':
        final value = action['value'] as String?;
        if (value != null && value.trim().isNotEmpty) {
          state = state.copyWith(notes: value.trim());
          _appendAssistantMessage('Noted. I\'ll include that in the ${_currentDocLabel()}.');
          return true;
        }
        return false;
      case 'summary':
        _appendAssistantMessage(_buildDraftSummary());
        return true;
      case 'finish':
        await createDocument();
        return true;
      case 'clarify':
        final message = action['message'] as String? ??
            'I\'m not sure how to act on that. Could you clarify?';
        _appendAssistantMessage(message);
        return true;
      default:
        return false;
    }
  }

  String _buildDraftSummary() {
    final buffer = StringBuffer();
    final docType = state.documentType?.displayLabel ?? 'invoice or estimate';
    buffer.writeln('Here\'s where we stand:');
    buffer.writeln('- Type: $docType');
    if (state.client != null) {
      buffer.writeln('- Client: ${state.client!.name}');
    } else {
      buffer.writeln('- Client: not set yet');
    }
    buffer.writeln(
        '- Issue date: ${DateFormat.yMMMd().format(state.issuedAt)}, due ${DateFormat.yMMMd().format(state.dueAt)}');
    if (state.items.isEmpty) {
      buffer.writeln('- No line items added yet.');
    } else {
      buffer.writeln('- ${state.items.length} line item(s):');
      for (final item in state.items) {
        buffer.writeln(
          '  • ${item.description}: ${item.quantity > 0 ? item.quantity : '?'} × ${item.unitPrice > 0 ? _formatCurrency(item.unitPrice) : '?'}',
        );
      }
      buffer.writeln(
          '- Subtotal ${_formatCurrency(state.subtotal)}, tax ${state.taxPct.toStringAsFixed(2)}%, discount ${state.discountPct.toStringAsFixed(2)}%, total ${_formatCurrency(state.total)}');
    }
    if (state.notes != null && state.notes!.isNotEmpty) {
      buffer.writeln('- Notes: ${state.notes}');
    }
    return buffer.toString();
  }

  void _appendUserMessage(String content) {
    final updatedHistory = [
      ...state.history,
      AssistantMessage(role: AssistantRole.user, content: content),
    ];
    state = state.copyWith(history: updatedHistory);
  }

  void _appendAssistantMessage(String content) {
    final updatedHistory = [
      ...state.history,
      AssistantMessage(role: AssistantRole.assistant, content: content),
    ];
    state = state.copyWith(history: updatedHistory);
  }

  double? _extractNumber(String text) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text.replaceAll(',', ''));
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  double _stringSimilarity(String a, String b) {
    final tokensA = a.split(' ');
    final tokensB = b.split(' ');
    var matches = 0;
    for (final token in tokensA) {
      if (tokensB.any((element) => element.contains(token) || token.contains(element))) {
        matches++;
      }
    }
    return matches / math.max(tokensA.length, tokensB.length);
  }

  DateTime? _parseDate(String input) {
    final trimmed = input.trim();
    final formats = [
      DateFormat('MMMM d, yyyy'),
      DateFormat('MMMM d yyyy'),
      DateFormat('MMM d, yyyy'),
      DateFormat('MMM d yyyy'),
      DateFormat('MMMM d'),
      DateFormat('MMM d'),
      DateFormat('M/d/yyyy'),
      DateFormat('M/d/yy'),
      DateFormat('M-d-yyyy'),
      DateFormat('M-d-yy'),
      DateFormat('y-MM-dd'),
    ];

    for (final format in formats) {
      try {
        final parsed = format.parseLoose(trimmed);
        if (!trimmed.contains(parsed.year.toString())) {
          final now = DateTime.now();
          return DateTime(now.year, parsed.month, parsed.day);
        }
        return parsed;
      } catch (_) {
        continue;
      }
    }

    final iso = DateTime.tryParse(trimmed);
    return iso;
  }

  String _formatCurrency(double value) {
    final format = NumberFormat.simpleCurrency();
    return format.format(value);
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  String _currentDocLabel() {
    return state.documentType?.displayLabel ?? 'invoice';
  }
}

class _LineItemParseResult {
  const _LineItemParseResult({required this.item});

  final InvoiceLineDraft item;
}

