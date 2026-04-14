import ScreenSaver
import WebKit

class MatrixScreenSaverView: ScreenSaverView {

    private var webView: WKWebView?
    private var configSheet: NSWindow?
    private var sheetController: ConfigureSheetController?

    // MARK: - Init

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setupWebView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }

    // MARK: - Setup

    private func setupWebView() {
        let prefs = MatrixPreferences.load()

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        // WebGL requires the GPU process; no extra flags needed on macOS 12+

        let wv = WKWebView(frame: bounds, configuration: config)
        wv.autoresizingMask = [.width, .height]
        wv.enclosingScrollView?.hasHorizontalScroller = false
        wv.enclosingScrollView?.hasVerticalScroller = false

        // Disable right-click context menu
        wv.configuration.preferences.setValue(false, forKey: "developerExtrasEnabled")

        addSubview(wv)
        self.webView = wv

        loadMatrix(with: prefs)
    }

    private func loadMatrix(with prefs: MatrixPreferences) {
        guard let resourceURL = Bundle(for: type(of: self))
            .url(forResource: "index", withExtension: "html") else {
            return
        }

        var components = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false)!
        components.queryItems = prefs.asQueryItems()

        if let url = components.url {
            webView?.loadFileURL(url, allowingReadAccessTo: resourceURL.deletingLastPathComponent())
        }
    }

    // MARK: - ScreenSaverView overrides

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        if sheetController == nil {
            sheetController = ConfigureSheetController()
            sheetController?.screenSaverView = self
        }
        return sheetController?.window
    }

    /// Called by ConfigureSheetController after the user saves preferences.
    func reloadWithCurrentPreferences() {
        loadMatrix(with: MatrixPreferences.load())
    }

    override func animateOneFrame() {
        // Animation is driven by the web app's own requestAnimationFrame loop.
    }

    override func startAnimation() {
        super.startAnimation()
        // Resume if the page was suspended (e.g. power nap woke the screensaver briefly)
        webView?.evaluateJavaScript("document.dispatchEvent(new Event('visibilitychange'))", completionHandler: nil)
    }
}
