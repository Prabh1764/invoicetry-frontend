// Stub implementation for non-web platforms
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Conditionally import webview_flutter (not available on web)
import 'package:webview_flutter/webview_flutter.dart'
    if (dart.library.html) 'webview_stub.dart';

/// Creates a preview widget for HTML content on mobile
Widget createPreviewWidget(String htmlContent, String baseUrl) {
  if (kIsWeb) {
    return const Center(child: Text('Preview only available on mobile'));
  }

  final controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.white)
    ..loadHtmlString(htmlContent, baseUrl: baseUrl);
  
  return WebViewWidget(controller: controller);
}

