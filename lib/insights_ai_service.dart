import 'package:flutter/foundation.dart';

import 'family_check_in_loader.dart';
import 'family_models.dart';
import 'check_in_openai_insights.dart';
import 'openai_config.dart';

class InsightsAiResult {
  const InsightsAiResult({
    this.summary,
    this.trendsAlert,
    this.fromCache = false,
    this.errorMessage,
  });

  final String? summary;
  final String? trendsAlert;
  final bool fromCache;
  final String? errorMessage;

  bool get hasSummary => summary != null && summary!.trim().isNotEmpty;
  bool get hasTrendsAlert =>
      trendsAlert != null && trendsAlert!.trim().isNotEmpty;
}

class _CacheEntry {
  _CacheEntry(this.result, this.fingerprint);

  final InsightsAiResult result;
  final String fingerprint;
  final DateTime createdAt = DateTime.now();

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) < ttl;
}

/// Loads and caches OpenAI insights for family check-in data.
class InsightsAiService {
  InsightsAiService._();

  static final InsightsAiService instance = InsightsAiService._();

  static const _cacheTtl = Duration(minutes: 45);

  _CacheEntry? _cache;

  Future<FamilyInsightsAiContext> buildContext({
    required String currentUserName,
    required Map<String, int?> memberScores,
    required Map<String, int> stressSourceCounts,
    required List<UserProfile> familyProfiles,
    int? familyWellnessAverage,
  }) async {
    final recent = familyProfiles.isEmpty
        ? <String, List<int>>{}
        : await FamilyCheckInLoader.recentScoresByMemberName(
            familyProfiles,
            limit: 7,
          );
    return FamilyInsightsAiContext(
      currentUserName: currentUserName.trim().isNotEmpty
          ? currentUserName.trim()
          : 'You',
      memberScores: memberScores,
      stressSourceCounts: stressSourceCounts,
      familyWellnessAverage: familyWellnessAverage,
      recentScoresByMember: recent,
    );
  }

  Future<InsightsAiResult> load({
    required FamilyInsightsAiContext context,
    bool forceRefresh = false,
  }) async {
    if (!isOpenAiConfigured) {
      return InsightsAiResult(
        errorMessage: kDebugMode
            ? 'Add OPENAI_API_KEY in assets/openai.local.env for AI insights.'
            : 'AI insights are unavailable right now.',
      );
    }
    if (!context.hasCheckInData) {
      return const InsightsAiResult();
    }

    final fingerprint = context.cacheFingerprint;
    if (!forceRefresh &&
        _cache != null &&
        _cache!.fingerprint == fingerprint &&
        _cache!.isFresh(_cacheTtl)) {
      return InsightsAiResult(
        summary: _cache!.result.summary,
        trendsAlert: _cache!.result.trendsAlert,
        fromCache: true,
      );
    }

    try {
      final results = await Future.wait([
        generateFamilyInsightsSummary(context),
        generateTrendsAlertLine(context),
      ]);
      final result = InsightsAiResult(
        summary: results[0],
        trendsAlert: results[1],
      );
      _cache = _CacheEntry(result, fingerprint);
      return result;
    } catch (e) {
      return InsightsAiResult(
        errorMessage: 'Could not generate AI insights. Try again later.',
      );
    }
  }

  void clearCache() => _cache = null;
}
