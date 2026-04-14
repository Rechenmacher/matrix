# macOS Screensaver — Next Session Plan

> Read this at the start of the next session. Current state: working screensaver on local machine,
> universal binary (arm64e + x86_64), macOS 12+ target. Not yet CI/CD or cross-version tested.

## Where we left off

- `screensaver-port` branch, 3 commits ahead of fork remote (not yet pushed)
- Screensaver works when idle-activated and via `open -a ScreenSaverEngine`
- Preview button in System Settings may or may not work (was black, fix committed but untested)
- Options panel saves preferences but untested end-to-end
- Visual style: Matrix 1 (1999) tuning — dark cursor, strong bloom, fast decay
- Build: `screensaver/mac/build.sh` produces `dist/Matrix.saver` (3.2 MB)

## Tasks for this session

### 1. Push to fork (5 min)

```bash
# Will need a fresh GitHub PAT — the old one should have been revoked
git remote set-url fork https://Rechenmacher:<NEW_TOKEN>@github.com/Rechenmacher/matrix.git
git push fork screensaver-port
git remote set-url fork https://github.com/Rechenmacher/matrix.git  # strip token
```

### 2. GitHub Actions CI/CD workflow (30 min)

Create `.github/workflows/build-screensaver-mac.yml` that:

- **Triggers on:** push to `screensaver-port`, PR to `master`
- **Runner:** `macos-14` (Apple Silicon M1) — GitHub provides this free for public repos
- **Matrix strategy:** Also test on `macos-13` (Intel) for x86_64 verification
- **Steps:**
  1. Checkout repo
  2. Select Xcode version (`sudo xcode-select -s /Applications/Xcode_15.4.app` or latest available)
  3. Run `screensaver/mac/build.sh`
  4. Verify universal binary: `file dist/Matrix.saver/Contents/MacOS/Matrix` must show both architectures
  5. Verify companion app: `file dist/Matrix.saver/Contents/Resources/MatrixSaverApp`
  6. Upload `Matrix.saver` as build artifact
- **Optional:** On tag push (`v*`), create a GitHub Release with `Matrix.saver.zip` attached

Key CI considerations:
- `CODE_SIGNING_REQUIRED=NO` is already set in build.sh — works without certificates
- No simulator needed — this is a bundle, not an app
- The `xcodebuild -runFirstLaunch` may be needed on CI runners
- `swiftc` is available on all macOS runners

### 3. Cross-version compatibility audit (20 min)

Test/verify these areas for macOS 12–16 compatibility:

| Area | Risk | Fix if needed |
|---|---|---|
| `WKWebView` in companion app | Low — standard API since macOS 10.10 | None expected |
| `allowFileAccessFromFileURLs` KVC key | Medium — private API, may be removed | Fall back to localhost HTTP server if it fails |
| `ScreenSaverView` subclass | Low — stable API | None expected |
| `NSEvent.addGlobalMonitorForEvents` | Low — stable since 10.6 | None expected |
| `ProcessInfo.beginActivity` (currently unused) | N/A — removed in latest code | Already clean |
| `Process.run()` from .saver bundle | Medium — sandbox may vary by OS version | Add fallback: `NSWorkspace.shared.open()` |
| arm64e vs arm64 | **High on older macOS** — arm64e only works on macOS 12+ Apple Silicon. Intel Macs need x86_64 only. | Already building universal binary |
| Code signing | Works ad-hoc locally, Gatekeeper blocks unsigned on other machines | Need Developer ID for distribution (separate task) |

**Action items:**
- Add a `try/catch` around `config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")` in the companion app — if it throws on a future macOS, fall back gracefully
- Add `NSWorkspace.shared.open()` as fallback launch method in the .saver if `Process.run()` fails
- Test: Run the CI build on both `macos-13` and `macos-14` runners to verify both architectures work

### 4. Hardening (15 min)

- [ ] Remove any remaining `/tmp/matrix_probe.txt` debug writes (check all Swift files)
- [ ] Ensure companion app exits cleanly on SIGTERM (already handled, verify)
- [ ] Ensure `.saver` calls `waitUntilExit()` on stop (already done, verify no zombie processes)
- [ ] Test: activate screensaver → move mouse → verify companion app process is gone (`pgrep MatrixSaverApp`)
- [ ] Test: activate screensaver → close laptop lid → open → verify it recovers or exits cleanly
- [ ] Add `LSUIElement = true` to companion app's Info.plist equivalent (prevent Dock icon from appearing) — this requires embedding an `Info.plist` in the binary or wrapping it in a .app bundle

### 5. Companion app Dock icon suppression (15 min)

Currently `MatrixSaverApp` is a raw executable, so it shows a Dock icon when running.
Fix: either embed `LSUIElement` via `-sectcreate __TEXT __info_plist Info.plist` linker flag,
or restructure as a minimal `.app` bundle inside the `.saver`.

Recommended approach — `.app` bundle:
```
Matrix.saver/
  Contents/
    Resources/
      MatrixSaverApp.app/
        Contents/
          MacOS/MatrixSaverApp
          Info.plist          ← includes LSUIElement = true
```

Update `build.sh` to create this structure instead of a bare executable.

### 6. Installer .pkg (optional, 15 min)

Create a `.pkg` installer using `pkgbuild`:
```bash
pkgbuild --root dist/Matrix.saver \
  --identifier com.rezmason.MatrixScreenSaver \
  --version 1.0 \
  --install-location "/Library/Screen Savers/Matrix.saver" \
  dist/Matrix-Screensaver.pkg
```

This gives end users a double-click installer with a nice macOS install wizard.

## What's NOT in scope for this session

- Apple Developer ID signing + notarization ($99/year account needed)
- Windows or Linux ports (Phase 2 and 3)
- PR to upstream Rezmason/matrix (wait until all platforms are done)

## Quick reference

```bash
# Build
cd /Users/danielrechenmacher/projects/dev/matrix/screensaver/mac
./build.sh

# Install locally
cp -R dist/Matrix.saver ~/Library/Screen\ Savers/

# Test
open -a ScreenSaverEngine  # fullscreen test
pkill MatrixSaverApp        # force exit

# Test companion app directly
dist/Matrix.saver/Contents/Resources/MatrixSaverApp dist/Matrix.saver/Contents/Resources

# Check for zombie processes
pgrep -l MatrixSaverApp
```
