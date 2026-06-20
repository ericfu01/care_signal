import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'openai_config.dart';

/// Minimal OpenAI Chat Completions client for Care Signal features.
class OpenAiClient {
  OpenAiClient._();

  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const String defaultModel = 'gpt-4o-mini';

  /// Keeps [system], drops leading [assistant] turns, merges adjacent same roles,
  /// and skips empty content so the API is less likely to reject the thread.
  static List<Map<String, String>> sanitizeChatMessages(
    List<Map<String, String>> raw,
  ) {
    if (raw.isEmpty) return raw;

    final out = <Map<String, String>>[];
    var i = 0;
    if (raw.first['role'] == 'system') {
      final c = raw.first['content']?.trim() ?? '';
      if (c.isNotEmpty) {
        out.add({'role': 'system', 'content': c});
      }
      i = 1;
    }

    while (i < raw.length && raw[i]['role'] == 'assistant') {
      i++;
    }

    for (; i < raw.length; i++) {
      final m = raw[i];
      final role = m['role'] ?? 'user';
      if (role != 'user' && role != 'assistant' && role != 'system') {
        continue;
      }
      final content = m['content']?.trim() ?? '';
      if (content.isEmpty) continue;

      if (out.isEmpty || out.last['role'] == 'system') {
        out.add({'role': role, 'content': content});
        continue;
      }

      if (out.last['role'] == role) {
        final merged = '${out.last['content']}\n\n$content';
        out[out.length - 1] = {'role': role, 'content': merged};
      } else {
        out.add({'role': role, 'content': content});
      }
    }

    if (out.isEmpty) {
      throw ArgumentError('sanitizeChatMessages: no valid messages after cleaning');
    }
    if (out.length == 1 && out.first['role'] == 'system') {
      throw ArgumentError('sanitizeChatMessages: only system message, missing user');
    }

    return out;
  }

  static Future<String> chatCompletion({
    required List<Map<String, String>> messages,
    String model = defaultModel,
  }) async {
    final key = openAiApiKeyOrNull;
    if (key == null || key.isEmpty) {
      throw StateError('OPENAI_API_KEY is not configured');
    }

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'temperature': 0.65,
            'max_tokens': 700,
          }),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException(
            'OpenAI request timed out after 60s',
          ),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'OpenAI HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('OpenAI returned no choices');
    }
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('OpenAI returned empty content');
    }
    return content.trim();
  }
}
