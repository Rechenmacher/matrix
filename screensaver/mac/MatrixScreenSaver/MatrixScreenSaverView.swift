import ScreenSaver

/// Thin .saver wrapper that launches the MatrixSaverApp companion app.
/// WKWebView cannot render inside the screensaver sandbox on modern macOS,
/// so the actual rendering happens in a standalone app with full GPU access.
class MatrixScreenSaverView: ScreenSaverView {

    private var appProcess: Process?
    private var sheetController: ConfigureSheetController?
    private var previewImageView: NSImageView?

    // MARK: - Init

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setupPreviewImage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setupPreviewImage()
    }

    /// Show a static Matrix screenshot in the System Settings thumbnail
    private func setupPreviewImage() {
        let bundle = Bundle(for: type(of: self))
        guard let imgPath = bundle.path(forResource: "preview", ofType: "png"),
              let image = NSImage(contentsOfFile: imgPath) else { return }

        let iv = NSImageView(frame: bounds)
        iv.image = image
        iv.imageScaling = .scaleAxesIndependently
        iv.autoresizingMask = [.width, .height]
        addSubview(iv)
        previewImageView = iv
    }

    // MARK: - Animation

    override func startAnimation() {
        super.startAnimation()

        // Skip the tiny thumbnail in System Settings (typically ~300x200)
        // but allow the full-screen Preview mode
        if frame.width < 500 || frame.height < 500 { return }

        let bundle = Bundle(for: type(of: self))

        guard let appPath = bundle.path(forResource: "MatrixSaverApp", ofType: nil) else {
            return
        }

        let webRoot = bundle.resourcePath ?? bundle.bundlePath
        let prefs = MatrixPreferences.load()

        // Hide the static preview image — the companion app renders fullscreen
        previewImageView?.isHidden = true

        let process = Process()
        process.executableURL = URL(fileURLWithPath: appPath)
        process.arguments = [webRoot]
            + prefs.asCommandLineArgs()

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
