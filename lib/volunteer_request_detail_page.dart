import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'counter_time_dialog.dart';
import 'volunteer_family_chat_page.dart';
import 'volunteer_repository.dart';

class VolunteerRequestDetailPage extends StatefulWidget {
  const VolunteerRequestDetailPage({
    super.key,
    required this.assignment,
    required this.volunteerName,
    required this.volunteerCatalogId,
    this.onStatusChanged,
  });

  final VolunteerAssignment assignment;
  final String volunteerName;
  final String volunteerCatalogId;
  final ValueChanged<String>? onStatusChanged;

  @override
  State<VolunteerRequestDetailPage> createState() =>
      _VolunteerRequestDetailPageState();
}

class _VolunteerRequestDetailPageState extends State<VolunteerRequestDetailPage> {
  bool _updating = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.assignment.status;
  }

  VolunteerAssignment get assignment => widget.assignment;

  Future<void> _openMaps(String address) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps.')),
      );
    }
  }

  Future<void> _proposeCounterTime() async {
    final proposed = await showCounterTimeDialog(
      context,
      familyName: assignment.familyName,
    );
    if (proposed == null || !mounted) return;

    setState(() => _updating = true);
    try {
      await VolunteerRepository.instance.proposeCounterTime(
        familyUserId: assignment.familyUserId,
        requestId: assignment.requestId,
        counterScheduledAt: proposed,
        volunteerUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        volunteerName: widget.volunteerName,
      );
      if (!mounted) return;
      setState(() => _status = 'counter_proposed');
      widget.onStatusChanged?.call('counter_proposed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Counter time sent — waiting for the family to respond.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send counter time: $e')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (status == 'accepted') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Accept this request?'),
          content: Text(
            'You will be helping ${assignment.familyName} for '
            '${assignment.durationLabel}. '
            'Your calendar will be blocked for that time so you will not '
            'receive other requests during the visit.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _updating = true);
    try {
      await VolunteerRepository.instance.updateAssignmentStatus(
        familyUserId: assignment.familyUserId,
        requestId: assignment.requestId,
        status: status,
        volunteerUid: FirebaseAuth.instance.currentUser?.uid,
        volunteerName: widget.volunteerName,
      );
      if (!mounted) return;
      setState(() => _status = status);
      widget.onStatusChanged?.call(status);

      if (status == 'accepted') {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Request accepted'),
            content: Text(
              'You are now connected with ${assignment.familyName}. '
              'Your calendar is blocked for ${assignment.durationLabel}. '
              'Message them to confirm details, then mark complete when finished.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Got it'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openMessage();
                },
                child: const Text('Message family'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request marked as $status.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: $e')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _openMessage() {
    final catalogId =
        assignment.volunteerCatalogId ?? widget.volunteerCatalogId;
    if (catalogId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VolunteerFamilyChatPage(
          familyUserId: assignment.familyUserId,
          volunteerCatalogId: catalogId,
          volunteerName: widget.volunteerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = assignment.routeSummary;
    final location = assignment.locationSummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request details'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF439A7D).withValues(alpha: 0.15),
                child: Text(
                  _initials(assignment.familyName),
                  style: const TextStyle(
                    color: Color(0xFF439A7D),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.familyName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignment.serviceTypeLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    if (assignment.isUrgent) ...[
                      const SizedBox(height: 6),
                      Chip(
                        label: const Text('Urgent · all volunteers notified'),
                        backgroundColor: Colors.red.shade50,
                        side: BorderSide(color: Colors.red.shade200),
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusChip(status: _status),
            ],
          ),
          if (_status == 'counter_proposed') ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Text(
                'You proposed ${assignment.counterWhenLabel()}. '
                'Waiting for ${assignment.familyName} to accept or decline.',
                style: TextStyle(
                  color: Colors.purple.shade900,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _DetailSection(
            title: 'When',
            child: Text(
              assignment.whenLabel(),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Duration',
            child: Text(
              assignment.durationLabel,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (_status == 'accepted' &&
              assignment.blockedStartAt != null &&
              assignment.blockedEndAt != null) ...[
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Your calendar',
              child: Text(
                'Blocked ${assignment.blockedWindowLabel}',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
          if (assignment.needsNow) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'ASAP — family needs help soon',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Location',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location, style: theme.textTheme.bodyLarge),
                  if (assignment.homeAddress != null &&
                      assignment.homeAddress!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openMaps(assignment.homeAddress!),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open home in Maps'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (route.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Route',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (assignment.pickup != null &&
                      assignment.pickup!.isNotEmpty) ...[
                    Text('Pickup', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(assignment.pickup!, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openMaps(assignment.pickup!),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open pickup in Maps'),
                    ),
                  ],
                  if (assignment.destination != null &&
                      assignment.destination!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Destination', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      assignment.destination!,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openMaps(assignment.destination!),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open destination in Maps'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (assignment.notes != null) ...[
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Instructions from family',
              child: Text(
                assignment.notes!,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
            ),
          ],
          if (assignment.familyEmail != null) ...[
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Contact',
              child: Text(
                assignment.familyEmail!,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_status == 'pending' || _status == 'follow_up') ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _updating ? null : () => _updateStatus('accepted'),
                    child: _updating
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _updating ? null : () => _updateStatus('declined'),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _updating ? null : _proposeCounterTime,
              icon: const Icon(Icons.schedule_send_outlined),
              label: const Text('Unavailable — suggest another time'),
            ),
          ],
          if (_status == 'accepted') ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _updating ? null : () => _updateStatus('completed'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF439A7D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: _updating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Mark complete',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openMessage,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Message',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'accepted' => Colors.green.shade700,
      'completed' => Colors.blue.shade700,
      'declined' => Colors.red.shade700,
      'cancelled' => Colors.grey.shade700,
      'follow_up' => Colors.purple.shade700,
      'counter_proposed' => Colors.purple.shade700,
      _ => Colors.orange.shade800,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
