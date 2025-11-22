import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  AiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.openai.com/v1',
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  final Dio _dio;
  static const _model = 'gpt-4o';

  Future<Map<String, dynamic>> interpretCommand({
    required String transcript,
    required Map<String, dynamic> draftState,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY is not configured.');
    }

    final response = await _dio.post(
      '/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: jsonEncode(_buildRequestPayload(transcript, draftState)),
    );

    final data = response.data as Map<String, dynamic>?;
    final choices = data?['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('Unexpected response from GPT model.');
    }
    final message = (choices.first as Map<String, dynamic>)['message'];
    if (message is! Map<String, dynamic>) {
      throw Exception('Unexpected response from GPT model.');
    }
    final text = message['content'];
    if (text == null || text.trim().isEmpty) {
      throw Exception('Model returned empty response.');
    }

    debugPrint('🤖 [AI_SERVICE] Raw model output: $text');

    return Map<String, dynamic>.from(jsonDecode(text));
  }

  Map<String, dynamic> _buildRequestPayload(
    String transcript,
    Map<String, dynamic> draftState,
  ) {
    final systemPrompt = '''
You are an assistant that converts free-form voice commands into structured actions for an invoicing app. Always respond with JSON ONLY.
Return either a single action object, or an object with an "actions" array when multiple steps are needed.
Supported action objects:
- {"action":"set_type","value":"invoice"|"estimate"}
- {"action":"set_client","value":"<client name>","confidence":0.0-1.0}
- {"action":"add_item","description":"...","quantity":number|null,"unit_price":number|null}
- {"action":"set_tax","value":number}
- {"action":"set_discount","value":number}
- {"action":"set_issue_date","value":"YYYY-MM-DD"}
- {"action":"set_due_date","value":"YYYY-MM-DD"}
- {"action":"set_notes","value":"..."}
- {"action":"summary"}
- {"action":"finish"}
- {"action":"clarify","message":"..."}
Respond with {"actions":[...]} when more than one action is appropriate.
Never include explanations or extra keys.''';

    final userPrompt = '''
Voice input: "$transcript"
Current draft (JSON):
${jsonEncode(draftState)}
Generate the next action(s) to update the draft accordingly.''';

    return {
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        {
          'role': 'user',
          'content': userPrompt,
        },
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.2,
      'max_tokens': 400,
    };
  }
}

