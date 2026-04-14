/// MatrixSaverApp — Companion app launched by the Matrix.saver bundle.
/// Opens fullscreen borderless windows with WKWebView on every screen.
/// Exits on mouse movement, keyboard input, or SIGTERM from the .saver.

import Cocoa
import WebKit

// MARK: - Configuration

struct MatrixConfig {
    /// Default URL parameters for the Matrix 1 (1999) movie style.
    static let defaultParams: [(String, String)] = [
        ("skipIntro", "true"),
        ("suppressWarnings", "true"),
        ("version", "classic"),
        ("font", "matrixcode"),
        ("numColumns", "90"),
        ("fallSpeed", "0.3"),
        ("cycleSpeed", "0.015"),
        ("raindropLength", "1.0"),
        // Strong bloom for phosphor glow
        ("bloomStrength", "1.0"),
        ("bloomSize", "0.7"),
        ("highPassThreshold", "0.0"),
        // Cursor suppressed — no bright leading edge
        ("cursorHSL", "0.33,1,0.1"),
        ("cursorIntensity", "0.0"),
        ("isolateCursor", "false"),
        // Fast decay: glyphs snap to dark green quickly
        ("brightnessDecay", "3.0"),
        ("baseBrightness", "-0.8"),
        ("baseContrast", "1.5"),
        // Pure green palette
        ("paletteHSL", "0.33,0.95,0,0,0.33,1,0.3,30,0.33,1,0.6,70,0.34,0.85,0.8,100"),
        ("fps", "60"),
        ("resolution", "1"),
    ]
}

// MARK: - Window

class MatrixWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - App Delegate

class MatrixAppDelegate: NSObject, NSApplicationDelegate {

    private var windows: [NSWindow] = []
    private var initialMouseLocation: NSPoint?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let webRoot = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : Bundle.main.resourcePath ?? "."

        let indexURL = URL(fileURLWithPath: webRoot).appendingPathComponent("index.html")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            NSApp.terminate(nil)
            return
        }

        var components = URLComponents(url: indexURL, resolvingAgainstBaseURL: false)!
        components.queryItems = MatrixConfig.defaultParams.map {
            URLQueryItem(name: $0.0, value: $0.1)
        }

        guard let url = components.url else {
            NSApp.terminate(nil)
            return
        }

        let resourceDir = indexURL.deletingLastPathComponent()

        // Remember initial mouse position to detect real movement vs jitter
        initialMouseLocation = NSEvent.mouseLocation

        // Create a fullscreen window on every connected display
        for screen in NSScreen.screens {
            let window = MatrixWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.acceptsMouseMovedEvents = true

            let config = WKWebViewConfiguration()
            config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

            let webView = WKWebView(frame: screen.frame, configuration: config)
            webView.autoresizingMask = [.width, .height]
            window.contentView = webView
            webView.loadFileURL(url, allowingReadAccessTo: resourceDir)

            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        NSCursor.hide()
        installInputMonitors()

        // Handle SIGTERM gracefully (sent by .saver's stopAnimation)
        signal(SIGTERM) { _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSCursor.unhide()
    }

    // MARK: - Input monitoring

    private func installInputMonitors() {
        let exitEvents: NSEvent.EventTypeMask = [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]

        NSEvent.addGlobalMonitorForEvents(matching: exitEvents) { [weak self] event in
            self?.handleInput(event)
        }

        NSEvent.addLocalMonitorForEvents(matching: exitEvents) { [weak self] event in
            self?.handleInput(event)
            return event
        }
    }

    private func handleInput(_ event: NSEvent) {
        if event.type == .mouseMoved {
            // Require significant movement to avoid exit from jitter or tiny bumps
            if let initial = initialMouseLocation {
                let current = NSEvent.mouseLocation
                let d = hypot(current.x - initial.x, current.y - initial.y)
                if d < 10 { return }
            }
        }
        NSApp.terminate(nil)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = MatrixAppDelegate()  // strong ref — prevents deallocation
app.delegate = delegate
app.run()
