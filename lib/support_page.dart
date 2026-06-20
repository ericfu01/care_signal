import 'package:flutter/material.dart';

import 'event_signup_page.dart';
import 'scheduled_event.dart';
import 'support_action_pages.dart';
import 'support_available_page.dart';
import 'support_catalog.dart';
import 'support_recommendations.dart';
import 'support_repository.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  bool _shareWithPartners = true;
  ScheduledEvent? _scheduledEvent;
  bool _signedUpForEvent = false;
  bool _loading = true;
  PersonalizedSupportPlan _plan = PersonalizedSupportPlan.empty();
  String? _eventReason;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final catalogEvent = SupportCatalog.nextEvent;
    try {
      final plan =
          await SupportRepository.instance.loadPersonalizedSupportPlan();
      final share = await SupportRepository.instance.getShareWithPartners();
      var signedUp = false;
      var signupCount = catalogEvent?.baseFamiliesSignedUp ?? 0;
      final event = plan.featuredEvent ?? catalogEvent;
      if (event != null) {
        signedUp = await SupportRepository.instance.hasEventSignup(event.id);
        if (signedUp) signupCount += 1;
      }

      if (!mounted) return;
      setState(() {
        _plan = plan;
        _eventReason = plan.eventReason;
        _shareWithPartners = share;
        _signedUpForEvent = signedUp;
        if (event != null) {
          _scheduledEvent = ScheduledEvent(
            id: event.id,
            monthAbbrev: event.monthAbbrev,
            day: event.day,
            title: event.title,
            isOnline: event.isOnline,
            timeDisplay: event.timeDisplay,
            familiesSignedUp: signupCount,
          );
        } else {
          _scheduledEvent = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (catalogEvent != null) {
          _scheduledEvent = ScheduledEvent(
            id: catalogEvent.id,
            monthAbbrev: catalogEvent.monthAbbrev,
            day: catalogEvent.day,
            title: catalogEvent.title,
            isOnline: catalogEvent.isOnline,
            timeDisplay: catalogEvent.timeDisplay,
            familiesSignedUp: catalogEvent.baseFamiliesSignedUp,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onShareChanged(bool value) async {
    setState(() => _shareWithPartners = value);
    try {
      await SupportRepository.instance.setShareWithPartners(value);
      if (!mounted) return;
      final plan =
          await SupportRepository.instance.loadPersonalizedSupportPlan();
      if (!mounted) return;
      setState(() => _plan = plan);
    } catch (e) {
      if (!mounted) return;
      setState(() => _shareWithPartners = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update partner sharing: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SupportLoadingView(
        message: 'Personalizing suggestions for you…',
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: const Color(0xFFFFF3CD),
            elevation: 2,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const SupportAvailablePage(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6D49A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E6A3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: Color(0xFFB8860B),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended for you',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                 fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _plan.hasCheckInData
                                ? _plan.headline
                                : 'Tap for personalized resources, groups, and volunteer help',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.black87,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                   fontWeight: FontWeight.bold,
                 ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _QuickActionTile(
                icon: Icons.phone_in_talk_rounded,
                label: 'Crisis Line',
                subtitle: '24/7',
                accentColor: const Color(0xFFD32F2F),
                emphasized: _plan.highlightCrisisLine,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const CrisisLinePage(),
                    ),
                  );
                },
              ),
              _QuickActionTile(
                icon: Icons.chat_rounded,
                label: 'Chat',
                subtitle: 'Online',
                accentColor: const Color(0xFF1976D2),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const SupportChatListPage(),
                    ),
                  );
                },
              ),
              _QuickActionTile(
                icon: Icons.groups_rounded,
                label: 'Peer Groups',
                subtitle: 'Community',
                accentColor: const Color(0xFF7B1FA2),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const PeerGroupsPage(),
                    ),
                  );
                },
              ),
              _QuickActionTile(
                icon: Icons.menu_book_rounded,
                label: 'Resources',
                subtitle: 'Guides',
                accentColor: const Color(0xFFF57C00),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const SupportResourcesPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF7F1),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFB2DFDB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E6C9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        size: 28,
                        color: Color(0xFF00695C),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voluntary Sharing',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF263238),
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'De-identified trends only',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF00897B),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share with Partners',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF263238),
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _shareWithPartners
                                  ? 'De-identified wellness trends shared with care partners'
                                  : 'Partner peer groups and wellness export are off',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.black54,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _shareWithPartners,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF26A69A),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.grey.shade300,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: _onShareChanged,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  constraints: const BoxConstraints(minHeight: 72),
                  alignment: Alignment.center,
                  child: _scheduledEvent == null
                      ? const SizedBox.shrink()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _scheduledEvent!.monthAbbrev.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _scheduledEvent!.day,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                    color: const Color(0xFF263238),
                                  ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scheduledEvent?.title ?? 'No events scheduled yet',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF263238),
                            ),
                      ),
                      const SizedBox(height: 6),
                      if (_eventReason != null &&
                          _eventReason!.isNotEmpty &&
                          _scheduledEvent != null) ...[
                        Text(
                          _eventReason!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF00897B),
                                    height: 1.35,
                                  ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        _scheduledEvent == null
                            ? '— · —'
                            : '${_scheduledEvent!.isOnline ? 'Online' : 'In person'} · ${_scheduledEvent!.timeDisplay}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.black54,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _scheduledEvent == null
                            ? '0 families signed up'
                            : '${_scheduledEvent!.familiesSignedUp} ${_scheduledEvent!.familiesSignedUp == 1 ? 'family' : 'families'} signed up',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.black54,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _scheduledEvent == null
                      ? null
                      : _signedUpForEvent
                          ? null
                          : () async {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (context) => EventSignupPage(
                                    event: _scheduledEvent!,
                                  ),
                                ),
                              );
                              if (mounted) await _load();
                            },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF26A69A),
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(_signedUpForEvent ? 'Signed up' : 'Join'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportLoadingView extends StatelessWidget {
  const _SupportLoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading your events and preferences',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final lightBg = Color.lerp(accentColor, Colors.white, 0.86)!;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: emphasized ? accentColor : Colors.black12,
              width: emphasized ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: lightBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: IconTheme(
                    data: const IconThemeData(weight: 700),
                    child: Icon(
                      icon,
                      size: 28,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                       fontWeight: FontWeight.bold,
                     ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
