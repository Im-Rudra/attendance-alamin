// `/fees/collection`: the same tabbed Fees page opened on its আদায় segment.
// The segmented control swaps the body in place, so this route only chooses
// the starting segment (no separate page, no back arrow).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/features/dues/ui/fees_screen.dart';
import 'package:attendance_alamin/features/dues/widgets/fees_segments.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeesScreen(initialSegment: FeesSegment.collection);
}
