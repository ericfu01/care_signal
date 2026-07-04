import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'peer_group_create_page.dart';
import 'peer_group_host_manage_page.dart';
import 'peer_group_models.dart';
import 'peer_group_repository.dart';

const kPeerGroupAccent = Color(0xFF7B1FA2);

/// Peer group hosting inside the volunteer home.
class PeerGroupVolunteerTab extends StatefulWidget {
  const PeerGroupVolunteerTab({super.key});

  @override
  State<PeerGroupVolunteerTab> createState() => _PeerGroupVolunteerTabState();
}

class _PeerGroupVolunteerTabState extends State<PeerGroupVolunteerTab> {
  final _respondingCoHost = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(PeerGroupRepository.instance.deleteCatalogDemoGroups());
  }

  Future<void> _openCreateGroup() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const PeerGroupCreatePage(),
      ),
    );
  }

  Future<void> _respondCoHostInvite(
    PeerGroupCoHostInvitation invite,
    bool accept,
  ) async {
    if (_respondingCoHost.contains(invite.groupId)) return;
    setState(() => _respondingCoHost.add(invite.groupId));
    try {
      if (accept) {
        await PeerGroupRepository.instance.acceptCoHostInvitation(
          groupId: invite.groupId,
        );
      } else {
        await PeerGroupRepository.instance.declineCoHostInvitation(
          groupId: invite.groupId,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'You are now a co-host of ${invite.groupTitle}.'
                : 'Co-host invitation declined.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingCoHost.remove(invite.groupId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to manage peer groups.'));
    }

    return StreamBuilder<List<PeerGroupRecord>>(
      stream: PeerGroupRepository.instance.watchManagedGroups(uid),
      builder: (context, managedSnap) {
        final managed = managedSnap.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _CreateGroupCard(onCreate: _openCreateGroup),
            const SizedBox(height: 20),
            StreamBuilder<List<PeerGroupCoHostInvitation>>(
              stream: PeerGroupRepository.instance
                  .watchPendingCoHostInvitesForUser(uid),
              builder: (context, inviteSnap) {
                final invites = inviteSnap.data ?? [];
                if (invites.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionHeader(
                      title: 'Co-host invitations',
                      subtitle:
                          'Another volunteer invited you to help run their group.',
                    ),
                    const SizedBox(height: 12),
                    ...invites.map((invite) {
                      final busy = _respondingCoHost.contains(invite.groupId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invite.groupTitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'From ${invite.hostName}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.black54),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: busy
                                            ? null
                                            : () => _respondCoHostInvite(
                                                  invite,
                                                  false,
                                                ),
                                        child: const Text('Decline'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: busy
                                            ? null
                                            : () => _respondCoHostInvite(
                                                  invite,
                                                  true,
                                                ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: kPeerGroupAccent,
                                        ),
                                        child: Text(busy ? '…' : 'Accept'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
            if (managed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'You are not hosting any groups yet. Create one to start '
                  'inviting families and reviewing join requests.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                ),
              )
            else ...[
              _SectionHeader(
                title: 'Your groups',
                subtitle:
                    'Manage join requests and invite families to groups you host or co-host.',
              ),
              const SizedBox(height: 12),
              ...managed.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ManagedGroupCard(group: group),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CreateGroupCard extends StatelessWidget {
  const _CreateGroupCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPeerGroupAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPeerGroupAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Host a peer group',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your own support group. Invite a co-host to help manage '
            'join requests and participants.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(backgroundColor: kPeerGroupAccent),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create a group'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.black54,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ManagedGroupCard extends StatelessWidget {
  const _ManagedGroupCard({required this.group});

  final PeerGroupRecord group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isCoHost = uid != null && group.cohostUids.contains(uid);
    final isHost = uid != null && group.hostUid == uid;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => PeerGroupHostManagePage(group: group),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: kPeerGroupAccent.withValues(alpha: 0.12),
                child: const Icon(Icons.groups_rounded, color: kPeerGroupAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.schedule,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<int>(
                      stream: PeerGroupRepository.instance
                          .watchParticipantCount(group.id),
                      builder: (context, countSnap) {
                        final count = countSnap.data;
                        if (count == null) return const SizedBox.shrink();
                        return Text(
                          count == 1 ? '1 participant' : '$count participants',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: kPeerGroupAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    if (isCoHost) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Co-host',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: kPeerGroupAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (isHost) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Host',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
