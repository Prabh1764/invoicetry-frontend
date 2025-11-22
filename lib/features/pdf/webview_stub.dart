// Stub for webview_flutter on web (not available)
import 'package:flutter/material.dart';

// Stub classes for web
class WebViewController {
  void setJavaScriptMode(dynamic mode) {}
  void setBackgroundColor(Color color) {}
  void setNavigationDelegate(dynamic delegate) {}
  void loadRequest(Uri uri) {}
}

class WebViewWidget extends StatelessWidget {
  final WebViewController controller;
  const WebViewWidget({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('WebView not available on web'));
  }
}

class JavaScriptMode {
  static const unrestricted = JavaScriptMode._();
  const JavaScriptMode._();
}

class NavigationDelegate {
  final void Function(String)? onPageStarted;
  final void Function(String)? onPageFinished;
  final void Function(WebResourceError)? onWebResourceError;
  
  NavigationDelegate({
    this.onPageStarted,
    this.onPageFinished,
    this.onWebResourceError,
  });
}

class WebResourceError {
  final String description;
  WebResourceError({required this.description});
}

