import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_chat_repository.dart';
import 'family_messages_inbox_page.dart';
import 'family_presence.dart';

/// 1:1 chat between two family members.
///
/// If required ids are missing (e.g. hot reload), shows [FamilyMessagesInboxPage].
class FamilyChatPage extends StatefulWidget {
  const FamilyChatPage({
    super.key,
    this.familyId,
    this.chatId,
    this.otherUid,
    this.otherDisplayName,
  });

  final String? familyId;
  final String? chatId;
  final String? otherUid;
  final String? otherDisplayName;

  @override
  State<FamilyChatPage> createState() => _FamilyChatPageState();
}

/// Kept for hot-reload compatibility with earlier builds of this screen.
class _FamilyChatPageState extends State<FamilyChatPage> {
  @override
  Widget build(BuildContext context) {
    final fId = widget.familyId?.trim() ?? '';
    final cId = widget.chatId?.trim() ?? '';
    final oUid = widget.otherUid?.trim() ?? '';
    final oName = widget.otherDisplayName?.trim() ?? '';

    if (fId.isEmpty || cId.isEmpty || oUid.isEmpty || oName.isEmpty) {
      return const FamilyMessagesInboxPage();
    }

    return _FamilyChatThreadPage(
      familyId: fId,
      chatId: cId,
      otherUid: oUid,
      otherDisplayName: oName,
    );
  }
}

class _FamilyChatThreadPage extends StatefulWidget {
  const _FamilyChatThreadPage({
    required this.familyId,
    required this.chatId,
    required this.otherUid,
    required this.otherDisplayName,
  });

  final String familyId;
  final String chatId;
  final String otherUid;
  final String otherDisplayName;

  @override
  State<_FamilyChatThreadPage> createState() => _FamilyChatThreadPageState();
}

class _FamilyChatThreadPageState extends State<_FamilyChatThreadPage> {
  static const Color _myBubble = Color(0xFF439A7D);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await FamilyChatRepository.instance.sendMessage(
        familyId: widget.familyId,
        chatId: widget.chatId,
        senderUid: user.uid,
        senderName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Member',
        text: text,
      );
      if (!mounted) return;
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherDisplayName)),
        body: const Center(child: Text('Sign in to send messages.')),
      );
    }

    final messagesStream = FamilyChatRepository.instance.watchMessages(
      familyId: widget.familyId,
      chatId: widget.chatId,
    );

    final otherProfileStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: otherProfileStream,
          builder: (context, profileSnap) {
            final lastActive = profileSnap.hasData && profileSnap.data!.exists
                ? FamilyPresence.timestampToDate(
                    profileSnap.data!.data()?['lastActiveAt'],
                  )
                : null;
            final presenceLabel = FamilyPresence.label(
              lastActiveAt: lastActive,
              isCurrentUser: false,
              currentUserAppActive: false,
            );
            final online = FamilyPresence.isOnline(lastActive);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherDisplayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  presenceLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: online
                            ? const Color(0xFF2E7D32)
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.65),
                        fontWeight:
                            online ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              child: StreamBuilder(
                stream: messagesStream,
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Say hello to ${widget.otherDisplayName}. '
                          'Only your family can see this chat.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                                height: 1.35,
                              ),
                        ),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderUid == user.uid;
                      return _FamilyChatBubble(
                        text: msg.text,
                        isMe: isMe,
                        senderLabel: isMe ? null : msg.senderName,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_sending,
                        decoration: InputDecoration(
                          hintText: 'Message…',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: _myBubble,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyChatBubble extends StatelessWidget {
  const _FamilyChatBubble({
    required this.text,
    required this.isMe,
    this.senderLabel,
  });

  final String text;
  final bool isMe;
  final String? senderLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (senderLabel != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    senderLabel!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black45,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
              DecoratedBox(
                decoration: BoxDecoration(
                  color: isMe ? _FamilyChatThreadPageState._myBubble : Colors.white,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
