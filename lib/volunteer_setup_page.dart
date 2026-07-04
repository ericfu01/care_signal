import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_repository.dart';
import 'support_catalog.dart';
import 'volunteer_availability_page.dart';

/// One-time setup: volunteer picks the type of help they offer.
class VolunteerSetupPage extends StatefulWidget {
  const VolunteerSetupPage({super.key});

  @override
  State<VolunteerSetupPage> createState() => _VolunteerSetupPageState();
}

class _VolunteerSetupPageState extends State<VolunteerSetupPage> {
  String? _selectedCatalogId;
  bool _saving = false;

  Future<void> _continue() async {
    final catalogId = _selectedCatalogId;
    if (catalogId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose how you would like to help.')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await FamilyRepository.instance.setVolunteerProfile(
        uid: uid,
        volunteerCatalogId: catalogId,
      );
      if (!mounted) return;

      final scheduleSaved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const VolunteerAvailabilityPage(),
        ),
      );

      if (!mounted) return;
      if (scheduleSaved != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can set your weekly hours anytime from Home or Profile.',
            ),
          ),
        );
      }

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lanes = SupportCatalog.volunteers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How would you like to help families?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This matches you with the right support requests. You can also host '
              'peer support groups from the Groups tab after setup.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            for (final lane in lanes) ...[
              _ServiceLaneTile(
                volunteer: lane,
                selected: _selectedCatalogId == lane.id,
                onTap: () => setState(() => _selectedCatalogId = lane.id),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _continue,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue to volunteer home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceLaneTile extends StatelessWidget {
  const _ServiceLaneTile({
    required this.volunteer,
    required this.selected,
    required this.onTap,
  });

  final CatalogVolunteer volunteer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF439A7D).withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF439A7D)
                  : Colors.black12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? const Color(0xFF439A7D) : Colors.black38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      volunteer.role,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      volunteer.specialties.join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
