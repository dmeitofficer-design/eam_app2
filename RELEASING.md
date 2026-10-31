# Releasing a new version

Releases are built by GitHub Actions (`.github/workflows/release.yml`).
After a release, installed apps show **Update available** the next time
they start:

- **Android**: tapping **Update Now** downloads the APK inside the app and
  opens the system installer. The user taps **Update** once.
- **Windows**: **Update Now** opens the download of `DME-CM-windows.zip`;
  extract it over the old app folder.

## Release

```bash
git checkout main && git pull
git tag -a v1.0.2+9 -m "What changed, in a line or two"
git push origin v1.0.2+9
```

- `1.0.2` is the version users see, and `9` is the build number. **The
  build number must be higher than the previous release's**, or apps won't
  see the update.
- The tag message becomes the release notes shown in the update dialog.
- Add `[mandatory]` anywhere in the message to block the app until users
  update, e.g. `-m "Fixes login [mandatory]"`.
- Follow the run under the repository's **Actions** tab (about 15 minutes).
  When it is green, the release is live.

Optionally also bump `version:` in `pubspec.yaml` to the same value, so
local builds report the right version.

## One-time setup: repository secrets

GitHub → repository → **Settings → Secrets and variables → Actions →
New repository secret**:

| Secret | Value |
| --- | --- |
| `ENV_FILE` | The full contents of your local `.env` file |
| `ANDROID_KEYSTORE_BASE64` | Your release keystore (`.jks`) as base64, see below |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` from `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` from `android/key.properties` |
| `SUPABASE_URL` | Your project URL, e.g. `https://xxxx.supabase.co` |
| `SUPABASE_SERVICE_KEY` | Supabase → Project Settings → API Keys: the `service_role` key (or a new `sb_secret_…` key). Never put this in the app. |

Keystore as base64 (copies it to the clipboard):

```powershell
# Windows PowerShell — use the path from storeFile in android/key.properties
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\upload-keystore.jks")) | Set-Clipboard
```

```bash
# macOS / Linux
base64 -i path/to/upload-keystore.jks | pbcopy   # or: base64 -w0 path/to/upload-keystore.jks
```

**Use the same keystore that signed the APK people have installed now.**
Android only installs an update signed with the same key. If the key is
different, users must uninstall the app once and install the new APK.

## First update on each phone

The first time, Android asks to **allow installs from DME CM** ("Install
unknown apps"). Users allow it once; later updates go straight to the
installer.

Phones on an older app version don't have the in-app installer yet: their
**Update Now** opens the APK download in the browser. After installing
that, future updates happen inside the app.
