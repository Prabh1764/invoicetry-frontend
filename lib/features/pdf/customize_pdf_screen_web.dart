// Web-specific implementation for customize PDF preview
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Creates a preview widget for HTML content on web
Widget createPreviewWidget(String htmlContent, String baseUrl) {
  if (!kIsWeb) {
    return const Center(child: Text('Preview only available on web'));
  }

  // Generate unique view ID
  final viewId = 'customize-pdf-preview-${DateTime.now().millisecondsSinceEpoch}';
  
  // Register the iframe view factory
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final html.IFrameElement iframe = html.IFrameElement();
      
      // Create a data URI from the HTML content
      final encodedHtml = Uri.encodeComponent(htmlContent);
      final dataUri = 'data:text/html;charset=utf-8,$encodedHtml';
      
      iframe.src = dataUri;
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.allowFullscreen = true;
      
      return iframe;
    },
  );
  
  return HtmlElementView(viewType: viewId);
}

