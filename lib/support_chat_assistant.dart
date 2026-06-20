import 'openai_client.dart';

/// Produces assistant replies for support chat.
///
/// For production at scale, prefer a backend / Cloud Function so the API key
/// stays off-device.
abstract class SupportChatAssistant {
  /// [openAiHistory] is optional full Chat Completions payload (system + turns).
  /// When null, implementations use [latestUserText] only.
  Future<String> replyToUserMessage(
    String latestUserText, {
    List<Map<String, String>>? openAiHistory,
  });
}

/// OpenAI-backed replies (requires [openAiApiKeyOrNull]).
class OpenAiSupportChatAssistant implements SupportChatAssistant {
  /// Shared system message for history building and single-turn fallback.
  static const systemPrompt =
      'You are Care Signal support for family caregivers. Be warm, clear, and '
      'practical; keep replies concise unless the user asks for more depth. '
      'Use Markdown for structure when helpful: **bold** for key phrases, short '
      'bulleted lists for steps, and blank lines between paragraphs. '
      'Do not diagnose or prescribe. If someone may be in immediate danger, tell them '
      'to get emergency help and to use Crisis Line under Support in this app.';

  @override
  Future<String> replyToUserMessage(
    String latestUserText, {
    List<Map<String, String>>? openAiHistory,
  }) async {
    if (openAiHistory != null && openAiHistory.isNotEmpty) {
      final cleaned = OpenAiClient.sanitizeChatMessages(openAiHistory);
      return OpenAiClient.chatCompletion(messages: cleaned);
    }
    return OpenAiClient.chatCompletion(
      messages: OpenAiClient.sanitizeChatMessages([
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': latestUserText},
      ]),
    );
  }
}

/// Placeholder when no API key is configured.
class StubSupportChatAssistant implements SupportChatAssistant {
  @override
  Future<String> replyToUserMessage(
    String userMessage, {
    List<Map<String, String>>? openAiHistory,
  }) async {
    // Tiny delay so the UI feels like a response is being generated.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final t = userMessage.trim();
    if (t.isEmpty) {
      return 'Go ahead whenever you are ready — what is on your mind?';
    }
    final preview = t.length > 160 ? '${t.substring(0, 157)}...' : t;
    return 'Thanks — I have noted this:\n\n"$preview"\n\nWhat would you like to do next?';
  }
}
