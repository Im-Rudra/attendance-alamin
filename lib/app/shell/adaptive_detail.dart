// Detail route body that adapts to the window: on wide windows (≥ 840) the
// master screen renders list ‖ detail itself (it receives the selected id);
// on phones the detail screen is shown alone.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/shell/window_class.dart';

class AdaptiveDetail extends StatelessWidget {
  const AdaptiveDetail({
    super.key,
    required this.id,
    required this.master,
    required this.detail,
  });

  final String id;
  final Widget Function(String id) master;
  final Widget Function(String id) detail;

  @override
  Widget build(BuildContext context) =>
      WindowClass.of(context).isWide ? master(id) : detail(id);
}
