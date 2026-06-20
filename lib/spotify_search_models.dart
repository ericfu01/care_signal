import 'package:flutter/material.dart';

enum SpotifySearchKind { track, artist, album, playlist }

/// One row from the Spotify Search API — opens via [uri] in the Spotify app.
class SpotifySearchHit {
  const SpotifySearchHit({
    required this.title,
    required this.subtitle,
    required this.uri,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final Uri uri;
  final SpotifySearchKind kind;

  IconData get icon {
    switch (kind) {
      case SpotifySearchKind.track:
        return Icons.music_note_rounded;
      case SpotifySearchKind.artist:
        return Icons.person_rounded;
      case SpotifySearchKind.album:
        return Icons.album_rounded;
      case SpotifySearchKind.playlist:
        return Icons.queue_music_rounded;
    }
  }

  String get kindLabel {
    switch (kind) {
      case SpotifySearchKind.track:
        return 'Song';
      case SpotifySearchKind.artist:
        return 'Artist';
      case SpotifySearchKind.album:
        return 'Album';
      case SpotifySearchKind.playlist:
        return 'Playlist';
    }
  }
}
