import 'package:flutter/material.dart';

import 'feedback_models.dart';
import 'staff_repository.dart';

/// Staff view of one feedback submission, including photo evidence.
class StaffFeedbackDetailPage extends StatefulWidget {
  const StaffFeedbackDetailPage({
    required this.feedback,
    super.key,
  });

  final FeedbackRecord feedback;

  @override
  State<StaffFeedbackDetailPage> createState() =>
      _StaffFeedbackDetailPageState();
}

class _StaffFeedbackDetailPageState extends State<StaffFeedbackDetailPage> {
  late FeedbackRecord _feedback;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _feedback = widget.feedback;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Unknown time';
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d · $h:$min';
  }

  void _openPhoto(BuildContext context, String url, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('Photo ${index + 1}'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setResolved(bool resolved) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await StaffRepository.instance.setFeedbackStatus(
        feedbackId: _feedback.id,
        resolved: resolved,
      );
      if (!mounted) return;
      setState(() {
        _feedback = FeedbackRecord(
          id: _feedback.id,
          message: _feedback.message,
          uid: _feedback.uid,
          email: _feedback.email,
          photoUrls: _feedback.photoUrls,
          createdAt: _feedback.createdAt,
          status: resolved ? FeedbackStatus.resolved : FeedbackStatus.open,
          resolvedAt: resolved ? DateTime.now() : null,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resolved ? 'Marked resolved' : 'Reopened'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = _feedback.isResolved;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback detail'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(
                resolved ? Icons.check_circle : Icons.mark_email_unread_outlined,
                size: 18,
                color: resolved ? Colors.green.shade800 : Colors.orange.shade800,
              ),
              label: Text(resolved ? 'Resolved' : 'Open'),
              backgroundColor:
                  resolved ? Colors.green.shade50 : Colors.orange.shade50,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'From',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(_feedback.email?.isNotEmpty == true
              ? _feedback.email!
              : 'Signed-in user'),
          if (_feedback.uid != null && _feedback.uid!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'UID: ${_feedback.uid}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatDate(_feedback.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          if (resolved && _feedback.resolvedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Resolved ${_formatDate(_feedback.resolvedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Message',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _feedback.message.isEmpty ? '(No message)' : _feedback.message,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 24),
          Text(
            'Evidence photos',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (!_feedback.hasPhotos)
            Text(
              'No photos attached.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _feedback.photoUrls.length; i++)
                  InkWell(
                    onTap: () => _openPhoto(context, _feedback.photoUrls[i], i),
                    borderRadius: BorderRadius.circular(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _feedback.photoUrls[i],
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 104,
                          height: 104,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 28),
          if (resolved)
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _setResolved(false),
              icon: const Icon(Icons.replay_rounded),
              label: Text(_saving ? 'Saving…' : 'Reopen'),
            )
          else
            FilledButton.icon(
              onPressed: _saving ? null : () => _setResolved(true),
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving…' : 'Mark resolved'),
            ),
        ],
      ),
    );
  }
}
