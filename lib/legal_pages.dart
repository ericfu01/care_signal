import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config_service.dart';

/// Opens an external legal URL when configured; otherwise shows in-app text.
Future<void> openPrivacyPolicy(BuildContext context) async {
  final config = await AppConfigService.instance.loadConfig();
  final url = config.privacyPolicyUrl;
  if (url != null && await _tryLaunch(url)) return;
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()),
  );
}

Future<void> openTermsOfService(BuildContext context) async {
  final config = await AppConfigService.instance.loadConfig();
  final url = config.termsOfServiceUrl;
  if (url != null && await _tryLaunch(url)) return;
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const TermsOfServicePage()),
  );
}

Future<bool> _tryLaunch(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScaffold(
      title: 'Privacy Policy',
      sections: const [
        _LegalSection(
          heading: 'Overview',
          body:
              'Care Signal helps family caregivers track wellbeing, request support, '
              'and connect with volunteers and peer groups. This policy explains what '
              'information we collect and how we use it.',
        ),
        _LegalSection(
          heading: 'Information we collect',
          body:
              'Account details (such as email and display name), family and volunteer '
              'profile information, check-ins and wellness entries you choose to log, '
              'support requests (including ride pickup/destination when you provide them), '
              'messages you send in the app, feedback you submit, and basic device/app '
              'data needed to deliver notifications and keep the service secure.',
        ),
        _LegalSection(
          heading: 'How we use information',
          body:
              'We use your information to operate Care Signal: match volunteer requests, '
              'show trends and insights, send in-app or push notifications you enable, '
              'review volunteer screening applications, improve the product, and respond '
              'to support or feedback. We do not sell your personal information.',
        ),
        _LegalSection(
          heading: 'Sharing',
          body:
              'Information may be shared with family members you connect with, volunteers '
              'assigned to your requests, staff reviewers for screening/feedback, and '
              'service providers that host the app (such as Firebase). Crisis or safety '
              'features may surface urgent signals to people you have designated in the app.',
        ),
        _LegalSection(
          heading: 'Your choices',
          body:
              'You can update profile information in the app, turn notification '
              'preferences on or off where offered, export your data from Profile, and '
              'delete your account. Deleting your account removes associated personal '
              'data from active systems, subject to limited records we must keep for '
              'security or legal reasons.',
        ),
        _LegalSection(
          heading: 'Contact',
          body:
              'Questions about privacy can be sent through Help → Send feedback in the app, '
              'or to the support email shown there when configured.',
        ),
      ],
    );
  }
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScaffold(
      title: 'Terms of Service',
      sections: const [
        _LegalSection(
          heading: 'Agreement',
          body:
              'By creating an account or using Care Signal, you agree to these Terms. '
              'If you do not agree, do not use the app.',
        ),
        _LegalSection(
          heading: 'The service',
          body:
              'Care Signal provides caregiver support tools, volunteer coordination, peer '
              'groups, and related features. Availability may vary by region. Volunteer '
              'transportation and other services may be limited while we expand.',
        ),
        _LegalSection(
          heading: 'Not medical care',
          body:
              'Care Signal is not a medical device and does not provide diagnosis, '
              'treatment, or emergency services. Insights and chat are informational '
              'only. If you or someone else may be in danger, call local emergency '
              'services. Crisis resources in the app are not a substitute for emergency help.',
        ),
        _LegalSection(
          heading: 'Accounts and conduct',
          body:
              'You are responsible for your account credentials and for information you '
              'submit. Do not misuse the service, harass others, submit false screening '
              'information, or attempt to access data you are not authorized to see. '
              'We may suspend accounts that violate these Terms or put the community at risk.',
        ),
        _LegalSection(
          heading: 'Volunteers and third parties',
          body:
              'Volunteer help is provided by community members and is not employment by '
              'Care Signal. Rideshare options (such as Uber or Lyft) are third-party '
              'services with their own terms. Care Signal is not responsible for those '
              'providers or for volunteer availability.',
        ),
        _LegalSection(
          heading: 'Disclaimers',
          body:
              'The service is provided “as is” without warranties of uninterrupted or '
              'error-free operation. To the fullest extent permitted by law, Care Signal '
              'is not liable for indirect or consequential damages arising from use of '
              'the app.',
        ),
        _LegalSection(
          heading: 'Changes',
          body:
              'We may update these Terms from time to time. Continued use after changes '
              'means you accept the updated Terms. Material changes may be noted in the app.',
        ),
      ],
    );
  }
}

class _LegalSection {
  const _LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

class _LegalDocumentScaffold extends StatelessWidget {
  const _LegalDocumentScaffold({
    required this.title,
    required this.sections,
  });

  final String title;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text(
            'Last updated: July 25, 2026',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          for (final section in sections) ...[
            Text(
              section.heading,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
