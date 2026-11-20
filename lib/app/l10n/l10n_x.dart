import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Short access to localisation from any widget (plan section 2.8).
extension L10nX on BuildContext {
  /// Generated strings for the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// The current app language; anything but `en` is Bangla.
  Lang get lang => Lang.fromCode(Localizations.localeOf(this).languageCode);

  /// Numbers, money, dates and times for the current language.
  AppFormat get fmt => AppFormat(lang);
}
