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
3. The Release workflow builds the signed APK, Windows zip and web zip and publishes a GitHub Release with `SHA256SUMS.txt`. Version name = tag, versionCode = workflow run number (always increasing, so the APK installs over the old one and keeps data).
4. If the android job fails with "No release keystore", the secrets are missing: do the one-time steps, then re-run the failed workflow.
5. Give the teacher only the APK from the Release page, never one from a CI run (those may be debug-signed).

## Web (GitHub Pages)
Set repo variable `ENABLE_PAGES=true` and Pages source "GitHub Actions"; every push to `main` redeploys. Builds are cache-busted (`tool/web_postbuild.py`): a normal reload shows the newest build within about 10 minutes (Pages' own `index.html` cache), and old caching service workers are removed automatically.
