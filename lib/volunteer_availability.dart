import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'request_duration.dart';

/// One recurring weekly window when a volunteer can receive requests.
class VolunteerAvailabilitySlot {
  const VolunteerAvailabilitySlot({
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
  });

  /// [DateTime.monday] (1) through [DateTime.sunday] (7).
  final int weekday;
  final int startMinutes;
  final int endMinutes;

  Map<String, dynamic> toMap() => {
        'weekday': weekday,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  factory VolunteerAvailabilitySlot.fromMap(Map<String, dynamic> map) {
    return VolunteerAvailabilitySlot(
      weekday: (map['weekday'] as num?)?.toInt() ?? DateTime.monday,
      startMinutes: (map['startMinutes'] as num?)?.toInt() ?? 540,
      endMinutes: (map['endMinutes'] as num?)?.toInt() ?? 1020,
    );
  }

  String get weekdayLabel {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final index = weekday - DateTime.monday;
    if (index < 0 || index >= labels.length) return 'Day';
    return labels[index];
  }

  String get timeRangeLabel =>
      '${VolunteerAvailabilitySchedule.formatMinutes(startMinutes)} – '
      '${VolunteerAvailabilitySchedule.formatMinutes(endMinutes)}';
}

class VolunteerAvailabilitySchedule {
  const VolunteerAvailabilitySchedule({this.slots = const []});

  static const empty = VolunteerAvailabilitySchedule();

  final List<VolunteerAvailabilitySlot> slots;

  bool get isEmpty => slots.isEmpty;

  factory VolunteerAvailabilitySchedule.fromFirestore(dynamic raw) {
    if (raw == null || raw is! List) return VolunteerAvailabilitySchedule.empty;
    final slots = raw
        .whereType<Map>()
        .map((item) => VolunteerAvailabilitySlot.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((slot) => slot.endMinutes > slot.startMinutes)
        .toList()
      ..sort((a, b) {
        final day = a.weekday.compareTo(b.weekday);
        if (day != 0) return day;
        return a.startMinutes.compareTo(b.startMinutes);
      });
    return VolunteerAvailabilitySchedule(slots: slots);
  }

  List<Map<String, dynamic>> toFirestore() =>
      slots.map((slot) => slot.toMap()).toList();

  bool isAvailableAt(DateTime moment) {
    if (slots.isEmpty) return false;
    final minutes = moment.hour * 60 + moment.minute;
    for (final slot in slots) {
      if (slot.weekday == moment.weekday &&
          minutes >= slot.startMinutes &&
          minutes < slot.endMinutes) {
        return true;
      }
    }
    return false;
  }

  String summaryLines() {
    if (slots.isEmpty) return 'No hours set yet';
    return slots.map((s) => '${s.weekdayLabel} ${s.timeRangeLabel}').join('\n');
  }

  String statusLabel(DateTime now) {
    if (slots.isEmpty) {
      return 'Set your weekly hours to receive requests';
    }
    if (isAvailableAt(now)) {
      return 'Available now — families can be matched to you';
    }
    final next = nextWindowStart(now);
    if (next == null) {
      return 'Offline — outside your scheduled hours';
    }
    return 'Offline — next window ${formatWindowStart(next)}';
  }

  DateTime? nextWindowStart(DateTime from) {
    if (slots.isEmpty) return null;
    DateTime? best;
    for (var offset = 0; offset < 8; offset++) {
      final day = from.add(Duration(days: offset));
      for (final slot in slots.where((s) => s.weekday == day.weekday)) {
        final candidate = DateTime(
          day.year,
          day.month,
          day.day,
          slot.startMinutes ~/ 60,
          slot.startMinutes % 60,
        );
        if (!candidate.isAfter(from)) continue;
        if (best == null || candidate.isBefore(best)) {
          best = candidate;
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  static String formatMinutes(int minutes) {
    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  static String formatWindowStart(DateTime time) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final day = days[time.weekday - DateTime.monday];
    return '$day ${formatMinutes(time.hour * 60 + time.minute)}';
  }

  static TimeOfDay minutesToTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  static int timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;
}

/// A one-off busy window after a volunteer accepts a request.
class VolunteerAvailabilityBlock {
  const VolunteerAvailabilityBlock({
    required this.startAt,
    required this.endAt,
    this.requestId,
    this.familyUserId,
  });

  final DateTime startAt;
  final DateTime endAt;
  final String? requestId;
  final String? familyUserId;

  factory VolunteerAvailabilityBlock.fromMap(Map<String, dynamic> map) {
    DateTime readTime(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    final start = readTime(map['startAt'], DateTime.now());
    final end = readTime(map['endAt'], start.add(const Duration(hours: 1)));
    return VolunteerAvailabilityBlock(
      startAt: start,
      endAt: end.isAfter(start) ? end : start.add(const Duration(hours: 1)),
      requestId: map['requestId'] as String?,
      familyUserId: map['familyUserId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        if (requestId != null) 'requestId': requestId,
        if (familyUserId != null) 'familyUserId': familyUserId,
      };

  bool contains(DateTime moment) =>
      !moment.isBefore(startAt) && moment.isBefore(endAt);

  bool overlaps(DateTime start, DateTime end) =>
      start.isBefore(endAt) && end.isAfter(startAt);
}

class VolunteerAvailabilityBlocks {
  const VolunteerAvailabilityBlocks({this.blocks = const []});

  final List<VolunteerAvailabilityBlock> blocks;

  factory VolunteerAvailabilityBlocks.fromFirestore(dynamic raw) {
    if (raw is! List) return const VolunteerAvailabilityBlocks();
    final blocks = raw
        .whereType<Map>()
        .map((item) => VolunteerAvailabilityBlock.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((block) => block.endAt.isAfter(block.startAt))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return VolunteerAvailabilityBlocks(blocks: blocks);
  }

  List<Map<String, dynamic>> toFirestore() =>
      blocks.map((block) => block.toMap()).toList();

  VolunteerAvailabilityBlocks withoutExpired(DateTime now) =>
      VolunteerAvailabilityBlocks(
        blocks: blocks.where((block) => block.endAt.isAfter(now)).toList(),
      );

  VolunteerAvailabilityBlocks adding(VolunteerAvailabilityBlock block) {
    final next = [
      ...blocks.where((existing) => existing.requestId != block.requestId),
      block,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    return VolunteerAvailabilityBlocks(blocks: next);
  }

  VolunteerAvailabilityBlocks removingRequest(String requestId) =>
      VolunteerAvailabilityBlocks(
        blocks: blocks.where((block) => block.requestId != requestId).toList(),
      );

  bool isBlockedAt(DateTime moment) => blocks.any((block) => block.contains(moment));

  bool isBlockedDuring(DateTime start, DateTime end) =>
      blocks.any((block) => block.overlaps(start, end));

  String? activeBlockLabel(DateTime now) {
    for (final block in blocks) {
      if (block.contains(now)) {
        return 'Busy until ${VolunteerAvailabilitySchedule.formatWindowStart(block.endAt)}';
      }
    }
    return null;
  }
}

class VolunteerAvailability {
  VolunteerAvailability._();

  static bool isAvailable({
    required VolunteerAvailabilitySchedule schedule,
    required VolunteerAvailabilityBlocks blocks,
    required DateTime moment,
  }) =>
      schedule.isAvailableAt(moment) && !blocks.isBlockedAt(moment);

  static bool isAvailableForWindow({
    required VolunteerAvailabilitySchedule schedule,
    required VolunteerAvailabilityBlocks blocks,
    required DateTime start,
    required int durationMinutes,
  }) {
    final end = start.add(Duration(minutes: durationMinutes));
    if (!schedule.isAvailableAt(start)) return false;
    return !blocks.isBlockedDuring(start, end);
  }

  /// Next [maxSuggestions] start times that fit [durationMinutes] in schedule
  /// and do not overlap accepted-visit blocks.
  static List<DateTime> findNextAvailableStarts({
    required VolunteerAvailabilitySchedule schedule,
    required VolunteerAvailabilityBlocks blocks,
    required DateTime searchFrom,
    required int durationMinutes,
    int maxSuggestions = 3,
    int maxDays = 14,
  }) {
    if (schedule.isEmpty || durationMinutes <= 0) return const [];

    final now = DateTime.now();
    var cursor = searchFrom.isBefore(now) ? now : searchFrom;
    cursor = _roundUpToQuarterHour(cursor);

    final suggestions = <DateTime>[];
    final deadline = cursor.add(Duration(days: maxDays));
    var iterations = 0;

    while (cursor.isBefore(deadline) &&
        suggestions.length < maxSuggestions &&
        iterations < 2000) {
      iterations++;
      final activeBlocks = blocks.withoutExpired(cursor);

      if (isAvailableForWindow(
        schedule: schedule,
        blocks: activeBlocks,
        start: cursor,
        durationMinutes: durationMinutes,
      )) {
        final duplicate = suggestions.any(
          (existing) => existing.difference(cursor).inMinutes.abs() < 30,
        );
        if (!duplicate) suggestions.add(cursor);
      }

      if (!schedule.isAvailableAt(cursor)) {
        final next = schedule.nextWindowStart(cursor);
        if (next != null && next.isAfter(cursor)) {
          cursor = _roundUpToQuarterHour(next);
          continue;
        }
      }

      cursor = cursor.add(const Duration(minutes: 15));
    }

    return suggestions;
  }

  static DateTime _roundUpToQuarterHour(DateTime time) {
    final remainder = time.minute % 15;
    if (remainder == 0 && time.second == 0 && time.millisecond == 0) {
      return DateTime(
        time.year,
        time.month,
        time.day,
        time.hour,
        time.minute,
      );
    }
    final addMinutes = remainder == 0 ? 15 : 15 - remainder;
    final rounded = time.add(Duration(minutes: addMinutes));
    return DateTime(
      rounded.year,
      rounded.month,
      rounded.day,
      rounded.hour,
      rounded.minute,
    );
  }

  static String formatSuggestion(DateTime time) {
    final local = time.toLocal();
    return '${VolunteerAvailabilitySchedule.formatWindowStart(local)} '
        '(${local.month}/${local.day})';
  }

  static String conflictMessage({
    required String volunteerName,
    required VolunteerAvailabilitySchedule schedule,
    required VolunteerAvailabilityBlocks blocks,
    required DateTime requestedStart,
    required int durationMinutes,
  }) {
    if (isAvailableForWindow(
      schedule: schedule,
      blocks: blocks.withoutExpired(requestedStart),
      start: requestedStart,
      durationMinutes: durationMinutes,
    )) {
      return '';
    }

    final end = requestedStart.add(Duration(minutes: durationMinutes));
    final activeBlocks = blocks.withoutExpired(requestedStart);
    var searchFrom = requestedStart;
    String reason;

    if (activeBlocks.isBlockedDuring(requestedStart, end)) {
      VolunteerAvailabilityBlock? conflict;
      for (final block in activeBlocks.blocks) {
        if (block.overlaps(requestedStart, end)) {
          conflict = block;
          break;
        }
      }
      if (conflict != null) {
        reason =
            '$volunteerName is busy until '
            '${VolunteerAvailabilitySchedule.formatWindowStart(conflict.endAt.toLocal())}';
        searchFrom = conflict.endAt;
      } else {
        reason = '$volunteerName is already booked during that time';
      }
    } else if (!schedule.isAvailableAt(requestedStart)) {
      reason = 'That time is outside $volunteerName\'s weekly hours';
      searchFrom = schedule.nextWindowStart(requestedStart) ?? requestedStart;
    } else {
      reason =
          '$volunteerName is not free for the full '
          '${RequestDuration.label(durationMinutes)} visit';
    }

    final suggestions = findNextAvailableStarts(
      schedule: schedule,
      blocks: activeBlocks,
      searchFrom: searchFrom,
      durationMinutes: durationMinutes,
    );

    if (suggestions.isNotEmpty) {
      final labels = suggestions.map(formatSuggestion).join(', ');
      return '$reason. Try: $labels.';
    }

    if (schedule.isEmpty) {
      return '$reason. Please pick another time.';
    }

    return '$reason. Weekly hours: '
        '${schedule.summaryLines().replaceAll('\n', ' · ')}.';
  }

  static DateTime requestBlockStart(Map<String, dynamic> data, DateTime now) {
    if (data['needsNow'] == true) return now;
    final scheduled = data['scheduledAt'];
    if (scheduled is Timestamp) return scheduled.toDate();
    return now;
  }

  static int requestDurationMinutes(Map<String, dynamic> data) {
    final minutes = (data['durationMinutes'] as num?)?.toInt();
    if (minutes != null && minutes > 0) return minutes;
    final serviceType = data['serviceType'] as String? ?? '';
    return RequestDuration.defaultForService(serviceType);
  }

  static VolunteerAvailabilityBlock blockForRequest({
    required Map<String, dynamic> requestData,
    required String requestId,
    required String familyUserId,
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    final start = requestBlockStart(requestData, moment);
    final duration = requestDurationMinutes(requestData);
    return VolunteerAvailabilityBlock(
      startAt: start,
      endAt: start.add(Duration(minutes: duration)),
      requestId: requestId,
      familyUserId: familyUserId,
    );
  }
}
