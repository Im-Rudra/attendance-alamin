// BatchDetailScreen: STUB by M5-A (plan section 0). The body belongs to M6-C (batches);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class BatchDetailScreen extends StatelessWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleBatchDetail,
        icon: Icons.class_outlined,
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.commonEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.batchEdit(batchId)),
          ),
        ],
      );
}
