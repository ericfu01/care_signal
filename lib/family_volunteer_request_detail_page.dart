import 'package:flutter/material.dart';

import 'family_volunteer_request_helpers.dart';
import 'family_volunteer_requests_page.dart';
import 'support_repository.dart';

/// Single volunteer request for a family — opened from notifications.
class FamilyVolunteerRequestDetailPage extends StatelessWidget {
  const FamilyVolunteerRequestDetailPage({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request details'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: SupportRepository.instance.getVolunteerRequest(requestId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final request = snapshot.data;
          if (request == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'This request is no longer available.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                const FamilyVolunteerRequestsPage(),
                          ),
                        );
                      },
                      child: const Text('View all requests'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FamilyVolunteerRequestCard(
                request: request,
                title: FamilyVolunteerRequestHelpers.visitTitle(request),
                subtitle: FamilyVolunteerRequestHelpers.formatVisit(request),
                showActions: true,
              ),
            ],
          );
        },
      ),
    );
  }
}
