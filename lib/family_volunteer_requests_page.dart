import 'package:flutter/material.dart';

import 'family_volunteer_request_helpers.dart';
import 'support_repository.dart';
import 'volunteer_message_schedule_pages.dart';

class FamilyVolunteerRequestsPage extends StatefulWidget {
  const FamilyVolunteerRequestsPage({super.key});

  @override
  State<FamilyVolunteerRequestsPage> createState() =>
      _FamilyVolunteerRequestsPageState();
}

class _FamilyVolunteerRequestsPageState extends State<FamilyVolunteerRequestsPage> {
  int _filter = 0;

  List<Map<String, dynamic>> _filterRequests(List<Map<String, dynamic>> all) {
    return switch (_filter) {
      1 => all.where((r) {
          final status = r['status'] as String? ?? 'pending';
          return FamilyVolunteerRequestHelpers.isActive(status);
        }).toList(),
      2 => all.where((r) {
          final status = r['status'] as String? ?? 'pending';
          return FamilyVolunteerRequestHelpers.isHistory(status);
        }).toList(),
      _ => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My requests'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('All')),
                ButtonSegment(value: 1, label: Text('Active')),
                ButtonSegment(value: 2, label: Text('History')),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupportRepository.instance.watchVolunteerRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data ?? [];
                final items = _filterRequests(all);

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _filter == 1
                            ? 'No active requests.'
                            : _filter == 2
                                ? 'No completed or cancelled requests yet.'
                                : 'No volunteer requests yet.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final request = items[index];
                    return FamilyVolunteerRequestCard(
                      request: request,
                      title: FamilyVolunteerRequestHelpers.visitTitle(request),
                      subtitle: FamilyVolunteerRequestHelpers.formatVisit(request),
                      showActions: true,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FamilyVolunteerRequestCard extends StatefulWidget {
  const FamilyVolunteerRequestCard({
    super.key,
    required this.request,
    required this.title,
    required this.subtitle,
    this.showActions = false,
  });

  final Map<String, dynamic> request;
  final String title;
  final String subtitle;
  final bool showActions;

  @override
  State<FamilyVolunteerRequestCard> createState() =>
      _FamilyVolunteerRequestCardState();
}

class _FamilyVolunteerRequestCardState extends State<FamilyVolunteerRequestCard> {
  bool _busy = false;

  String get _status => widget.request['status'] as String? ?? 'pending';

  Future<void> _respondToCounter({required bool accept}) async {
    final requestId = widget.request['requestId'] as String?;
    if (requestId == null || requestId.isEmpty) return;

    setState(() => _busy = true);
    try {
      await SupportRepository.instance.respondToCounterProposal(
        requestId: requestId,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Alternate time accepted — visit confirmed.'
                : 'Alternate time declined — request sent back to volunteers.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final requestId = widget.request['requestId'] as String?;
    if (requestId == null || requestId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text(
          _status == 'accepted'
              ? 'This will cancel your confirmed visit. The assigned volunteer will be notified.'
              : 'Volunteers involved with this request will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await SupportRepository.instance.cancelVolunteerRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel request: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openMessage() {
    final catalogId = widget.request['volunteerId'] as String?;
    if (catalogId == null || catalogId.isEmpty) return;
    final volunteerName =
        widget.request['volunteerName'] as String? ?? 'Volunteer';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VolunteerMessagePage(
          volunteerId: catalogId,
          volunteerName: volunteerName,
        ),
      ),
    );
  }

  Color _statusColor() {
    return switch (_status) {
      'accepted' => Colors.green.shade700,
      'completed' => Colors.blue.shade700,
      'declined' => Colors.red.shade700,
      'cancelled' => Colors.grey.shade700,
      'counter_proposed' => Colors.purple.shade700,
      'follow_up' => Colors.purple.shade700,
      _ => Colors.orange.shade800,
    };
  }

  @override
  Widget build(BuildContext context) {
    final urgent = FamilyVolunteerRequestHelpers.isUrgent(widget.request);
    final showActions = widget.showActions &&
        (FamilyVolunteerRequestHelpers.canCancel(_status) ||
            _status == 'counter_proposed' ||
            FamilyVolunteerRequestHelpers.canMessage(widget.request));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FamilyVolunteerRequestHelpers.serviceTypeLabel(
                        widget.request,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF439A7D),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      FamilyVolunteerRequestHelpers.statusLabel(_status),
                      style: TextStyle(
                        color: _statusColor(),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (urgent) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'URGENT',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  height: 1.35,
                ),
          ),
          if (showActions) ...[
            if (_status == 'counter_proposed') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _busy ? null : () => _respondToCounter(accept: true),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept time'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _busy ? null : () => _respondToCounter(accept: false),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (FamilyVolunteerRequestHelpers.canMessage(widget.request))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _openMessage,
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 18),
                        label: const Text('Message'),
                      ),
                    ),
                  if (FamilyVolunteerRequestHelpers.canMessage(widget.request) &&
                      FamilyVolunteerRequestHelpers.canCancel(_status))
                    const SizedBox(width: 10),
                  if (FamilyVolunteerRequestHelpers.canCancel(_status))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _cancel,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
