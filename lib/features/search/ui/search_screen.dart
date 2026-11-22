// SearchScreen (UX 3 "Search", review G4): global find reached from the sidebar
// search field, Ctrl+F or Ctrl+K. Results appear as you type, grouped into
// students and batches; the filter is pure in-memory work over the repository
// streams. Phones: one full-page list. Wide windows: a command palette (a
// scrim plus a centred 720 card, results || preview) over the current page; its
// route is transparent (see the router) so the page below stays visible. Esc or
// a click on the scrim closes it. Tap/Enter opens the profile or batch; the
// query is remembered in the recent list (LocalMeta search_recent).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/search/controllers/search_engine.dart';
import 'package:attendance_alamin/features/search/controllers/search_providers.dart';
import 'package:attendance_alamin/features/search/widgets/search_tiles.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// `s:<studentId>` or `b:<batchId>`; null = follow the first result.
  String? _selected;

  SearchIndex? _cachedIndex;
  String _cachedQuery = '';
  SearchResults _cachedResults = const SearchResults();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onEscape);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onEscape);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Esc anywhere on the page (not only in the field): with text it clears
  /// the query, with an empty query it closes search. Ignored while a
  /// popup is open above the page (it closes only the top-most layer).
  bool _onEscape(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape || !mounted) return false;
    if (bhorOverlayAbove(context)) return false;
    // The desktop palette: Esc closes it. Phones: first clear the query.
    if (_text.text.isNotEmpty && !context.bhorIsWide) {
      _setQuery('');
    } else {
      _close();
    }
    return true;
  }

  SearchResults _results(SearchIndex index) {
    final String q = _text.text;
    if (!identical(index, _cachedIndex) || q != _cachedQuery) {
      _cachedIndex = index;
      _cachedQuery = q;
      _cachedResults = runSearch(index, q);
    }
    return _cachedResults;
  }

  static List<String> _keys(SearchResults r) => <String>[
        for (final StudentEntry e in r.students) 's:${e.id}',
        for (final BatchEntry e in r.batches) 'b:${e.id}',
      ];

  String? _effective(SearchResults r) {
    final List<String> keys = _keys(r);
    if (keys.isEmpty) return null;
    return keys.contains(_selected) ? _selected : keys.first;
  }

  void _move(SearchResults r, int delta) {
    final List<String> keys = _keys(r);
    if (keys.isEmpty) return;
    final int i = keys.indexOf(_effective(r)!);
    setState(() => _selected = keys[(i + delta).clamp(0, keys.length - 1)]);
  }

  void _setQuery(String q) {
    _text.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    setState(() => _selected = null);
    _focus.requestFocus();
  }

  void _close() {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.today);
    }
  }

  void _open(String key) {
    final String q = _text.text.trim();
    if (q.isNotEmpty) ref.read(recentSearchesProvider.notifier).add(q);
    final String id = key.substring(2);
    final String path = key.startsWith('s:') ? Routes.student(id) : Routes.batch(id);
    GoRouter.maybeOf(context)?.go(path);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, SearchResults r) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(r, 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(r, -1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final WindowClass wc = WindowClass.of(context);
    final bool wide = wc.isWide;
    final double g = wc.gutter;
    final AsyncValue<SearchIndex> async = ref.watch(searchIndexProvider);
    final List<String> recent = ref.watch(recentSearchesProvider);

    final SearchIndex? index = async.value;
    final SearchResults results =
        index == null ? const SearchResults() : _results(index);
    final String? effective = _effective(results);
    final bool hasQuery = _text.text.trim().isNotEmpty;

    final Widget field = Focus(
      onKeyEvent: (FocusNode n, KeyEvent e) => _onKey(n, e, results),
      child: BhorTextField(
        key: const ValueKey<String>('search-field'),
        controller: _text,
        focusNode: _focus,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (String _) => setState(() => _selected = null),
        onSubmitted: (String _) {
          final String? key = wide ? effective : _keys(results).firstOrNull;
          if (key != null) {
            _open(key);
          } else if (_text.text.trim().isNotEmpty) {
            ref.read(recentSearchesProvider.notifier).add(_text.text);
          }
        },
        prefix: const Icon(BhorIcons.search),
        hint: l10n.searchHint,
        semanticLabel: l10n.searchHint,
        suffix: _text.text.isEmpty
            ? null
            : BhorPressable(
                key: const ValueKey<String>('search-clear'),
                onTap: () => _setQuery(''),
                semanticLabel: l10n.searchClearField,
                excludeChildSemantics: true,
                builder: (BuildContext context, BhorStates st) => const SizedBox.square(
                  dimension: 28,
                  child: Center(child: Icon(BhorIcons.close)),
                ),
              ),
      ),
    );

    Widget listPane;
    if (async.hasError && index == null) {
      listPane = _EmptyCard(
        child: BhorEmptyState(icon: BhorIcons.warning, title: l10n.searchLoadFailed),
      );
    } else if (index == null) {
      listPane = const Center(child: BhorSpinner(size: 28));
    } else if (!hasQuery) {
      listPane = recent.isEmpty
          ? const _StartState()
          : _RecentList(
              recent: recent,
              onPick: _setQuery,
              onClear: () => ref.read(recentSearchesProvider.notifier).clear(),
            );
    } else if (results.isEmpty) {
      listPane = _EmptyCard(
        child: BhorEmptyState(
          icon: BhorIcons.search,
          title: l10n.searchNoResult(_text.text.trim()),
          action: BhorButton(
            label: l10n.searchAddStudent,
            onPressed: () => GoRouter.maybeOf(context)?.push(Routes.studentNew),
          ),
        ),
      );
    } else {
      listPane = _ResultList(
        results: results,
        query: _text.text,
        selected: wide ? effective : null,
        onTap: (String key) {
          if (wide) {
            setState(() => _selected = key);
          } else {
            _open(key);
          }
        },
      );
    }

    Widget preview;
    if (effective == null) {
      preview = _EmptyCard(
        child: BhorEmptyState(
          icon: BhorIcons.search,
          title: hasQuery && index != null
              ? l10n.searchPreviewHint
              : l10n.searchPreviewTyping,
        ),
      );
    } else {
      final String id = effective.substring(2);
      StudentEntry? s;
      BatchEntry? b;
      if (effective.startsWith('s:')) {
        s = results.students.firstWhere((StudentEntry e) => e.id == id);
      } else {
        b = results.batches.firstWhere((BatchEntry e) => e.id == id);
      }
      preview = SearchPreview(
        key: ValueKey<String>('search-preview-$effective'),
        student: s,
        batch: b,
        onOpen: () => _open(effective),
      );
    }

    final Widget header = Padding(
      padding: EdgeInsets.fromLTRB(BhorSpace.s8, BhorSpace.s8, wide ? BhorSpace.s16 : g, BhorSpace.s8),
      child: Row(
        children: <Widget>[
          BhorIconButton(
            icon: BhorIcons.close,
            semanticLabel: l10n.commonClose,
            color: context.bhor.colors.text,
            onPressed: _close,
          ),
          const SizedBox(width: BhorSpace.s4),
          Expanded(child: field),
        ],
      ),
    );
    final Widget body = wide
        // The preview only appears once there is something to preview, so the
        // palette never shows two empty states side by side.
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: 5, child: listPane),
              if (effective != null) ...<Widget>[
                const SizedBox(width: BhorSpace.s12),
                Expanded(flex: 4, child: BhorPaneSwitcher(paneKey: effective, child: preview)),
              ],
            ],
          )
        : listPane;

    if (!wide) {
      return BhorScaffold(
        header: header,
        body: Padding(padding: EdgeInsets.fromLTRB(g, 0, g, g), child: body),
      );
    }
    // Desktop (G4): a command palette over the current page. The route is
    // transparent (see the router), so the page below shows through a scrim;
    // a click on the scrim or Esc closes it, Up / Down move through the
    // results, Enter opens.
    final BhorThemeData th = context.bhor;
    final BhorColors c = th.colors;
    return DefaultTextStyle(
      style: th.type.body,
      child: IconTheme(
        data: IconThemeData(color: c.text2, size: 22),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            // A 720-wide palette, 12% down from the top of the window.
            final double top = box.maxHeight * 0.12;
            double height = box.maxHeight - top - g;
            if (height > 560) height = 560;
            if (height < 320) height = 320;
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('search-scrim'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: ColoredBox(color: c.scrim),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(g, top, g, g),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: SizedBox(
                        height: height,
                        child: DecoratedBox(
                          key: const Key('search-palette'),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(BhorRadius.hero),
                            border: Border.all(color: c.line),
                            boxShadow: c.floatShadow,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(BhorRadius.hero),
                            child: Column(
                              children: <Widget>[
                                header,
                                Container(height: 1, color: c.line),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(BhorSpace.s16),
                                    child: body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A card that centres an empty / message state.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BhorCard(
        padding: EdgeInsets.zero,
        child: Center(child: SingleChildScrollView(child: child)),
      );
}

class _StartState extends StatelessWidget {
  const _StartState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _EmptyCard(
      child: BhorEmptyState(
        icon: BhorIcons.search,
        title: l10n.searchStartTitle,
        message: l10n.searchStartHelp,
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.recent,
    required this.onPick,
    required this.onClear,
  });

  final List<String> recent;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    return BhorCard(
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.only(bottom: BhorSpace.s16),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s8, BhorSpace.s8, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.searchRecentTitle, style: b.type.heading),
                  ),
                ),
                BhorButton(
                  key: const ValueKey<String>('search-clear-recent'),
                  label: l10n.searchClearRecent,
                  variant: BhorButtonVariant.ghost,
                  size: BhorButtonSize.sm,
                  onPressed: onClear,
                ),
              ],
            ),
          ),
          for (final String r in recent)
            BhorListRow(
              key: ValueKey<String>('search-recent-$r'),
              leading: Icon(BhorIcons.clock, color: b.colors.text3),
              title: r,
              trailing: Icon(BhorIcons.arrowRight, size: 18, color: b.colors.text3),
              onTap: () => onPick(r),
            ),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.results,
    required this.query,
    required this.selected,
    required this.onTap,
  });

  final SearchResults results;
  final String query;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Semantics(
            header: true,
            child: Text(text, style: b.type.label.copyWith(color: b.colors.accent)),
          ),
        );

    int i = 0;
    final List<Widget> children = <Widget>[
      if (results.students.isNotEmpty) ...<Widget>[
        header(l10n.searchGroupStudents),
        for (final StudentEntry e in results.students)
          BhorStagger(
            key: ValueKey<String>('search-student-${e.id}'),
            index: i++,
            child: SearchStudentTile(
              entry: e,
              query: query,
              selected: selected == 's:${e.id}',
              onTap: () => onTap('s:${e.id}'),
            ),
          ),
      ],
      if (results.batches.isNotEmpty) ...<Widget>[
        header(l10n.searchGroupBatches),
        for (final BatchEntry e in results.batches)
          BhorStagger(
            key: ValueKey<String>('search-batch-${e.id}'),
            index: i++,
            child: SearchBatchTile(
              entry: e,
              selected: selected == 'b:${e.id}',
              onTap: () => onTap('b:${e.id}'),
            ),
          ),
      ],
    ];
    return BhorStaggerScope(
      child: BhorCard(
        padding: EdgeInsets.zero,
        child: ListView(
          padding: const EdgeInsets.only(bottom: BhorSpace.s16),
          children: children,
        ),
      ),
    );
  }
}
