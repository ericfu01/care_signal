import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_chat_page.dart';
import 'family_chat_models.dart';
import 'family_chat_repository.dart';
import 'family_models.dart';
import 'family_presence.dart';
import 'family_repository.dart';
import 'presence_service.dart';

/// Inbox of 1:1 family message threads.
class FamilyMessagesInboxPage extends StatelessWidget {
  const FamilyMessagesInboxPage({super.key});

  static const Color _accent = Color(0xFF439A7D);

  String _presenceLabel(UserProfile profile, String myUid) {
    return FamilyPresence.label(
      lastActiveAt: profile.lastActiveAt,
      isCurrentUser: profile.uid == myUid,
      currentUserAppActive:
          profile.uid == myUid && PresenceService.appInForeground,
    );
  }

  bool _isOnline(UserProfile profile, String myUid) {
    if (profile.uid == myUid && PresenceService.appInForeground) return true;
    return FamilyPresence.isOnline(profile.lastActiveAt);
  }

  String _formatWhen(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final m = local.minute.toString().padLeft(2, '0');
      final am = local.hour < 12 ? 'AM' : 'PM';
      return '$h:$m $am';
    }
    return '${local.month}/${local.day}/${local.year}';
  }

  Future<void> _pickFamilyMemberAndChat(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final myProfile = await FamilyRepository.instance.getUserProfile(user.uid);
    if (myProfile == null || !myProfile.hasFamily) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join a family to message members.')),
      );
      return;
    }

    final members = await FamilyRepository.instance
        .watchFamilyMembers(myProfile.familyId!)
        .first;
    final others =
        members.where((m) => m.uid != user.uid).toList();

    if (!context.mounted) return;
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite more family members to start messaging.'),
        ),
      );
      return;
    }

    final picked = await showModalBottomSheet<UserProfile>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Message a family member',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ...others.map(
                (m) {
                  final presence = _presenceLabel(m, user.uid);
                  final online = _isOnline(m, user.uid);
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        initialsFromName(m.displayName),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(m.displayName),
                    subtitle: Text(
                      presence,
                      style: TextStyle(
                        color: online
                            ? const Color(0xFF2E7D32)
                            : Colors.black54,
                        fontWeight:
                            online ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onTap: () => Navigator.of(ctx).pop(m),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (picked == null || !context.mounted) return;
    await _openChatWith(context, myProfile, picked);
  }

  Future<void> _openChatWith(
    BuildContext context,
    UserProfile me,
    UserProfile other,
  ) async {
    final chatId = await FamilyChatRepository.instance.openOrCreateThread(
      familyId: me.familyId!,
      me: me,
      other: other,
    );
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FamilyChatPage(
          familyId: me.familyId!,
          chatId: chatId,
          otherUid: other.uid,
          otherDisplayName: other.displayName,
        ),
      ),
    );
  }

  Future<void> _openThread(
    BuildContext context,
    String familyId,
    FamilyChatThread thread,
    String myUid,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FamilyChatPage(
          familyId: familyId,
          chatId: thread.id,
          otherUid: thread.otherParticipantUid(myUid),
          otherDisplayName: thread.otherParticipantName(myUid),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family messages')),
        body: const Center(child: Text('Sign in to message your family.')),
      );
    }

    return FutureBuilder<UserProfile?>(
      future: FamilyRepository.instance.getUserProfile(user.uid),
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Family messages')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final profile = profileSnap.data;
        if (profile == null || !profile.hasFamily) {
          return Scaffold(
            appBar: AppBar(title: const Text('Family messages')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Create or join a family to message members privately in the app.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          );
        }

        final familyId = profile.familyId!;
        final threadsStream = FamilyChatRepository.instance.watchThreads(
          familyId: familyId,
          myUid: user.uid,
        );
        final membersStream =
            FamilyRepository.instance.watchFamilyMembers(familyId);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Family messages'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _pickFamilyMemberAndChat(context),
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('New message'),
          ),
          body: StreamBuilder<List<UserProfile>>(
            stream: membersStream,
            builder: (context, membersSnap) {
              final members = membersSnap.data ?? [];
              final byUid = {for (final m in members) m.uid: m};

              return StreamBuilder<List<FamilyChatThread>>(
                stream: threadsStream,
                builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load messages.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting ||
                  membersSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final threads = snapshot.data ?? [];
              if (threads.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap New message to chat with someone in your family.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: threads.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  final otherUid = thread.otherParticipantUid(user.uid);
                  final otherProfile = byUid[otherUid];
                  final name = thread.otherParticipantName(user.uid);
                  final preview = thread.lastMessageText.isEmpty
                      ? 'No messages yet'
                      : thread.lastMessageText;
                  final presence = otherProfile != null
                      ? _presenceLabel(otherProfile, user.uid)
                      : 'No activity yet';
                  final online = otherProfile != null &&
                      _isOnline(otherProfile, user.uid);
                  return ListTile(
                    isThreeLine: true,
                    leading: CircleAvatar(
                      backgroundColor: _accent.withValues(alpha: 0.15),
                      child: Text(
                        initialsFromName(name),
                        style: const TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          presence,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: online
                                ? const Color(0xFF2E7D32)
                                : Colors.black54,
                            fontWeight:
                                online ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      _formatWhen(thread.lastMessageAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.black45,
                      ),
                    ),
                    onTap: () => _openThread(
                      context,
                      familyId,
                      thread,
                      user.uid,
                    ),
                  );
                },
              );
                },
              );
            },
          ),
        );
      },
    );
  }
}
