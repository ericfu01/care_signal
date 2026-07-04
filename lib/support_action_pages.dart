import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'peer_group_member_detail_page.dart';
import 'peer_group_models.dart';
import 'peer_group_repository.dart';
import 'support_catalog.dart';
import 'support_repository.dart';

export 'support_chat_list_page.dart' show SupportChatListPage;
export 'support_chat_page.dart' show SupportChatPage;

class CrisisLinePage extends StatelessWidget {
  const CrisisLinePage({super.key});

  static const Color _crisisRed = Color(0xFFD32F2F);

  Future<void> _launchUri(
    BuildContext context,
    Uri uri, {
    required String label,
  }) async {
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $label on this device.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $label: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crisis Line'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: _crisisRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.emergency_rounded, color: _crisisRed, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Immediate danger?',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _crisisRed,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'If you or someone else is in life-threatening danger, call 911 now.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.black87,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: () => _launchUri(
                                context,
                                Uri(scheme: 'tel', path: '911'),
                                label: '911',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _crisisRed,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.call_rounded),
                              label: const Text('Call 911'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '24/7 support lines',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Free, confidential help any time. Tap to call or text from your phone.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              _CrisisHelplineCard(
                icon: Icons.phone_in_talk_rounded,
                title: '988 Suicide & Crisis Lifeline',
                detail: 'Call or text 988',
                accent: const Color(0xFF1976D2),
                onTap: () => _launchUri(
                  context,
                  Uri(scheme: 'tel', path: '988'),
                  label: '988 Lifeline',
                ),
              ),
              const SizedBox(height: 12),
              _CrisisHelplineCard(
                icon: Icons.sms_rounded,
                title: 'Crisis Text Line',
                detail: 'Text HOME to 741741',
                accent: const Color(0xFF7B1FA2),
                onTap: () => _launchUri(
                  context,
                  Uri(
                    scheme: 'sms',
                    path: '741741',
                    queryParameters: const {'body': 'HOME'},
                  ),
                  label: 'Crisis Text Line',
                ),
              ),
              const SizedBox(height: 12),
              _CrisisHelplineCard(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Veterans Crisis Line',
                detail: 'Dial 988, then press 1',
                accent: const Color(0xFF00695C),
                onTap: () => _launchUri(
                  context,
                  Uri(scheme: 'tel', path: '988'),
                  label: 'Veterans Crisis Line',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Care Signal does not provide emergency services. Use the options above or local services in a crisis.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black45,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrisisHelplineCard extends StatelessWidget {
  const _CrisisHelplineCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

class PeerGroupsPage extends StatefulWidget {
  const PeerGroupsPage({super.key});

  static const Color _accent = Color(0xFF7B1FA2);

  @override
  State<PeerGroupsPage> createState() => _PeerGroupsPageState();
}

class _PeerGroupsPageState extends State<PeerGroupsPage> {
  final _statuses = <String, PeerGroupMemberStatus>{};
  final _invitations = <String, PeerGroupInvitation>{};
  final _acting = <String>{};
  bool _loadingStatuses = false;
  bool _groupsLoading = true;
  List<PeerGroupRecord> _groups = const [];
  String? _loadedGroupIdsKey;
  StreamSubscription<List<PeerGroupRecord>>? _groupsSub;

  @override
  void initState() {
    super.initState();
    unawaited(PeerGroupRepository.instance.deleteCatalogDemoGroups());
    _groupsSub = PeerGroupRepository.instance.watchPublicGroups().listen(
      (groups) => unawaited(_onGroupsUpdated(groups)),
    );
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    super.dispose();
  }

  Future<void> _onGroupsUpdated(List<PeerGroupRecord> groups) async {
    final key = groups.map((g) => g.id).join('|');
    if (!mounted) return;

    setState(() {
      _groups = groups;
      _groupsLoading = false;
    });

    if (key == _loadedGroupIdsKey) return;
    _loadedGroupIdsKey = key;
    await _loadStatuses(groups);
  }

  Future<void> _loadStatuses(List<PeerGroupRecord> groups) async {
    if (groups.isEmpty) {
      if (!mounted) return;
      setState(() {
        _statuses.clear();
        _invitations.clear();
        _loadingStatuses = false;
      });
      return;
    }

    setState(() => _loadingStatuses = true);
    try {
      final statuses = await PeerGroupRepository.instance.loadMemberStatuses(
        groups.map((g) => g.id),
      );
      final invites =
          await PeerGroupRepository.instance.loadInvitationsForGroups(
        groups.map((g) => g.id),
      );
      final inviteMap = {
        for (final invite in invites.where((i) => i.isPending))
          invite.groupId: invite,
      };
      if (!mounted) return;
      setState(() {
        _statuses
          ..clear()
          ..addAll(statuses);
        _invitations
          ..clear()
          ..addAll(inviteMap);
      });
    } finally {
      if (mounted) setState(() => _loadingStatuses = false);
    }
  }

  Future<void> _join(PeerGroupRecord group) async {
    final status = _statuses[group.id] ?? PeerGroupMemberStatus.none;
    if (status == PeerGroupMemberStatus.pending ||
        status == PeerGroupMemberStatus.accepted ||
        _acting.contains(group.id)) {
      return;
    }
    setState(() => _acting.add(group.id));
    try {
      await SupportRepository.instance.submitPeerGroupRequest(
        groupId: group.id,
        groupTitle: group.title,
      );
      if (!mounted) return;
      setState(() => _statuses[group.id] = PeerGroupMemberStatus.pending);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent for “${group.title}”.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    } finally {
      if (mounted) setState(() => _acting.remove(group.id));
    }
  }

  Future<void> _acceptInvite(PeerGroupRecord group) async {
    final invite = _invitations[group.id];
    if (invite == null || _acting.contains(group.id)) return;
    setState(() => _acting.add(group.id));
    try {
      await PeerGroupRepository.instance.acceptInvitation(
        groupId: group.id,
        invitationId: invite.id,
      );
      if (!mounted) return;
      setState(() {
        _statuses[group.id] = PeerGroupMemberStatus.accepted;
        _invitations.remove(group.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You joined “${group.title}”.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept invitation: $e')),
      );
    } finally {
      if (mounted) setState(() => _acting.remove(group.id));
    }
  }

  String _statusLabel(PeerGroupMemberStatus status) {
    return switch (status) {
      PeerGroupMemberStatus.invited => 'Invited',
      PeerGroupMemberStatus.pending => 'Requested',
      PeerGroupMemberStatus.accepted => 'Member',
      PeerGroupMemberStatus.declined => 'Declined',
      PeerGroupMemberStatus.none => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer Groups'),
      ),
      body: SafeArea(
        child: _groupsLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Community',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Request to join a group, or accept an invitation from your host.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                  if (_loadingStatuses) ...[
                    const SizedBox(height: 20),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  const SizedBox(height: 20),
                  if (_groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No peer groups are available yet. Check back when '
                        'volunteers create support groups.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    )
                  else
                    ..._groups.map(
                      (group) {
                        final status = _invitations.containsKey(group.id)
                            ? PeerGroupMemberStatus.invited
                            : (_statuses[group.id] ??
                                PeerGroupMemberStatus.none);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PeerGroupCard(
                            group: group,
                            accent: PeerGroupsPage._accent,
                            status: status,
                            acting: _acting.contains(group.id),
                            onJoin: () => _join(group),
                            onAcceptInvite: () => _acceptInvite(group),
                            onViewDetails: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      PeerGroupMemberDetailPage(group: group),
                                ),
                              );
                            },
                            statusLabel: _statusLabel(status),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
      ),
    );
  }
}

class _PeerGroupCard extends StatelessWidget {
  const _PeerGroupCard({
    required this.group,
    required this.accent,
    required this.status,
    required this.acting,
    required this.onJoin,
    required this.onAcceptInvite,
    required this.onViewDetails,
    required this.statusLabel,
  });

  final PeerGroupRecord group;
  final Color accent;
  final PeerGroupMemberStatus status;
  final bool acting;
  final VoidCallback onJoin;
  final VoidCallback onAcceptInvite;
  final VoidCallback onViewDetails;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.groups_rounded, color: accent, size: 26),
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
                    const SizedBox(height: 6),
                    _PeerMetaRow(
                      icon: Icons.event_rounded,
                      text: group.schedule,
                    ),
                    const SizedBox(height: 4),
                    _PeerMetaRow(
                      icon: group.mode.startsWith('In person')
                          ? Icons.place_rounded
                          : Icons.videocam_rounded,
                      text: group.mode,
                    ),
                    const SizedBox(height: 4),
                    _PeerMetaRow(
                      icon: Icons.people_outline_rounded,
                      text: group.membersLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (statusLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(statusLabel),
                  backgroundColor: status == PeerGroupMemberStatus.accepted
                      ? Colors.green.shade50
                      : accent.withValues(alpha: 0.1),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: status == PeerGroupMemberStatus.invited
                ? FilledButton(
                    onPressed: acting ? null : onAcceptInvite,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(acting ? 'Joining…' : 'Accept invitation'),
                  )
                : status == PeerGroupMemberStatus.accepted
                    ? FilledButton(
                        onPressed: onViewDetails,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('View details'),
                      )
                    : FilledButton(
                        onPressed: acting ||
                                status == PeerGroupMemberStatus.pending
                            ? null
                            : onJoin,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          status == PeerGroupMemberStatus.pending
                              ? acting
                                  ? 'Sending…'
                                  : 'Requested'
                              : status == PeerGroupMemberStatus.declined
                                  ? acting
                                      ? 'Sending…'
                                      : 'Request again'
                                  : acting
                                      ? 'Sending…'
                                      : 'Request to join',
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PeerMetaRow extends StatelessWidget {
  const _PeerMetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  height: 1.3,
                ),
          ),
        ),
      ],
    );
  }
}
class SupportResourcesPage extends StatelessWidget {
  const SupportResourcesPage({super.key});

  static const Color _accent = Color(0xFFF57C00);

  Future<void> _openResource(BuildContext context, CatalogResource link) async {
    final launched = await launchUrl(
      link.url,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${link.url.host}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = SupportCatalog.resourceSections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          itemCount: sections.length,
          itemBuilder: (context, sectionIndex) {
            final section = sections[sectionIndex];
            return Padding(
              padding: EdgeInsets.only(
                bottom: sectionIndex < sections.length - 1 ? 24 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.menu_book_rounded, color: _accent, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          section.heading,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...section.items.map(
                    (link) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openResource(context, link),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        link.title,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        link.minutes,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

