# Release checklist (owner)

## One time: Android signing key
1. Repo Settings > Secrets and variables > Actions: create `KEYSTORE_EXPORT_PASSPHRASE` (16+ random characters, the repo is public).
2. Actions > "Generate Android release keystore" > Run workflow on `main`, type `generate`. Run it **once, ever**.
3. Download the artifact `android-keystore-ENCRYPTED` (kept 1 day) and decrypt in Git Bash:
   `openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in keystore-bundle.tar.gz.enc -out keystore-bundle.tar.gz && tar -xzf keystore-bundle.tar.gz`
4. Create four repo secrets, pasting each file's content exactly: `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
5. Keep `upload.jks` and the passwords **offline in two places** (and the export passphrase). If they are lost the teacher can never upgrade in place; uninstalling wipes all data. Then delete the artifact and the decrypted files.

## Each release
1. Make sure `main` CI is green.
2. Tag and push: `git tag v1.0.0 && git push origin v1.0.0` (format `vMAJOR.MINOR.PATCH`).
3. The Release workflow builds three signed per-ABI APKs, the Windows setup .exe and portable zip, and the web zip, and publishes a GitHub Release with `SHA256SUMS.txt`. Version name = tag, versionCode = workflow run number plus Flutter's per-ABI offset (v7a +1000, arm64-v8a +2000, x86_64 +4000), always increasing, so an APK installs over the old one and keeps data. Obfuscation symbols are uploaded as the separate artifact `symbols-android-<ver>` / `symbols-windows-<ver>` (90 days, never published; needed for `flutter symbolize` on crash traces).
4. If the android job fails with "No release keystore", the secrets are missing: do the one-time steps, then re-run the failed workflow.
5. Give the teacher only the APK (or setup .exe) from the Release page, never one from a CI run (those may be debug-signed).

## Web (GitHub Pages)
Set repo variable `ENABLE_PAGES=true` and Pages source "GitHub Actions"; every push to `main` redeploys. Builds are cache-busted (`tool/web_postbuild.py`): a normal reload shows the newest build within about 10 minutes (Pages' own `index.html` cache), and old caching service workers are removed automatically.

## Which file to install
**Android** (the Release has three APKs, `HajiraKhata-<ver>-<abi>.apk`; install only one):
- `arm64-v8a`: almost every phone made since about 2017. Use this unless it says "App not installed" or "not compatible".
- `armeabi-v7a`: old 32-bit phones (or if arm64-v8a is refused).
- `x86_64`: emulators and Chromebooks, not real phones. (Flutter has no 32-bit x86 release build.)
Not sure? Try arm64-v8a first. Phones: Settings > About phone, or an app like "CPU-Z", shows the architecture. CI test builds are named `...-TEST-DEBUGKEY.apk` (debug key, never give those to the teacher).

**Windows**: download `HajiraKhata-<ver>-windows-setup.exe`, double-click, accept the UAC prompt (installs to Program Files for all users). In the first dialog you can choose "Install for me only" (no admin needed, goes to the user's AppData). Tick "Create a desktop shortcut" if wanted; Start menu entry is always created. Run a newer setup to upgrade in place (data is kept); uninstall from Settings > Apps. Windows SmartScreen may warn because the setup is not code-signed: More info > Run anyway. The portable zip needs no install: unzip and run `attendance_alamin.exe`. No MSI is built.

## Size work (what is in CI)
Android: R8 + resource shrinking with `android/app/proguard-rules.pro`, `--obfuscate --split-debug-info`, per-ABI split, compressed native libs, META-INF junk excluded. Icon tree-shaking is on (`--tree-shake-icons`); only the 4 Hind Siliguri weights are declared in `pubspec.yaml`. Windows: `--obfuscate`, LZMA2 ultra installer. Each CI job prints a before/after table in its run summary.
