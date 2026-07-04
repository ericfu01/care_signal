import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_notification.dart';
import 'family_chat_page.dart';
import 'notification_debug.dart';
import 'notification_navigation.dart';
import 'notification_repository.dart';
import 'notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _testRunning = false;

  Future<void> _copyFcmToken() async {
    final token = await NotificationService.instance.getFcmTokenForDebug();
    if (!mounted) return;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No FCM token yet. Use a physical iPhone, allow notifications, '
            'and upload your APNs .p8 key in Firebase (see docs/IOS_PUSH_SETUP.md).',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('FCM token copied — paste in Firebase “Send test message”.'),
      ),
    );
  }

  Future<void> _runDebugTest() async {
    if (_testRunning) return;
    setState(() => _testRunning = true);
    final message = await NotificationDebug.runSelfTest(context);
    if (!mounted) return;
    setState(() => _testRunning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ?? 'Test notification sent — check the list and your banner.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Sign in to see notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (kDebugMode)
            IconButton(
              onPressed: _copyFcmToken,
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy FCM token (iOS push test)',
            ),
          if (kDebugMode)
            IconButton(
              onPressed: _testRunning ? null : _runDebugTest,
              icon: _testRunning
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined),
              tooltip: 'Send test notification (debug)',
            ),
          IconButton(
            onPressed: () =>
                NotificationRepository.instance.markAllRead(),
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationRepository.instance.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load notifications\n${snapshot.error}'),
            );
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No notifications yet.\nYou\'ll see alerts here for family messages and volunteer updates.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _testRunning ? null : _runDebugTest,
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('Send test notification'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      return '$h:$m $period';
    }
    return '${months[local.month - 1]} ${local.day}';
  }

  Future<void> _onTap(BuildContext context) async {
    if (!notification.read) {
      await NotificationRepository.instance.markRead(notification.id);
    }
    if (!context.mounted) return;

    if (notification.isFamilyMessage) {
      final familyId = notification.familyId ?? '';
      final chatId = notification.chatId ?? '';
      final otherUid = notification.otherUid ?? '';
      final otherName = notification.otherDisplayName ?? '';
      if (familyId.isEmpty ||
          chatId.isEmpty ||
          otherUid.isEmpty ||
          otherUid == 'debug' ||
          otherName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debug only — invite another family member to test opening a chat.',
            ),
          ),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => FamilyChatPage(
            familyId: familyId,
            chatId: chatId,
            otherUid: otherUid,
            otherDisplayName: otherName,
          ),
        ),
      );
      return;
    }

    if (notification.isVolunteerRequestCancelled ||
        notification.isVolunteerRequestNew) {
      final familyUserId = notification.familyUserId ?? '';
      final requestId = notification.requestId ?? '';
      if (familyUserId.isNotEmpty && requestId.isNotEmpty) {
        await NotificationNavigation.openVolunteerRequest(
          context,
          familyUserId: familyUserId,
          requestId: requestId,
        );
      } else {
        await NotificationNavigation.openFromPayload(context, {
          'type': notification.type,
        });
      }
      return;
    }

    if (notification.isFamilyVolunteerRequestUpdate) {
      final requestId = notification.requestId ?? '';
      await NotificationNavigation.openFamilyVolunteerRequest(
        context,
        requestId: requestId,
      );
      return;
    }

    if (notification.isFamilyRiskAlert) {
      // Inbox-only — message explains who may need support.
      return;
    }

    if (notification.isPeerGroupJoinRequest) {
      final groupId = notification.groupId ?? '';
      if (groupId.isNotEmpty) {
        await NotificationNavigation.openPeerGroupHostManage(
          context,
          groupId: groupId,
        );
      }
      return;
    }

    if (notification.isPeerGroupCoHostInvite) {
      await NotificationNavigation.openPeerGroupCoHostInvites(context);
      return;
    }

    if (notification.isPeerGroupFamilyInvite) {
      await NotificationNavigation.openPeerGroupFamilyInvites(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(notification.createdAt);
    return ListTile(
      leading: Icon(
        notification.read
            ? Icons.notifications_none
            : Icons.notifications_active,
        color: notification.read ? Colors.grey : const Color(0xFF0FA69A),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.read ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body),
          if (timeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                timeLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black45,
                    ),
              ),
            ),
        ],
      ),
      onTap: () => _onTap(context),
    );
  }
}
