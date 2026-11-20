// Result rows and the preview pane of the search screen.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/features/search/controllers/search_engine.dart';

/// The phone to show under a result when the query looks like a phone number
/// (so the teacher sees why it matched); null otherwise.
String? matchedPhone(StudentEntry e, String rawQuery) {
  final String q = searchNorm(rawQuery);
  final String digits = searchDigits(q);
  if (digits.length < kSearchMinPhoneDigits ||
      !RegExp(r'^[0-9+\-\s]+$').hasMatch(q)) {
    return null;
  }
  for (final String? p in <String?>[e.student.guardianPhone, e.student.phone]) {
    if (p != null && searchDigits(p).contains(digits)) return p;
  }
  return null;
}

class SearchStudentTile extends StatelessWidget {
  const SearchStudentTile({
    super.key,
    required this.entry,
    required this.query,
    required this.selected,
    required this.onTap,
  });

  final StudentEntry entry;
  final String query;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final TextTheme tt = Theme.of(context).textTheme;
    final String? roll = entry.student.roll;
    final String? phone = matchedPhone(entry, query);
    final List<String> sub = <String>[
      if (phone != null) context.fmt.digits(phone),
      if (entry.left) l10n.searchLeftTag,
      if (entry.batchNames.isNotEmpty) entry.batchNames.join(' · '),
    ];
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: Material(
        color: selected ? tokens.accentContainer : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: tokens.track,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  InitialsAvatar(name: entry.student.name, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          roll == null || roll.isEmpty
                              ? entry.student.name
                              : '${context.fmt.digits(roll)} · ${entry.student.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium
                              ?.copyWith(color: tokens.textPrimary),
                        ),
                        if (sub.isNotEmpty)
                          Text(
                            sub.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelMedium
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tokens.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SearchBatchTile extends StatelessWidget {
  const SearchBatchTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final BatchEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String count =
        context.l10n.searchBatchStudents(context.fmt.digits('${entry.studentCount}'));
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: Material(
        color: selected ? tokens.accentContainer : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: tokens.track,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: tokens.avatarBg,
                    child: Icon(Icons.groups_outlined, color: tokens.avatarText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          entry.batch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium
                              ?.copyWith(color: tokens.textPrimary),
                        ),
                        Text(
                          <String>[
                            if (entry.subjectName.isNotEmpty) entry.subjectName,
                            count,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelMedium
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tokens.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: tt.bodyLarge?.copyWith(color: tokens.textPrimary)),
        ],
      ),
    );
  }
}

/// Desktop preview of the highlighted result: header block, facts, open button.
class SearchPreview extends StatelessWidget {
  const SearchPreview({
    super.key,
    this.student,
    this.batch,
    required this.onOpen,
  }) : assert((student == null) != (batch == null));

  final StudentEntry? student;
  final BatchEntry? batch;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final StudentEntry? s = student;
    final BatchEntry? b = batch;

    final String title = s?.student.name ?? b!.batch.name;
    final String? roll = s?.student.roll;
    final String headSub = <String>[
      if (roll != null && roll.isNotEmpty) l10n.searchRollLabel(fmt.digits(roll)),
      if (s != null && s.left) l10n.searchLeftTag,
    ].join(' · ');
    final List<Widget> facts = <Widget>[];
    if (s != null) {
      final String? gName = s.student.guardianName;
      final String? gPhone = s.student.guardianPhone;
      final String? sPhone = s.student.phone;
      facts
        ..add(_Fact(
          label: l10n.searchBatchesLabel,
          value: s.batchNames.isEmpty
              ? l10n.searchNoBatch
              : s.batchNames.join(' · '),
        ))
        ..addAll(<Widget>[
          if (gName != null && gName.isNotEmpty)
            _Fact(label: l10n.searchGuardianName, value: gName),
          if (gPhone != null && gPhone.isNotEmpty)
            _Fact(label: l10n.searchGuardianPhone, value: fmt.digits(gPhone)),
          if (sPhone != null && sPhone.isNotEmpty)
            _Fact(label: l10n.searchStudentPhone, value: fmt.digits(sPhone)),
        ]);
    } else {
      facts
        ..add(_Fact(
            label: l10n.searchSubjectLabel,
            value: b!.subjectName.isEmpty ? '—' : b.subjectName))
        ..add(_Fact(
            label: l10n.searchGroupStudents,
            value: l10n.searchBatchStudents(fmt.digits('${b.studentCount}'))));
    }

    return GlassCard(
      dense: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(color: tokens.accentContainer),
            child: Row(
              children: <Widget>[
                if (s != null)
                  InitialsAvatar(name: s.student.name, size: 72)
                else
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: tokens.avatarBg,
                    child: Icon(Icons.groups_outlined,
                        size: 36, color: tokens.avatarText),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.headlineSmall
                            ?.copyWith(color: tokens.onAccentContainer),
                      ),
                      if (headSub.isNotEmpty)
                        Text(
                          headSub,
                          style: tt.titleSmall
                              ?.copyWith(color: tokens.onAccentContainer),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              children: facts,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              key: const ValueKey<String>('search-open'),
              onPressed: onOpen,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(s != null ? Icons.person_outline : Icons.groups_outlined),
              label: Text(s != null ? l10n.searchOpenStudent : l10n.searchOpenBatch),
            ),
          ),
        ],
      ),
    );
  }
}
