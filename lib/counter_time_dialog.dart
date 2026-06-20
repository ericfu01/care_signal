import 'package:flutter/material.dart';

/// Lets a volunteer propose an alternate time when they are unavailable.
Future<DateTime?> showCounterTimeDialog(
  BuildContext context, {
  required String familyName,
}) async {
  DateTime? date;
  TimeOfDay? time;
  String? error;

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> pickDate() async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? now,
            firstDate: now,
            lastDate: now.add(const Duration(days: 365)),
          );
          if (picked != null) {
            setState(() {
              date = picked;
              error = null;
            });
          }
        }

        Future<void> pickTime() async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time ??
                TimeOfDay.fromDateTime(
                  DateTime.now().add(const Duration(hours: 2)),
                ),
          );
          if (picked != null) {
            setState(() {
              time = picked;
              error = null;
            });
          }
        }

        String dateLabel() {
          if (date == null) return 'Choose a date';
          final d = date!;
          return '${d.month}/${d.day}/${d.year}';
        }

        return AlertDialog(
          title: const Text('Suggest another time'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'You are unavailable at the requested time. '
                  'Propose when you could help $familyName instead.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded),
                  title: const Text('Date'),
                  subtitle: Text(dateLabel()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pickDate,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Time'),
                  subtitle: Text(
                    time == null ? 'Choose a time' : time!.format(context),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pickTime,
                ),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (date == null || time == null) {
                  setState(
                    () => error = 'Please choose both a date and a time.',
                  );
                  return;
                }
                final proposed = DateTime(
                  date!.year,
                  date!.month,
                  date!.day,
                  time!.hour,
                  time!.minute,
                );
                if (!proposed.isAfter(DateTime.now())) {
                  setState(
                    () => error = 'Choose a date and time in the future.',
                  );
                  return;
                }
                Navigator.of(ctx).pop(proposed);
              },
              child: const Text('Send counter time'),
            ),
          ],
        );
      },
    ),
  );
}

String formatRequestDateTime(DateTime dt) {
  final local = dt.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} · $hour:$minute $period';
}
