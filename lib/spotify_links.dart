/// Curated Spotify playlists and tracks for Music Therapy.
/// Opens in the Spotify app (or browser) via [SpotifyLauncher] — no API or sign-in.
class SpotifyMusicLink {
  const SpotifyMusicLink({
    required this.title,
    required this.subtitle,
    required this.spotifyUrl,
  });

  final String title;
  final String subtitle;

  /// `https://open.spotify.com/playlist/...` or `.../track/...`
  final String spotifyUrl;

  Uri get uri => Uri.parse(spotifyUrl);
}

class MoodSpotifyContent {
  const MoodSpotifyContent({
    required this.moodTitle,
    required this.playlist,
    required this.tracks,
  });

  final String moodTitle;
  final SpotifyMusicLink playlist;
  final List<SpotifyMusicLink> tracks;
}

/// Featured pick on the main Music Therapy screen.
const SpotifyMusicLink kFeaturedEveningPlaylist = SpotifyMusicLink(
  title: 'Evening Winddown',
  subtitle: 'Spotify · Peaceful evening',
  spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1EIeq9dtoPZAEM',
);

MoodSpotifyContent moodSpotifyContent(String moodTitle) {
  return _moodContent[moodTitle] ??
      MoodSpotifyContent(
        moodTitle: moodTitle,
        playlist: SpotifyMusicLink(
          title: '$moodTitle therapy',
          subtitle: 'Spotify playlist',
          spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX4sWSpwq3LiO',
        ),
        tracks: const [],
      );
}

final Map<String, MoodSpotifyContent> _moodContent = {
  'Sleep': MoodSpotifyContent(
    moodTitle: 'Sleep',
    playlist: SpotifyMusicLink(
      title: 'Deep Sleep',
      subtitle: 'Spotify · Drift off',
      // Spotify editorial "Deep Sleep" playlist (replaces stale/broken ID).
      spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DWYcDQ1hSjOpY',
    ),
    tracks: [
      SpotifyMusicLink(
        title: 'Weightless',
        subtitle: 'Marconi Union',
        spotifyUrl: 'https://open.spotify.com/track/6kkwzB6hXLIONkEk9JciA6',
      ),
      SpotifyMusicLink(
        title: 'Clair de Lune',
        subtitle: 'Claude Debussy',
        spotifyUrl: 'https://open.spotify.com/album/3Y2XD2K4RvJPbXnGxYhCci',
      ),
      SpotifyMusicLink(
        title: 'Moonlight Sonata',
        subtitle: 'Ludwig van Beethoven',
        spotifyUrl: 'https://open.spotify.com/album/6lYMdGFShVneIDstynwcfW',
      ),
      SpotifyMusicLink(
        title: 'Only Time',
        subtitle: 'Enya',
        spotifyUrl: 'https://open.spotify.com/track/6FLwmdmW77N1Pxb1aWsZmO',
      ),
      SpotifyMusicLink(
        title: 'Nuvole Bianche',
        subtitle: 'Ludovico Einaudi',
        spotifyUrl: 'https://open.spotify.com/track/3weNRklVDqb4Rr5MhKBR3D',
      ),
    ],
  ),
  'Calm': MoodSpotifyContent(
    moodTitle: 'Calm',
    playlist: SpotifyMusicLink(
      title: 'Peaceful Piano',
      subtitle: 'Spotify · Relax and unwind',
      spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX4sWSpwq3LiO',
    ),
    tracks: [
      SpotifyMusicLink(
        title: 'River Flows in You',
        subtitle: 'Yiruma',
        spotifyUrl: 'https://open.spotify.com/track/2agBDIr9MYDUducQPC1sFU',
      ),
      SpotifyMusicLink(
        title: 'Experience',
        subtitle: 'Ludovico Einaudi',
        spotifyUrl: 'https://open.spotify.com/track/1BncfTJAWxrsxyT9culBrj',
      ),
      SpotifyMusicLink(
        title: 'Nuvole Bianche',
        subtitle: 'Ludovico Einaudi',
        spotifyUrl: 'https://open.spotify.com/track/3weNRklVDqb4Rr5MhKBR3D',
      ),
      SpotifyMusicLink(
        title: "Comptine d'un autre été",
        subtitle: 'Yann Tiersen',
        spotifyUrl: 'https://open.spotify.com/track/14rZjW3RioG7WesZhYESso',
      ),
      SpotifyMusicLink(
        title: 'Una Mattina',
        subtitle: 'Ludovico Einaudi',
        spotifyUrl: 'https://open.spotify.com/track/0Dkibk70FDp6t7eOZNemNQ',
      ),
    ],
  ),
  'Energize': MoodSpotifyContent(
    moodTitle: 'Energize',
    playlist: SpotifyMusicLink(
      title: 'Mood Booster',
      subtitle: 'Spotify · Feel-good energy',
      spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX3rxVfibe1L0',
    ),
    tracks: [
      SpotifyMusicLink(
        title: 'Good as Hell',
        subtitle: 'Lizzo',
        spotifyUrl: 'https://open.spotify.com/track/6KgBpzTuTRPebChN0VTyzV',
      ),
      SpotifyMusicLink(
        title: 'Walking on Sunshine',
        subtitle: 'Katrina & The Waves',
        spotifyUrl: 'https://open.spotify.com/track/05wIrZSwuaVWhcv5FfqeH0',
      ),
      SpotifyMusicLink(
        title: 'Happy',
        subtitle: 'Pharrell Williams',
        spotifyUrl: 'https://open.spotify.com/track/60nZcImufyMA1MKQY3dcCH',
      ),
      SpotifyMusicLink(
        title: "Don't Stop Me Now",
        subtitle: 'Queen',
        spotifyUrl: 'https://open.spotify.com/track/5T8EDUDqKcs6OSOwEsfqG7',
      ),
      SpotifyMusicLink(
        title: 'Uptown Funk',
        subtitle: 'Mark Ronson, Bruno Mars',
        spotifyUrl: 'https://open.spotify.com/track/32OlwWuMpZ6b0aN2RZOeMS',
      ),
    ],
  ),
  'Comfort': MoodSpotifyContent(
    moodTitle: 'Comfort',
    playlist: SpotifyMusicLink(
      title: 'Comfort Zone',
      subtitle: 'Spotify · Gentle and reassuring',
      spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DWYWddJiPzbvb',
    ),
    tracks: [
      SpotifyMusicLink(
        title: 'Here Comes the Sun',
        subtitle: 'The Beatles',
        spotifyUrl: 'https://open.spotify.com/track/6dGnYIeXmHdcikdzNNDMm2',
      ),
      SpotifyMusicLink(
        title: 'Lean on Me',
        subtitle: 'Bill Withers',
        spotifyUrl: 'https://open.spotify.com/track/3M8FzayQWtkvOhqMn2V4T2',
      ),
      SpotifyMusicLink(
        title: 'Fix You',
        subtitle: 'Coldplay',
        spotifyUrl: 'https://open.spotify.com/track/7LVHVU3tWfcxj5aiPFEW4Q',
      ),
      SpotifyMusicLink(
        title: 'Yellow',
        subtitle: 'Coldplay',
        spotifyUrl: 'https://open.spotify.com/track/3AJwUDP919kvQ9QcozQPxg',
      ),
      SpotifyMusicLink(
        title: 'Somewhere Only We Know',
        subtitle: 'Keane',
        spotifyUrl: 'https://open.spotify.com/track/6uNP8aOZphmhsYlOwRhNh1',
      ),
    ],
  ),
};
