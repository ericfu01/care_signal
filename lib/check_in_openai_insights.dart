import 'openai_client.dart';
import 'openai_config.dart';

/// Inputs for OpenAI family wellness copy (Insights + Trends).
class FamilyInsightsAiContext {
  const FamilyInsightsAiContext({
    required this.currentUserName,
    required this.memberScores,
    required this.stressSourceCounts,
    this.familyWellnessAverage,
    this.recentScoresByMember = const {},
  });

  final String currentUserName;
  final Map<String, int?> memberScores;
  final Map<String, int> stressSourceCounts;
  final int? familyWellnessAverage;
  final Map<String, List<int>> recentScoresByMember;

  bool get hasCheckInData =>
      memberScores.values.any((score) => score != null);

  String get cacheFingerprint {
    final scores = memberScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final stress = stressSourceCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final history = recentScoresByMember.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [
      familyWellnessAverage,
      currentUserName,
      scores.map((e) => '${e.key}:${e.value}').join('|'),
      stress.map((e) => '${e.key}:${e.value}').join('|'),
      history.map((e) => '${e.key}:[${e.value.join(",")}]').join('|'),
    ].join(';');
  }

  String _formatDataBlock() {
    final buf = StringBuffer();
    if (familyWellnessAverage != null) {
      buf.writeln('Family wellness average (0–100): $familyWellnessAverage');
    }
    buf.writeln('Caregiver viewing insights: $currentUserName');
    buf.writeln();
    buf.writeln('Latest score per family member (null = no check-in yet):');
    final names = memberScores.keys.toList()..sort();
    for (final name in names) {
      final score = memberScores[name];
      buf.writeln('- $name: ${score ?? "no check-in"}');
    }
    if (recentScoresByMember.isNotEmpty) {
      buf.writeln();
      buf.writeln('Recent check-in scores (oldest to newest, per person):');
      for (final entry in recentScoresByMember.entries) {
        if (entry.value.isEmpty) continue;
        buf.writeln('- ${entry.key}: ${entry.value.join(", ")}');
      }
    }
    final stress = stressSourceCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (stress.isNotEmpty) {
      buf.writeln();
      buf.writeln('Stress sources mentioned in check-ins (counts):');
      for (final e in stress) {
        buf.writeln('- ${e.key}: ${e.value}');
      }
    }
    return buf.toString();
  }
}

const _systemPrompt =
    'You are Care Signal, helping family caregivers reflect on wellness trends. '
    'Be warm and practical. Never diagnose or claim medical authority. '
    'Only reference people and scores provided in the data — do not invent family members.';

/// Weekly narrative for the Insights tab. Returns `null` if no API key or no data.
Future<String?> generateFamilyInsightsSummary(
  FamilyInsightsAiContext context,
) async {
  if (!isOpenAiConfigured) return null;
  if (!context.hasCheckInData) return null;

  return OpenAiClient.chatCompletion(
    messages: [
      {'role': 'system', 'content': _systemPrompt},
      {
        'role': 'user',
        'content':
            '${context._formatDataBlock()}\n\n'
            'Write a supportive weekly-style summary for the caregiver (3–5 sentences). '
            'Mention who may need extra support only if their data shows it. '
            'If only one person has checked in, say so gently.',
      },
    ],
  );
}

/// One-line alert for the Trends tab.
Future<String?> generateTrendsAlertLine(
  FamilyInsightsAiContext context,
) async {
  if (!isOpenAiConfigured) return null;
  if (!context.hasCheckInData) return null;

  final text = await OpenAiClient.chatCompletion(
    messages: [
      {'role': 'system', 'content': _systemPrompt},
      {
        'role': 'user',
        'content':
            '${context._formatDataBlock()}\n\n'
            'Write exactly ONE short sentence for a dashboard alert (max 120 characters). '
            'Start with "AI Alert:" (include that prefix). No medical diagnosis.',
      },
    ],
  );
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length <= 160) return trimmed;
  return '${trimmed.substring(0, 157)}...';
}
