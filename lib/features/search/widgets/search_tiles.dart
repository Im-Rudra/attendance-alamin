// Result rows and the preview pane of the search screen.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
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
    final l10n = context.l10n;
    final String? roll = entry.student.roll;
    final String? phone = matchedPhone(entry, query);
    final List<String> sub = <String>[
      if (phone != null) context.fmt.digits(phone),
      if (entry.left) l10n.searchLeftTag,
      if (entry.batchNames.isNotEmpty) entry.batchNames.join(' · '),
    ];
    return Semantics(
      container: true,
      selected: selected,
      child: BhorListRow(
        leading: BhorAvatar(name: entry.student.name, size: 40),
        title: roll == null || roll.isEmpty
            ? entry.student.name
            : '${context.fmt.digits(roll)} · ${entry.student.name}',
        subtitle: sub.isEmpty ? null : sub.join(' · '),
        trailing: Icon(BhorIcons.chevronRight, color: context.bhor.colors.text3),
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}

/// Round batch glyph used where a student would show an avatar.
class _BatchGlyph extends StatelessWidget {
  const _BatchGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
      child: Icon(BhorIcons.batches, size: size / 2, color: c.accent),
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
    final String count =
        context.l10n.searchBatchStudents(context.fmt.digits('${entry.studentCount}'));
    return Semantics(
      container: true,
      selected: selected,
      child: BhorListRow(
        leading: const _BatchGlyph(size: 40),
        title: entry.batch.name,
        subtitle: <String>[
          if (entry.subjectName.isNotEmpty) entry.subjectName,
          count,
        ].join(' · '),
        trailing: Icon(BhorIcons.chevronRight, color: context.bhor.colors.text3),
        selected: selected,
        onTap: onTap,
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
    final BhorThemeData b = context.bhor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BhorSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: b.type.meta),
          const SizedBox(height: 2),
          Text(value, style: b.type.body),
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
    final BhorThemeData b0 = context.bhor;
    final BhorColors c = b0.colors;
    final l10n = context.l10n;
    final fmt = context.fmt;
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

    return BhorCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BhorRadius.card - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(BhorSpace.s24, 28, BhorSpace.s24, BhorSpace.s24),
              decoration: BoxDecoration(color: c.accentTint),
              child: Row(
                children: <Widget>[
                  if (s != null) BhorAvatar(name: s.student.name, size: 72) else const _BatchGlyph(size: 72),
                  const SizedBox(width: BhorSpace.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: b0.type.title,
                        ),
                        if (headSub.isNotEmpty) Text(headSub, style: b0.type.meta.copyWith(color: c.text2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(BhorSpace.s24, BhorSpace.s12, BhorSpace.s24, BhorSpace.s12),
                children: facts,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BhorSpace.s16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: BhorButton(
                  key: const ValueKey<String>('search-open'),
                  onPressed: onOpen,
                  icon: s != null ? BhorIcons.user : BhorIcons.batches,
                  label: s != null ? l10n.searchOpenStudent : l10n.searchOpenBatch,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
