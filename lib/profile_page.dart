import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'family_member_presence_avatar.dart';
import 'profile_account_pages.dart';

class ProfileFamilyMember {
  const ProfileFamilyMember({
    required this.uid,
    required this.name,
    required this.initials,
    required this.avatarColor,
    this.photoBytes,
    this.photoUrl,
    required this.presenceLabel,
    required this.isOnline,
    this.isCurrentUser = false,
  });

  final String uid;
  final String name;
  final String initials;
  final Color avatarColor;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String presenceLabel;
  final bool isOnline;
  final bool isCurrentUser;
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.profileImageBytes,
    this.profilePhotoUrl,
    required this.displayName,
    required this.statusLabel,
    required this.onChangePhoto,
    required this.dayStreakCount,
    required this.checkInsCompleted,
    required this.familyMemberCount,
    required this.weeksCount,
    required this.familyMembers,
    required this.onAddFamilyMember,
    required this.onOpenFamilyMessages,
    this.onMessageFamilyMember,
    required this.shareTrendsEnabled,
    required this.onShareTrendsChanged,
    required this.riskAlertsEnabled,
    required this.onRiskAlertsChanged,
    required this.checkInReminderEnabled,
    required this.checkInReminderTimeLabel,
    required this.onCheckInReminderEnabledChanged,
    required this.onCheckInReminderTimeTap,
    required this.onSignOut,
    super.key,
  });

  final Uint8List? profileImageBytes;
  final String? profilePhotoUrl;
  final String displayName;
  final String statusLabel;
  final VoidCallback onChangePhoto;
  final int dayStreakCount;
  final int checkInsCompleted;
  final int familyMemberCount;
  final int weeksCount;
  final List<ProfileFamilyMember> familyMembers;
  final VoidCallback onAddFamilyMember;
  final VoidCallback onOpenFamilyMessages;
  final void Function(String memberUid, String memberName)? onMessageFamilyMember;
  final bool shareTrendsEnabled;
  final ValueChanged<bool> onShareTrendsChanged;
  final bool riskAlertsEnabled;
  final ValueChanged<bool> onRiskAlertsChanged;
  final bool checkInReminderEnabled;
  final String checkInReminderTimeLabel;
  final ValueChanged<bool> onCheckInReminderEnabledChanged;
  final VoidCallback onCheckInReminderTimeTap;
  final Future<void> Function() onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'You will need to sign in again to use Care Signal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await onSignOut();
    }
  }

  ImageProvider? _profileAvatarImage() {
    if (profileImageBytes != null) {
      return MemoryImage(profileImageBytes!);
    }
    final url = profilePhotoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onChangePhoto,
              child: CircleAvatar(
                radius: 56,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _profileAvatarImage(),
                child: _profileAvatarImage() == null
                    ? Icon(Icons.person, size: 56, color: Colors.grey.shade600)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              statusLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE1BEE7)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 20,
                    color: const Color(0xFFE65100),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$dayStreakCount Day Streak',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6A1B9A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProfileStatBox(
                  value: '$checkInsCompleted',
                  label: 'Check-ins',
                ),
                const SizedBox(width: 14),
                _ProfileStatBox(
                  value: '$familyMemberCount',
                  label: 'Family members',
                ),
                const SizedBox(width: 14),
                _ProfileStatBox(value: '$weeksCount', label: 'Weeks'),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Family',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onOpenFamilyMessages,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF439A7D),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Messages'),
                      ),
                      TextButton.icon(
                        onPressed: onAddFamilyMember,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6A1B9A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 108,
                    child: familyMembers.isEmpty
                        ? Center(
                            child: Text(
                              'No family members yet',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.black45),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: familyMembers.length,
                            padding: const EdgeInsets.only(right: 4),
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final member = familyMembers[index];
                              return _FamilyMemberAvatarTile(
                                member: member,
                                onTap: member.isCurrentUser ||
                                        onMessageFamilyMember == null
                                    ? null
                                    : () => onMessageFamilyMember!(
                                          member.uid,
                                          member.name,
                                        ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PrivacyToggleRow(
                    icon: Icons.alarm_rounded,
                    iconColor: const Color(0xFF1565C0),
                    iconBoxColor: const Color(0xFFE3F2FD),
                    label: 'Daily check-in',
                    value: checkInReminderEnabled,
                    onChanged: onCheckInReminderEnabledChanged,
                  ),
                  if (checkInReminderEnabled) ...[
                    Divider(
                      height: 22,
                      thickness: 1,
                      color: Colors.grey.shade200,
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onCheckInReminderTimeTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.schedule_rounded,
                                size: 24,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reminder time',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    checkInReminderTimeLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PrivacyToggleRow(
                    icon: Icons.share_rounded,
                    iconColor: const Color(0xFF6A1B9A),
                    iconBoxColor: const Color(0xFFF0E4FF),
                    label: 'Share Trends',
                    value: shareTrendsEnabled,
                    onChanged: onShareTrendsChanged,
                  ),
                  Divider(
                    height: 22,
                    thickness: 1,
                    color: Colors.grey.shade200,
                  ),
                  _PrivacyToggleRow(
                    icon: Icons.notifications_rounded,
                    iconColor: const Color(0xFFD84315),
                    iconBoxColor: const Color(0xFFFFE8E1),
                    label: 'Risk Alerts',
                    value: riskAlertsEnabled,
                    onChanged: onRiskAlertsChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  _ProfileActionRow(
                    icon: Icons.download_rounded,
                    iconColor: const Color(0xFF00695C),
                    iconBoxColor: const Color(0xFFE0F2F1),
                    label: 'Export Data',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const ExportDataPage(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                  _ProfileActionRow(
                    icon: Icons.help_rounded,
                    iconColor: const Color(0xFF1565C0),
                    iconBoxColor: const Color(0xFFE3F2FD),
                    label: 'Help',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const HelpPage(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                  _ProfileActionRow(
                    icon: Icons.delete_forever_rounded,
                    iconColor: const Color(0xFFC62828),
                    iconBoxColor: const Color(0xFFFFEBEE),
                    label: 'Delete Account',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const DeleteAccountPage(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                  _ProfileActionRow(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFC62828),
                    iconBoxColor: const Color(0xFFFFEBEE),
                    label: 'Sign Out',
                    onTap: () => _confirmSignOut(context),
                    showChevron: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBoxColor,
    required this.label,
    required this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBoxColor;
  final String label;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final isSignOut = label == 'Sign Out';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBoxColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 24,
                  color: iconColor,
                  weight: 700,
                  grade: 50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSignOut ? const Color(0xFFC62828) : null,
                  ),
                ),
              ),
              if (showChevron)
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyToggleRow extends StatelessWidget {
  const _PrivacyToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBoxColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBoxColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: iconBoxColor,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 24, color: iconColor, weight: 700, grade: 50),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _FamilyMemberAvatarTile extends StatelessWidget {
  const _FamilyMemberAvatarTile({
    required this.member,
    this.onTap,
  });

  final ProfileFamilyMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FamilyMemberPresenceAvatar(
            radius: 32,
            initials: member.initials,
            backgroundColor: member.avatarColor,
            isOnline: member.isOnline,
            photoBytes: member.photoBytes,
            photoUrl: member.photoUrl,
          ),
          const SizedBox(height: 8),
          Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            member.presenceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: member.isOnline
                      ? const Color(0xFF2E7D32)
                      : Colors.black45,
                  fontSize: 10,
                ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ProfileStatBox extends StatelessWidget {
  const _ProfileStatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
