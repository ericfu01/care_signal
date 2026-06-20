import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'family_check_in_loader.dart';
import 'support_repository.dart';

class DailyCheckInResult {
  const DailyCheckInResult({
    required this.score,
    required this.stressSources,
  });

  final int score;
  final List<String> stressSources;
}

String _memberLabelForFirestore(User user) {
  final dn = user.displayName?.trim();
  if (dn != null && dn.isNotEmpty) return dn;
  final email = user.email?.trim();
  if (email != null && email.isNotEmpty) {
    final at = email.indexOf('@');
    if (at > 0) return email.substring(0, at);
  }
  return 'Member';
}

class DailyCheckInPage extends StatefulWidget {
  const DailyCheckInPage({super.key});

  @override
  State<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends State<DailyCheckInPage> {
  double _mood = 7;
  double _energy = 7;
  double _stress = 3;
  bool _isSubmitting = false;
  final List<String> _stressSourceOptions = const [
    'Medical',
    'Time',
    'Financial',
    'Work',
    'Family',
    'Sleep',
  ];
  final Set<String> _selectedStressSources = {};

  int _calculateScore() {
    return (((_mood + _energy + (10 - _stress)) / 30) * 100).round();
  }

  Future<void> _submitCheckIn() async {
    if (_isSubmitting) return;

    final result = DailyCheckInResult(
      score: _calculateScore(),
      stressSources: _selectedStressSources.toList(),
    );

    final user = FirebaseAuth.instance.currentUser;
    setState(() => _isSubmitting = true);
    try {
      if (user != null) {
        final now = DateTime.now();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('daily_check_ins')
            .add({
              'memberName': _memberLabelForFirestore(user),
              'mood': _mood.round(),
              'energy': _energy.round(),
              'stress': _stress.round(),
              'stressSources': result.stressSources,
              'score': result.score,
              'dayKey': FamilyCheckInLoader.dayKey(now),
              'createdAt': FieldValue.serverTimestamp(),
            });
        unawaited(
          SupportRepository.instance.syncPartnerWellnessSnapshot(
            score: result.score,
            dayKey: FamilyCheckInLoader.dayKey(now),
            stressSources: result.stressSources,
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e, st) {
      debugPrint(
        '[CareSignal][DailyCheckIn] Firestore save failed uid=${user?.uid}: $e',
      );
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save check-in. Please try again.'),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildSliderRow({
      required String label,
      required double value,
      required ValueChanged<double> onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                value.toStringAsFixed(0),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: onChanged,
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Check-in')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Answer a few questions to update your wellness score.',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              buildSliderRow(
                label: 'Mood',
                value: _mood,
                onChanged: (value) => setState(() => _mood = value),
              ),
              buildSliderRow(
                label: 'Energy',
                value: _energy,
                onChanged: (value) => setState(() => _energy = value),
              ),
              buildSliderRow(
                label: 'Stress',
                value: _stress,
                onChanged: (value) => setState(() => _stress = value),
              ),
              const SizedBox(height: 8),
              Text(
                'What are your main stress sources today?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _stressSourceOptions
                    .map(
                      (source) => FilterChip(
                        label: Text(source),
                        selected: _selectedStressSources.contains(source),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedStressSources.add(source);
                            } else {
                              _selectedStressSources.remove(source);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitCheckIn,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Check-in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
