// EffectsMode (UX 4, performance rule 5): the app-level reduced-effects flag,
// with the OS reduce-motion and high-contrast flags applied on top.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/widgets/effects_mode.dart';

import 'harness.dart';

/// Reads [EffectsMode.reducedOf] where it is built.
class _Probe extends StatelessWidget {
  const _Probe(this.onRead);

  final ValueChanged<bool> onRead;

  @override
  Widget build(BuildContext context) {
    onRead(EffectsMode.reducedOf(context));
    return const SizedBox();
  }
}

void main() {
  testWidgets('the app flag reaches the tree', (WidgetTester tester) async {
    bool? seen;
    await pumpLayout(tester, _Probe((bool v) => seen = v), reduced: true);
    expect(seen, isTrue);
    await pumpLayout(tester, _Probe((bool v) => seen = v), reduced: false);
    expect(seen, isFalse);
  });

  testWidgets('OS reduce-motion forces the reduced path', (WidgetTester tester) async {
    bool? seen;
    await pumpLayout(
      tester,
      _Probe((bool v) => seen = v),
      reduced: false,
      media: (MediaQueryData d) => d.copyWith(disableAnimations: true),
    );
    expect(seen, isTrue);
  });

  testWidgets('OS high contrast forces the reduced path', (WidgetTester tester) async {
    bool? seen;
    await pumpLayout(
      tester,
      _Probe((bool v) => seen = v),
      reduced: false,
      media: (MediaQueryData d) => d.copyWith(highContrast: true),
    );
    expect(seen, isTrue);
  });

  testWidgets('reducedOf: default is false, explicit true wins', (WidgetTester tester) async {
    bool? plain;
    bool? explicit;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Column(
          children: <Widget>[
            Builder(builder: (BuildContext c) {
              plain = EffectsMode.reducedOf(c);
              return const SizedBox();
            }),
            EffectsMode(
              reduced: true,
              child: Builder(builder: (BuildContext c) {
                explicit = EffectsMode.reducedOf(c);
                return const SizedBox();
              }),
            ),
          ],
        ),
      ),
    );
    expect(plain, isFalse);
    expect(explicit, isTrue);
  });
}
