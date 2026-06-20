import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'spotify_config.dart';
import 'spotify_search_models.dart';

/// Spotify Web API (client credentials) — catalog search, no user login.
class SpotifyApiClient {
  SpotifyApiClient._();

  static String? _accessToken;
  static DateTime? _tokenExpiresAt;

  static Future<List<SpotifySearchHit>> search(String query) async {
    if (!isSpotifyApiConfigured) {
      throw StateError('Spotify API credentials are not configured');
    }

    final token = await _accessTokenOrFetch();
    final uri = Uri.https('api.spotify.com', '/v1/search', {
      'q': query.trim(),
      'type': 'track,artist,album,playlist',
      'limit': '8',
    });

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('Spotify search timed out'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Spotify search failed (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseHits(json);
  }

  static Future<String> _accessTokenOrFetch() async {
    final now = DateTime.now();
    if (_accessToken != null &&
        _tokenExpiresAt != null &&
        now.isBefore(_tokenExpiresAt!)) {
      return _accessToken!;
    }

    final id = spotifyClientIdOrNull!;
    final secret = spotifyClientSecretOrNull!;
    final basic = base64Encode(utf8.encode('$id:$secret'));

    final response = await http
        .post(
          Uri.parse('https://accounts.spotify.com/api/token'),
          headers: {
            'Authorization': 'Basic $basic',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: 'grant_type=client_credentials',
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Spotify token timed out'),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Spotify auth failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['access_token'] as String?;
    final expiresIn = body['expires_in'] as int? ?? 3600;
    if (token == null || token.isEmpty) {
      throw Exception('Spotify returned no access token');
    }

    _accessToken = token;
    _tokenExpiresAt = now.add(Duration(seconds: expiresIn - 60));
    return token;
  }

  static List<SpotifySearchHit> _parseHits(Map<String, dynamic> json) {
    final hits = <SpotifySearchHit>[];

    void addFromList(
      dynamic section,
      SpotifySearchKind kind,
      String Function(Map<String, dynamic>) title,
      String Function(Map<String, dynamic>) subtitle,
    ) {
      final items = (section as Map<String, dynamic>?)?['items'] as List?;
      if (items == null) return;
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final url = raw['external_urls']?['spotify'] as String?;
        if (url == null || url.isEmpty) continue;
        hits.add(
          SpotifySearchHit(
            title: title(raw),
            subtitle: subtitle(raw),
            uri: Uri.parse(url),
            kind: kind,
          ),
        );
      }
    }

    addFromList(
      json['tracks'],
      SpotifySearchKind.track,
      (t) => t['name'] as String? ?? 'Track',
      (t) {
        final artists = t['artists'] as List?;
        if (artists == null || artists.isEmpty) return 'Track';
        return artists
            .map((a) => (a as Map)['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ');
      },
    );
    addFromList(
      json['playlists'],
      SpotifySearchKind.playlist,
      (p) => p['name'] as String? ?? 'Playlist',
      (_) => 'Playlist',
    );
    addFromList(
      json['albums'],
      SpotifySearchKind.album,
      (a) => a['name'] as String? ?? 'Album',
      (a) {
        final artists = a['artists'] as List?;
        if (artists == null || artists.isEmpty) return 'Album';
        return artists
            .map((x) => (x as Map)['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ');
      },
    );
    addFromList(
      json['artists'],
      SpotifySearchKind.artist,
      (a) => a['name'] as String? ?? 'Artist',
      (_) => 'Artist',
    );

    return hits.take(12).toList();
  }
}
