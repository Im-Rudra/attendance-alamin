// Share plain text (dues reminders, receipts, cancel notices) through the
// system share sheet (share_plus). Windows and web also copy the text and say
// so (a BhorToast), because a desktop share target is often missing; a desktop
// browser has no share sheet at all (share_plus would open a mail client), so
// there the copy is the whole action.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

abstract final class ShareService {
  static bool get _isMobilePlatform =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  /// Copy as well as share (web and Windows).
  static bool get _alsoCopy => kIsWeb || defaultTargetPlatform == TargetPlatform.windows;

  /// Open the share sheet at all (not on desktop browsers).
  static bool get _openSheet => !kIsWeb || _isMobilePlatform;

  /// Shares [text]; whenever the share API is missing or fails, the text is
  /// copied and the teacher is told so, so a tap always gives feedback (QA-06).
  static Future<void> shareText(BuildContext context, String text) async {
    if (text.trim().isEmpty) return;
    // Read before any await: the caller (often a sheet) may be gone by then.
    final BuildContext anchor = BhorToast.anchorOf(context);
    final double lift = BhorToastInset.of(context);
    final String copiedMessage = context.l10n.shellTextCopied;

    Future<void> copy() async {
      try {
        await Clipboard.setData(ClipboardData(text: text));
      } catch (_) {
        // Still tell the teacher: the toast below is the feedback.
      }
      if (anchor.mounted) BhorToast.show(anchor, message: copiedMessage, bottomOffset: lift);
    }

    if (_alsoCopy) await copy();
    if (!_openSheet) return;
    try {
      final ShareResult result = await SharePlus.instance.share(ShareParams(text: text));
      if (!_alsoCopy && result.status == ShareResultStatus.unavailable) await copy();
    } catch (_) {
      if (!_alsoCopy) await copy();
    }
  }
}
