// Money figure where the taka sign is a separate, smaller, lighter span so it
// can never be misread as the digit ৬ (QA-02). Plain text equals the input.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow,
    this.textAlign,
  });

  /// Already formatted with `fmt.money`.
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final int at = text.indexOf('৳');
    if (at < 0) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }
    final TextStyle base = DefaultTextStyle.of(context).style.merge(style);
    final double size = base.fontSize ?? 14;
    final TextStyle sign = TextStyle(
      fontSize: size * 0.7,
      fontWeight: FontWeight.w400,
      color: context.aurora.textSecondary,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          if (at > 0) TextSpan(text: text.substring(0, at)),
          TextSpan(text: '৳', style: sign),
          TextSpan(text: text.substring(at + 1)),
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
