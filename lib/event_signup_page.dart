import 'package:flutter/material.dart';

import 'scheduled_event.dart';
import 'support_repository.dart';

class EventSignupPage extends StatefulWidget {
  const EventSignupPage({
    required this.event,
    super.key,
  });

  final ScheduledEvent event;

  @override
  State<EventSignupPage> createState() => _EventSignupPageState();
}

class _EventSignupPageState extends State<EventSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _familyCountController = TextEditingController(text: '1');
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _familyCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event sign-up'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.event.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.event.isOnline ? 'Online' : 'In person'} · ${widget.event.timeDisplay}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _familyCountController,
                  decoration: const InputDecoration(
                    labelText: 'Family members attending',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a number';
                    }
                    final n = int.tryParse(value.trim());
                    if (n == null || n < 1) {
                      return 'Enter at least 1';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            FocusScope.of(context).unfocus();
                            setState(() => _submitting = true);
                            try {
                              await SupportRepository.instance.submitEventSignup(
                                eventId: widget.event.id,
                                eventTitle: widget.event.title,
                                name: _nameController.text,
                                email: _emailController.text,
                                phone: _phoneController.text,
                                familyCount: int.parse(
                                  _familyCountController.text.trim(),
                                ),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'You are signed up. We will confirm by email.',
                                  ),
                                ),
                              );
                              Navigator.of(context).pop();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not sign up: $e')),
                              );
                            } finally {
                              if (mounted) setState(() => _submitting = false);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF26A69A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_submitting ? 'Submitting…' : 'Submit sign-up'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
