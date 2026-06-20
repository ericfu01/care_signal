import 'package:cloud_firestore/cloud_firestore.dart';

import 'counter_time_dialog.dart';
import 'request_duration.dart';
import 'request_priority.dart';

class FamilyVolunteerRequestHelpers {
  FamilyVolunteerRequestHelpers._();

  static String visitTitle(Map<String, dynamic> request) {
    if (request['followUpOnly'] == true) {
      return 'Transportation follow-up';
    }
    final volunteerName = request['volunteerName'] as String?;
    if (volunteerName != null && volunteerName.isNotEmpty) {
      return volunteerName;
    }
    return request['label'] as String? ?? 'Support visit';
  }

  static String formatVisit(Map<String, dynamic> request) {
    final status = request['status'] as String? ?? 'pending';
    if (status == 'counter_proposed') {
      final name = request['counterVolunteerName'] as String? ?? 'Volunteer';
      final counter = request['counterScheduledAt'];
      if (counter is Timestamp) {
        return '$name suggested ${formatRequestDateTime(counter.toDate())}';
      }
      return '$name suggested an alternate time';
    }

    final serviceType = request['serviceType'] as String? ?? '';
    final pickup = request['pickup'] as String?;
    final destination = request['destination'] as String?;
    final route = [
      if (pickup != null && pickup.isNotEmpty) pickup,
      if (destination != null && destination.isNotEmpty) destination,
    ].join(' → ');

    if (serviceType == 'transport' && request['needsNow'] == true) {
      if (request['followUpOnly'] == true) {
        return route.isEmpty ? 'Follow-up · ASAP' : 'Follow-up · ASAP · $route';
      }
      return route.isEmpty ? 'ASAP ride request' : 'ASAP · $route';
    }

    if (request['followUpOnly'] == true) {
      return route.isEmpty ? 'Follow-up requested' : 'Follow-up · $route';
    }

    final duration = _durationLabel(request);
    final scheduled = request['scheduledAt'];
    if (scheduled is Timestamp) {
      final dt = scheduled.toDate().toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final when =
          '${dt.month}/${dt.day}/${dt.year} · $hour:$minute $period · $duration';
      if (serviceType == 'transport' && route.isNotEmpty) {
        return '$when · $route';
      }
      return when;
    }

    if (request['needsNow'] == true) {
      return 'ASAP · $duration';
    }

    final label = request['label'] as String?;
    if (label != null && label.isNotEmpty) return '$label · $duration';
    return 'Pending · $duration';
  }

  static String _durationLabel(Map<String, dynamic> request) {
    final label = request['durationLabel'] as String?;
    if (label != null && label.trim().isNotEmpty) return label.trim();
    final minutes = (request['durationMinutes'] as num?)?.toInt();
    if (minutes != null && minutes > 0) {
      return RequestDuration.label(minutes);
    }
    final serviceType = request['serviceType'] as String? ?? '';
    return RequestDuration.label(RequestDuration.defaultForService(serviceType));
  }

  static String serviceTypeLabel(Map<String, dynamic> request) {
    final serviceType = request['serviceType'] as String? ?? '';
    switch (serviceType) {
      case 'respite':
        return 'Respite care';
      case 'meal':
        return 'Meal delivery';
      case 'transport':
        return request['followUpOnly'] == true
            ? 'Transportation follow-up'
            : 'Transportation';
      case 'peer':
        return 'Peer support';
      default:
        return request['label'] as String? ?? 'Support request';
    }
  }

  static String statusLabel(String status) {
    return switch (status) {
      'accepted' => 'Accepted',
      'completed' => 'Completed',
      'declined' => 'Declined',
      'cancelled' => 'Cancelled',
      'counter_proposed' => 'Counter proposed',
      'follow_up' => 'Follow-up',
      _ => 'Pending',
    };
  }

  static bool isActive(String status) =>
      status == 'pending' ||
      status == 'accepted' ||
      status == 'follow_up' ||
      status == 'counter_proposed';

  static bool isHistory(String status) =>
      status == 'completed' ||
      status == 'declined' ||
      status == 'cancelled';

  static bool canCancel(String status) =>
      status == 'pending' ||
      status == 'accepted' ||
      status == 'counter_proposed' ||
      status == 'follow_up';

  static bool canMessage(Map<String, dynamic> request) {
    final catalogId = request['volunteerId'] as String?;
    return catalogId != null && catalogId.isNotEmpty;
  }

  static bool isUrgent(Map<String, dynamic> request) =>
      RequestPriority.isUrgent(request);
}
