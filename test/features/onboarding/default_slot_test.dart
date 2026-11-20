import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/features/onboarding/controllers/onboarding_service.dart';

void main() {
  test('default first slot: next full hour inside 07:00-20:00, else 16:00', () {
    expect(defaultSlotStartMin(4 * 60 + 30), 16 * 60, reason: 'early morning');
    expect(defaultSlotStartMin(5 * 60), 16 * 60);
    expect(defaultSlotStartMin(6 * 60 + 10), 7 * 60, reason: 'next hour is 07:00');
    expect(defaultSlotStartMin(10 * 60 + 15), 11 * 60);
    expect(defaultSlotStartMin(19 * 60 + 59), 20 * 60);
    expect(defaultSlotStartMin(20 * 60), 16 * 60, reason: '21:00 is too late');
    expect(defaultSlotStartMin(23 * 60 + 30), 16 * 60);
    expect(defaultSlotStartMin(0), 16 * 60);
  });
}
