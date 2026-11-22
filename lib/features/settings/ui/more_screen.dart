// More tab = Settings (Product 3.12, UX 3a). Every section uses
// BhorSettingsPage (review M1, M2): a 240 section nav on wide windows, the
// selected section in one top-aligned column of at most 720, so the highlighted
// nav item always matches the content. Holidays is its own section; Archive
// holds archived batches and left students, which open in the same column with
// a crumb back to Archive. Phones show one scrolling list of groups.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/backup/ui/backup_screen.dart';
import 'package:attendance_alamin/features/batches/ui/archived_batches_screen.dart';
import 'package:attendance_alamin/features/extras/ui/holiday_screen.dart';
import 'package:attendance_alamin/features/settings/widgets/settings_groups.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
import 'package:attendance_alamin/features/students/ui/left_students_screen.dart';

/// Window width (of the content area) from which the section nav ‖ content
/// layout is used.
const double kMoreSplitMinWidth = BhorSettingsPage.navMinWidth;

/// Routed More sub-pages that sit inside the settings layout on wide windows
/// and are plain pages on phones ([MoreRouteTarget]).
enum MoreTarget { backup, holidays, archived, left }

/// What a `/more/...` route shows: the settings layout opened on the right
/// section (wide), or the page itself (phones).
class MoreRouteTarget extends StatelessWidget {
  const MoreRouteTarget({super.key, required this.target});

  final MoreTarget target;

  @override
  Widget build(BuildContext context) {
    if (WindowClass.of(context).isWide) {
      return switch (target) {
        MoreTarget.backup => const MoreScreen(initialGroup: SettingsGroup.backup),
        MoreTarget.holidays => const MoreScreen(initialGroup: SettingsGroup.holidays),
        MoreTarget.archived =>
          const MoreScreen(initialGroup: SettingsGroup.archive, initialSub: MoreSub.archivedBatches),
        MoreTarget.left => const MoreScreen(initialGroup: SettingsGroup.archive, initialSub: MoreSub.leftStudents),
      };
    }
    return switch (target) {
      MoreTarget.backup => const BackupScreen(),
      MoreTarget.holidays => const HolidayScreen(),
      MoreTarget.archived => const ArchivedBatchesScreen(),
      MoreTarget.left => const LeftStudentsScreen(),
    };
  }
}

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key, this.initialGroup, this.initialSub});

  /// The section to open on (default: the first).
  final SettingsGroup? initialGroup;

  /// The Archive sub-page to open on.
  final MoreSub? initialSub;

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  late SettingsGroup _selected = widget.initialGroup ?? SettingsGroup.values.first;

  /// Open Archive sub-page; null = the section's own cards.
  late MoreSub? _sub = widget.initialSub;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth >= kMoreSplitMinWidth) return _wide(context);
        final double g = WindowClass.of(context).gutter;
        final bool embedded = PaneScope.isEmbedded(context);
        return BhorScaffold(
          header: BhorHeader(
            title: l10n.navMore,
            large: true,
            showBack: embedded ? false : null,
          ),
          body: _list(context, g),
        );
      },
    );
  }

  Widget _list(BuildContext context, double g) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(g, 4, g, g),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final SettingsGroup group in SettingsGroup.values) ...<Widget>[
            SettingsHeader(group.title(l10n)),
            SettingsGroupBody(group: group),
          ],
        ],
      ),
    );
  }

  Widget _wide(BuildContext context) {
    final l10n = context.l10n;
    final MoreSub? sub = _sub;
    final Widget body = switch (sub) {
      MoreSub.archivedBatches => const ArchivedBatchesScreen(embedded: true),
      MoreSub.leftStudents => const LeftStudentsScreen(embedded: true),
      null => SettingsGroupBody(
          group: _selected,
          wide: true,
          onOpenSub: (MoreSub s) => setState(() => _sub = s),
        ),
    };
    return BhorSettingsPage(
      sections: <BhorSettingsSection>[
        for (final SettingsGroup g in SettingsGroup.values)
          BhorSettingsSection(id: g.name, label: g.title(l10n), icon: g.icon),
      ],
      selected: _selected.name,
      onSelect: (String id) => setState(() {
        _selected = SettingsGroup.values.byName(id);
        _sub = null;
      }),
      title: sub?.title(l10n) ?? _selected.title(l10n),
      crumb: sub == null ? null : _selected.title(l10n),
      onCrumb: () => setState(() => _sub = null),
      child: BhorPaneSwitcher(paneKey: sub ?? _selected, child: body),
    );
  }
}
