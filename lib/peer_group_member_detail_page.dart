import 'package:flutter/material.dart';

import 'peer_group_models.dart';
import 'peer_group_volunteer_tab.dart';

/// Caregiver view after joining a peer group.
class PeerGroupMemberDetailPage extends StatelessWidget {
  const PeerGroupMemberDetailPage({
    required this.group,
    super.key,
  });

  final PeerGroupRecord group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPeerGroupAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPeerGroupAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: kPeerGroupAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You are in this group. Save the details below for your calendar.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'When & where',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.event_rounded,
            label: 'Schedule',
            value: group.schedule,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: group.mode.startsWith('In person')
                ? Icons.place_rounded
                : Icons.videocam_rounded,
            label: 'Location / format',
            value: group.mode,
          ),
          if (group.membersLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.people_outline_rounded,
              label: 'Who it is for',
              value: group.membersLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: kPeerGroupAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
