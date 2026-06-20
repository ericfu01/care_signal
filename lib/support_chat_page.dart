import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'openai_config.dart';
import 'support_chat_assistant.dart';
import 'support_chat_list_page.dart';
import 'support_chat_title_service.dart';
import 'support_conversation_repository.dart';
import 'support_message_body.dart';

/// One support thread: Firestore `users/{uid}/support_conversations/{id}/messages`.
///
/// If [conversationId] is missing (e.g. hot reload after an old route), shows
/// [SupportChatListPage] instead of crashing.
class SupportChatPage extends StatelessWidget {
  const SupportChatPage({
    super.key,
    this.conversationId,
  });

  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    final id = conversationId?.trim();
    if (id == null || id.isEmpty) {
      return const SupportChatListPage();
    }
    return _SupportChatThreadPage(conversationId: id);
  }
}

class _SupportChatThreadPage extends StatefulWidget {
  const _SupportChatThreadPage({required this.conversationId});

  final String conversationId;

  @override
  State<_SupportChatThreadPage> createState() => _SupportChatThreadPageState();
}

class _SupportChatThreadPageState extends State<_SupportChatThreadPage> {
  static const Color _userBubble = Color(0xFF439A7D);

  static const String _welcomeText =
      'Hi — welcome to Care Signal.\n\nHow can I help you today?';

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final SupportChatAssistant _assistant;
  late final bool _assistantUsesOpenAi;
  bool _sending = false;
  String _conversationTitle = 'Support chat';

  @override
  void initState() {
    super.initState();
    _assistantUsesOpenAi = isOpenAiConfigured;
    _assistant = _assistantUsesOpenAi
        ? OpenAiSupportChatAssistant()
        : StubSupportChatAssistant();
    _listenConversationTitle();
  }

  void _listenConversationTitle() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('support_conversations')
        .doc(widget.conversationId)
        .snapshots()
        .listen((snap) {
      final title = snap.data()?['title'] as String?;
      if (title != null && title.trim().isNotEmpty && mounted) {
        setState(() => _conversationTitle = title.trim());
      }
    });
  }

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

  CollectionReference<Map<String, dynamic>> _messagesRef(String uid) {
    return SupportConversationRepository.instance.messagesRef(
      uid,
      widget.conversationId,
    );
  }

  Future<List<Map<String, String>>> _openAiMessagesFromFirestore(
    String uid,
    String latestUserText,
    String latestDocId,
  ) async {
    final trimmed = latestUserText.trim();
    final snap = await _messagesRef(uid)
        .orderBy('createdAt', descending: false)
        .limit(50)
        .get();

    final out = <Map<String, String>>[
      {'role': 'system', 'content': OpenAiSupportChatAssistant.systemPrompt},
    ];

    var sawLatest = false;
    for (final doc in snap.docs) {
      final data = doc.data();
      final messageText = doc.id == latestDocId
          ? trimmed
          : ((data['text'] as String?)?.trim() ?? '');
      if (doc.id == latestDocId) sawLatest = true;
      if (messageText.isEmpty) continue;
      final roleTag = data['role'] as String?;
      final fromUser = roleTag == 'assistant'
          ? false
          : roleTag == 'user'
              ? true
              : (data['fromUser'] as bool? ?? true);
      out.add({
        'role': fromUser ? 'user' : 'assistant',
        'content': messageText,
      });
    }

    if (!sawLatest) {
      out.add({'role': 'user', 'content': trimmed});
    }

    const maxAfterSystem = 21;
    if (out.length > maxAfterSystem + 1) {
      return [out.first, ...out.sublist(out.length - maxAfterSystem)];
    }
    return out;
  }

  bool _isFromUserBubble(Map<String, dynamic> data) {
    final roleTag = data['role'] as String?;
    if (roleTag == 'assistant') return false;
    if (roleTag == 'user') return true;
    return data['fromUser'] as bool? ?? true;
  }

  Future<void> _maybeGenerateTitle(
    String uid,
    String userText,
    String assistantReply,
  ) async {
    final convRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('support_conversations')
        .doc(widget.conversationId);
    final snap = await convRef.get();
    final data = snap.data();
    if (data == null) return;
    if (data['titleGenerated'] == true) return;

    final title = await generateSupportConversationTitle(
      userMessage: userText,
      assistantReply: assistantReply,
    );
    if (title == null || title.isEmpty) return;

    await SupportConversationRepository.instance.setConversationTitle(
      uid,
      widget.conversationId,
      title,
      titleGenerated: true,
    );
  }

  Future<void> _send(String uid) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message.')),
      );
      return;
    }
    if (_sending) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      final docRef = await _messagesRef(uid).add({
        'text': text,
        'fromUser': true,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await SupportConversationRepository.instance.touchConversation(
        uid,
        widget.conversationId,
      );

      List<Map<String, String>>? openAiHistory;
      if (_assistantUsesOpenAi) {
        openAiHistory = await _openAiMessagesFromFirestore(uid, text, docRef.id);
      }

      String replyText;
      var assistantSource = _assistantUsesOpenAi ? 'openai' : 'stub';
      try {
        replyText = await _assistant.replyToUserMessage(
          text,
          openAiHistory: openAiHistory,
        );
      } catch (e, st) {
        debugPrint('[CareSignal][SupportChat] assistant failed: $e\n$st');
        if (_assistantUsesOpenAi) {
          try {
            replyText = await _assistant.replyToUserMessage(
              text,
              openAiHistory: null,
            );
          } catch (e2) {
            replyText =
                'I could not reach the assistant just now, but your message was saved. '
                'Please try again in a moment.';
            assistantSource = 'openai_error';
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Assistant error: $e2')),
              );
            }
          }
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      await _messagesRef(uid).add({
        'text': replyText,
        'fromUser': false,
        'role': 'assistant',
        'source': assistantSource,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await SupportConversationRepository.instance.touchConversation(
        uid,
        widget.conversationId,
      );

      unawaited(_maybeGenerateTitle(uid, text, replyText));

      if (!mounted) return;
      _messageController.clear();
      _scrollToBottom();
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _scrollToBottom();
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final hint = e.code == 'permission-denied'
          ? ' Deploy firestore.rules for support_conversations.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save message (${e.code}).$hint')),
      );
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
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Support chat')),
        body: const Center(child: Text('Sign in to use support chat.')),
      );
    }

    final uid = user.uid;
    final messagesStream = _messagesRef(uid)
        .orderBy('createdAt', descending: false)
        .limit(500)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _conversationTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Care Signal support',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

                  final docs = snapshot.data?.docs ?? [];
                  final itemCount = 1 + docs.length;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _SupportChatBubble(
                          text: _welcomeText,
                          isUser: false,
                          userColor: _userBubble,
                        );
                      }
                      final doc = docs[index - 1];
                      final data = doc.data();
                      final text = data['text'] as String? ?? '';
                      final fromUser = _isFromUserBubble(data);
                      return _SupportChatBubble(
                        text: text,
                        isUser: fromUser,
                        userColor: _userBubble,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Material(
            elevation: 8,
            color: theme.colorScheme.surface,
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
                        onSubmitted: (_) => _send(uid),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: _sending ? null : () => _send(uid),
                      style: FilledButton.styleFrom(
                        backgroundColor: _userBubble,
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

class _SupportChatBubble extends StatelessWidget {
  const _SupportChatBubble({
    required this.text,
    required this.isUser,
    required this.userColor,
  });

  final String text;
  final bool isUser;
  final Color userColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 18),
    );
    final textColor = isUser ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser ? userColor : Colors.white,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SupportMessageBody(
                text: text,
                isUser: isUser,
                textColor: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
