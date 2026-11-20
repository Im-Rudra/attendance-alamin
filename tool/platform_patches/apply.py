#!/usr/bin/env python3
"""Idempotent platform patcher for the `flutter create` output (module M0-B).

Run from the repo root right after
    flutter create --org com.imrudra --project-name attendance_alamin \
        --platforms=android,windows,web .
on Flutter 3.47.9. It applies the platform edits required by
docs/council/02-architecture.md section 4B and docs/council/04-plan.md M0-B:

Android
  settings.gradle.kts           AGP >= 9.1.1 (flutter_local_notifications 23 needs it)
  gradle-wrapper.properties     Gradle >= 9.3.1 (AGP 9.1 minimum; template already has it)
  app/build.gradle.kts          compileSdk >= 37, core library desugaring
                                (desugar_jdk_libs 2.1.4), multiDexEnabled, release
                                signing from android/key.properties else the debug key
  app/src/main/AndroidManifest.xml
                                android:label, notification permissions (never
                                USE_EXACT_ALARM), the three plugin receivers
  res/drawable/ic_stat_class.png  96x96 white glyph on transparent (generated here)
  res/raw/keep.xml              keeps ic_stat_class through release resource shrinking
Windows
  runner/main.cpp               window title "Hajira Khata", initial size 1280x800
  runner/win32_window.cpp       WM_GETMINMAXINFO: minimum client area 960x600 (DPI scaled)
  runner/Runner.rc              ProductName / FileDescription
Web
  index.html                    <title>, description, apple title, theme-color
  manifest.json                 name, short_name, description, colours

android/key.properties (written by CI from secrets, never committed) uses the
standard Flutter keys, with storeFile resolved relative to android/app/:
    storeFile=upload.jks
    storePassword=...
    keyAlias=...
    keyPassword=...

Every edit is anchored. A missing or ambiguous anchor aborts the whole run before
anything is written, naming the file and the anchor. Edits are detected as already
applied, so a second run changes nothing.

Usage
    python3 tool/platform_patches/apply.py [--root DIR]     apply the edits
    python3 tool/platform_patches/apply.py --verify         exit 1 if any edit would
                                                            change a file (lists them)
Exit codes: 0 ok / nothing to change, 1 --verify found drift, 2 anchor or input error.

Stdlib only, Python 3.10+. Files are read and written as UTF-8 (a BOM is kept only
if the file already had one) and keep their original line endings.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

# ---------------------------------------------------------------------------
# Values (contract: 02-architecture.md 4B / 6.3, 03-ux.md, 04-plan.md M0-B)
# ---------------------------------------------------------------------------

AGP_MIN = "9.1.1"
GRADLE_MIN = "9.3.1"
COMPILE_SDK_MIN = 37
DESUGAR_COORD = "com.android.tools:desugar_jdk_libs"
DESUGAR_MIN = "2.1.4"

APP_LABEL_BN = "হাজিরা খাতা"
APP_NAME_LATIN = "Hajira Khata"
WEB_DESCRIPTION = "হাজিরা খাতা — কোচিং সেন্টারের হাজিরা, ক্লাস রুটিন ও বেতনের হিসাব"
WEB_THEME_COLOR = "#0A0C12"

WINDOW_SIZE = (1280, 800)
WINDOW_MIN_CLIENT = (960, 600)

NOTIFICATION_PERMISSIONS = (
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.VIBRATE",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.SCHEDULE_EXACT_ALARM",
)
FORBIDDEN_PERMISSIONS = ("android.permission.USE_EXACT_ALARM",)
FLN_PKG = "com.dexterous.flutterlocalnotifications"
BOOT_ACTIONS = (
    "android.intent.action.BOOT_COMPLETED",
    "android.intent.action.MY_PACKAGE_REPLACED",
    "android.intent.action.QUICKBOOT_POWERON",
    "com.htc.intent.action.QUICKBOOT_POWERON",
)

ANDROID_NS = "http://schemas.android.com/apk/res/android"

# ---------------------------------------------------------------------------
# Errors and small helpers
# ---------------------------------------------------------------------------


class PatchError(Exception):
    """An anchor is missing/ambiguous or a file is in a state we refuse to patch."""


def _fail(rel: str, message: str) -> PatchError:
    return PatchError(f"{rel}: {message}")


def _version_tuple(v: str) -> tuple[int, ...]:
    parts = re.findall(r"\d+", v)
    return tuple(int(p) for p in parts)


def _version_lt(a: str, b: str) -> bool:
    ta, tb = _version_tuple(a), _version_tuple(b)
    n = max(len(ta), len(tb))
    return ta + (0,) * (n - len(ta)) < tb + (0,) * (n - len(tb))


def _one(rel: str, text: str, pattern: str, what: str, flags: int = re.M) -> re.Match[str]:
    """Return the single match of `pattern`; fail loudly on none or several."""
    matches = list(re.finditer(pattern, text, flags))
    if not matches:
        raise _fail(rel, f"anchor not found: {what}  (regex: {pattern})")
    if len(matches) > 1:
        raise _fail(rel, f"anchor is ambiguous ({len(matches)} matches): {what}  (regex: {pattern})")
    return matches[0]


def _splice(text: str, start: int, end: int, new: str) -> str:
    return text[:start] + new + text[end:]


def _line_start(text: str, pos: int) -> int:
    return text.rfind("\n", 0, pos) + 1


def _line_end(text: str, pos: int) -> int:
    nl = text.find("\n", pos)
    return len(text) if nl < 0 else nl + 1


def _indent_block(block: str, indent: str) -> str:
    return "".join((indent + line if line.strip() else line) for line in block.splitlines(keepends=True))


# ---------------------------------------------------------------------------
# Android: android/settings.gradle.kts
# ---------------------------------------------------------------------------


def patch_settings_gradle(text: str, rel: str) -> str:
    m = _one(
        rel,
        text,
        r'id\("com\.android\.application"\)\s+version\s+"(?P<v>[^"]+)"',
        'plugins { id("com.android.application") version "..." }',
    )
    if _version_lt(m["v"], AGP_MIN):
        text = _splice(text, m.start("v"), m.end("v"), AGP_MIN)
    return text


# ---------------------------------------------------------------------------
# Android: android/gradle/wrapper/gradle-wrapper.properties
# ---------------------------------------------------------------------------


def patch_gradle_wrapper(text: str, rel: str) -> str:
    m = _one(
        rel,
        text,
        r"^distributionUrl=.*/gradle-(?P<v>[0-9][0-9.]*)-(?:all|bin)\.zip\s*$",
        "distributionUrl=...gradle-<version>-all.zip",
    )
    if _version_lt(m["v"], GRADLE_MIN):
        text = _splice(text, m.start("v"), m.end("v"), GRADLE_MIN)
    return text


# ---------------------------------------------------------------------------
# Android: android/app/build.gradle.kts
# ---------------------------------------------------------------------------

_SIGNING_PREAMBLE = """\
// Release signing (added by tool/platform_patches/apply.py). CI writes android/key.properties
// (storeFile, storePassword, keyAlias, keyPassword) from repo secrets; without it, release
// builds fall back to the debug key so `flutter build apk --release` still works.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

"""

# In build.gradle.kts, a bare `java` resolves to the project's `java {}` extension,
# so `java.util.Properties()` does not compile: import the classes at the top instead.
_SIGNING_IMPORTS = "import java.io.FileInputStream\nimport java.util.Properties\n\n"
_OLD_PREAMBLE_FIXES = (
    ("val keystoreProperties = java.util.Properties()", "val keystoreProperties = Properties()"),
    (
        "keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }",
        "FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }",
    ),
)

_SIGNING_CONFIGS = """\
signingConfigs {
    if (hasReleaseKeystore) {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
}

"""

_RELEASE_COMMENT = "// Release key from android/key.properties when present, else the debug key (apply.py).\n"
_RELEASE_SIGNING = (
    'signingConfig = if (hasReleaseKeystore) signingConfigs.getByName("release") '
    'else signingConfigs.getByName("debug")'
)


def _insert_after_block_open(text: str, rel: str, block: str, line: str, done_re: str) -> str:
    """Insert `line` as the first statement of `<block> {` unless `done_re` matches."""
    if re.search(done_re, text, re.M):
        return text
    m = _one(rel, text, rf"^(?P<i>[ \t]*){re.escape(block)}\s*\{{[ \t]*\n", f"{block} {{")
    indent = m["i"] + "    "
    return _splice(text, m.end(), m.end(), f"{indent}{line}\n")


def patch_app_gradle(text: str, rel: str) -> str:
    # 0. imports for the signing preamble (must precede `plugins {`).
    for old, new in _OLD_PREAMBLE_FIXES:
        text = text.replace(old, new)
    if not re.search(r"^import java\.util\.Properties[ \t]*$", text, re.M):
        text = _SIGNING_IMPORTS + text

    # 1. keystore preamble, top level, right before `android {`.
    if "val hasReleaseKeystore" not in text:
        m = _one(rel, text, r"^android\s*\{", "top-level `android {` block")
        text = _splice(text, m.start(), m.start(), _SIGNING_PREAMBLE)

    # 2. compileSdk >= 37 (template: `compileSdk = flutter.compileSdkVersion`).
    m = _one(rel, text, r"^(?P<i>[ \t]+)compileSdk\s*=\s*(?P<v>[^\n]*?)[ \t]*$", "compileSdk = ...")
    value = m["v"].strip()
    if not (value.isdigit() and int(value) >= COMPILE_SDK_MIN):
        text = _splice(text, m.start("v"), m.end("v"), str(COMPILE_SDK_MIN))

    # 3. core library desugaring flag inside compileOptions.
    m_false = re.search(r"^([ \t]*)isCoreLibraryDesugaringEnabled\s*=\s*false[ \t]*$", text, re.M)
    if m_false:
        text = _splice(text, m_false.start(), m_false.end(), f"{m_false.group(1)}isCoreLibraryDesugaringEnabled = true")
    text = _insert_after_block_open(
        text,
        rel,
        "compileOptions",
        "isCoreLibraryDesugaringEnabled = true",
        r"^[ \t]*isCoreLibraryDesugaringEnabled\s*=\s*true[ \t]*$",
    )

    # 4. multidex inside defaultConfig.
    m_false = re.search(r"^([ \t]*)multiDexEnabled\s*=\s*false[ \t]*$", text, re.M)
    if m_false:
        text = _splice(text, m_false.start(), m_false.end(), f"{m_false.group(1)}multiDexEnabled = true")
    text = _insert_after_block_open(
        text, rel, "defaultConfig", "multiDexEnabled = true", r"^[ \t]*multiDexEnabled\s*=\s*true[ \t]*$"
    )

    # 5. signingConfigs block right before buildTypes.
    if not re.search(r"^[ \t]*signingConfigs\s*\{", text, re.M):
        m = _one(rel, text, r"^(?P<i>[ \t]*)buildTypes\s*\{", "buildTypes {")
        text = _splice(text, m.start(), m.start(), _indent_block(_SIGNING_CONFIGS, m["i"]))

    # 6. release build type: release key when present, else debug.
    if _RELEASE_SIGNING not in text:
        m = _one(
            rel,
            text,
            r'^(?P<i>[ \t]*)signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)[ \t]*$',
            'buildTypes { release { signingConfig = signingConfigs.getByName("debug") } }',
        )
        start = m.start()
        # Replace the template's now-misleading TODO comment when it is right above.
        todo = re.search(
            r"^[ \t]*// TODO: Add your own signing config for the release build\.\n"
            r"[ \t]*// Signing with the debug keys for now[^\n]*\n\Z",
            text[: m.start()],
            re.M,
        )
        if todo:
            start = todo.start()
        text = _splice(text, start, m.end(), m["i"] + _RELEASE_COMMENT + m["i"] + _RELEASE_SIGNING)

    # 7. desugar_jdk_libs dependency (>= 2.1.4).
    dep_re = rf'coreLibraryDesugaring\("{re.escape(DESUGAR_COORD)}:(?P<v>[^"]+)"\)'
    deps = list(re.finditer(dep_re, text))
    if len(deps) > 1:
        raise _fail(rel, "coreLibraryDesugaring(desugar_jdk_libs) declared more than once")
    if deps:
        if _version_lt(deps[0]["v"], DESUGAR_MIN):
            text = _splice(text, deps[0].start("v"), deps[0].end("v"), DESUGAR_MIN)
    else:
        dep_line = f'coreLibraryDesugaring("{DESUGAR_COORD}:{DESUGAR_MIN}")'
        blocks = list(re.finditer(r"^dependencies\s*\{[ \t]*\n", text, re.M))
        if len(blocks) > 1:
            raise _fail(rel, "anchor is ambiguous: more than one top-level `dependencies {` block")
        if blocks:
            text = _splice(text, blocks[0].end(), blocks[0].end(), f"    {dep_line}\n")
        else:
            if not text.endswith("\n"):
                text += "\n"
            text += f"\ndependencies {{\n    {dep_line}\n}}\n"
    return text


# ---------------------------------------------------------------------------
# Android: AndroidManifest.xml
# ---------------------------------------------------------------------------


def _has_android_name(text: str, tag: str, name: str) -> bool:
    return re.search(rf'<{tag}\b[^>]*\bandroid:name="{re.escape(name)}"', text, re.S) is not None


def patch_manifest(text: str, rel: str) -> str:
    for perm in FORBIDDEN_PERMISSIONS:
        if _has_android_name(text, "uses-permission", perm):
            raise _fail(rel, f"{perm} is declared; the architecture forbids it (use SCHEDULE_EXACT_ALARM). Remove it.")

    # android:label on <application>.
    app = _one(rel, text, r"<application\b[^>]*>", "<application ...> opening tag", re.S)
    label = _one(rel, app.group(0), r'\bandroid:label="(?P<v>[^"]*)"', "android:label on <application>", 0)
    if label["v"] != APP_LABEL_BN:
        start = app.start() + label.start("v")
        end = app.start() + label.end("v")
        text = _splice(text, start, end, APP_LABEL_BN)

    # <uses-permission> lines, right before <application>.
    missing = [p for p in NOTIFICATION_PERMISSIONS if not _has_android_name(text, "uses-permission", p)]
    if missing:
        m = _one(rel, text, r"^(?P<i>[ \t]*)<application\b", "<application at line start")
        lines = "".join(f'{m["i"]}<uses-permission android:name="{p}"/>\n' for p in missing)
        text = _splice(text, m.start(), m.start(), lines)

    # Receivers, right before </application>.
    sched = f"{FLN_PKG}.ScheduledNotificationReceiver"
    boot = f"{FLN_PKG}.ScheduledNotificationBootReceiver"
    action = f"{FLN_PKG}.ActionBroadcastReceiver"
    blocks: list[str] = []
    if not _has_android_name(text, "receiver", sched):
        blocks.append(f'<receiver android:exported="false" android:name="{sched}"/>\n')
    if _has_android_name(text, "receiver", boot):
        for a in BOOT_ACTIONS:
            if f'android:name="{a}"' not in text:
                raise _fail(rel, f"{boot} exists but lacks <action android:name=\"{a}\"/>; fix it by hand")
    else:
        acts = "".join(f'        <action android:name="{a}"/>\n' for a in BOOT_ACTIONS)
        blocks.append(
            f'<receiver android:exported="false" android:name="{boot}">\n'
            f"    <intent-filter>\n{acts}    </intent-filter>\n"
            f"</receiver>\n"
        )
    if not _has_android_name(text, "receiver", action):
        blocks.append(f'<receiver android:exported="false" android:name="{action}"/>\n')
    if blocks:
        m = _one(rel, text, r"^(?P<i>[ \t]*)</application>", "</application> at line start")
        indent = m["i"] + "    "
        body = "<!-- flutter_local_notifications receivers (tool/platform_patches/apply.py) -->\n" + "".join(blocks)
        text = _splice(text, m.start(), m.start(), _indent_block(body, indent))

    # Sanity: still well-formed and structurally what we expect.
    try:
        root = ET.fromstring(text.encode("utf-8"))
    except ET.ParseError as e:  # pragma: no cover - only on a broken input
        raise _fail(rel, f"patched manifest is not well-formed XML: {e}") from e
    app_el = root.find("application")
    names = {r.get(f"{{{ANDROID_NS}}}name") for r in (app_el.findall("receiver") if app_el is not None else [])}
    if not {sched, boot, action} <= names:
        raise _fail(rel, "receivers are not direct children of <application> after patching")
    return text


# ---------------------------------------------------------------------------
# Android: notification icon + resource keep rules (generated files)
# ---------------------------------------------------------------------------

ICON_SIZE = 96
_SS = 4  # supersampling per axis


def _rrect(x: float, y: float, x0: float, y0: float, x1: float, y1: float, r: float) -> bool:
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def _seg(x: float, y: float, ax: float, ay: float, bx: float, by: float, r: float) -> bool:
    dx, dy = bx - ax, by - ay
    t = ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)
    t = min(max(t, 0.0), 1.0)
    px, py = ax + t * dx - x, ay + t * dy - y
    return px * px + py * py <= r * r


def _glyph(x: float, y: float) -> bool:
    """Calendar page with two binder rings and a check mark (96-unit canvas)."""
    rings = ((26.0, 36.0), (60.0, 70.0))
    for rx0, rx1 in rings:
        if _rrect(x, y, rx0, 6.0, rx1, 27.0, 5.0):
            return True
    for rx0, rx1 in rings:  # transparent gap around each ring
        if _rrect(x, y, rx0 - 3.5, 2.5, rx1 + 3.5, 30.5, 8.5):
            return False
    if _rrect(x, y, 8.0, 15.0, 88.0, 89.0, 10.0) and not _rrect(x, y, 15.0, 37.0, 81.0, 82.0, 4.0):
        return True
    return _seg(x, y, 30.0, 60.0, 43.0, 72.0, 4.5) or _seg(x, y, 43.0, 72.0, 67.0, 47.0, 4.5)


def _icon_raw() -> bytes:
    """Unfiltered RGBA scanlines (filter byte 0 per row)."""
    rows = bytearray()
    step = 1.0 / _SS
    for py in range(ICON_SIZE):
        rows.append(0)
        for px in range(ICON_SIZE):
            hits = 0
            for sy in range(_SS):
                for sx in range(_SS):
                    if _glyph(px + (sx + 0.5) * step, py + (sy + 0.5) * step):
                        hits += 1
            alpha = (hits * 255 + (_SS * _SS) // 2) // (_SS * _SS)
            rows += bytes((255, 255, 255, alpha))
    return bytes(rows)


def _png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def _ihdr() -> bytes:
    return struct.pack(">IIBBBBB", ICON_SIZE, ICON_SIZE, 8, 6, 0, 0, 0)


def _encode_png(raw: bytes) -> bytes:
    return (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", _ihdr())
        + _png_chunk(b"IDAT", zlib.compress(raw, 9))
        + _png_chunk(b"IEND", b"")
    )


def _png_matches(data: bytes, raw: bytes) -> bool:
    """Compare decoded pixels, so a different zlib build never reports false drift."""
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return False
    pos, ihdr, idat = 8, None, b""
    try:
        while pos < len(data):
            (length,) = struct.unpack(">I", data[pos : pos + 4])
            kind = data[pos + 4 : pos + 8]
            body = data[pos + 8 : pos + 8 + length]
            pos += 12 + length
            if kind == b"IHDR":
                ihdr = body
            elif kind == b"IDAT":
                idat += body
            elif kind == b"IEND":
                break
        return ihdr == _ihdr() and zlib.decompress(idat) == raw
    except (struct.error, zlib.error):
        return False


_KEEP_XML = """\
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/platform_patches/apply.py. The notification icon is looked up by name
     at runtime, so keep it through release resource shrinking. -->
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_stat_class" />
"""


# ---------------------------------------------------------------------------
# Windows
# ---------------------------------------------------------------------------


def patch_main_cpp(text: str, rel: str) -> str:
    m = _one(rel, text, r'window\.Create\(L"(?P<v>[^"]*)"', 'window.Create(L"<title>", origin, size)')
    if m["v"] != APP_NAME_LATIN:
        text = _splice(text, m.start("v"), m.end("v"), APP_NAME_LATIN)
    m = _one(rel, text, r"Win32Window::Size size\((?P<v>[^)]*)\);", "Win32Window::Size size(w, h);")
    want = f"{WINDOW_SIZE[0]}, {WINDOW_SIZE[1]}"
    if m["v"] != want:
        text = _splice(text, m.start("v"), m.end("v"), want)
    return text


_MINMAX_CASE = """\
case WM_GETMINMAXINFO: {
  // Minimum client area {w}x{h} logical px (03-ux.md), scaled to this window's
  // DPI and grown by the frame. Added by tool/platform_patches/apply.py.
  UINT dpi = GetDpiForWindow(hwnd);
  if (dpi == 0) {
    dpi = USER_DEFAULT_SCREEN_DPI;
  }
  const double scale_factor = dpi / 96.0;
  RECT min_rect = {0, 0, Scale({w}, scale_factor), Scale({h}, scale_factor)};
  AdjustWindowRectExForDpi(
      &min_rect, static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_STYLE)), FALSE,
      static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_EXSTYLE)), dpi);
  auto min_max_info = reinterpret_cast<MINMAXINFO*>(lparam);
  min_max_info->ptMinTrackSize.x = min_rect.right - min_rect.left;
  min_max_info->ptMinTrackSize.y = min_rect.bottom - min_rect.top;
  return 0;
}
""".replace("{w}", str(WINDOW_MIN_CLIENT[0])).replace("{h}", str(WINDOW_MIN_CLIENT[1]))


def patch_win32_window_cpp(text: str, rel: str) -> str:
    _one(rel, text, r"^int Scale\(int source, double scale_factor\)", "helper `int Scale(int source, double scale_factor)`")
    _one(
        rel,
        text,
        r"^Win32Window::MessageHandler\(HWND hwnd,",
        "`Win32Window::MessageHandler(HWND hwnd, ...)` (the case uses `hwnd`/`lparam`)",
    )
    if re.search(r"^[ \t]*case WM_GETMINMAXINFO:", text, re.M):
        return text
    m = _one(rel, text, r"^(?P<i>[ \t]*)case WM_DPICHANGED:", "case WM_DPICHANGED:")
    return _splice(text, m.start(), m.start(), _indent_block(_MINMAX_CASE, m["i"]))


def patch_runner_rc(text: str, rel: str) -> str:
    for key in ("FileDescription", "ProductName"):
        m = _one(rel, text, rf'VALUE "{key}", "(?P<v>[^"]*)"', f'VALUE "{key}", "..."')
        if m["v"] != APP_NAME_LATIN:
            text = _splice(text, m.start("v"), m.end("v"), APP_NAME_LATIN)
    return text


# ---------------------------------------------------------------------------
# Web
# ---------------------------------------------------------------------------


def _set_attr_value(text: str, rel: str, pattern: str, what: str, value: str) -> str:
    m = _one(rel, text, pattern, what)
    if m["v"] != value:
        text = _splice(text, m.start("v"), m.end("v"), value)
    return text


def patch_index_html(text: str, rel: str) -> str:
    text = _set_attr_value(text, rel, r"<title>(?P<v>[^<]*)</title>", "<title>...</title>", APP_LABEL_BN)
    text = _set_attr_value(
        text, rel, r'<meta name="description" content="(?P<v>[^"]*)"', '<meta name="description" ...>', WEB_DESCRIPTION
    )
    text = _set_attr_value(
        text,
        rel,
        r'<meta name="apple-mobile-web-app-title" content="(?P<v>[^"]*)"',
        '<meta name="apple-mobile-web-app-title" ...>',
        APP_LABEL_BN,
    )
    if re.search(r'<meta name="theme-color"', text):
        text = _set_attr_value(
            text, rel, r'<meta name="theme-color" content="(?P<v>[^"]*)"', '<meta name="theme-color" ...>', WEB_THEME_COLOR
        )
    else:
        m = _one(rel, text, r'^(?P<i>[ \t]*)<meta name="description"[^\n]*\n', '<meta name="description" ...> line')
        text = _splice(text, m.end(), m.end(), f'{m["i"]}<meta name="theme-color" content="{WEB_THEME_COLOR}">\n')
    return text


def patch_manifest_json(text: str, rel: str) -> str:
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise _fail(rel, f"not valid JSON: {e}") from e
    if not isinstance(data, dict):
        raise _fail(rel, "top-level JSON value is not an object")
    wanted = {
        "name": APP_LABEL_BN,
        "short_name": APP_LABEL_BN,
        "description": WEB_DESCRIPTION,
        "background_color": WEB_THEME_COLOR,
        "theme_color": WEB_THEME_COLOR,
    }
    missing = [k for k in wanted if k not in data]
    if missing:
        raise _fail(rel, f"anchor not found: key(s) {', '.join(missing)}")
    if all(data[k] == v for k, v in wanted.items()):
        return text  # leave formatting alone when nothing changes
    data.update(wanted)
    out = json.dumps(data, indent=4, ensure_ascii=False)
    return out + "\n" if text.endswith("\n") else out


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------


@dataclass
class Result:
    rel: str
    old: bytes | None
    new: bytes
    text_diff: tuple[str, str] | None  # (old, new) normalized text for diffs


def _decode(rel: str, data: bytes) -> tuple[str, bool, bool]:
    bom = data.startswith(b"\xef\xbb\xbf")
    if bom:
        data = data[3:]
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as e:
        raise _fail(rel, f"not UTF-8: {e}") from e
    crlf = "\r\n" in text
    if crlf:
        text = text.replace("\r\n", "\n")
    return text, crlf, bom


def _encode(text: str, crlf: bool, bom: bool) -> bytes:
    if crlf:
        text = text.replace("\n", "\r\n")
    return (b"\xef\xbb\xbf" if bom else b"") + text.encode("utf-8")


TEXT_PATCHES: list[tuple[str, Callable[[str, str], str]]] = [
    ("android/settings.gradle.kts", patch_settings_gradle),
    ("android/gradle/wrapper/gradle-wrapper.properties", patch_gradle_wrapper),
    ("android/app/build.gradle.kts", patch_app_gradle),
    ("android/app/src/main/AndroidManifest.xml", patch_manifest),
    ("windows/runner/main.cpp", patch_main_cpp),
    ("windows/runner/win32_window.cpp", patch_win32_window_cpp),
    ("windows/runner/Runner.rc", patch_runner_rc),
    ("web/index.html", patch_index_html),
    ("web/manifest.json", patch_manifest_json),
]

RES_DIR = "android/app/src/main/res"
ICON_REL = f"{RES_DIR}/drawable/ic_stat_class.png"
KEEP_REL = f"{RES_DIR}/raw/keep.xml"


def compute(root: Path) -> tuple[list[Result], list[str]]:
    results: list[Result] = []
    errors: list[str] = []

    for rel, fn in TEXT_PATCHES:
        path = root / rel
        try:
            if not path.is_file():
                raise _fail(rel, "file not found (did `flutter create` run with --platforms=android,windows,web?)")
            data = path.read_bytes()
            text, crlf, bom = _decode(rel, data)
            new_text = fn(text, rel)
            # Idempotence guard: a second pass over our own output must be a no-op.
            if fn(new_text, rel) != new_text:
                raise _fail(rel, "internal error: patch is not idempotent")
            results.append(Result(rel, data, _encode(new_text, crlf, bom), (text, new_text)))
        except PatchError as e:
            errors.append(str(e))

    if not (root / RES_DIR).is_dir():
        errors.append(f"{RES_DIR}: directory not found (Android project missing?)")
        return results, errors

    icon_path = root / ICON_REL
    raw = _icon_raw()
    old_icon = icon_path.read_bytes() if icon_path.is_file() else None
    if old_icon is not None and _png_matches(old_icon, raw):
        results.append(Result(ICON_REL, old_icon, old_icon, None))
    else:
        results.append(Result(ICON_REL, old_icon, _encode_png(raw), None))

    keep_path = root / KEEP_REL
    old_keep = keep_path.read_bytes() if keep_path.is_file() else None
    keep_crlf = old_keep is not None and b"\r\n" in old_keep
    new_keep = _encode(_KEEP_XML, keep_crlf, False)
    old_keep_text = old_keep.decode("utf-8", "replace").replace("\r\n", "\n") if old_keep is not None else ""
    results.append(Result(KEEP_REL, old_keep, new_keep, (old_keep_text, _KEEP_XML)))
    return results, errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Apply (or verify) the platform patches after `flutter create`.")
    parser.add_argument("--root", default=".", help="project root containing android/, windows/, web/ (default: cwd)")
    parser.add_argument("--verify", action="store_true", help="change nothing; exit 1 if any file would change")
    args = parser.parse_args(argv)

    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
        except (AttributeError, ValueError):
            pass

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"apply.py: --root {root} is not a directory", file=sys.stderr)
        return 2

    results, errors = compute(root)
    if errors:
        print("apply.py: FAILED, nothing was written. Fix these anchors/inputs:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 2

    changed = [r for r in results if r.old != r.new]

    if args.verify:
        if not changed:
            print(f"apply.py --verify: OK, {len(results)} files already patched.")
            return 0
        print("apply.py --verify: these files are not in the patched state:", file=sys.stderr)
        for r in changed:
            print(f"  - {r.rel}{'' if r.old is not None else ' (missing)'}", file=sys.stderr)
        for r in changed:
            if r.text_diff is not None:
                diff = difflib.unified_diff(
                    r.text_diff[0].splitlines(keepends=True),
                    r.text_diff[1].splitlines(keepends=True),
                    fromfile=f"a/{r.rel}",
                    tofile=f"b/{r.rel}",
                )
                sys.stderr.writelines(diff)
        print("Run `python3 tool/platform_patches/apply.py` and commit the result.", file=sys.stderr)
        return 1

    for r in changed:
        path = root / r.rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(r.new)
        print(f"patched  {r.rel}")
    for r in results:
        if r not in changed:
            print(f"ok       {r.rel}")
    print(f"apply.py: {len(changed)} file(s) changed, {len(results) - len(changed)} already up to date.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
