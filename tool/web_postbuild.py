#!/usr/bin/env python3
"""Make a Pages deploy visible on the next reload (lead-notes bug 6: stale web cache).

GitHub Pages serves every file with `Cache-Control: max-age=600` and we cannot change headers,
and earlier deploys may have installed Flutter's caching service worker in the teacher's
browser. Three fixes, all content-addressed so an unchanged build keeps its cache:

1. flutter_service_worker.js is replaced by a stub that deletes all caches and unregisters
   itself. Browsers re-check the SW script on navigation, so this evicts the old worker that
   kept serving the previous build.
2. main.dart.js is referenced as main.dart.js?v=<sha> from flutter_bootstrap.js, and
   flutter_bootstrap.js as flutter_bootstrap.js?v=<sha> from index.html: a new build always
   changes the URLs, so the browser cannot reuse a stale copy of either file.
3. Only index.html (and its 404.html copy) can still be up to 10 minutes stale; it holds no code.

sqlite3.wasm and drift_worker.js are untouched (loaded by fixed name from Dart).
"""
import hashlib
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")


def digest(p: pathlib.Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()[:12]


STUB = """// Replaces Flutter's caching service worker (cache-busting, see tool/web_postbuild.py).
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const k of await caches.keys()) await caches.delete(k);
    await self.registration.unregister();
    for (const c of await self.clients.matchAll({ type: 'window' })) c.navigate(c.url);
  })());
});
"""
(root / "flutter_service_worker.js").write_text(STUB, encoding="utf-8")

main = root / "main.dart.js"
boot = root / "flutter_bootstrap.js"
index = root / "index.html"
for f in (main, boot, index):
    if not f.is_file():
        sys.exit(f"web_postbuild: missing {f}")

text = boot.read_text(encoding="utf-8")
new, n = re.subn(
    r'(["\'])main\.dart\.js\1',
    lambda m: f"{m.group(1)}main.dart.js?v={digest(main)}{m.group(1)}",
    text,
)
if n == 0:
    sys.exit("web_postbuild: no main.dart.js reference in flutter_bootstrap.js (loader format changed?)")
boot.write_text(new, encoding="utf-8")

html = index.read_text(encoding="utf-8")
html, n = re.subn(r"flutter_bootstrap\.js(?!\?)", f"flutter_bootstrap.js?v={digest(boot)}", html)
if n == 0:
    sys.exit("web_postbuild: no flutter_bootstrap.js reference in index.html")
index.write_text(html, encoding="utf-8")
print(f"web_postbuild: main.dart.js?v={digest(main)}, flutter_bootstrap.js?v={digest(boot)}, SW stub written")
