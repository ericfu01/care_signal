import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _joined = <String>{};
  final _joining = <String>{};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadJoined();
  }

  Future<void> _loadJoined() async {
    setState(() => _loading = true);
    try {
      final groups = SupportCatalog.peerGroups;
      final joined = <String>{};
      for (final group in groups) {
        if (await SupportRepository.instance.hasPeerGroupRequest(group.id)) {
          joined.add(group.id);
        }
      }
      if (!mounted) return;
      setState(() => _joined.addAll(joined));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join(CatalogPeerGroup group) async {
    if (_joined.contains(group.id) || _joining.contains(group.id)) return;
    setState(() => _joining.add(group.id));
    try {
      await SupportRepository.instance.submitPeerGroupRequest(
        groupId: group.id,
        groupTitle: group.title,
      );
      if (!mounted) return;
      setState(() {
        _joined.add(group.id);
        _joining.remove(group.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent for “${group.title}”.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining.remove(group.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = SupportCatalog.peerGroups;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer Groups'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                'Request to join a group. A coordinator will follow up with details.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: 20),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 20),
              ...groups.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PeerGroupCard(
                    item: g,
                    accent: PeerGroupsPage._accent,
                    joined: _joined.contains(g.id),
                    joining: _joining.contains(g.id),
                    onJoin: () => _join(g),
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

class _PeerGroupCard extends StatelessWidget {
  const _PeerGroupCard({
    required this.item,
    required this.accent,
    required this.joined,
    required this.joining,
    required this.onJoin,
  });

  final CatalogPeerGroup item;
  final Color accent;
  final bool joined;
  final bool joining;
  final VoidCallback onJoin;

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
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PeerMetaRow(
                      icon: Icons.event_rounded,
                      text: item.schedule,
                    ),
                    const SizedBox(height: 4),
                    _PeerMetaRow(
                      icon: item.mode.startsWith('In person')
                          ? Icons.place_rounded
                          : Icons.videocam_rounded,
                      text: item.mode,
                    ),
                    const SizedBox(height: 4),
                    _PeerMetaRow(
                      icon: Icons.people_outline_rounded,
                      text: item.members,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: joined || joining ? null : onJoin,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              child: Text(
                joined
                    ? 'Requested'
                    : joining
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

