import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/routes.dart';

void main() {
  group('pickInitialLocation (QA-11)', () {
    test('a deep link or reload on an inner route lands on that route', () {
      expect(pickInitialLocation(entryRoute: '/batches/b1', onboardingDone: true), '/batches/b1');
      expect(pickInitialLocation(entryRoute: '/more', onboardingDone: true), '/more');
      expect(pickInitialLocation(entryRoute: '/students/s1?x=1', onboardingDone: true), '/students/s1?x=1');
    });

    test('a bare "/" or junk goes to Today', () {
      expect(pickInitialLocation(entryRoute: '/', onboardingDone: true), Routes.today);
      expect(pickInitialLocation(entryRoute: '', onboardingDone: true), Routes.today);
      expect(pickInitialLocation(entryRoute: 'nonsense', onboardingDone: true), Routes.today);
    });

    test('onboarding is needed: onboarding wins over a deep link', () {
      expect(pickInitialLocation(entryRoute: '/more', onboardingDone: false), Routes.onboarding);
    });

    test('a tapped reminder wins', () {
      expect(
        pickInitialLocation(entryRoute: '/more', onboardingDone: true, launchRoute: '/x'),
        '/x',
      );
    });
  });
}
