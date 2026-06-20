import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_repository.dart';
import 'volunteer_availability.dart';

class VolunteerAvailabilityPage extends StatefulWidget {
  const VolunteerAvailabilityPage({
    super.key,
    this.initialSchedule = const VolunteerAvailabilitySchedule(),
  });

  final VolunteerAvailabilitySchedule initialSchedule;

  @override
  State<VolunteerAvailabilityPage> createState() =>
      _VolunteerAvailabilityPageState();
}

class _DayEditor {
  _DayEditor({
    required this.weekday,
    required this.enabled,
    required this.start,
    required this.end,
  });

  final int weekday;
  bool enabled;
  TimeOfDay start;
  TimeOfDay end;

  String get label {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - DateTime.monday];
  }
}

class _VolunteerAvailabilityPageState extends State<VolunteerAvailabilityPage> {
  late final List<_DayEditor> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _days = List.generate(7, (index) {
      final weekday = DateTime.monday + index;
      final existing = widget.initialSchedule.slots
          .where((slot) => slot.weekday == weekday)
          .toList();
      if (existing.isEmpty) {
        return _DayEditor(
          weekday: weekday,
          enabled: false,
          start: const TimeOfDay(hour: 9, minute: 0),
          end: const TimeOfDay(hour: 17, minute: 0),
        );
      }
      final slot = existing.first;
      return _DayEditor(
        weekday: weekday,
        enabled: true,
        start: VolunteerAvailabilitySchedule.minutesToTime(slot.startMinutes),
        end: VolunteerAvailabilitySchedule.minutesToTime(slot.endMinutes),
      );
    });
  }

  Future<void> _pickTime(_DayEditor day, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? day.start : day.end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        day.start = picked;
      } else {
        day.end = picked;
      }
    });
  }

  VolunteerAvailabilitySchedule _buildSchedule() {
    final slots = <VolunteerAvailabilitySlot>[];
    for (final day in _days.where((d) => d.enabled)) {
      final start = VolunteerAvailabilitySchedule.timeToMinutes(day.start);
      final end = VolunteerAvailabilitySchedule.timeToMinutes(day.end);
      if (end <= start) continue;
      slots.add(
        VolunteerAvailabilitySlot(
          weekday: day.weekday,
          startMinutes: start,
          endMinutes: end,
        ),
      );
    }
    return VolunteerAvailabilitySchedule(slots: slots);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final invalidDays = _days.where((day) {
      if (!day.enabled) return false;
      return VolunteerAvailabilitySchedule.timeToMinutes(day.end) <=
          VolunteerAvailabilitySchedule.timeToMinutes(day.start);
    }).toList();

    if (invalidDays.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'End time must be after start time on ${invalidDays.first.label}.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FamilyRepository.instance.saveVolunteerAvailabilitySchedule(
        uid: uid,
        schedule: _buildSchedule(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save schedule: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly availability'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            'Set when you are available each week. Your status updates automatically — '
            'no manual on/off switch needed.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          for (final day in _days) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: day.enabled
                      ? const Color(0xFF439A7D).withValues(alpha: 0.45)
                      : Colors.black12,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      day.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: day.enabled,
                    activeThumbColor: const Color(0xFF439A7D),
                    onChanged: (value) => setState(() => day.enabled = value),
                  ),
                  if (day.enabled) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: const Text('Start'),
                      subtitle: Text(day.start.format(context)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickTime(day, isStart: true),
                    ),
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: const Text('End'),
                      subtitle: Text(day.end.format(context)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickTime(day, isStart: false),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF439A7D),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save weekly schedule'),
          ),
        ],
      ),
    );
  }
}
