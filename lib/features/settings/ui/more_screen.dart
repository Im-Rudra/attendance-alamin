// More tab = Settings (Product 3.12, UX 3a). One scrolling list of groups on
// phones; on wide windows a group index (240) next to the selected group's
// cards in one calm column (max 720).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/batches/ui/archived_batches_screen.dart';
import 'package:attendance_alamin/features/extras/ui/holiday_screen.dart';
import 'package:attendance_alamin/features/settings/widgets/settings_groups.dart';
import 'package:attendance_alamin/features/students/ui/left_students_screen.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';

/// Window width (of the content area) from which the index ‖ content layout is used.
const double kMoreSplitMinWidth = 720;

/// Width of the group index in the split layout.
const double kMoreIndexWidth = 240;

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  // The split layout always opens on the first group (UX 3b).
  SettingsGroup _selected = SettingsGroup.values.first;

  /// Route of a sub-page (archived batches, left students, holidays) shown in
  /// the right pane on wide windows instead of leaving More; null = the
  /// selected group's cards.
  String? _inline;

  Widget? _inlinePage() => switch (_inline) {
        Routes.moreArchived => const ArchivedBatchesScreen(),
        Routes.moreLeft => const LeftStudentsScreen(),
        Routes.moreHolidays => const HolidayScreen(),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final bool embedded = PaneScope.isEmbedded(context);
    return BhorScaffold(
      header: BhorHeader(
        title: l10n.navMore,
        large: true,
        showBack: embedded ? false : null,
        actions: <Widget>[
          BhorIconButton(
            icon: BhorIcons.search,
            semanticLabel: l10n.commonSearch,
            variant: BhorButtonVariant.secondary,
            circle: true,
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          if (c.maxWidth >= kMoreSplitMinWidth) return _split(context, c, g);
          return _list(context, g);
        },
      ),
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

  Widget _split(BuildContext context, BoxConstraints c, double g) {
    final l10n = context.l10n;
    final Widget? inline = _inlinePage();
    return Padding(
      padding: EdgeInsets.fromLTRB(g, 4, g, g),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: kMoreIndexWidth,
            child: _Index(
              selected: _selected,
              onSelect: (SettingsGroup v) => setState(() {
                _selected = v;
                _inline = null;
              }),
            ),
          ),
          SizedBox(width: g),
          // One calm column (max 720); switching groups cross-fades and rises.
          Expanded(
            child: BhorPaneSwitcher(
              paneKey: _inline ?? _selected,
              child: inline != null
                  ? PaneScope(child: inline)
                  : Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SettingsHeader(_selected.title(l10n)),
                        SettingsGroupBody(
                          group: _selected,
                          onOpenInline: (String route) => setState(() => _inline = route),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Index extends StatelessWidget {
  const _Index({required this.selected, required this.onSelect});

  final SettingsGroup selected;
  final ValueChanged<SettingsGroup> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A light sub-navigation, not a card: the selected row is tinted.
    return Semantics(
      container: true,
      label: l10n.setIndexLabel,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final SettingsGroup group in SettingsGroup.values)
              Padding(
                padding: const EdgeInsets.only(bottom: BhorSpace.s4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BhorRadius.control),
                  child: BhorListRow(
                    key: Key('more-index-${group.name}'),
                    leading: Icon(group.icon, size: BhorIconSize.row),
                    title: group.title(l10n),
                    selected: group == selected,
                    divider: false,
                    onTap: () => onSelect(group),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
