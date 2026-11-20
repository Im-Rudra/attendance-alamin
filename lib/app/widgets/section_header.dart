// Section header: title (semantics header) with an optional trailing widget.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: tokens.textPrimary),
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
