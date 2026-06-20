import 'package:flutter/material.dart';

import 'spotify_api_client.dart';
import 'spotify_config.dart';
import 'spotify_launcher.dart';
import 'spotify_search_results_sheet.dart';

/// User types what they want → app finds it on Spotify → opens that link.
class MusicTherapySearchSection extends StatefulWidget {
  const MusicTherapySearchSection({
    super.key,
    this.hintText,
  });

  final String? hintText;

  @override
  State<MusicTherapySearchSection> createState() =>
      _MusicTherapySearchSectionState();
}

class _MusicTherapySearchSectionState extends State<MusicTherapySearchSection> {
  static const Color _accent = Color(0xFF439A7D);

  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _findAndOpen() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a song, artist, or paste a Spotify link.'),
        ),
      );
      return;
    }
    if (_busy) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final direct = SpotifyLauncher.uriFromUserInput(text);
      if (direct != null) {
        await SpotifyLauncher.openUri(context, direct);
        return;
      }

      if (!isSpotifyApiConfigured) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add Spotify API keys in assets/spotify.local.env to search by '
              'name, or paste a Spotify link from the Share menu.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      final hits = await SpotifyApiClient.search(text);
      if (!mounted) return;

      if (hits.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No Spotify results for “$text”.')),
        );
        return;
      }

      if (hits.length == 1) {
        await SpotifyLauncher.openUri(context, hits.first.uri);
        return;
      }

      final picked = await showSpotifySearchResultsSheet(
        context: context,
        query: text,
        hits: hits,
      );
      if (!mounted || picked == null) return;
      await SpotifyLauncher.openUri(context, picked.uri);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not search Spotify: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = widget.hintText ??
        'Song, artist, album, or paste a Spotify link';
    final apiReady = isSpotifyApiConfigured;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.headphones_rounded, color: _accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'What do you want to listen to?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              apiReady
                  ? 'Pick a match here — we open that song or playlist in Spotify.'
                  : 'Paste a Spotify share link, or add API keys in '
                      'assets/spotify.local.env to search by name.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_busy,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _findAndOpen(),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _busy ? null : _findAndOpen,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded, size: 20),
              label: Text(_busy ? 'Searching…' : 'Find on Spotify'),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
