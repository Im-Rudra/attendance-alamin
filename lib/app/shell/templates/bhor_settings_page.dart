// BhorSettingsPage (docs/council/16-windows-rebuild-plan.md W1-B 5): every
// More / settings section uses it (review M1, M2). Wide: a 240 section nav on
// the left (the selected section in the one selection style, so the nav
// always matches the content), then one content column at most 720 wide,
// top-aligned and centred in the remaining space. Sub-pages show a back
// crumb ("‹ Fees & payments") above their title. Narrow: the content alone
// (the More list is the section nav on phones).
// Usage:
//   BhorSettingsPage(
//     sections: const [BhorSettingsSection(id: 'look', label: 'চেহারা', icon: BhorIcons.light), ...],
//     selected: 'look',
//     onSelect: (id) => context.go(...),
//     title: 'চেহারা',
//     child: AppearanceForm(),
//   )
//   Sub-page: BhorSettingsPage(..., crumb: 'বেতন ও পেমেন্ট', onCrumb: () => context.pop(), title: 'রসিদের টেমপ্লেট', child: ...)

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

/// One entry of the settings section nav.
class BhorSettingsSection {
  const BhorSettingsSection({required this.id, required this.label, required this.icon, this.badge});

  final String id;
  final String label;
  final IconData icon;

  /// Short trailing text ("৩"); null hides it.
  final String? badge;
}

class BhorSettingsPage extends StatelessWidget {
  const BhorSettingsPage({
    super.key,
    required this.sections,
    required this.selected,
    required this.onSelect,
    required this.title,
    required this.child,
    this.subtitle,
    this.crumb,
    this.onCrumb,
    this.actions = const <Widget>[],
    this.scrollable = true,
  });

  static const double navWidth = 240;
  static const double contentMaxWidth = 720;

  /// The nav shows from this pane width up.
  static const double navMinWidth = 720;

  static const Key navKey = Key('bhor-settings-nav');
  static const Key contentKey = Key('bhor-settings-content');
  static const Key crumbKey = Key('bhor-settings-crumb');

  final List<BhorSettingsSection> sections;

  /// Id of the section shown (highlighted in the nav).
  final String selected;
  final ValueChanged<String> onSelect;

  /// Title of the section / sub-page.
  final String title;
  final String? subtitle;

  /// Parent section of a sub-page: shows "‹ [crumb]" above the title.
  final String? crumb;

  /// Crumb tap; default pops the route.
  final VoidCallback? onCrumb;
  final List<Widget> actions;

  /// The content column scrolls (false: [child] scrolls itself and gets
  /// the remaining height).
  final bool scrollable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BhorScaffold(
      wash: false,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final bool wide = box.maxWidth >= navMinWidth;
          final Widget content = KeyedSubtree(key: contentKey, child: _content(context, wide));
          if (!wide) return content;
          final BhorColors c = context.bhor.colors;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: navWidth, child: _Nav(sections: sections, selected: selected, onSelect: onSelect)),
              SizedBox(width: 1, child: ColoredBox(color: c.line)),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, bool wide) {
    final BhorThemeData b = context.bhor;
    final double gutter = wide ? BhorSpace.screenDesktop : BhorSpace.screenPhone;
    final Widget head = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (crumb != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _Crumb(
              key: crumbKey,
              label: crumb!,
              onTap: onCrumb ?? () => Navigator.of(context).maybePop(),
            ),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: b.type.title),
                  ),
                  if (subtitle != null) Text(subtitle!, style: b.type.meta),
                ],
              ),
            ),
            for (final Widget a in actions) ...<Widget>[const SizedBox(width: BhorSpace.s8), a],
          ],
        ),
        const SizedBox(height: BhorSpace.s16),
      ],
    );
    final EdgeInsets pad = EdgeInsets.fromLTRB(gutter, wide ? BhorSpace.s24 : BhorSpace.s12, gutter, BhorSpace.s24);
    Widget column(Widget body) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: contentMaxWidth), child: body),
        );
    if (scrollable) {
      return SingleChildScrollView(
        padding: pad,
        child: column(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[head, child],
        )),
      );
    }
    return Padding(
      padding: pad.copyWith(bottom: 0),
      child: column(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[head, Expanded(child: child)],
      )),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: BhorSpace.s4),
      child: BhorPressable(
        onTap: onTap,
        semanticLabel: '${context.l10n.commonBack}, $label',
        excludeChildSemantics: true,
        scaleOnPress: false,
        radius: 10,
        builder: (BuildContext context, BhorStates s) => AnimatedContainer(
          duration: BhorMotion.of(context, BhorMotion.instant),
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.fromLTRB(BhorSpace.s4, 0, BhorSpace.s12, 0),
          decoration: BoxDecoration(
            color: s.hovered || s.pressed ? c.accentTint : c.accentTint.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(BhorIcons.chevronLeft, size: BhorIconSize.chip, color: c.accent),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: b.type.label.copyWith(color: c.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.sections, required this.selected, required this.onSelect});

  final List<BhorSettingsSection> sections;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Semantics(
      key: BhorSettingsPage.navKey,
      container: true,
      explicitChildNodes: true,
      label: context.l10n.layoutSettingsSections,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(BhorSpace.s12, BhorSpace.s24, BhorSpace.s12, BhorSpace.s24),
        children: <Widget>[
          for (final BhorSettingsSection sec in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: BhorPressable(
                onTap: () => onSelect(sec.id),
                selected: sec.id == selected,
                semanticLabel: sec.badge == null ? sec.label : '${sec.label}, ${sec.badge}',
                excludeChildSemantics: true,
                scaleOnPress: false,
                radius: BhorRadius.sidebarItem,
                builder: (BuildContext context, BhorStates s) {
                  final bool sel = sec.id == selected;
                  return AnimatedContainer(
                    duration: BhorMotion.of(context, BhorMotion.fast),
                    curve: BhorMotion.ease,
                    height: 40,
                    decoration: BoxDecoration(
                      color: sel
                          ? c.accentTint
                          : (s.hovered || s.pressed ? c.soft : c.soft.withValues(alpha: 0)),
                      borderRadius: BorderRadius.circular(BhorRadius.sidebarItem),
                    ),
                    child: Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: <Widget>[
                        Positioned.fill(child: BhorSelectionBar(selected: sel, inset: BhorSpace.s8)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
                          child: Row(
                            children: <Widget>[
                              Icon(sec.icon, size: BhorIconSize.row, color: sel ? c.accent : c.text2),
                              const SizedBox(width: BhorSpace.s12),
                              Expanded(
                                child: Text(
                                  sec.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: (sel ? b.type.bodyStrong : b.type.body).copyWith(color: c.text),
                                ),
                              ),
                              if (sec.badge != null)
                                Text(sec.badge!, style: BhorType.tabular(b.type.caption.copyWith(color: c.text3))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
