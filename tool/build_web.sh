#!/usr/bin/env bash
# Build the release web bundle used by ci.yml (web), pages.yml and release.yml, so all three
# behave identically. Extra args (e.g. --build-number=7 --build-name=1.2.0) pass to flutter.
# Output: build/web (with 404.html fallback and cache-busting applied, see web_postbuild.py).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

extra=()
# --pwa-strategy is deprecated in Flutter 3.4x and removed in 3.51: pass it only if still known.
if flutter build web --help 2>/dev/null | grep -q -- '--pwa-strategy'; then
  extra+=(--pwa-strategy=none)
fi

flutter build web --release --no-web-resources-cdn \
  --base-href /attendance-alamin/ ${extra[@]+"${extra[@]}"} "$@"

python3 tool/web_postbuild.py build/web
cp build/web/index.html build/web/404.html
