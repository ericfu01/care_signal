import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'support_chat_page.dart';
import 'support_conversation_models.dart';
import 'support_conversation_repository.dart';

/// ChatGPT-style hub: start a new thread or open a previous one.
class SupportChatListPage extends StatelessWidget {
  const SupportChatListPage({super.key});

  static const Color _accent = Color(0xFF439A7D);

  Future<void> _startNewChat(BuildContext context, String uid) async {
    final id = await SupportConversationRepository.instance
        .createConversation(uid);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SupportChatPage(conversationId: id),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Support chat')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Sign in to start support chats and save your conversation history.',
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

    final uid = user.uid;
    final stream =
        SupportConversationRepository.instance.watchConversations(uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support chat'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewChat(context, uid),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('New chat'),
      ),
      body: StreamBuilder<List<SupportConversation>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load conversations.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 100),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap New chat to talk with Care Signal support. '
                      'Each chat is saved so you can pick up where you left off.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = list[index];
              return Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.black12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _accent.withValues(alpha: 0.15),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: _accent),
                  ),
                  title: Text(
                    c.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(_formatWhen(c.updatedAt ?? c.createdAt)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            SupportChatPage(conversationId: c.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
