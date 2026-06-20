import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spotify_links.dart';

/// Opens [SpotifyMusicLink] via `https://open.spotify.com/...` so the OS can
/// hand off to the Spotify app (Universal Links / App Links). Avoids `spotify:`
/// URIs, which often open a blank screen in the Spotify app.
class SpotifyLauncher {
  SpotifyLauncher._();

  static Future<bool> open(BuildContext context, SpotifyMusicLink link) async {
    return openUri(context, link.uri);
  }

  /// Song/artist text → Spotify search; `https://open.spotify.com/...` → that link.
  static Future<bool> openUserInput(BuildContext context, String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to search for.')),
        );
      }
      return false;
    }

    final direct = uriFromUserInput(trimmed);
    if (direct != null) {
      return openUri(context, direct);
    }
    return openSearch(context, trimmed);
  }

  /// Parses a pasted Spotify link or `spotify:track:...` into an https URI.
  static Uri? uriFromUserInput(String input) {
    final match = RegExp(
      r'https?://open\.spotify\.com/[^\s]+',
      caseSensitive: false,
    ).firstMatch(input);
    if (match != null) {
      return Uri.parse(match.group(0)!);
    }

    final scheme = input.trim();
    if (!scheme.toLowerCase().startsWith('spotify:')) return null;

    final body = scheme.substring('spotify:'.length);
    final parts = body.split(':');
    if (parts.length < 2) return null;

    final type = parts[0];
    final id = parts[1].split('?').first;
    if (id.isEmpty) return null;

    return Uri.parse('https://open.spotify.com/$type/$id');
  }

  /// Opens Spotify search for [query] (results in the Spotify app).
  static Future<bool> openSearch(BuildContext context, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to search for.')),
        );
      }
      return false;
    }

    return openUri(
      context,
      Uri.https(
        'open.spotify.com',
        '/search/${Uri.encodeComponent(trimmed)}',
      ),
    );
  }

  static Future<bool> openUri(BuildContext context, Uri uri) async {
    var launched = false;
    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open Spotify. Install the Spotify app or try again.',
          ),
        ),
      );
    }
    return launched;
  }
}
