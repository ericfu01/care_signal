import 'openai_client.dart';
import 'openai_config.dart';

/// Short thread title from the first exchange (OpenAI).
Future<String?> generateSupportConversationTitle({
  required String userMessage,
  required String assistantReply,
}) async {
  if (!isOpenAiConfigured) return _fallbackTitle(userMessage);

  try {
    final title = await OpenAiClient.chatCompletion(
      messages: [
        {
          'role': 'system',
          'content':
              'You label caregiver support chats. Reply with ONLY a short title '
              '(3–8 words, no quotes, no punctuation at the end). Describe the '
              'main topic of the conversation.',
        },
        {
          'role': 'user',
          'content':
              'User: $userMessage\n\nAssistant: $assistantReply',
        },
      ],
      model: OpenAiClient.defaultModel,
    );
    final cleaned = title
        .replaceAll(RegExp(r'^["\x27]+|["\x27]+$'), '')
        .trim();
    if (cleaned.isEmpty) return _fallbackTitle(userMessage);
    return cleaned.length > 80 ? '${cleaned.substring(0, 77)}…' : cleaned;
  } catch (_) {
    return _fallbackTitle(userMessage);
  }
}

String _fallbackTitle(String userMessage) {
  final t = userMessage.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return 'Support chat';
  if (t.length <= 48) return t;
  return '${t.substring(0, 45)}…';
}
