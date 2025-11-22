import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import '../../widgets/app_card.dart';
import '../../widgets/tag_chip.dart';
import '../../data/models/invoice.dart';
import '../../data/models/invoice_image.dart';
import 'package:dio/dio.dart';
import '../../data/repositories/invoice_repo.dart';
import '../../data/repositories/invoice_images_repo.dart';
import '../../data/repositories/payment_repo.dart';
import '../../data/services/api_client.dart';
import '../../data/services/pdf_service.dart';
import '../auth/providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'edit_invoice_screen.dart';
import '../pdf/pdf_viewer_screen.dart';
import 'invoice_list_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

final invoiceDetailsProvider = FutureProvider.autoDispose.family<Invoice, String>((ref, id) async {
  try {
    debugPrint('🔄 [INVOICE_DETAILS_PROVIDER] Fetching invoice: $id');
    final repo = ref.watch(invoiceRepoProvider);
    final invoice = await repo.getById(id);
    debugPrint('✅ [INVOICE_DETAILS_PROVIDER] Invoice fetched: ${invoice.number}');
    return invoice;
  } catch (e, stack) {
    debugPrint('❌ [INVOICE_DETAILS_PROVIDER] Error fetching invoice $id: $e');
    debugPrint('   - Stack: $stack');
    rethrow;
  }
});

class InvoiceDetailsScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends ConsumerState<InvoiceDetailsScreen> {
  bool _isConvertingEstimate = false;
  bool _isGeneratingPaymentLink = false;
  bool _isSendingReminder = false;
  Map<String, dynamic>? _paymentLink;

  Future<void> _generatePdf(WidgetRef ref, BuildContext context) async {
    try {
      final repo = ref.read(invoiceRepoProvider);
      await repo.generatePdf(widget.invoiceId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generated successfully')),
        );
        ref.invalidate(invoiceDetailsProvider(widget.invoiceId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showEmailDialog(Invoice invoice, BuildContext context) async {
    if (!context.mounted) return;
    
    final clientEmail = invoice.client?.email ?? '';
    
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _EmailDialogContent(
        initialEmail: clientEmail,
      ),
    );
    
    if (!context.mounted) return;
    
    if (result != null && result.isNotEmpty) {
      await _shareViaEmail(invoice, context, result);
    }
  }

  Future<void> _shareViaEmail(Invoice invoice, BuildContext context, [String? emailAddress]) async {
    // Use provided email or get from invoice, or show dialog if no email
    final email = emailAddress ?? invoice.client?.email ?? '';
    
    if (email.isEmpty) {
      // Show dialog to enter email
      await _showEmailDialog(invoice, context);
      return;
    }
    
    // Send email via backend
    await _sendEmailViaBackend(invoice, context, email);
  }

  Future<void> _sendEmailViaBackend(Invoice invoice, BuildContext context, String email) async {
    if (!context.mounted) return;
    
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Sending email...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final apiClient = ref.read(apiClientProvider);
      debugPrint('📧 [EMAIL_SEND] Sending email to: $email for invoice: ${invoice.id}');
      
      final response = await apiClient.dio.post(
        '/invoices/${invoice.id}/send-email',
        data: {'to': email},
      );

      if (!context.mounted) return;

      debugPrint('✅ [EMAIL_SEND] Email sent successfully: ${response.data}');
      
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Email sent successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('❌ [EMAIL_SEND] Error sending email: $e');
      if (!context.mounted) return;
      
      messenger.hideCurrentSnackBar();
      String errorMessage = 'Failed to send email';
      if (e is DioException && e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'] as String;
        } else {
          errorMessage = 'Failed to send email: ${e.response?.statusCode}';
        }
      } else if (e is DioException) {
        errorMessage = 'Network error: ${e.message}';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _shareViaEmailInternal(Invoice invoice, BuildContext context, String email) async {
    // Declare messenger outside try block so it's accessible in catch
    ScaffoldMessengerState? messenger;
    
    try {
      // First, ensure PDF is generated
      if (invoice.pdfUrl == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please generate PDF first')),
          );
        }
        return;
      }

      // Show loading indicator
      if (context.mounted) {
        messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Preparing PDF for sharing...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get the full PDF URL
      final apiClient = ref.read(apiClientProvider);
      String pdfUrl = invoice.pdfUrl!;
      
      debugPrint('📄 [EMAIL_SHARE] PDF URL from invoice: $pdfUrl');
      
      // Extract the filename from the path
      String pdfFileName;
      if (pdfUrl.contains('path=')) {
        // URL format: /pdf/file?path=FILENAME.pdf
        final pathMatch = RegExp(r'path=([^&]+)').firstMatch(pdfUrl);
        pdfFileName = pathMatch != null ? Uri.decodeComponent(pathMatch.group(1)!) : pdfUrl.split('/').last;
      } else if (pdfUrl.contains('/')) {
        // Path format: /pdf/file?path=... or just FILENAME.pdf
        pdfFileName = pdfUrl.split('/').last.split('?').first;
      } else {
        pdfFileName = pdfUrl;
      }
      
      debugPrint('📄 [EMAIL_SHARE] Extracted filename: $pdfFileName');
      
      // Get signed URL first (or use direct PDF access)
      // Try to get signed URL from the backend
      String actualPdfUrl;
      try {
        debugPrint('🔗 [EMAIL_SHARE] Getting signed URL...');
        final signedUrlResponse = await apiClient.dio.get(
          '/pdf/signed-url',
          queryParameters: {'path': pdfFileName},
          options: Options(
            responseType: ResponseType.json,
            validateStatus: (status) => status! < 500,
          ),
        );
        
        if (signedUrlResponse.statusCode == 200 && signedUrlResponse.data is Map) {
          final signedUrl = signedUrlResponse.data['signedUrl'] as String?;
          if (signedUrl != null && signedUrl.isNotEmpty) {
            actualPdfUrl = signedUrl;
            debugPrint('✅ [EMAIL_SHARE] Got signed URL: $actualPdfUrl');
          } else {
            throw Exception('No signed URL in response');
          }
        } else {
          throw Exception('Failed to get signed URL');
        }
      } catch (e) {
        debugPrint('⚠️ [EMAIL_SHARE] Failed to get signed URL: $e, trying direct access');
        // Fallback: try direct access (may require auth)
        actualPdfUrl = pdfUrl.startsWith('http') 
            ? pdfUrl 
            : '${apiClient.baseUrl}/pdf/view?path=${Uri.encodeComponent(pdfFileName)}';
      }
      
      debugPrint('📥 [EMAIL_SHARE] Downloading PDF from: $actualPdfUrl');

      // Use Dio for authenticated download (has auth interceptor built-in)
      // Increase timeout for large PDFs
      // Note: If it's a signed URL, it may be a full URL or relative
      final isFullUrl = actualPdfUrl.startsWith('http');
      final downloadUrl = isFullUrl 
          ? actualPdfUrl 
          : '${apiClient.baseUrl}${actualPdfUrl.startsWith('/') ? '' : '/'}$actualPdfUrl';
      
      debugPrint('📥 [EMAIL_SHARE] Final download URL: $downloadUrl');
      
      final dioResponse = await apiClient.dio.get(
        downloadUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
          receiveTimeout: const Duration(seconds: 120), // Increased for large PDFs
          sendTimeout: const Duration(seconds: 60),
          // Don't add auth header if it's a signed URL (already has signature)
          extra: isFullUrl ? {'noAuth': true} : {},
        ),
      );

      if (dioResponse.statusCode != 200) {
        debugPrint('❌ [EMAIL_SHARE] PDF download failed: ${dioResponse.statusCode}');
        throw Exception('Failed to download PDF: ${dioResponse.statusCode}');
      }

      final pdfBytesList = dioResponse.data as List<int>;
      final pdfBytes = Uint8List.fromList(pdfBytesList);
      debugPrint('✅ [EMAIL_SHARE] PDF downloaded: ${pdfBytes.length} bytes');

      final docLabel = invoice.isEstimate ? 'estimate' : 'invoice';
      final saveFileName = '${docLabel}_${invoice.number.replaceAll(RegExp(r'[^\w-]'), '_')}.pdf';
      
      XFile xFile;
      File? tempFile;
      
      if (kIsWeb) {
        // For web, create a Blob/File from bytes
        debugPrint('💾 [EMAIL_SHARE] Creating file for web...');
        xFile = XFile.fromData(
          pdfBytes,
          mimeType: 'application/pdf',
          name: saveFileName,
        );
      } else {
        // For mobile/desktop, save to temporary directory
        debugPrint('💾 [EMAIL_SHARE] Saving PDF to temporary file...');
        final tempDir = await getTemporaryDirectory();
        final filePath = path.join(tempDir.path, saveFileName);
        tempFile = File(filePath);
        
        // Ensure parent directory exists
        await tempFile.parent.create(recursive: true);
        
        await tempFile.writeAsBytes(pdfBytes);
        
        // Verify file was written
        final savedFileSize = await tempFile.length();
        debugPrint('✅ [EMAIL_SHARE] PDF saved to: $filePath');
        debugPrint('✅ [EMAIL_SHARE] Saved file size: $savedFileSize bytes (expected: ${pdfBytes.length} bytes)');
        
        if (savedFileSize != pdfBytes.length) {
          throw Exception('File size mismatch: expected ${pdfBytes.length} bytes, got $savedFileSize bytes');
        }
        
        xFile = XFile(
          filePath, 
          mimeType: 'application/pdf', 
          name: saveFileName,
        );
      }

      // Prepare email subject and body
      final total = invoice.totalCached?.toStringAsFixed(2) ?? '0.00';
      final docLabelUpper = invoice.isEstimate ? 'Estimate' : 'Invoice';
      final subject = '$docLabelUpper #${invoice.number} - \$$total';
      final body = 'Hi ${invoice.client?.name},\n\nPlease find attached your $docLabel #${invoice.number} for \$$total.\n\nThank you!';

      // Share the PDF via Email using share sheet
      // On iOS, share sheet with Mail app allows PDF attachment
      debugPrint('📧 [EMAIL_SHARE] Sharing via email: $email');
      
      if (kIsWeb) {
        // On web: Use mailto: URL scheme with PDF attached via share sheet
        debugPrint('🌐 [EMAIL_SHARE] Sharing on web...');
        
        // Try mailto: URL first
        try {
          final mailtoUrl = 'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
          final mailtoUri = Uri.parse(mailtoUrl);
          
          if (await canLaunchUrl(mailtoUri)) {
            await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
            debugPrint('✅ [EMAIL_SHARE] Email client opened');
            
            // Also show share sheet for PDF attachment
            await Future.delayed(const Duration(milliseconds: 500));
            await Share.shareXFiles(
              [xFile],
              text: body,
              subject: subject,
            );
            
            if (context.mounted) {
              messenger?.hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email client opened. Use share sheet to attach PDF.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('⚠️ [EMAIL_SHARE] Mailto failed: $e, using share sheet only');
          await Share.shareXFiles(
            [xFile],
            text: body,
            subject: subject,
          );
          
          if (context.mounted) {
            messenger?.hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Share sheet opened. Select Mail to send email with PDF.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // On mobile (iOS/Android): Show share sheet with Mail app option
        // Mail app supports PDF attachments via share sheet
        debugPrint('📱 [EMAIL_SHARE] Sharing file on mobile/desktop...');
        debugPrint('📱 [EMAIL_SHARE] File path: ${xFile.path}');
        debugPrint('📱 [EMAIL_SHARE] File name: ${xFile.name}');
        debugPrint('📱 [EMAIL_SHARE] Email: $email');
        debugPrint('📱 [EMAIL_SHARE] Subject: $subject');
        debugPrint('📱 [EMAIL_SHARE] Body: $body');
        
        try {
          final fileSize = await xFile.length();
          debugPrint('📱 [EMAIL_SHARE] File size: $fileSize bytes');
          
          final fileExists = await File(xFile.path).exists();
          debugPrint('📱 [EMAIL_SHARE] File exists: $fileExists');
          
          // Verify file exists before sharing
          if (!fileExists) {
            throw Exception('PDF file not found at ${xFile.path}');
          }
          
          // On iOS, show share sheet with PDF and message
          // The share sheet will allow selecting Mail app with PDF attachment
          debugPrint('📱 [EMAIL_SHARE] Showing share sheet with PDF and message...');
          
          // Show share sheet with PDF and message
          // When user selects Mail, PDF will be attached and they can enter the email
          await Share.shareXFiles(
            [xFile],
            text: 'To: $email\n\n$body',
            subject: subject,
          );
          
          debugPrint('✅ [EMAIL_SHARE] Share sheet displayed');
          
          // After share sheet is shown, try to open Mail app with mailto: URL
          // This will help user know where to send, but PDF is already in share sheet
          try {
            await Future.delayed(const Duration(milliseconds: 300));
            
            final mailtoUrl = 'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
            final mailtoUri = Uri.parse(mailtoUrl);
            
            if (await canLaunchUrl(mailtoUri)) {
              debugPrint('📧 [EMAIL_SHARE] Opening Mail app with email: $email');
              await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
              debugPrint('✅ [EMAIL_SHARE] Mail app opened');
            }
          } catch (mailtoError) {
            debugPrint('⚠️ [EMAIL_SHARE] Could not open Mail app: $mailtoError');
            // Not critical - share sheet already shown
          }
          
          if (context.mounted) {
            messenger?.hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Share sheet opened. Select Mail to send email with PDF.\nRecipient: $email'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          
          debugPrint('✅ [EMAIL_SHARE] Email share completed');
        } catch (shareError) {
          debugPrint('❌ [EMAIL_SHARE] Share error: $shareError');
          
          if (context.mounted) {
            messenger?.hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to share: $shareError'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }

      // Clean up (only for non-web platforms)
      if (!kIsWeb && tempFile != null) {
        if (await tempFile.exists()) {
          // Keep file for a bit in case share takes time, but schedule deletion
          Future.delayed(const Duration(minutes: 5), () async {
            try {
              if (await tempFile!.exists()) {
                await tempFile!.delete();
                debugPrint('🗑️ [EMAIL_SHARE] Temporary file deleted');
              }
            } catch (e) {
              debugPrint('Error deleting temp file: $e');
            }
          });
        }
      }

      if (context.mounted) {
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          const SnackBar(content: Text('Email ready to send with PDF attached')),
        );
      }
      debugPrint('✅ [EMAIL_SHARE] Share completed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ [EMAIL_SHARE] Error sharing via email: $e');
      debugPrint('   - Stack: $stackTrace');
      if (context.mounted) {
        messenger?.hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _downloadPdfOnWeb(Uint8List pdfBytes, String fileName) {
    if (!kIsWeb) return;
    
    try {
      // On web, trigger a download using blob URL
      // Import dart:html conditionally for web-only code
      debugPrint('📥 [WHATSAPP_SHARE] Triggering PDF download: $fileName (${pdfBytes.length} bytes)');
      
      // Use platform-specific implementation
      // On web, we can use Share.shareXFiles to download
      // Or trigger download manually via dart:html
      // For now, just log - the Share API should handle it
      
      // Alternative: Use Share.shareXFiles without text to trigger download dialog
      Share.shareXFiles(
        [XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: fileName)],
      ).catchError((e) {
        debugPrint('⚠️ [WHATSAPP_SHARE] Download trigger failed: $e');
      });
    } catch (e) {
      debugPrint('⚠️ [WHATSAPP_SHARE] Could not trigger download: $e');
    }
  }

  Future<void> _share(Invoice invoice, BuildContext context) async {
    ScaffoldMessengerState? messenger;
    
    try {
      // First, ensure PDF is generated
      if (invoice.pdfUrl == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please generate PDF first')),
          );
        }
        return;
      }

      // Show loading indicator
      if (context.mounted) {
        messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Preparing PDF for sharing...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get the full PDF URL
      final apiClient = ref.read(apiClientProvider);
      String pdfUrl = invoice.pdfUrl!;
      
      // Extract the filename from the path
      String pdfFileName;
      if (pdfUrl.contains('path=')) {
        final pathMatch = RegExp(r'path=([^&]+)').firstMatch(pdfUrl);
        pdfFileName = pathMatch != null ? Uri.decodeComponent(pathMatch.group(1)!) : pdfUrl.split('/').last;
      } else if (pdfUrl.contains('/')) {
        pdfFileName = pdfUrl.split('/').last.split('?').first;
      } else {
        pdfFileName = pdfUrl;
      }
      
      // Get signed URL or use direct access
      String actualPdfUrl;
      try {
        final signedUrlResponse = await apiClient.dio.get(
          '/pdf/signed-url',
          queryParameters: {'path': pdfFileName},
          options: Options(
            responseType: ResponseType.json,
            validateStatus: (status) => status! < 500,
          ),
        );
        
        if (signedUrlResponse.statusCode == 200 && signedUrlResponse.data is Map) {
          final signedUrl = signedUrlResponse.data['signedUrl'] as String?;
          if (signedUrl != null && signedUrl.isNotEmpty) {
            actualPdfUrl = signedUrl;
          } else {
            throw Exception('No signed URL in response');
          }
        } else {
          throw Exception('Failed to get signed URL');
        }
      } catch (e) {
        actualPdfUrl = pdfUrl.startsWith('http') 
            ? pdfUrl 
            : '${apiClient.baseUrl}/pdf/view?path=${Uri.encodeComponent(pdfFileName)}';
      }
      
      // Download PDF
      final isFullUrl = actualPdfUrl.startsWith('http');
      final downloadUrl = isFullUrl 
          ? actualPdfUrl 
          : '${apiClient.baseUrl}${actualPdfUrl.startsWith('/') ? '' : '/'}$actualPdfUrl';
      
      final dioResponse = await apiClient.dio.get(
        downloadUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
          extra: isFullUrl ? {'noAuth': true} : {},
        ),
      );

      if (dioResponse.statusCode != 200) {
        throw Exception('Failed to download PDF: ${dioResponse.statusCode}');
      }

      final pdfBytesList = dioResponse.data as List<int>;
      final pdfBytes = Uint8List.fromList(pdfBytesList);

      final docLabel = invoice.isEstimate ? 'estimate' : 'invoice';
      final saveFileName = '${docLabel}_${invoice.number.replaceAll(RegExp(r'[^\w-]'), '_')}.pdf';
      
      XFile xFile;
      File? tempFile;
      
      if (kIsWeb) {
        xFile = XFile.fromData(
          pdfBytes,
          mimeType: 'application/pdf',
          name: saveFileName,
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final filePath = path.join(tempDir.path, saveFileName);
        tempFile = File(filePath);
        
        await tempFile.parent.create(recursive: true);
        await tempFile.writeAsBytes(pdfBytes);
        
        xFile = XFile(
          filePath, 
          mimeType: 'application/pdf', 
          name: saveFileName,
        );
      }

      // Prepare message
      final total = invoice.totalCached?.toStringAsFixed(2) ?? '0.00';
      final docLabelUpper = invoice.isEstimate ? 'Estimate' : 'Invoice';
      final message = '$docLabelUpper #${invoice.number} - \$$total';

      // Use system share sheet
      if (context.mounted) {
        messenger?.hideCurrentSnackBar();
      }
      
      await Share.shareXFiles(
        [xFile],
        text: message,
        subject: '$docLabelUpper #${invoice.number}',
      );
      
      if (context.mounted) {
        messenger?.hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Share sheet opened'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Clean up (only for non-web platforms)
      if (!kIsWeb && tempFile != null) {
        Future.delayed(const Duration(minutes: 5), () async {
          try {
            if (await tempFile!.exists()) {
              await tempFile!.delete();
              debugPrint('🗑️ [SHARE] Cleaned up temporary file');
            }
          } catch (e) {
            debugPrint('⚠️ [SHARE] Could not delete temp file: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [SHARE] Error: $e');
      if (context.mounted) {
        messenger?.hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadPaymentLink(Invoice invoice, WidgetRef ref) async {
    try {
      final repo = ref.read(paymentRepoProvider);
      final link = await repo.getPaymentLink(invoice.id);
      if (mounted) {
        setState(() {
          _paymentLink = link;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [PAYMENT_LINK] Could not load payment link: $e');
    }
  }

  Future<void> _generatePaymentLink(Invoice invoice, WidgetRef ref, BuildContext context) async {
    if (_isGeneratingPaymentLink) return;

    setState(() {
      _isGeneratingPaymentLink = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(paymentRepoProvider);
      final result = await repo.generatePaymentLink(invoice.id);
      
      if (mounted) {
        setState(() {
          _paymentLink = result;
          _isGeneratingPaymentLink = false;
        });
      }

      // Reload invoice to get updated status
      ref.invalidate(invoiceDetailsProvider(invoice.id));
      ref.invalidate(invoiceListProvider);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Payment link generated successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingPaymentLink = false;
        });
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error generating payment link: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _showPaymentLinkDialog(Invoice invoice, BuildContext context) async {
    final paymentLinkUrl = _paymentLink?['paymentLinkUrl'] as String?;
    if (paymentLinkUrl == null) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this link with your customer to accept payment:'),
            const SizedBox(height: 16),
            SelectableText(
              paymentLinkUrl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: paymentLinkUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Link'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Share.share(
                paymentLinkUrl,
                subject: 'Payment Link for Invoice #${invoice.number}',
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReminder(Invoice invoice, WidgetRef ref, BuildContext context) async {
    if (_isSendingReminder) return;

    // Only send reminders for invoices (not estimates) that are not paid
    if (invoice.isEstimate || invoice.status == InvoiceStatus.paid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminders can only be sent for unpaid invoices'),
        ),
      );
      return;
    }

    // Check if client has email
    if (invoice.client?.email == null || invoice.client!.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client email is required to send reminders'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSendingReminder = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(paymentRepoProvider);
      await repo.sendReminder(invoice.id);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Payment reminder sent successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload invoice to update reminder count
      ref.invalidate(invoiceDetailsProvider(invoice.id));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error sending reminder: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReminder = false;
        });
      }
    }
  }

  Future<void> _convertEstimate(Invoice invoice, WidgetRef ref) async {
    if (_isConvertingEstimate) return;
    setState(() {
      _isConvertingEstimate = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(invoiceRepoProvider);
      final converted = await repo.convertEstimateToInvoice(invoice.id);
      ref.invalidate(invoiceDetailsProvider(invoice.id));
      ref.invalidate(invoiceListProvider);
      ref.invalidate(homeStatsProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Quote converted to invoice ${converted.number}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              if (mounted) {
                context.go('/invoices/${converted.id}');
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
          _isConvertingEstimate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ [INVOICE_DETAILS] Building screen for invoice: ${widget.invoiceId}');
    final invoice = ref.watch(invoiceDetailsProvider(widget.invoiceId));
    final isEstimate = invoice.maybeWhen(
      data: (inv) => inv.isEstimate,
      orElse: () => false,
    );
    final documentLabel = isEstimate ? 'Quote' : 'Invoice';

    return Scaffold(
      appBar: AppBar(
        title: Text('$documentLabel Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Edit button in AppBar (icon only)
          Builder(
            builder: (context) {
              final invoice = ref.watch(invoiceDetailsProvider(widget.invoiceId));
              return invoice.maybeWhen(
                data: (inv) {
                  final editRouteBase = inv.isEstimate ? '/estimates' : '/invoices';
                  return IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => context.push('$editRouteBase/${inv.id}/edit'),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
      body: invoice.when(
        data: (inv) {
          debugPrint('✅ [INVOICE_DETAILS] Document loaded: ${inv.number}');
          
          // Load payment link when invoice loads (only for invoices, not estimates)
          if (!inv.isEstimate && inv.status != InvoiceStatus.paid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadPaymentLink(inv, ref);
            });
          }
          
          final totals = inv.calculateTotals();
          final dateFormat = DateFormat('MMM d, y');
          final dueLabel = inv.isEstimate ? 'Valid until' : 'Due';
          final totalLabel = inv.isEstimate ? 'Quote total' : 'Total';
          final notesLabel = inv.isEstimate ? 'Notes & follow-up' : 'Notes';
          final statusLabel = inv.isEstimate ? 'QUOTE' : inv.status.displayName;
          final statusType =
              inv.isEstimate ? TagType.draft : _getTagType(inv.status);
          final pdfButtonLabel =
              inv.isEstimate ? 'Generate Quote PDF' : 'Generate PDF';
          final pdfPreviewLabel =
              inv.isEstimate ? 'View Quote PDF' : 'View PDF';
          final editRouteBase = inv.isEstimate ? '/estimates' : '/invoices';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            inv.number,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          TagChip(label: statusLabel, type: statusType),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (inv.client != null) ...[
                        Text(
                          'Client: ${inv.client!.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (inv.client!.email != null)
                          Text('Email: ${inv.client!.email}'),
                        if (inv.client!.phone != null)
                          Text('Phone: ${inv.client!.phone}'),
                      ],
                      const Divider(),
                      Text('Issued: ${dateFormat.format(inv.issuedAt)}'),
                      Text('$dueLabel: ${dateFormat.format(inv.dueAt)}'),
                    ],
                  ),
                ),
                if (inv.items != null && inv.items!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Line items',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Divider(),
                        ...inv.items!.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(item.description)),
                                Text(
                                  '${item.qty} × \$${item.unitPrice.toStringAsFixed(2)} = \$${item.lineTotal.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    children: [
                      _TotalRow(label: 'Subtotal', amount: totals['subtotal']!),
                      _TotalRow(
                        label: 'Tax (${inv.taxPct}%)',
                        amount: totals['taxAmount']!,
                      ),
                      _TotalRow(
                        label: 'Discount (${inv.discountPct}%)',
                        amount: -totals['discountAmount']!,
                      ),
                      const Divider(),
                      _TotalRow(
                        label: totalLabel,
                        amount: totals['total']!,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                if (inv.notes != null && inv.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notesLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(inv.notes!),
                      ],
                    ),
                  ),
                ],
                // Work Photos section
                const SizedBox(height: 16),
                _WorkPhotosSection(invoiceId: inv.id, invoice: inv),
                const SizedBox(height: 24),
                // Actions - Organized into clean sections
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // PDF Actions Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PDF',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _generatePdf(ref, context),
                                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                                      label: const Text('Generate PDF'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => context.push('/invoices/${widget.invoiceId}/customize'),
                                      icon: const Icon(Icons.palette, size: 18),
                                      label: const Text('Customize'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.secondary,
                                        foregroundColor: Theme.of(context).colorScheme.onSecondary,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (inv.pdfUrl != null)
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final apiClient = ApiClient();
                                            final pdfService = PdfService(apiClient);
                                            
                                            String pdfUrl = inv.pdfUrl!;
                                            String pdfFileName;
                                            if (pdfUrl.contains('path=')) {
                                              final pathMatch = RegExp(r'path=([^&]+)').firstMatch(pdfUrl);
                                              if (pathMatch != null) {
                                                pdfFileName = Uri.decodeComponent(pathMatch.group(1)!);
                                              } else {
                                                throw Exception('Could not extract filename');
                                              }
                                            } else {
                                              final uri = Uri.tryParse(pdfUrl);
                                              if (uri != null && uri.hasQuery && uri.queryParameters.containsKey('path')) {
                                                pdfFileName = Uri.decodeComponent(uri.queryParameters['path']!);
                                              } else {
                                                pdfFileName = pdfUrl.split('/').last.split('?').first;
                                              }
                                            }
                                            
                                            final signedUrl = await pdfService.getSignedUrl(pdfFileName);
                                            final encoded = base64Url.encode(utf8.encode(signedUrl));
                                            context.push('/pdf/$encoded');
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error opening PDF: $e')),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.visibility, size: 18),
                                        label: const Text('View PDF'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Share Actions Card - More visible and placed first
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Share',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showEmailDialog(inv, context),
                                      icon: const Icon(Icons.email, size: 20),
                                      label: const Text('Email'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _share(inv, context),
                                      icon: const Icon(Icons.share, size: 20),
                                      label: const Text('Share'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Payment Actions Card (only for unpaid invoices)
                      if (!inv.isEstimate && inv.status != InvoiceStatus.paid) ...[
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _paymentLink != null
                                          ? ElevatedButton.icon(
                                              onPressed: () => _showPaymentLinkDialog(inv, context),
                                              icon: const Icon(Icons.payment, size: 18),
                                              label: const Text('Payment Link'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Theme.of(context).colorScheme.primary,
                                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                elevation: 0,
                                              ),
                                            )
                                          : ElevatedButton.icon(
                                              onPressed: _isGeneratingPaymentLink
                                                  ? null
                                                  : () => _generatePaymentLink(inv, ref, context),
                                              icon: _isGeneratingPaymentLink
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : const Icon(Icons.payment, size: 18),
                                              label: Text(_isGeneratingPaymentLink ? 'Generating...' : 'Get Payment Link'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Theme.of(context).colorScheme.primary,
                                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                elevation: 0,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _isSendingReminder
                                            ? null
                                            : () => _sendReminder(inv, ref, context),
                                        icon: _isSendingReminder
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.notifications_active, size: 18),
                                        label: const Text('Remind'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      
                      // Estimate Convert Button
                      if (inv.isEstimate) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isConvertingEstimate
                                ? null
                                : () => _convertEstimate(inv, ref),
                            icon: _isConvertingEstimate
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.swap_horiz_rounded),
                            label: Text(_isConvertingEstimate ? 'Converting...' : 'Convert to Invoice'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () {
          debugPrint('⏳ [INVOICE_DETAILS] Loading document...');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading $documentLabel...'),
              ],
            ),
          );
        },
        error: (error, stack) {
          debugPrint('❌ [INVOICE_DETAILS] Error loading document: $error');
          debugPrint('   - Stack: $stack');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading $documentLabel',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(
                        invoiceDetailsProvider(widget.invoiceId),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go back'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  TagType _getTagType(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return TagType.draft;
      case InvoiceStatus.pending:
        return TagType.pending;
      case InvoiceStatus.paid:
        return TagType.paid;
      case InvoiceStatus.overdue:
        return TagType.overdue;
    }
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;

  const _TotalRow({required this.label, required this.amount, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isTotal ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: isTotal ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 18) : null,
          ),
        ],
      ),
    );
  }
}

class _EmailDialogContent extends StatefulWidget {
  final String initialEmail;

  const _EmailDialogContent({
    required this.initialEmail,
  });

  @override
  State<_EmailDialogContent> createState() => _EmailDialogContentState();
}

class _EmailDialogContentState extends State<_EmailDialogContent> {
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send via Email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recipient email address:'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              hintText: 'Enter email address',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
          if (widget.initialEmail.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No email found for this client',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final email = _emailController.text.trim();
            if (email.isNotEmpty && email.contains('@')) {
              Navigator.of(context).pop(email);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid email address'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}

// Work Photos Section Widget
class _WorkPhotosSection extends ConsumerStatefulWidget {
  final String invoiceId;
  final Invoice invoice;

  const _WorkPhotosSection({
    required this.invoiceId,
    required this.invoice,
  });

  @override
  ConsumerState<_WorkPhotosSection> createState() => _WorkPhotosSectionState();
}

class _WorkPhotosSectionState extends ConsumerState<_WorkPhotosSection> {
  static const int maxPhotos = 3;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isDeleting = false;

  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return;

    final images = widget.invoice.images ?? [];
    if (images.length >= maxPhotos) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum $maxPhotos photos allowed per invoice'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    try {
      setState(() {
        _isUploading = true;
      });

      // Show dialog to choose camera or gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Pick image from selected source
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Upload image
      final repo = ref.read(invoiceImagesRepoProvider);
      await repo.uploadImage(widget.invoiceId, pickedFile);

      // Refresh invoice details
      ref.invalidate(invoiceDetailsProvider(widget.invoiceId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteImage(String imageId) async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
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

    if (confirmed != true) return;

    try {
      setState(() {
        _isDeleting = true;
      });

      final repo = ref.read(invoiceImagesRepoProvider);
      await repo.deleteImage(widget.invoiceId, imageId);

      // Refresh invoice details
      ref.invalidate(invoiceDetailsProvider(widget.invoiceId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete photo: $e'),
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
    final images = widget.invoice.images ?? [];
    final canAddMore = images.length < maxPhotos;
    final apiClient = ref.read(apiClientProvider);
    final baseUrl = apiClient.baseUrl;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Work Photos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${images.length}/$maxPhotos',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: images.length + (canAddMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show add photo icon as the last item when there's space
              if (index == images.length && canAddMore) {
                return InkWell(
                  onTap: _isUploading ? null : _pickAndUploadImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    ),
                    child: _isUploading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Photo',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                  ),
                );
              }

              // Show actual photo
              final image = images[index];
              final imageUrl = image.url.startsWith('http')
                  ? image.url
                  : '$baseUrl/invoices/${widget.invoiceId}/images/${image.filename}';

              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: _isDeleting
                            ? null
                            : () => _deleteImage(image.id),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

