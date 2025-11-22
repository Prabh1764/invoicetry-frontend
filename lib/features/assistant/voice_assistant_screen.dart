import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderSubscription;

import '../../data/models/invoice.dart';
import '../../theme/app_theme.dart';
import '../../ui/widgets/billing_card.dart';
import '../../ui/widgets/status_pill.dart';
import '../invoices/invoice_details_screen.dart';
import 'voice_assistant_controller.dart';

class VoiceAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  ConsumerState<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends ConsumerState<VoiceAssistantScreen> {
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  ProviderSubscription<VoiceAssistantState>? _listenerSub;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();

    _listenerSub = ref.listenManual<VoiceAssistantState>(
      voiceAssistantControllerProvider,
      (previous, next) {
        if (previous?.lastCreatedInvoiceId != next.lastCreatedInvoiceId &&
            next.lastCreatedInvoiceId != null) {
          final docType = next.lastCreatedDocumentType ?? InvoiceDocumentType.invoice;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${docType.displayLabel} created successfully. Tap to view.',
              ),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          InvoiceDetailsScreen(invoiceId: next.lastCreatedInvoiceId!),
                    ),
                  );
                },
              ),
            ),
          );
          ref.read(voiceAssistantControllerProvider.notifier).clearCreationSuccess();
        }
      },
    );
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    if (mounted) {
      setState(() {
        _speechAvailable = available;
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    _scrollController.dispose();
    _listenerSub?.close();
    super.dispose();
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Voice capture error: ${error.errorMsg}')),
    );
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
      if (!mounted) return;
      if (!_speechAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permissions are required.')),
        );
        return;
      }
    }

    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      return;
    }

    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );

    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not available on this device.')),
      );
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty) {
            ref.read(voiceAssistantControllerProvider.notifier).processUserInput(text);
          }
          setState(() {
            _isListening = false;
          });
          _speech.stop();
        }
      },
      localeId: 'en_US',
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 8),
    );
  }

  void _sendManualInput() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ref.read(voiceAssistantControllerProvider.notifier).processUserInput(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceAssistantControllerProvider);
    final theme = Theme.of(context);
    final spacing = theme.extension<BillingSpacing>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Billing Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset session',
            onPressed: () => ref.read(voiceAssistantControllerProvider.notifier).resetSession(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: state.history.length,
              itemBuilder: (context, index) {
                final message = state.history[index];
                final isUser = message.role == AssistantRole.user;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      color: isUser
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surface,
                      margin: EdgeInsets.only(
                        top: index == 0 ? 0 : 8,
                        bottom: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          message.content,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isUser
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DraftSummary(state: state),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, spacing?.lg ?? 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Type a command if you prefer…',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: _sendManualInput,
                            icon: const Icon(Icons.send),
                          ),
                        ),
                        onSubmitted: (_) => _sendManualInput(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      heroTag: 'voice-mic',
                      tooltip: _isListening ? 'Listening… tap to stop' : 'Press and speak',
                      backgroundColor: _isListening
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primaryContainer,
                      foregroundColor: _isListening
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onPrimaryContainer,
                      onPressed: _startListening,
                      child: Icon(_isListening ? Icons.hearing : Icons.mic_none_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: state.canCreate
                      ? () => ref.read(voiceAssistantControllerProvider.notifier).createDocument()
                      : null,
                  icon: state.creationInProgress
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    state.documentType == InvoiceDocumentType.estimate
                        ? 'Create estimate'
                        : 'Create invoice',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftSummary extends ConsumerWidget {
  const _DraftSummary({required this.state});

  final VoiceAssistantState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();

    return BillingCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.documentType?.displayLabel ?? 'Document type not set',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.client?.name ?? 'No client selected yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors?.textSecondary ??
                            theme.colorScheme.onSurface.withOpacity(0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: state.items.isEmpty
                    ? 'No items'
                    : '${state.items.length} item${state.items.length == 1 ? '' : 's'}',
                variant:
                    state.items.isEmpty ? StatusPillVariant.warning : StatusPillVariant.success,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryField(
                  label: 'Issued',
                  value: DateFormat.yMMMd().format(state.issuedAt),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryField(
                  label: 'Due',
                  value: DateFormat.yMMMd().format(state.dueAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.items.isEmpty)
            Text(
              'Add a line item (e.g. "Add item asphalt repair quantity 2 at 450 each").',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            )
          else
            Column(
              children: [
                for (final item in state.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.description,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          item.quantity > 0
                              ? '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} × ${NumberFormat.simpleCurrency().format(item.unitPrice)}'
                              : 'qty?',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: theme.textTheme.bodyLarge),
              Text(
                NumberFormat.simpleCurrency().format(state.subtotal),
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tax ${state.taxPct.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodyMedium),
              Text(
                NumberFormat.simpleCurrency().format(state.taxAmount),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Discount ${state.discountPct.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodyMedium),
              Text(
                '-${NumberFormat.simpleCurrency().format(state.discountAmount)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                NumberFormat.simpleCurrency().format(state.total),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (state.notes != null && state.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Notes',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              state.notes!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryField extends StatelessWidget {
  const _SummaryField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BillingCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

