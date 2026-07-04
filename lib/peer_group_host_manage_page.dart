import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_repository.dart';
import 'peer_group_models.dart';
import 'peer_group_repository.dart';
import 'peer_group_volunteer_tab.dart';

/// Host tools for one peer group.
class PeerGroupHostManagePage extends StatefulWidget {
  const PeerGroupHostManagePage({
    required this.group,
    super.key,
  });

  final PeerGroupRecord group;

  @override
  State<PeerGroupHostManagePage> createState() => _PeerGroupHostManagePageState();
}

class _PeerGroupHostManagePageState extends State<PeerGroupHostManagePage> {
  final _familyEmailController = TextEditingController();
  final _coHostEmailController = TextEditingController();
  bool _invitingFamily = false;
  bool _invitingCoHost = false;
  final _responding = <String>{};
  final _removing = <String>{};

  @override
  void dispose() {
    _familyEmailController.dispose();
    _coHostEmailController.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool _isHost(PeerGroupRecord group) => _uid != null && group.hostUid == _uid;

  Future<void> _sendFamilyInvite(PeerGroupRecord group) async {
    final hostUid = _uid;
    if (hostUid == null) return;
    final email = _familyEmailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _invitingFamily = true);
    try {
      await PeerGroupRepository.instance.sendInvitation(
        groupId: group.id,
        groupTitle: group.title,
        hostUid: hostUid,
        inviteeEmail: email,
      );
      if (!mounted) return;
      _familyEmailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invitation saved for $email. '
            'They will get an email (if configured) and see it in Peer Groups '
            'when signed in with that email.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send invitation: $e')),
      );
    } finally {
      if (mounted) setState(() => _invitingFamily = false);
    }
  }

  Future<void> _sendCoHostInvite(PeerGroupRecord group) async {
    final hostUid = _uid;
    if (hostUid == null) return;
    final email = _coHostEmailController.text.trim();
    if (email.isEmpty) return;

    final hostProfile =
        await FamilyRepository.instance.getUserProfile(hostUid);
    final hostName = hostProfile?.displayName.trim().isNotEmpty == true
        ? hostProfile!.displayName
        : 'Host';

    setState(() => _invitingCoHost = true);
    try {
      await PeerGroupRepository.instance.sendCoHostInvitation(
        groupId: group.id,
        groupTitle: group.title,
        hostUid: hostUid,
        hostName: hostName,
        inviteeEmail: email,
      );
      if (!mounted) return;
      _coHostEmailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Co-host invitation sent to $email '
            '(in-app notification if they have a volunteer account).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _invitingCoHost = false);
    }
  }

  Future<void> _cancelInvitation(PeerGroupInvitation invitation) async {
    try {
      await PeerGroupRepository.instance.cancelInvitation(
        groupId: widget.group.id,
        invitationId: invitation.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation cancelled')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel invitation: $e')),
      );
    }
  }

  Future<void> _respond(PeerGroupJoinRequest request, bool accept) async {
    if (_responding.contains(request.requesterUid)) return;
    setState(() => _responding.add(request.requesterUid));
    try {
      await PeerGroupRepository.instance.respondToJoinRequest(
        groupId: widget.group.id,
        requesterUid: request.requesterUid,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Accepted ${request.requesterName}'
                : 'Declined ${request.requesterName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _responding.remove(request.requesterUid));
      }
    }
  }

  Future<void> _removeParticipant(PeerGroupMember member) async {
    if (_removing.contains(member.memberUid)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove participant?'),
        content: Text(
          'Remove ${member.memberName} from this group? They can request to join again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removing.add(member.memberUid));
    try {
      await PeerGroupRepository.instance.removeParticipant(
        groupId: widget.group.id,
        memberUid: member.memberUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${member.memberName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove participant: $e')),
      );
    } finally {
      if (mounted) setState(() => _removing.remove(member.memberUid));
    }
  }

  Future<void> _removeCoHost(PeerGroupRecord group, String cohostUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove co-host?'),
        content: const Text(
          'They will no longer be able to manage this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await PeerGroupRepository.instance.removeCoHost(
        groupId: group.id,
        cohostUid: cohostUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Co-host removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove co-host: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<PeerGroupRecord?>(
      stream: PeerGroupRepository.instance.watchGroup(widget.group.id),
      initialData: widget.group,
      builder: (context, groupSnap) {
        final group = groupSnap.data ?? widget.group;
        if (groupSnap.data == null && groupSnap.connectionState == ConnectionState.active) {
          return Scaffold(
            appBar: AppBar(title: const Text('Peer group')),
            body: const Center(child: Text('This group is no longer available.')),
          );
        }

        final isHost = _isHost(group);

        return Scaffold(
          appBar: AppBar(
            title: Text(group.title),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _SectionTitle(
                title: 'Participants',
                subtitle: 'Families who have joined this group.',
              ),
              StreamBuilder<List<PeerGroupMember>>(
                stream: PeerGroupRepository.instance.watchParticipants(group.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _LoadingBox();
                  }
                  final participants = snapshot.data ?? [];
                  if (participants.isEmpty) {
                    return _EmptyText(
                      'No one has joined yet. Accept a request or wait for an '
                      'invitation to be accepted.',
                    );
                  }
                  return Column(
                    children: participants.map((member) {
                      final busy = _removing.contains(member.memberUid);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                kPeerGroupAccent.withValues(alpha: 0.12),
                            child: Text(
                              member.memberName.isNotEmpty
                                  ? member.memberName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: kPeerGroupAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(member.memberName),
                          subtitle: Text(member.participantSubtitle),
                          trailing: busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  tooltip: 'Remove',
                                  onPressed: () => _removeParticipant(member),
                                  icon: const Icon(Icons.person_remove_rounded),
                                ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Join requests',
                subtitle: 'Review families who asked to join.',
              ),
              StreamBuilder<List<PeerGroupJoinRequest>>(
                stream: PeerGroupRepository.instance.watchJoinRequests(group.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _LoadingBox();
                  }
                  final pending =
                      (snapshot.data ?? []).where((r) => r.isPending).toList();
                  if (pending.isEmpty) {
                    return const _EmptyText('No pending requests.');
                  }
                  return Column(
                    children: pending.map((request) {
                      final busy = _responding.contains(request.requesterUid);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(request.requesterName),
                          subtitle: const Text('Requested to join'),
                          trailing: busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Decline',
                                      onPressed: () => _respond(request, false),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                    IconButton(
                                      tooltip: 'Accept',
                                      onPressed: () => _respond(request, true),
                                      icon: Icon(
                                        Icons.check_rounded,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Family invitations',
                subtitle: 'Invite by email. Pending invites are listed below.',
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _familyEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Family member email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _invitingFamily ? null : () => _sendFamilyInvite(group),
                    style: FilledButton.styleFrom(backgroundColor: kPeerGroupAccent),
                    child: Text(_invitingFamily ? '…' : 'Invite'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<PeerGroupInvitation>>(
                stream:
                    PeerGroupRepository.instance.watchGroupInvitations(group.id),
                builder: (context, snapshot) {
                  final invites = (snapshot.data ?? [])
                      .where((invite) => invite.isPending)
                      .toList();
                  if (invites.isEmpty) {
                    return const _EmptyText('No pending family invitations.');
                  }
                  return Column(
                    children: invites.map((invite) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(invite.inviteeEmail),
                          subtitle: const Text('Invitation pending'),
                          trailing: TextButton(
                            onPressed: () => _cancelInvitation(invite),
                            child: const Text('Cancel'),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              if (isHost) ...[
                const SizedBox(height: 24),
                _SectionTitle(
                  title: 'Co-hosts',
                  subtitle:
                      'Invite another approved volunteer to help manage this group.',
                ),
                if (group.cohostUids.isNotEmpty)
                  StreamBuilder<List<PeerGroupCoHostInvitation>>(
                    stream: PeerGroupRepository.instance
                        .watchGroupCoHostInvitations(group.id),
                    builder: (context, snapshot) {
                      final invites = snapshot.data ?? [];
                      return Column(
                        children: group.cohostUids.map((cohostUid) {
                          final invite = invites
                              .where((item) => item.inviteeUid == cohostUid)
                              .cast<PeerGroupCoHostInvitation?>()
                              .firstOrNull;
                          final name = invite?.inviteeName ?? 'Co-host';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                Icons.handshake_rounded,
                                color: kPeerGroupAccent,
                              ),
                              title: Text(name),
                              subtitle: const Text('Co-host'),
                              trailing: IconButton(
                                tooltip: 'Remove co-host',
                                onPressed: () =>
                                    _removeCoHost(group, cohostUid),
                                icon: const Icon(Icons.person_remove_rounded),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _coHostEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Volunteer email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          _invitingCoHost ? null : () => _sendCoHostInvite(group),
                      style:
                          FilledButton.styleFrom(backgroundColor: kPeerGroupAccent),
                      child: Text(_invitingCoHost ? '…' : 'Invite'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<PeerGroupCoHostInvitation>>(
                  stream: PeerGroupRepository.instance
                      .watchGroupCoHostInvitations(group.id),
                  builder: (context, snapshot) {
                    final pending = (snapshot.data ?? [])
                        .where((invite) => invite.isPending)
                        .toList();
                    if (pending.isEmpty) {
                      return const _EmptyText('No pending co-host invitations.');
                    }
                    return Column(
                      children: pending.map((invite) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(invite.inviteeName),
                            subtitle: Text(invite.inviteeEmail),
                            trailing: Text(
                              'Pending',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              height: 1.35,
            ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
