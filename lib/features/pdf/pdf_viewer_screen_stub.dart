// Stub implementation for non-web platforms
import 'package:flutter/widgets.dart';

void registerWebPdfIframe(String viewId, String pdfUrl) {
  // No-op on non-web platforms
}

Widget createWebPdfView(String viewType) {
  return const Center(child: Text('PDF viewer only available on web'));
}

