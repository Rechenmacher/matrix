import ScreenSaver

/// Thin .saver wrapper that launches the MatrixSaverApp companion app.
/// WKWebView cannot render inside the screensaver sandbox on modern macOS,
/// so the actual rendering happens in a standalone app with full GPU access.
class MatrixScreenSaverView: ScreenSaverView {

    private var appProcess: Process?
    private var sheetController: ConfigureSheetController?

    // MARK: - Init

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    // MARK: - Animation

    override func startAnimation() {
        super.startAnimation()

        // Don't launch the fullscreen app in the tiny System Settings preview thumbnail
        if isPreview { return }

        let bundle = Bundle(for: type(of: self))

        guard let appPath = bundle.path(forResource: "MatrixSaverApp", ofType: nil) else {
            return
        }

        let webRoot = bundle.resourcePath ?? bundle.bundlePath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: appPath)
        process.arguments = [webRoot]

        do {
            try process.run()
            appProcess = process
        } catch {
            // Silently fail — the user sees a black screen, which is acceptable
        }
    }

    override func stopAnimation() {
        super.stopAnimation()
        if let p = appProcess, p.isRunning {
            p.terminate()
            p.waitUntilExit()
        }
        appProcess = nil
    }

    override func animateOneFrame() {
        // Rendering handled by companion app
    }

    // MARK: - Configuration

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        if sheetController == nil {
            sheetController = ConfigureSheetController()
            sheetController?.screenSaverView = self
        }
        return sheetController?.window
    }

    func reloadWithCurrentPreferences() {
        stopAnimation()
        startAnimation()
    }
}
