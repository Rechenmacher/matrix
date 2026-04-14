# Screensaver Port — Implementation Plan

> **Session continuity doc.** Any Claude Code session starting work here should read this file first, check the `## Status` section for current progress, and update it before ending the session.

## Goal

Add native screensaver wrappers for macOS, Windows, and Linux that embed the existing web app (index.html + WebGL/WebGPU pipeline) using each platform's WebView API. Structured as a new `screensaver/` directory alongside the existing `playdate/` port, with the intent to open a PR to `Rezmason/matrix`.

The rendering code does not change. Only thin native wrappers are added.

---

## Git Setup (one-time, not yet done)

The local repo currently tracks `origin = https://github.com/Rezmason/matrix.git` (upstream).

Steps before first commit:
1. User forks `Rezmason/matrix` on GitHub (click Fork in the browser)
2. Add fork as a second remote:
   ```bash
   git remote add fork https://github.com/<YOUR_GITHUB_USERNAME>/matrix.git
   ```
3. Create a feature branch:
   ```bash
   git checkout -b screensaver-port
   ```
4. All commits pushed to `fork`, not `origin`:
   ```bash
   git push -u fork screensaver-port
   ```
5. When ready: open PR from `<username>/matrix:screensaver-port` → `Rezmason/matrix:master`

---

## Directory Structure (target)

```
screensaver/
  PLAN.md           ← this file
  README.md         ← user-facing install + usage instructions (write last)
  mac/
    matrix.xcodeproj/
    MatrixScreenSaver/
      MatrixScreenSaverView.swift   ← ScreenSaverView subclass with WKWebView
      ConfigureSheetController.swift ← preferences panel
      Info.plist
    Resources/                      ← symlinked or copied web assets at build time
  windows/
    MatrixScreenSaver.sln
    MatrixScreenSaver/
      Program.cs                    ← entry point, arg handling (/s /p /c)
      ScreensaverForm.cs            ← fullscreen WebView2 window
      PreferencesForm.cs            ← settings dialog
      MatrixScreenSaver.csproj
  linux/
    CMakeLists.txt
    src/
      main.c                        ← XScreenSaver-compatible WebKit2GTK wrapper
    matrix-screensaver.desktop
    install.sh
```

---

## Status

**Last updated:** 2026-04-14  
**Current phase:** 1 complete (code written), awaiting build + test by user.  
**Branch:** `screensaver-port` (local only — push to fork once GitHub account is recovered)

### Phase checklist

#### Phase 0 — Repo scaffolding
- [x] User forks repo and adds `fork` remote — DEFERRED (GitHub account recovery in progress)
- [x] Create `screensaver-port` branch
- [x] Create `screensaver/` directory skeleton
- [ ] Commit skeleton to establish structure — do this once fork/push is unblocked

#### Phase 1 — macOS `.saver` (target: 1–2 sessions)
- [x] Create Xcode project: `Cocoa Framework` target, macOS 12+
- [x] Subclass `ScreenSaverView`, embed `WKWebView` filling the frame
- [x] Load `index.html` from bundle resources via `file://` URL with `skipIntro=true&suppressWarnings=true`
- [x] Disable WKWebView scrolling, selection, and context menu
- [x] Add `hasConfigureSheet` preferences panel exposing: `version`, `effect`, `animationSpeed`, `bloomStrength`
- [x] Persist prefs with `ScreenSaverDefaults`
- [x] Build phase script: `copy_web_assets.sh` copies `js/`, `shaders/`, `assets/`, `lib/`, `index.html`
- [ ] **NEXT:** Open `screensaver/mac/matrix.xcodeproj` in Xcode, add `copy_web_assets.sh` as a Run Script build phase, build, and install the `.saver`
- [ ] Test: System Settings → Screen Saver → Matrix
- [ ] Sign with `codesign` (ad-hoc for local use: `codesign --force --deep -s - Matrix.saver`)
- [ ] Document notarization steps (for distribution)

**Key Swift APIs:** `ScreenSaver.framework`, `WKWebView`, `WKWebViewConfiguration`, `WKPreferences`, `ScreenSaverDefaults`

#### Phase 2 — Windows `.scr` (target: 1–2 sessions)
- [ ] Create .NET 8 WinForms project targeting `net8.0-windows`
- [ ] Add NuGet: `Microsoft.Web.WebView2`
- [ ] Implement `Program.cs`: parse `/s` (screensaver), `/p <HWND>` (preview), `/c` (configure), no args → configure
- [ ] `ScreensaverForm.cs`: fullscreen `Form` with `WebView2` control, load `index.html` from app directory
- [ ] `PreferencesForm.cs`: simple WinForms dialog (same options as Mac prefs)
- [ ] Persist settings: `System.Configuration.ConfigurationManager` or simple JSON in `%APPDATA%`
- [ ] Build output: rename `.exe` → `.scr` in post-build step
- [ ] Bundle web assets alongside the `.scr` (or embed as resources)
- [ ] Test: right-click `.scr` → "Install" on Windows 10/11
- [ ] Document WebView2 redistributable requirement for Windows 10

**Key APIs:** `Microsoft.Web.WebView2.WinForms.WebView2`, `System.Windows.Forms`, screensaver protocol args

#### Phase 3 — Linux XScreenSaver module (target: 2–3 sessions)
- [ ] Write `main.c` using `webkit2gtk-4.1` and `gtk4`
- [ ] Accept `--window-id <XID>` for embedding into XScreenSaver's window
- [ ] Accept `--root` for running on the root window
- [ ] Load `index.html` from `$XDG_DATA_HOME/matrix-screensaver/` or `/usr/share/matrix-screensaver/`
- [ ] `install.sh`: copies web assets, desktop file, and binary; registers with `xscreensaver-demo`
- [ ] CMakeLists.txt: find `webkit2gtk-4.1`, `gtk4`
- [ ] Test on GNOME (Ubuntu 22.04+) and KDE (Plasma 6)
- [ ] Provide fallback: a `matrix-screensaver.sh` that launches fullscreen Firefox if WebKit not available

**Key APIs:** `webkit2gtk`, `WebKitWebView`, `gtk_plug_new` (for XEmbed), XScreenSaver `.xml` config format

#### Phase 4 — README + PR (target: 1 session)
- [ ] Write `screensaver/README.md`: platform requirements, install steps, config options
- [ ] Review all platform-specific code for quality and consistency
- [ ] Rebase branch cleanly on latest `master`
- [ ] Open PR to `Rezmason/matrix` with description referencing the TODO item ("Maybe pay someone to make Mac/Windows screensavers")

---

## Key Technical Notes (read before each session)

**Asset loading:** Web assets need to be accessible to WebView. On all platforms, the safest approach is to copy the assets at install time and load via `file://` URLs. Do not attempt to embed them as binary resources — the shaders are loaded dynamically by the JS.

**suppressWarnings:** Always pass `suppressWarnings=true` in the default URL. The warning overlay (which appears when SwiftShader/software rendering is detected) is disruptive in a screensaver context.

**skipIntro:** Pass `skipIntro=true`. The fade-in intro is beautiful but awkward when the screensaver activates after a few minutes of idle.

**Default URL params:** `?skipIntro=true&suppressWarnings=true` — additional params (version, effect, etc.) come from user preferences.

**WebGL in WKWebView:** Enabled by default on macOS 12+. No special flags needed. WebGPU is not yet available in WKWebView — the app will fall back to WebGL automatically.

**WebGL in WebView2:** Enabled by default. WebGPU available in WebView2 on Windows 11 (Chromium 113+).

**WebGL in WebKit2GTK:** Requires `webkit2gtk` built with WebGL support (default on most distros since 2021). Test with `webkit2gtk --version` >= 2.36.

**Preferences persistence:** Each platform has its own mechanism. Do not share a config file across platforms — keep it simple and native.

**Multi-monitor:** On Mac, `ScreenSaverView` is instantiated once per display automatically by the system. On Windows, handle the `/s` case by creating one fullscreen window per monitor using `Screen.AllScreens`. On Linux, let the window manager handle it.
