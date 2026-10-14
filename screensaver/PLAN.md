# Screensaver Port — Implementation Plan

> Implementation plan and progress tracker for the screensaver port.

## Goal

Add native screensaver wrappers for macOS, Windows, and Linux that embed the existing web app (index.html + WebGL/WebGPU pipeline) using each platform's WebView API. Structured as a new `screensaver/` directory alongside the existing `playdate/` port, with the intent to open a PR to `Rezmason/matrix`.

The rendering code does not change. Only thin native wrappers are added.

---

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

**Last updated:** 2026-04-15  
**Current phase:** All three platforms implemented. CI workflow added. Needs build verification and testing.

### Phase checklist

#### Phase 0 — Repo scaffolding
- [x] Create `screensaver-port` branch
- [x] Create `screensaver/` directory skeleton

#### Phase 1 — macOS `.saver` (COMPLETE)
- [x] Create Xcode project: `Cocoa Framework` target, macOS 12+
- [x] **Pivot to companion app pattern** — WKWebView cannot render inside .saver sandbox on modern macOS (process suspension + invisible compositor). Solved with MatrixSaverApp launched by .saver.
- [x] MatrixSaverApp: standalone app, fullscreen WKWebView on all screens, exits on input/SIGTERM
- [x] MatrixScreenSaverView: thin .saver wrapper, launches/kills companion app
- [x] ConfigureSheetController: preferences panel (version, effect, animationSpeed, bloomStrength)
- [x] MatrixPreferences: persistence via ScreenSaverDefaults
- [x] build.sh: one-command build, universal binary (arm64e + x86_64), macOS 12+
- [x] Visual tuning: Matrix 1 (1999) movie style
- [x] Tested and working on macOS 16 (Darwin 25.3.0)
- [x] Ad-hoc signed, 3.2 MB bundle
- [ ] **REMAINING:** Apple Developer ID signing + notarization for Gatekeeper (requires $99/year account)
- [ ] **REMAINING:** Preview thumbnail rendering in System Settings (currently shows black)

**Key Swift APIs:** `ScreenSaver.framework`, `WKWebView`, `WKWebViewConfiguration`, `WKPreferences`, `ScreenSaverDefaults`

#### Phase 2 — Windows `.scr` (target: 1–2 sessions)
- [x] Create .NET 8 WinForms project targeting `net8.0-windows`
- [x] Add NuGet: `Microsoft.Web.WebView2`
- [x] Implement `Program.cs`: parse `/s` (screensaver), `/p <HWND>` (preview), `/c` (configure), no args → configure
- [x] `ScreensaverForm.cs`: fullscreen `Form` with `WebView2` control, load `index.html` from app directory
- [x] `PreviewForm.cs`: embedded preview in Settings thumbnail (parented to HWND)
- [x] `PreferencesForm.cs`: simple WinForms dialog (same options as Mac prefs)
- [x] Persist settings: JSON in `%APPDATA%\MatrixScreenSaver\settings.json`
- [x] Build script (`build.ps1`): publish + rename `.exe` → `.scr` + copy web assets
- [ ] Test: right-click `.scr` → "Install" on Windows 10/11
- [ ] Document WebView2 redistributable requirement for Windows 10

**Key APIs:** `Microsoft.Web.WebView2.WinForms.WebView2`, `System.Windows.Forms`, screensaver protocol args

#### Phase 3 — Linux screensaver (target: 2–3 sessions)
- [x] Write `main.c` using GTK4 + WebKitGTK (webkitgtk-6.0 with webkit2gtk-4.1 fallback)
- [ ] Accept `--window-id <XID>` for embedding into XScreenSaver's window
- [ ] Accept `--root` for running on the root window
- [x] Load `index.html` from `$MATRIX_SCREENSAVER_WEB_ROOT`, `$XDG_DATA_HOME/matrix-screensaver/`, or `/usr/share/matrix-screensaver/`
- [x] `install.sh`: copies web assets, desktop file, and binary
- [x] CMakeLists.txt: find GTK4 + WebKitGTK with version fallback
- [x] `matrix-screensaver.desktop`: desktop entry
- [ ] Test on GNOME (Ubuntu 24.04) and KDE (Plasma 6)
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
