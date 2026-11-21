// Initials avatar (UX 4 Components): first grapheme cluster of each of the
// first two words, so a Bangla conjunct or vowel sign is never split.
// Colours are avatarBg / avatarText only, never a severity or attendance hue.

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';

/// "Rakib Hasan" -> "RH", "রাকিব হাসান" -> "রাহা", single word -> its first grapheme.
String initialsOf(String name) {
  final List<String> words =
      name.trim().split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final StringBuffer b = StringBuffer();
  for (final String w in words.take(2)) {
    b.write(w.characters.first);
  }
  return b.toString().toUpperCase();
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 40, this.background, this.foreground});

  final String name;
  final double size;

  /// Overrides for a coloured row (e.g. the roll-call slab); default tokens.
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final double fontSize = (size * 0.38).clamp(12.0, 28.0);
    // Decorative: the person's name always sits next to the avatar.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background ?? tokens.avatarBg, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          maxLines: 1,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground ?? tokens.avatarText,
                fontSize: fontSize,
                height: 1.2,
              ),
        ),
      ),
    );
  }
}
