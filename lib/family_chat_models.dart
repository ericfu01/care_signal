import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyChatThread {
  const FamilyChatThread({
    required this.id,
    required this.participantUids,
    required this.participantNames,
    required this.lastMessageText,
    this.lastMessageAt,
  });

  final String id;
  final List<String> participantUids;
  final Map<String, String> participantNames;
  final String lastMessageText;
  final DateTime? lastMessageAt;

  String otherParticipantName(String myUid) {
    for (final uid in participantUids) {
      if (uid != myUid) {
        return participantNames[uid] ?? 'Family member';
      }
    }
    return 'Family member';
  }

  String otherParticipantUid(String myUid) {
    for (final uid in participantUids) {
      if (uid != myUid) return uid;
    }
    return '';
  }

  factory FamilyChatThread.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final uids = (data['participantUids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final namesRaw = data['participantNames'] as Map<String, dynamic>?;
    final names = <String, String>{};
    namesRaw?.forEach((key, value) {
      names[key] = value.toString();
    });
    final lastAt = data['lastMessageAt'];
    return FamilyChatThread(
      id: doc.id,
      participantUids: uids,
      participantNames: names,
      lastMessageText: (data['lastMessageText'] as String?) ?? '',
      lastMessageAt: lastAt is Timestamp ? lastAt.toDate() : null,
    );
  }
}

class FamilyChatMessage {
  const FamilyChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String senderUid;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  factory FamilyChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final created = data['createdAt'];
    return FamilyChatMessage(
      id: doc.id,
      senderUid: (data['senderUid'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? 'Member',
      text: (data['text'] as String?) ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
