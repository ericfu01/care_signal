import 'package:care_signal/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportRepository.canViewMemberTrends', () {
    const memberUid = 'member-1';
    const viewerUid = 'viewer-1';

    test('member can always view own trends', () {
      expect(
        SupportRepository.canViewMemberTrends(
          memberUid: memberUid,
          viewerUid: memberUid,
          shareTrendsByUid: const {memberUid: false},
        ),
        isTrue,
      );
    });

    test('other viewers need shareTrendsEnabled', () {
      expect(
        SupportRepository.canViewMemberTrends(
          memberUid: memberUid,
          viewerUid: viewerUid,
          shareTrendsByUid: const {memberUid: true},
        ),
        isTrue,
      );
      expect(
        SupportRepository.canViewMemberTrends(
          memberUid: memberUid,
          viewerUid: viewerUid,
          shareTrendsByUid: const {memberUid: false},
        ),
        isFalse,
      );
    });

    test('missing preference defaults to hidden', () {
      expect(
        SupportRepository.canViewMemberTrends(
          memberUid: memberUid,
          viewerUid: viewerUid,
          shareTrendsByUid: const {},
        ),
        isFalse,
      );
    });

    test('without viewer uid, only share preference applies', () {
      expect(
        SupportRepository.canViewMemberTrends(
          memberUid: memberUid,
          viewerUid: null,
          shareTrendsByUid: const {memberUid: true},
        ),
        isTrue,
      );
      expect(
        SupportRepository.canViewMemberTrends(
          memberUid: memberUid,
          viewerUid: null,
          shareTrendsByUid: const {memberUid: false},
        ),
        isFalse,
      );
    });
  });
}
