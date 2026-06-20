import 'package:flutter/material.dart';

import 'volunteer_repository.dart';

class VolunteerFamilyChatPage extends StatefulWidget {
  const VolunteerFamilyChatPage({
    super.key,
    required this.familyUserId,
    required this.volunteerCatalogId,
    required this.volunteerName,
    this.familyDisplayName,
  });

  final String familyUserId;
  final String volunteerCatalogId;
  final String volunteerName;
  final String? familyDisplayName;

  @override
  State<VolunteerFamilyChatPage> createState() =>
      _VolunteerFamilyChatPageState();
}

class _VolunteerFamilyChatPageState extends State<VolunteerFamilyChatPage> {
  static const Color _volunteerBubble = Color(0xFF439A7D);

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  String? _familyName;

  @override
  void initState() {
    super.initState();
    _familyName = widget.familyDisplayName;
    _loadFamilyName();
  }

  Future<void> _loadFamilyName() async {
    if (_familyName != null) return;
    final name = await VolunteerRepository.instance
        .familyDisplayName(widget.familyUserId);
    if (!mounted) return;
    setState(() => _familyName = name ?? 'Family member');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await VolunteerRepository.instance.sendVolunteerReply(
        familyUserId: widget.familyUserId,
        volunteerCatalogId: widget.volunteerCatalogId,
        volunteerName: widget.volunteerName,
        text: text,
      );
      _controller.clear();
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
    final title = _familyName ?? 'Family member';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: VolunteerRepository.instance.watchFamilyMessages(
                  familyUserId: widget.familyUserId,
                  volunteerCatalogId: widget.volunteerCatalogId,
                ),
                builder: (context, snapshot) {
                  final lines = snapshot.data ?? [];
                  if (lines.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet.\nSay hello to start the conversation.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                              height: 1.4,
                            ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      final isVolunteer = line['isUser'] != true;
                      return _ChatBubble(
                        text: line['text'] as String? ?? '',
                        isVolunteer: isVolunteer,
                        volunteerColor: _volunteerBubble,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Reply to $title…',
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
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: _volunteerBubble,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send_rounded),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.isVolunteer,
    required this.volunteerColor,
  });

  final String text;
  final bool isVolunteer;
  final Color volunteerColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isVolunteer ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isVolunteer ? volunteerColor : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isVolunteer ? 18 : 4),
                bottomRight: Radius.circular(isVolunteer ? 4 : 18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                text,
                style: TextStyle(
                  color: isVolunteer ? Colors.white : Colors.black87,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
