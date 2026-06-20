import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'auth_navigation.dart';
import 'auth_session.dart';
import 'check_in_reminder_service.dart';
import 'daily_check_in_page.dart';
import 'family_chat_page.dart';
import 'family_chat_repository.dart';
import 'family_check_in_loader.dart';
import 'family_invite_sheet.dart';
import 'family_messages_inbox_page.dart';
import 'family_member_presence_avatar.dart';
import 'family_models.dart';
import 'family_presence.dart';
import 'family_repository.dart';
import 'presence_service.dart';
import 'insights_page.dart';
import 'notification_repository.dart';
import 'notification_service.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'profile_photo_service.dart';
import 'support_page.dart';
import 'support_repository.dart';
import 'trends_page.dart';
import 'volunteer_music_pages.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  String _userName = 'Member';
  String _userStatus = 'Family member';
  String? _myUid;
  String? _familyId;
  bool _isFamilyAdmin = false;
  Uint8List? _profileImageBytes;
  String? _profilePhotoUrl;
  bool _profilePhotoUploading = false;
  int _selectedTabIndex = 0;
  final List<int> _familyCheckInScores = [];
  final Map<String, List<int>> _memberCheckInScores = {};
  final Map<String, int> _stressSourceCounts = {
    'Medical': 0,
    'Time': 0,
    'Financial': 0,
    'Work': 0,
    'Family': 0,
    'Sleep': 0,
  };
  int? _wellnessScore;
  int _dayStreakCount = 0;
  int _checkInsCompleted = 0;
  bool _shareTrendsEnabled = false;
  bool _riskAlertsEnabled = true;
  Map<String, bool> _shareTrendsByUid = {};
  bool _checkInReminderEnabled = CheckInReminderSettings.defaults.enabled;
  TimeOfDay _checkInReminderTime = CheckInReminderSettings.defaults.time;
  List<FamilyMemberView> _familyMembers = [];
  List<UserProfile> _familyProfiles = [];
  StreamSubscription<List<UserProfile>>? _familyMembersSub;
  Timer? _presenceUiTimer;
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyFromFirestore();
    unawaited(_loadCheckInReminderSettings());
    unawaited(_backfillLegacyCheckInDayKeys());
    _presenceUiTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted && _familyProfiles.isNotEmpty) {
          setState(() => _rebuildFamilyMemberViews(_familyProfiles));
        }
      },
    );
  }

  @override
  void dispose() {
    _familyMembersSub?.cancel();
    _presenceUiTimer?.cancel();
    super.dispose();
  }

  int get _onlineFamilyCount {
    var count = 0;
    for (final p in _familyProfiles) {
      final isSelf = p.uid == _myUid;
      if (isSelf && PresenceService.appInForeground) {
        count++;
      } else if (FamilyPresence.isOnline(p.lastActiveAt)) {
        count++;
      }
    }
    return count;
  }

  void _rebuildFamilyMemberViews(List<UserProfile> profiles) {
    if (_myUid == null) return;
    _familyProfiles = profiles;
    _familyMembers = profiles
        .map(
          (p) => familyMemberViewFromProfile(
            profile: p,
            currentUid: _myUid!,
            latestScore: _latestScoreForUid(p.uid),
            currentUserAppActive: PresenceService.appInForeground,
          ),
        )
        .toList();
    for (final p in profiles) {
      _memberCheckInScores.putIfAbsent(p.uid, () => []);
    }
  }

  int? _latestScoreForUid(String uid) {
    final values = _memberCheckInScores[uid];
    if (values == null || values.isEmpty) return null;
    return values.last;
  }

  Future<void> _loadFamilyFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      await navigateAfterAuth(context);
      return;
    }

    _myUid = user.uid;
    unawaited(_backfillLegacyCheckInDayKeys());
    final profile = await FamilyRepository.instance.getUserProfile(user.uid);
    if (!mounted) return;

    if (profile == null || !profile.hasFamily) {
      await navigateAfterAuth(context);
      return;
    }

    setState(() {
      _userName = profile.displayName;
      _userStatus =
          profile.isAdmin ? 'Family admin' : 'Family member';
      _isFamilyAdmin = profile.isAdmin;
      _familyId = profile.familyId;
      _profileLoading = false;
      _profilePhotoUrl = profile.profilePhotoUrl;
      _memberCheckInScores.putIfAbsent(user.uid, () => []);
    });
    unawaited(_loadProfileSettings());

    _familyMembersSub?.cancel();
    _familyMembersSub = FamilyRepository.instance
        .watchFamilyMembers(profile.familyId!)
        .listen(
      (profiles) {
        if (!mounted) return;
        setState(() => _rebuildFamilyMemberViews(profiles));
        unawaited(_mergeFirestoreCheckInScores(profiles));
        unawaited(_refreshFamilyTrendData(profiles));
      },
      onError: (Object e) {
        debugPrint('[CareSignal][Home] family members stream: $e');
      },
    );
  }

  Future<void> _mergeFirestoreCheckInScores(List<UserProfile> profiles) async {
    final fromFirestore =
        await FamilyCheckInLoader.latestScoresByMemberName(profiles);
    if (!mounted) return;

    setState(() {
      for (final p in profiles) {
        if (!SupportRepository.canViewMemberTrends(
          memberUid: p.uid,
          viewerUid: _myUid,
          shareTrendsByUid: _shareTrendsByUid,
        )) {
          continue;
        }
        final remote = fromFirestore[p.displayName];
        if (remote == null) continue;
        final local = _memberCheckInScores[p.uid];
        if (local == null || local.isEmpty) {
          _memberCheckInScores[p.uid] = [remote];
        } else if (local.last != remote) {
          local.add(remote);
          if (local.length > 30) local.removeAt(0);
        }
      }
      if (_familyProfiles.isNotEmpty) {
        _rebuildFamilyMemberViews(_familyProfiles);
      }
    });
  }

  Future<void> _loadProfileSettings() async {
    final shareTrends = await SupportRepository.instance.getShareTrendsEnabled();
    final riskAlerts = await SupportRepository.instance.getRiskAlertsEnabled();
    if (!mounted) return;
    setState(() {
      _shareTrendsEnabled = shareTrends;
      _riskAlertsEnabled = riskAlerts;
    });
  }

  Future<void> _refreshFamilyTrendData(List<UserProfile> profiles) async {
    await _refreshShareTrendsPrefs(profiles);
    if (!mounted) return;
    await _refreshHomeMetrics(profiles);
  }

  Future<void> _refreshShareTrendsPrefs(List<UserProfile> profiles) async {
    if (profiles.isEmpty) return;
    final prefs = await SupportRepository.instance.getShareTrendsEnabledByUids(
      profiles.map((profile) => profile.uid),
    );
    if (_myUid != null) {
      prefs[_myUid!] = _shareTrendsEnabled;
    }
    if (!mounted) return;
    setState(() => _shareTrendsByUid = prefs);
  }

  Future<void> _refreshHomeMetrics(List<UserProfile> profiles) async {
    if (profiles.isEmpty) return;
    final visibleProfiles = profiles
        .where(
          (profile) => SupportRepository.canViewMemberTrends(
            memberUid: profile.uid,
            viewerUid: _myUid,
            shareTrendsByUid: _shareTrendsByUid,
          ),
        )
        .toList();
    final chartProfiles = visibleProfiles.isNotEmpty
        ? visibleProfiles
        : (_myUid == null
            ? profiles
            : profiles.where((profile) => profile.uid == _myUid).toList());
    final points = await FamilyCheckInLoader.dailyFamilyAverages(
      chartProfiles,
      dayCount: 30,
    );
    final dailyScores = points
        .where((point) => point.averageScore != null)
        .map((point) => point.averageScore!.round())
        .toList();

    final uid = _myUid;
    var streak = 0;
    var completed = 0;
    if (uid != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('daily_check_ins')
            .orderBy('createdAt', descending: true)
            .limit(120)
            .get();
        completed = snap.docs.length;
        streak = _computeDayStreak(snap.docs);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _familyCheckInScores
        ..clear()
        ..addAll(dailyScores);
      if (_familyCheckInScores.isEmpty) {
        _wellnessScore = null;
      } else {
        final total = _familyCheckInScores.reduce((a, b) => a + b);
        _wellnessScore = (total / _familyCheckInScores.length).round();
      }
      _dayStreakCount = streak;
      _checkInsCompleted = completed;
    });
  }

  int _computeDayStreak(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final uniqueDays = <DateTime>{};
    for (final doc in docs) {
      final createdAt = doc.data()['createdAt'];
      if (createdAt is! Timestamp) continue;
      final local = createdAt.toDate().toLocal();
      uniqueDays.add(DateTime(local.year, local.month, local.day));
    }
    if (uniqueDays.isEmpty) return 0;

    final days = uniqueDays.toList()..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!days.first.isAtSameMomentAs(cursor)) {
      final yesterday = cursor.subtract(const Duration(days: 1));
      if (!days.first.isAtSameMomentAs(yesterday)) return 0;
      cursor = yesterday;
    }

    var streak = 0;
    for (final day in days) {
      if (day.isAtSameMomentAs(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (day.isBefore(cursor)) {
        break;
      }
    }
    return streak;
  }

  Future<void> _setShareTrendsEnabled(bool value) async {
    final previous = _shareTrendsEnabled;
    setState(() {
      _shareTrendsEnabled = value;
      if (_myUid != null) {
        _shareTrendsByUid[_myUid!] = value;
      }
    });
    try {
      await SupportRepository.instance.setShareTrendsEnabled(value);
      if (_familyProfiles.isNotEmpty) {
        unawaited(_refreshFamilyTrendData(_familyProfiles));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _shareTrendsEnabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save Share Trends setting: $e')),
      );
    }
  }

  Future<void> _setRiskAlertsEnabled(bool value) async {
    final previous = _riskAlertsEnabled;
    setState(() => _riskAlertsEnabled = value);
    try {
      await SupportRepository.instance.setRiskAlertsEnabled(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _riskAlertsEnabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save Risk Alerts setting: $e')),
      );
    }
  }

  Future<void> _backfillLegacyCheckInDayKeys() async {
    final uid = _myUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    await FamilyCheckInLoader.backfillMissingDayKeys(uid);
  }

  Future<void> _loadCheckInReminderSettings() async {
    final settings =
        await NotificationService.instance.getCheckInReminderSettings();
    if (!mounted) return;
    setState(() {
      _checkInReminderEnabled = settings.enabled;
      _checkInReminderTime = settings.time;
    });
  }

  Future<void> _setCheckInReminderEnabled(bool enabled) async {
    final previousEnabled = _checkInReminderEnabled;
    setState(() => _checkInReminderEnabled = enabled);

    final saved = await NotificationService.instance.updateCheckInReminderSettings(
      CheckInReminderSettings(
        enabled: enabled,
        time: _checkInReminderTime,
      ),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _checkInReminderEnabled = previousEnabled);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification permission is required for daily check-in reminders.',
          ),
        ),
      );
    }
  }

  Future<void> _pickCheckInReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkInReminderTime,
      helpText: 'Daily check-in reminder',
    );
    if (picked == null || !mounted) return;

    setState(() => _checkInReminderTime = picked);

    final saved = await NotificationService.instance.updateCheckInReminderSettings(
      CheckInReminderSettings(
        enabled: _checkInReminderEnabled,
        time: picked,
      ),
    );
    if (!mounted) return;
    if (!saved && _checkInReminderEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update reminder time.'),
        ),
      );
    }
  }

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  List<UserProfile> _visibleFamilyProfiles() {
    return _familyProfiles
        .where(
          (profile) => SupportRepository.canViewMemberTrends(
            memberUid: profile.uid,
            viewerUid: _myUid,
            shareTrendsByUid: _shareTrendsByUid,
          ),
        )
        .toList();
  }

  List<String> _visibleMemberNames() {
    return _visibleFamilyProfiles().map((profile) => profile.displayName).toList();
  }

  ImageProvider? _profileAvatarImage() {
    if (_profileImageBytes != null) {
      return MemoryImage(_profileImageBytes!);
    }
    final url = _profilePhotoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }
    return null;
  }

  Future<void> _pickProfileImageFrom(ImageSource source) async {
    final uid = _myUid;
    if (uid == null) return;

    final XFile? pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 65,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    setState(() {
      _profileImageBytes = bytes;
      _profilePhotoUploading = true;
    });

    try {
      final url = await ProfilePhotoService.instance.uploadProfilePhoto(
        uid: uid,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = url;
        _profileImageBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _profileImageBytes = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile photo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _profilePhotoUploading = false);
      }
    }
  }

  Future<void> _showImageSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickProfileImageFrom(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickProfileImageFrom(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut() async {
    await AuthSession.confirmAndSignOut(context);
  }

  Future<void> _openFamilyMessages() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const FamilyMessagesInboxPage(),
      ),
    );
  }

  Future<void> _messageFamilyMember(String memberUid, String memberName) async {
    final myUid = _myUid;
    final familyId = _familyId;
    if (myUid == null || familyId == null) return;

    final me = await FamilyRepository.instance.getUserProfile(myUid);
    final other = await FamilyRepository.instance.getUserProfile(memberUid);
    if (!mounted || me == null || other == null) return;

    try {
      final chatId = await FamilyChatRepository.instance.openOrCreateThread(
        familyId: familyId,
        me: me,
        other: other,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => FamilyChatPage(
            familyId: familyId,
            chatId: chatId,
            otherUid: memberUid,
            otherDisplayName: memberName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    }
  }

  Future<void> _showInviteFamilyMemberSheet() async {
    final familyId = _familyId;
    if (familyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join or create a family first.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => FamilyInviteSheet(
        familyId: familyId,
        isAdmin: _isFamilyAdmin,
      ),
    );
  }

  String _wellnessTrendText() {
    if (_familyCheckInScores.length < 2) {
      return '+ __ from last week';
    }

    final latest = _familyCheckInScores.last;
    final previous = _familyCheckInScores[_familyCheckInScores.length - 2];
    final delta = latest - previous;

    if (delta > 0) return '+$delta from last week';
    if (delta < 0) return '-${delta.abs()} from last week';
    return '+0 from last week';
  }

  Map<String, int?> _latestMemberScores() {
    final scores = <String, int?>{};
    for (final member in _familyMembers) {
      final canView = SupportRepository.canViewMemberTrends(
        memberUid: member.uid,
        viewerUid: _myUid,
        shareTrendsByUid: _shareTrendsByUid,
      );
      scores[member.name] =
          canView ? _latestScoreForUid(member.uid) : null;
    }
    return scores;
  }

  Future<void> _startDailyCheckIn() async {
    final result = await Navigator.of(context).push<DailyCheckInResult>(
      MaterialPageRoute(
        builder: (context) => const DailyCheckInPage(),
      ),
    );

    if (result == null) return;

    setState(() {
      final uid = _myUid;
      if (uid != null) {
        final memberScores =
            _memberCheckInScores.putIfAbsent(uid, () => []);
        memberScores.add(result.score);
        if (memberScores.length > 30) {
          memberScores.removeAt(0);
        }
        if (_familyProfiles.isNotEmpty) {
          _rebuildFamilyMemberViews(_familyProfiles);
        }
      }

      _familyCheckInScores.add(result.score);
      if (_familyCheckInScores.length > 30) {
        _familyCheckInScores.removeAt(0);
      }

      for (final source in result.stressSources) {
        _stressSourceCounts[source] = (_stressSourceCounts[source] ?? 0) + 1;
      }

      final total = _familyCheckInScores.reduce((a, b) => a + b);
      _wellnessScore = (total / _familyCheckInScores.length).round();
    });
    if (_familyProfiles.isNotEmpty) {
      unawaited(_refreshHomeMetrics(_familyProfiles));
    }
  }

  Future<void> _handleDrawerNavigation(String selection) async {
    switch (selection) {
      case 'Home':
        setState(() {
          _selectedTabIndex = 0;
        });
        break;
      case 'Trends':
        setState(() {
          _selectedTabIndex = 1;
        });
        break;
      case 'Support':
        setState(() {
          _selectedTabIndex = 2;
        });
        break;
      case 'Insights':
        setState(() {
          _selectedTabIndex = 3;
        });
        break;
      case 'Profile':
        setState(() {
          _selectedTabIndex = 4;
        });
        break;
      case 'Notifications':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const NotificationsPage()),
        );
        break;
      case 'Daily Check-in':
        await _startDailyCheckIn();
        break;
      case 'Sign out':
        await _confirmSignOut();
        break;
      case 'Volunteers':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const VolunteerPage()));
        break;
      case 'Music Therapy':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const MusicPage()));
        break;
      case 'Family messages':
        await _openFamilyMessages();
        break;
    }
  }

  Widget _buildHomeTab(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                ),
              ),
              GestureDetector(
                onTap: _profilePhotoUploading ? null : _showImageSourcePicker,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _profileAvatarImage(),
                      child: _profileAvatarImage() == null
                          ? const Icon(Icons.person, color: Colors.black54)
                          : null,
                    ),
                    if (_profilePhotoUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_timeOfDayGreeting()}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.black54),
                  ),
                  Text(
                    _userName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              StreamBuilder<int>(
                stream: NotificationRepository.instance.watchUnreadCount(),
                builder: (context, snapshot) {
                  final unread = snapshot.data ?? 0;
                  return IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const NotificationsPage(),
                        ),
                      );
                    },
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text(unread > 9 ? '9+' : '$unread'),
                      child: const Icon(Icons.notifications),
                    ),
                    color: const Color(0xFF0FA69A),
                    tooltip: 'Notifications',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF20C7BB), Color(0xFF159BC7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332196F3),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Family Wellness',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _wellnessScore?.toString() ?? '--',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '/100',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 5),
                        ),
                        child: const Icon(Icons.favorite, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: _wellnessScore != null
                          ? (_wellnessScore!.clamp(0, 100)) / 100.0
                          : 0,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _wellnessScore != null
                        ? '$_wellnessScore% wellness from your check-ins'
                        : 'Complete a check-in to track wellness',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trending_up,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _wellnessTrendText(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context: context,
                  icon: Icons.sensors_rounded,
                  iconBackgroundColor: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF2E7D32),
                  value: _onlineFamilyCount.toString(),
                  label: 'Online now',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context: context,
                  icon: Icons.local_fire_department,
                  iconBackgroundColor: const Color(0xFFF0E4FF),
                  iconColor: const Color(0xFF8E3FD8),
                  value: _dayStreakCount.toString(),
                  label: 'Day Streak',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFB85BFF), Color(0xFF5647F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.touch_app, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Check-in',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Takes only 30 seconds',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startDailyCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7A35D8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Start Now  ->',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Family Status',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (_familyMembers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${_familyMembers.length} in family · '
              '$_onlineFamilyCount online (app open in last 3 min)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _familyMembers
                  .map(
                    (member) => Material(
                      color: Colors.white,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.black12),
                      ),
                      child: InkWell(
                        onTap: member.isCurrentUser
                            ? null
                            : () => _messageFamilyMember(
                                  member.uid,
                                  member.name,
                                ),
                        child: Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FamilyMemberPresenceAvatar(
                            radius: 22,
                            initials: member.initials,
                            backgroundColor: member.avatarColor,
                            isOnline: member.isOnline,
                            photoBytes: member.isCurrentUser
                                ? _profileImageBytes
                                : null,
                            photoUrl: member.isCurrentUser
                                ? _profilePhotoUrl
                                : member.photoUrl,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            member.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member.presenceLabel,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: member.isOnline
                                      ? const Color(0xFF2E7D32)
                                      : Colors.black45,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member.wellness,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: member.wellnessColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBackgroundColor,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabPages = <Widget>[
      _buildHomeTab(context),
      TrendsPage(
        key: ValueKey('trends-$_shareTrendsEnabled'),
        memberScores: _latestMemberScores(),
        stressSourceCounts: _stressSourceCounts,
        currentUserName: _userName,
        familyProfiles: _familyProfiles,
        familyWellnessAverage: _wellnessScore,
      ),
      const SupportPage(),
      InsightsPage(
        key: ValueKey('insights-$_shareTrendsEnabled'),
        familyWellnessAverage: _wellnessScore,
        currentUserName: _userName,
        familyMemberNames: _visibleMemberNames(),
        memberScores: _latestMemberScores(),
        stressSourceCounts: _stressSourceCounts,
        familyProfiles: _visibleFamilyProfiles(),
      ),
      ProfilePage(
        profileImageBytes: _profileImageBytes,
        profilePhotoUrl: _profilePhotoUrl,
        displayName: _userName,
        statusLabel: _userStatus,
        onChangePhoto: _showImageSourcePicker,
        dayStreakCount: _dayStreakCount,
        checkInsCompleted: _checkInsCompleted,
        familyMemberCount: _familyMembers.length,
        weeksCount: _familyCheckInScores.isEmpty
            ? 0
            : (_familyCheckInScores.length + 6) ~/ 7,
        familyMembers: [
          for (final m in _familyMembers)
            ProfileFamilyMember(
              uid: m.uid,
              name: m.name,
              initials: m.initials,
              avatarColor: m.avatarColor,
              photoBytes: m.isCurrentUser ? _profileImageBytes : null,
              photoUrl: m.isCurrentUser ? _profilePhotoUrl : m.photoUrl,
              presenceLabel: m.presenceLabel,
              isOnline: m.isOnline,
              isCurrentUser: m.isCurrentUser,
            ),
        ],
        onAddFamilyMember: _showInviteFamilyMemberSheet,
        onOpenFamilyMessages: _openFamilyMessages,
        onMessageFamilyMember: _messageFamilyMember,
        shareTrendsEnabled: _shareTrendsEnabled,
        onShareTrendsChanged: (value) {
          unawaited(_setShareTrendsEnabled(value));
        },
        riskAlertsEnabled: _riskAlertsEnabled,
        onRiskAlertsChanged: (value) {
          unawaited(_setRiskAlertsEnabled(value));
        },
        checkInReminderEnabled: _checkInReminderEnabled,
        checkInReminderTimeLabel:
            CheckInReminderService.formatTime(_checkInReminderTime),
        onCheckInReminderEnabledChanged: (value) {
          unawaited(_setCheckInReminderEnabled(value));
        },
        onCheckInReminderTimeTap: () {
          unawaited(_pickCheckInReminderTime());
        },
        onSignOut: _confirmSignOut,
      ),
    ];

    if (_profileLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text(
                  'Navigation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _buildDrawerItem('Home'),
              _buildDrawerItem('Trends'),
              _buildDrawerItem('Support'),
              _buildDrawerItem('Family messages'),
              _buildDrawerItem('Volunteers'),
              _buildDrawerItem('Music Therapy'),
              _buildDrawerItem('Insights'),
              _buildDrawerItem('Profile'),
              _buildDrawerItem('Notifications'),
              _buildDrawerItem('Daily Check-in'),
              _buildDrawerItem('Sign out'),
            ],
          ),
        ),
      ),
      body: SafeArea(child: tabPages[_selectedTabIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF26A69A),
        unselectedItemColor: Colors.grey.shade600,
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Trends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism),
            label: 'Support',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb),
            label: 'Insights',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(label),
        onTap: () async {
          Navigator.of(context).pop();
          await _handleDrawerNavigation(label);
        },
      ),
    );
  }
}

