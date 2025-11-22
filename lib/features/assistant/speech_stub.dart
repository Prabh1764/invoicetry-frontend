// Stub for speech_to_text on web (may not work)
// Import kIsWeb for conditional checks
import 'package:flutter/foundation.dart' show kIsWeb;

// Stub classes for web
class SpeechToText {
  Future<bool> initialize() async => false;
  Future<void> listen({Function(String)? onResult, Function()? onDone}) async {}
  void stop() {}
  void cancel() {}
  bool get isListening => false;
  bool get isAvailable => false;
}

class SpeechRecognitionError {
  final String errorMsg;
  final int errorType;
  SpeechRecognitionError({required this.errorMsg, required this.errorType});
}
