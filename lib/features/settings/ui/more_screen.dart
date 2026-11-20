// More tab = Settings (Product 3.12, UX 3a). One scrolling list of groups on
// phones; on wide windows a group index (240) next to the selected group's
// cards (two columns when there is room), so no area is left blank.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/features/settings/widgets/settings_groups.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';

/// Window width (of the content area) from which the index ‖ content layout is used.
const double kMoreSplitMinWidth = 720;

/// Width of the group index in the split layout.
const double kMoreIndexWidth = 240;

/// Content width from which a group's cards sit in two columns.
const double kMoreTwoUpMinWidth = 640;

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  // The split layout always opens on the first group (UX 3b).
  SettingsGroup _selected = SettingsGroup.values.first;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final bool embedded = PaneScope.isEmbedded(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Semantics(header: true, child: Text(l10n.navMore)),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.commonSearch,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            if (c.maxWidth >= kMoreSplitMinWidth) return _split(context, c, g);
            return _list(context, g);
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext context, double g) {
    final l10n = context.l10n;
    return ListView(
      padding: EdgeInsets.fromLTRB(g, 4, g, g),
      children: <Widget>[
        for (final SettingsGroup group in SettingsGroup.values) ...<Widget>[
          SettingsHeader(group.title(l10n)),
          SettingsGroupBody(group: group),
        ],
      ],
    );
  }

  Widget _split(BuildContext context, BoxConstraints c, double g) {
    final l10n = context.l10n;
    final double contentWidth = c.maxWidth - 2 * g - kMoreIndexWidth - g;
    return Padding(
      padding: EdgeInsets.fromLTRB(g, 4, g, g),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: kMoreIndexWidth,
            child: _Index(
              selected: _selected,
              onSelect: (SettingsGroup v) => setState(() => _selected = v),
            ),
          ),
          SizedBox(width: g),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey<SettingsGroup>(_selected),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SettingsHeader(_selected.title(l10n)),
                  SettingsGroupBody(
                    group: _selected,
                    twoUp: contentWidth >= kMoreTwoUpMinWidth,
                  ),
                ],
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
    final tokens = context.aurora;
    return Semantics(
      container: true,
      label: l10n.setIndexLabel,
      child: GlassCard(
        dense: true,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final SettingsGroup group in SettingsGroup.values)
                  ListTile(
                    key: Key('more-index-${group.name}'),
                    minTileHeight: 52,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
                    ),
                    selected: group == selected,
                    selectedColor: tokens.onAccentContainer,
                    selectedTileColor: tokens.accentContainer,
                    leading: Icon(group.icon),
                    title: Text(group.title(l10n)),
                    onTap: () => onSelect(group),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
