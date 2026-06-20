import 'package:flutter/material.dart';

import 'spotify_search_models.dart';

/// Lets the user pick one Spotify result before leaving the app.
Future<SpotifySearchHit?> showSpotifySearchResultsSheet({
  required BuildContext context,
  required String query,
  required List<SpotifySearchHit> hits,
}) {
  return showModalBottomSheet<SpotifySearchHit>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'Pick what to open in Spotify',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Results for “$query”',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  itemCount: hits.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final hit = hits[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF439A7D).withValues(
                          alpha: 0.15,
                        ),
                        child: Icon(
                          hit.icon,
                          color: const Color(0xFF439A7D),
                        ),
                      ),
                      title: Text(
                        hit.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${hit.kindLabel} · ${hit.subtitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => Navigator.of(context).pop(hit),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
