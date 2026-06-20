import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'family_repository.dart';

/// Shows invite code + link for the current user's family (admin can copy/share).
class FamilyInviteSheet extends StatefulWidget {
  const FamilyInviteSheet({
    super.key,
    required this.familyId,
    required this.isAdmin,
  });

  final String familyId;
  final bool isAdmin;

  @override
  State<FamilyInviteSheet> createState() => _FamilyInviteSheetState();
}

class _FamilyInviteSheetState extends State<FamilyInviteSheet> {
  String? _inviteCode;
  String? _familyName;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final family =
          await FamilyRepository.instance.getFamily(widget.familyId);
      if (family == null) {
        setState(() {
          _error = 'Family not found';
          _loading = false;
        });
        return;
      }
      final code = family.inviteCode.isNotEmpty
          ? family.inviteCode
          : await FamilyRepository.instance
              .ensureInviteCodeForFamily(widget.familyId);
      if (!mounted) return;
      setState(() {
        _inviteCode = code;
        _familyName = family.name;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = _inviteCode != null
        ? FamilyRepository.inviteLinkForCode(_inviteCode!)
        : '';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite family members',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_familyName != null && _familyName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _familyName!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              widget.isAdmin
                  ? 'Share the link or code. They create an account, choose '
                      'Join family, and paste it.'
                  : 'Ask your family admin for an invite link or code.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error))
            else ...[
              SelectableText(
                'Code: $_inviteCode',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                link,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (widget.isAdmin) ...[
                FilledButton.icon(
                  onPressed: () => _copy(link, 'Invite link'),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy invite link'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _copy(_inviteCode!, 'Invite code'),
                  icon: const Icon(Icons.tag_rounded),
                  label: const Text('Copy invite code'),
                ),
              ],
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
