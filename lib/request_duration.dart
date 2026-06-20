import 'package:flutter/material.dart';

import 'request_priority.dart';

/// Standard support-request lengths families can choose.
class RequestDuration {
  RequestDuration._();

  static const optionsMinutes = [30, 60, 90, 120, 180, 240];

  static int defaultForService(String serviceType) {
    switch (serviceType) {
      case 'respite':
        return 120;
      case 'meal':
        return 60;
      case 'transport':
        return 90;
      case 'peer':
        return 60;
      default:
        return 60;
    }
  }

  static String label(int minutes) {
    if (minutes < 60) return '$minutes min';
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return '${hours}h ${rest}m';
  }

  static Map<String, dynamic> fields(int minutes) => {
        'durationMinutes': minutes,
        'durationLabel': label(minutes),
      };
}

class RequestDurationPicker extends StatelessWidget {
  const RequestDurationPicker({
    super.key,
    required this.selectedMinutes,
    required this.onChanged,
    this.label = 'How long do you need help?',
  });

  final int selectedMinutes;
  final ValueChanged<int> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in RequestDuration.optionsMinutes)
              ChoiceChip(
                label: Text(RequestDuration.label(minutes)),
                selected: selectedMinutes == minutes,
                onSelected: (_) => onChanged(minutes),
              ),
          ],
        ),
      ],
    );
  }
}

class SupportRequestFormData {
  const SupportRequestFormData({
    required this.durationMinutes,
    required this.needsNow,
    required this.urgent,
    this.scheduledAt,
    this.instructions = '',
  });

  final int durationMinutes;
  final bool needsNow;
  final bool urgent;
  final DateTime? scheduledAt;
  final String instructions;
}

Future<SupportRequestFormData?> showSupportRequestFormDialog(
  BuildContext context, {
  required String title,
  required int defaultDurationMinutes,
  Future<String?> Function(SupportRequestFormData form)? validate,
}) {
  return showDialog<SupportRequestFormData>(
    context: context,
    builder: (ctx) => _SupportRequestFormDialog(
      title: title,
      defaultDurationMinutes: defaultDurationMinutes,
      validate: validate,
    ),
  );
}

class _SupportRequestFormDialog extends StatefulWidget {
  const _SupportRequestFormDialog({
    required this.title,
    required this.defaultDurationMinutes,
    this.validate,
  });

  final String title;
  final int defaultDurationMinutes;
  final Future<String?> Function(SupportRequestFormData form)? validate;

  @override
  State<_SupportRequestFormDialog> createState() =>
      _SupportRequestFormDialogState();
}

class _SupportRequestFormDialogState extends State<_SupportRequestFormDialog> {
  late int _durationMinutes;
  bool _needsNow = true;
  bool _urgent = false;
  DateTime? _date;
  TimeOfDay? _time;
  String? _timeError;
  bool _validating = false;
  final _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _durationMinutes = widget.defaultDurationMinutes;
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _timeError = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ??
          TimeOfDay.fromDateTime(
            DateTime.now().add(const Duration(hours: 1)),
          ),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _timeError = null;
      });
    }
  }

  String _dateLabel() {
    if (_date == null) return 'Choose a date';
    final d = _date!;
    return '${d.month}/${d.day}/${d.year}';
  }

  Future<void> _submit() async {
    if (_needsNow) {
      final form = SupportRequestFormData(
        durationMinutes: _durationMinutes,
        needsNow: true,
        urgent: _urgent,
        instructions: _instructionsController.text.trim(),
      );
      if (widget.validate != null && !_urgent) {
        setState(() {
          _validating = true;
          _timeError = null;
        });
        final error = await widget.validate!(form);
        if (!mounted) return;
        setState(() => _validating = false);
        if (error != null) {
          setState(() => _timeError = error);
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(form);
      return;
    }

    if (_date == null || _time == null) {
      setState(() => _timeError = 'Please choose both a date and a time.');
      return;
    }

    final scheduledAt = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    if (!scheduledAt.isAfter(DateTime.now())) {
      setState(
        () => _timeError = 'Choose a date and time in the future.',
      );
      return;
    }

    final form = SupportRequestFormData(
      durationMinutes: _durationMinutes,
      needsNow: false,
      urgent: _urgent,
      scheduledAt: scheduledAt,
      instructions: _instructionsController.text.trim(),
    );

    if (widget.validate != null && !_urgent) {
      setState(() {
        _validating = true;
        _timeError = null;
      });
      final error = await widget.validate!(form);
      if (!mounted) return;
      setState(() => _validating = false);
      if (error != null) {
        setState(() => _timeError = error);
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(form);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'When do you need help?',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('ASAP'),
                  icon: Icon(Icons.bolt_rounded, size: 18),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Schedule'),
                  icon: Icon(Icons.event_rounded, size: 18),
                ),
              ],
              selected: {_needsNow},
              onSelectionChanged: (selection) {
                setState(() {
                  _needsNow = selection.first;
                  _timeError = null;
                });
              },
            ),
            if (_timeError != null && _needsNow) ...[
              const SizedBox(height: 8),
              Text(
                _timeError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            if (!_needsNow) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Date'),
                subtitle: Text(_dateLabel()),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Time'),
                subtitle: Text(
                  _time == null ? 'Choose a time' : _time!.format(context),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickTime,
              ),
              if (_timeError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _timeError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            RequestPriorityPicker(
              urgent: _urgent,
              onChanged: (value) => setState(() => _urgent = value),
            ),
            const SizedBox(height: 16),
            RequestDurationPicker(
              selectedMinutes: _durationMinutes,
              onChanged: (value) => setState(() => _durationMinutes = value),
            ),
            const SizedBox(height: 16),
            Text(
              'Add location or instructions so volunteers know how to help.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
                hintText: 'Address, access notes, what you need…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _validating ? null : _submit,
          child: _validating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send request'),
        ),
      ],
    );
  }
}
