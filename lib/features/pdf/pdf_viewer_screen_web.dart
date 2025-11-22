// Web-specific implementation of PDF viewer
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Registers an iframe for PDF viewing on web
void registerWebPdfIframe(String viewId, String pdfUrl) {
  if (!kIsWeb) return;
  
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final html.IFrameElement iframe = html.IFrameElement();
      iframe.src = pdfUrl;
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.allowFullscreen = true;
      return iframe;
    },
  );
}

/// Creates an HtmlElementView for the registered iframe
Widget createWebPdfView(String viewType) {
  if (!kIsWeb) {
    return const Center(child: Text('Not on web'));
  }
  
  return HtmlElementView(viewType: viewType);
}
