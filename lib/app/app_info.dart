// App identity constants (docs/council/04-plan.md, M0-A contract; section 1 #36).
//
// Display names are labels only and may be renamed before release. The
// package name, applicationId, AUMID and toast GUID must never change after
// the first install (upgrades would break and local data would be orphaned).

/// Bangla display name. Must equal the bn `commonAppTitle` ARB value.
const kAppDisplayNameBn = 'হাজিরা খাতা';

/// Latin display name. Must equal the en `commonAppTitle` ARB value.
const kAppDisplayNameLatin = 'Hajira Khata';

/// Windows AppUserModelID used for toast notifications.
const kWindowsAumid = 'ImRudra.AttendanceAlamin';

/// Windows toast activator CLSID (flutter_local_notifications Windows settings).
const kWindowsToastGuid = '1e797322-5c87-4fef-8348-609333181532';
