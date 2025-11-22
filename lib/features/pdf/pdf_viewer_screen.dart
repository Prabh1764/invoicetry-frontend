import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// Conditionally import webview_flutter (not available on web)
import 'package:webview_flutter/webview_flutter.dart'
    if (dart.library.html) 'webview_stub.dart';
import 'package:dio/dio.dart';
import '../../data/services/api_client.dart';

// Conditionally import web implementation
import 'pdf_viewer_screen_stub.dart'
    if (dart.library.html) 'pdf_viewer_screen_web.dart' as web_impl;

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadPdfForMobile();
    }
  }

  Future<void> _loadPdfForMobile() async {
    try {
      debugPrint('📄 [PDF_VIEWER] Original PDF URL: ${widget.pdfUrl}');
      
      // Get authenticated API client
      final apiClient = ApiClient();
      
      // Parse the URL to handle both full and relative URLs
      Uri parsedUri;
      try {
        parsedUri = Uri.parse(widget.pdfUrl);
      } catch (e) {
        debugPrint('❌ [PDF_VIEWER] Failed to parse URL: $e');
        throw Exception('Invalid PDF URL: $e');
      }
      
      final isFullUrl = parsedUri.hasScheme && (parsedUri.scheme == 'http' || parsedUri.scheme == 'https');
      
      // Build download URL
      String downloadUrl;
      if (isFullUrl) {
        // Full URL - use as-is, but ensure it's properly formatted
        downloadUrl = widget.pdfUrl;
      } else {
        // Relative URL - prepend baseUrl
        downloadUrl = '${apiClient.baseUrl}${widget.pdfUrl.startsWith('/') ? '' : '/'}${widget.pdfUrl}';
      }
      
      // Re-parse to ensure URL is valid
      final finalUri = Uri.parse(downloadUrl);
      debugPrint('📥 [PDF_VIEWER] Final download URL: $downloadUrl');
      debugPrint('   - Scheme: ${finalUri.scheme}');
      debugPrint('   - Host: ${finalUri.host}');
      debugPrint('   - Port: ${finalUri.port}');
      debugPrint('   - Path: ${finalUri.path}');
      debugPrint('   - Query: ${finalUri.query}');
      debugPrint('   - Is full URL: $isFullUrl');
      debugPrint('   - API baseUrl: ${apiClient.baseUrl}');
      
      // The /pdf/view endpoint is public (signed URL), so we can use a simple Dio instance
      // For absolute URLs, create a new Dio instance without baseUrl
      Dio dioInstance;
      if (isFullUrl) {
        // Create a simple Dio instance for absolute URLs (no baseUrl, no auth needed for signed URLs)
        dioInstance = Dio(BaseOptions(
          responseType: ResponseType.bytes,
          followRedirects: true,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ));
      } else {
        // For relative URLs, we can still use the main Dio instance
        // But since it's a signed URL (public), auth isn't required
        dioInstance = apiClient.dio;
      }
      
      // Download PDF (signed URLs are public, so no auth needed)
      debugPrint('📤 [PDF_VIEWER] Sending GET request...');
      final response = await dioInstance.get(
        downloadUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      debugPrint('📊 [PDF_VIEWER] Response received');
      debugPrint('   - Status code: ${response.statusCode}');
      debugPrint('   - Status message: ${response.statusMessage}');
      debugPrint('   - Headers: ${response.headers}');
      
      if (response.statusCode != 200) {
        String errorBody = '';
        if (response.data != null) {
          if (response.data is String) {
            errorBody = response.data as String;
          } else if (response.data is List<int>) {
            try {
              errorBody = utf8.decode(response.data as List<int>);
            } catch (e) {
              errorBody = 'Binary data (${(response.data as List).length} bytes)';
            }
          }
        }
        debugPrint('❌ [PDF_VIEWER] Response error');
        debugPrint('   - Status: ${response.statusCode} ${response.statusMessage}');
        debugPrint('   - Body: $errorBody');
        throw Exception('Failed to download PDF: ${response.statusCode} ${response.statusMessage ?? ''}\n$errorBody');
      }

      final pdfBytes = Uint8List.fromList(response.data as List<int>);
      debugPrint('✅ [PDF_VIEWER] PDF downloaded: ${pdfBytes.length} bytes');

      // Convert to base64 data URI
      final base64Pdf = base64Encode(pdfBytes);
      final dataUri = 'data:application/pdf;base64,$base64Pdf';

      // Initialize WebView with data URI
      if (mounted) {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                  });
                }
              },
              onPageFinished: (String url) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('❌ [PDF_VIEWER] WebView error: ${error.description}');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = error.description;
                  });
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(dataUri));
        
        setState(() {});
      }
    } catch (e, stack) {
      debugPrint('❌ [PDF_VIEWER] Error loading PDF: $e');
      debugPrint('   Stack: $stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load PDF: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // On web, embed PDF in iframe for preview
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PDF Preview'),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in new tab',
              onPressed: () async {
                try {
                  final uri = Uri.parse(widget.pdfUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening PDF: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        body: WebPdfViewer(pdfUrl: widget.pdfUrl),
      );
    }

    // On mobile/desktop, use WebView to display PDF in-app
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in browser',
            onPressed: () async {
              try {
                final uri = Uri.parse(widget.pdfUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error opening PDF: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _loadPdfForMobile();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    // WebView with smooth rendering
                    ClipRRect(
                      child: WebViewWidget(
                        controller: _controller!,
                      ),
                    ),
                    if (_isLoading)
                      Container(
                        color: Colors.white,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
    );
  }
}

// Web PDF viewer - uses iframe on web
class WebPdfViewer extends StatefulWidget {
  final String pdfUrl;

  const WebPdfViewer({super.key, required this.pdfUrl});

  @override
  State<WebPdfViewer> createState() => _WebPdfViewerState();
}

class _WebPdfViewerState extends State<WebPdfViewer> {
  static int _viewIdCounter = 0;
  String? _viewId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _viewId = 'pdf-iframe-${_viewIdCounter++}';
      web_impl.registerWebPdfIframe(_viewId!, widget.pdfUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _viewId == null) {
      return const Center(child: Text('PDF viewer only available on web'));
    }

    return web_impl.createWebPdfView(_viewId!);
  }
}
