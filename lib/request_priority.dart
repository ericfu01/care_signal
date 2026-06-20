import 'package:flutter/material.dart';

/// Request urgency: normal matches one volunteer; urgent broadcasts to the lane.
class RequestPriority {
  RequestPriority._();

  static const normal = 'normal';
  static const urgent = 'urgent';

  static String field(bool urgent) => urgent ? RequestPriority.urgent : normal;

  static bool isUrgent(Map<String, dynamic> data) =>
      data['priority'] == urgent;
}

class RequestPriorityPicker extends StatelessWidget {
  const RequestPriorityPicker({
    super.key,
    required this.urgent,
    required this.onChanged,
  });

  final bool urgent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: false,
              label: Text('Normal'),
              icon: Icon(Icons.schedule_rounded, size: 18),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text('Urgent'),
              icon: Icon(Icons.priority_high_rounded, size: 18),
            ),
          ],
          selected: {urgent},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        const SizedBox(height: 8),
        Text(
          urgent
              ? 'Sent immediately to all volunteers in this category.'
              : 'Matched to one available volunteer in this category.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}
