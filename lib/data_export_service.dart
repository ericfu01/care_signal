import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import 'data_export_share_helper.dart'
    if (dart.library.io) 'data_export_share_helper_io.dart';
import 'family_repository.dart';
import 'support_repository.dart';

/// Builds and shares a JSON export of the signed-in user's Care Signal data.
class DataExportService {
  DataExportService._();

  static final DataExportService instance = DataExportService._();

  static const _maxCheckIns = 500;

  Future<Map<String, dynamic>> buildExportPayload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in to export your data.');
    }

    final profile = await FamilyRepository.instance.getUserProfile(user.uid);
    final shareWithPartners =
        await SupportRepository.instance.getShareWithPartners();
    final checkInsSnap = shareWithPartners
        ? await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('daily_check_ins')
            .orderBy('createdAt', descending: true)
            .limit(_maxCheckIns)
            .get()
        : null;

    final checkIns = checkInsSnap == null
        ? <Map<String, dynamic>>[]
        : checkInsSnap.docs.map((doc) {
      final data = doc.data();
      final created = data['createdAt'];
      final stressSources = data['stressSources'];
      return {
        'id': doc.id,
        'date': created is Timestamp
            ? created.toDate().toUtc().toIso8601String()
            : null,
        'score': data['score'],
        'mood': data['mood'],
        'energy': data['energy'],
        'stress': data['stress'],
        'stressSources': stressSources is List
            ? stressSources.map((e) => e.toString()).toList()
            : <String>[],
        'memberName': data['memberName'],
      };
    }).toList();

    final stressSourceSummary = <String, int>{};
    for (final checkIn in checkIns) {
      final sources = checkIn['stressSources'];
      if (sources is! List) continue;
      for (final source in sources) {
        final key = source.toString();
        if (key.isEmpty) continue;
        stressSourceSummary[key] = (stressSourceSummary[key] ?? 0) + 1;
      }
    }

    List<Map<String, dynamic>>? familyMembers;
    if (profile?.familyId != null && profile!.familyId!.isNotEmpty) {
      try {
        final familySnap = await FirebaseFirestore.instance
            .collection('users')
            .where('familyId', isEqualTo: profile.familyId)
            .get();
        familyMembers = familySnap.docs.map((doc) {
          final data = doc.data();
          return {
            'uid': doc.id,
            'displayName': data['displayName'],
            'familyRole': data['familyRole'],
          };
        }).toList()
          ..sort(
            (a, b) => (a['displayName'] as String? ?? '')
                .compareTo(b['displayName'] as String? ?? ''),
          );
      } catch (_) {
        familyMembers = null;
      }
    }

    return {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'app': 'Care Signal',
      'shareWithPartners': shareWithPartners,
      'account': {
        'uid': user.uid,
        'email': user.email ?? profile?.email,
        'displayName': profile?.displayName,
        'familyId': profile?.familyId,
        'familyRole': profile?.familyRole,
      },
      'familyMembers': familyMembers,
      'checkIns': checkIns,
      'checkInCount': checkIns.length,
      'stressSourceSummary': stressSourceSummary,
    };
  }

  Future<DataExportResult> exportAndShare() async {
    final payload = await buildExportPayload();
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final plainText = formatExportAsPlainText(payload);
    final checkInCount = payload['checkInCount'] as int? ?? 0;
    final fileName = _fileNameForNow();
    final shareText =
        'Care Signal export — $checkInCount check-in${checkInCount == 1 ? '' : 's'}.';

    try {
      await shareExportJson(
        json: json,
        fileName: fileName,
        shareText: shareText,
      );
      return DataExportResult(
        checkInCount: checkInCount,
        delivery: DataExportDelivery.shareSheet,
      );
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: plainText));
      return DataExportResult(
        checkInCount: checkInCount,
        delivery: DataExportDelivery.clipboard,
      );
    }
  }

  /// Human-readable export for clipboard when the native share sheet is unavailable.
  static String formatExportAsPlainText(Map<String, dynamic> payload) {
    final buffer = StringBuffer();
    final exportedAt = payload['exportedAt'] as String?;
    final account = payload['account'];
    final familyMembers = payload['familyMembers'];
    final checkIns = payload['checkIns'];
    final stressSummary = payload['stressSourceSummary'];
    final checkInCount = payload['checkInCount'] as int? ?? 0;

    buffer.writeln('Care Signal — Data Export');
    buffer.writeln('Exported: ${_formatDateTime(exportedAt)}');
    if (payload['shareWithPartners'] == false) {
      buffer.writeln(
        'Partner sharing is off — check-in details are excluded from this export.',
      );
    }
    buffer.writeln();

    if (account is Map) {
      buffer.writeln('ACCOUNT');
      _writeLine(buffer, 'Name', account['displayName']);
      _writeLine(buffer, 'Email', account['email']);
      _writeLine(buffer, 'Family role', account['familyRole']);
      buffer.writeln();
    }

    if (familyMembers is List && familyMembers.isNotEmpty) {
      buffer.writeln('FAMILY MEMBERS');
      for (final member in familyMembers) {
        if (member is! Map) continue;
        final name = member['displayName']?.toString().trim();
        final role = member['familyRole']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        buffer.writeln(role == null || role.isEmpty ? '• $name' : '• $name ($role)');
      }
      buffer.writeln();
    }

    if (stressSummary is Map && stressSummary.isNotEmpty) {
      buffer.writeln('STRESS SOURCES (summary)');
      final entries = stressSummary.entries.toList()
        ..sort((a, b) => (b.value as num).compareTo(a.value as num));
      for (final entry in entries) {
        final count = entry.value;
        final label = count == 1 ? 'time' : 'times';
        buffer.writeln('• ${entry.key}: $count $label');
      }
      buffer.writeln();
    }

    buffer.writeln('CHECK-INS ($checkInCount total)');
    buffer.writeln();

    if (checkIns is List && checkIns.isNotEmpty) {
      for (final checkIn in checkIns) {
        if (checkIn is! Map) continue;
        buffer.writeln(_formatDateTime(checkIn['date'] as String?));
        _writeLine(buffer, '  Mood', checkIn['mood'], indent: '');
        _writeLine(buffer, '  Energy', checkIn['energy'], indent: '');
        _writeLine(buffer, '  Stress', checkIn['stress'], indent: '');
        _writeLine(buffer, '  Score', checkIn['score'], indent: '');
        final sources = checkIn['stressSources'];
        if (sources is List && sources.isNotEmpty) {
          buffer.writeln(
            '  Stress sources: ${sources.map((e) => e.toString()).join(', ')}',
          );
        }
        buffer.writeln();
      }
    } else {
      buffer.writeln('No check-ins yet.');
    }

    return buffer.toString().trimRight();
  }

  static void _writeLine(
    StringBuffer buffer,
    String label,
    Object? value, {
    String indent = '',
  }) {
    if (value == null || value.toString().trim().isEmpty) return;
    buffer.writeln('$indent$label: $value');
  }

  static String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown date';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.month}/${dt.day}/${dt.year} $hour:$minute $period';
    } catch (_) {
      return iso;
    }
  }

  static String _fileNameForNow() {
    final stamp = DateTime.now().toUtc().toIso8601String().split('.').first;
    return 'care_signal_export_${stamp.replaceAll(':', '-')}Z.json';
  }
}

class DataExportResult {
  const DataExportResult({
    required this.checkInCount,
    required this.delivery,
  });

  final int checkInCount;
  final DataExportDelivery delivery;
}

enum DataExportDelivery { shareSheet, clipboard }
