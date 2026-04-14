import Cocoa
import ScreenSaver

/// Preferences panel shown when the user clicks "Screen Saver Options…" in System Settings.
class ConfigureSheetController: NSWindowController {

    weak var screenSaverView: MatrixScreenSaverView?

    // MARK: - Outlets

    @IBOutlet weak var versionPopUp: NSPopUpButton!
    @IBOutlet weak var effectPopUp: NSPopUpButton!
    @IBOutlet weak var animationSpeedSlider: NSSlider!
    @IBOutlet weak var bloomStrengthSlider: NSSlider!
    @IBOutlet weak var animationSpeedLabel: NSTextField!
    @IBOutlet weak var bloomStrengthLabel: NSTextField!

    // MARK: - Available options (mirrors config.js)

    private let versions = ["classic", "3d", "operator", "nightmare", "paradise",
                            "resurrections", "trinity", "megacity", "operator",
                            "palimpsest", "twilight", "morpheus", "bugs"]
    private let effects  = ["plain", "pride", "stripes", "image", "mirror", "none"]

    // MARK: - Init (programmatic — no xib needed)

    convenience init() {
        // Build the preferences window entirely in code so there's no .xib dependency.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 220),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Matrix Screensaver Options"
        self.init(window: window)
        buildUI()
        populateFromPreferences()
    }

    // MARK: - UI construction

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let versionLabel  = label("Version:")
        let effectLabel   = label("Effect:")
        let speedLabel    = label("Animation speed:")
        let bloomLabel    = label("Bloom strength:")

        let versionPop = NSPopUpButton(frame: .zero, pullsDown: false)
        versionPop.addItems(withTitles: versions)
        versionPopUp = versionPop

        let effectPop = NSPopUpButton(frame: .zero, pullsDown: false)
        effectPop.addItems(withTitles: effects)
        effectPopUp = effectPop

        let speedSlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 3.0,
                                   target: self, action: #selector(sliderChanged))
        animationSpeedSlider = speedSlider

        let bloomSlider = NSSlider(value: 0.7, minValue: 0.0, maxValue: 1.0,
                                   target: self, action: #selector(sliderChanged))
        bloomStrengthSlider = bloomSlider

        let speedVal = label("1.0")
        animationSpeedLabel = speedVal

        let bloomVal = label("0.7")
        bloomStrengthLabel = bloomVal

        let ok     = NSButton(title: "OK",     target: self, action: #selector(okClicked))
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        ok.keyEquivalent = "\r"

        let views: [NSView] = [versionLabel, versionPop, effectLabel, effectPop,
                                speedLabel, speedSlider, speedVal,
                                bloomLabel, bloomSlider, bloomVal, ok, cancel]
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        let m: CGFloat = 20
        NSLayoutConstraint.activate([
            versionLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: m),
            versionLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: m),
            versionPop.leadingAnchor.constraint(equalTo: versionLabel.trailingAnchor, constant: 8),
            versionPop.centerYAnchor.constraint(equalTo: versionLabel.centerYAnchor),
            versionPop.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -m),

            effectLabel.leadingAnchor.constraint(equalTo: versionLabel.leadingAnchor),
            effectLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 14),
            effectPop.leadingAnchor.constraint(equalTo: effectLabel.trailingAnchor, constant: 8),
            effectPop.centerYAnchor.constraint(equalTo: effectLabel.centerYAnchor),
            effectPop.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -m),

            speedLabel.leadingAnchor.constraint(equalTo: versionLabel.leadingAnchor),
            speedLabel.topAnchor.constraint(equalTo: effectLabel.bottomAnchor, constant: 14),
            speedSlider.leadingAnchor.constraint(equalTo: speedLabel.trailingAnchor, constant: 8),
            speedSlider.centerYAnchor.constraint(equalTo: speedLabel.centerYAnchor),
            speedSlider.trailingAnchor.constraint(equalTo: speedVal.leadingAnchor, constant: -8),
            speedVal.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -m),
            speedVal.centerYAnchor.constraint(equalTo: speedLabel.centerYAnchor),
            speedVal.widthAnchor.constraint(equalToConstant: 32),

            bloomLabel.leadingAnchor.constraint(equalTo: versionLabel.leadingAnchor),
            bloomLabel.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 14),
            bloomSlider.leadingAnchor.constraint(equalTo: bloomLabel.trailingAnchor, constant: 8),
            bloomSlider.centerYAnchor.constraint(equalTo: bloomLabel.centerYAnchor),
            bloomSlider.trailingAnchor.constraint(equalTo: bloomVal.leadingAnchor, constant: -8),
            bloomVal.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -m),
            bloomVal.centerYAnchor.constraint(equalTo: bloomLabel.centerYAnchor),
            bloomVal.widthAnchor.constraint(equalToConstant: 32),

            ok.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -m),
            ok.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -m),
            cancel.trailingAnchor.constraint(equalTo: ok.leadingAnchor, constant: -8),
            cancel.centerYAnchor.constraint(equalTo: ok.centerYAnchor),
        ])
    }

    private func label(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.alignment = .right
        return f
    }

    // MARK: - Actions

    @objc private func sliderChanged(_ sender: NSSlider) {
        let formatted = String(format: "%.2f", sender.doubleValue)
        if sender === animationSpeedSlider { animationSpeedLabel.stringValue = formatted }
        if sender === bloomStrengthSlider  { bloomStrengthLabel.stringValue  = formatted }
    }

    @objc private func okClicked() {
        var prefs = MatrixPreferences()
        prefs.version       = versionPopUp.titleOfSelectedItem ?? "classic"
        prefs.effect        = effectPopUp.titleOfSelectedItem  ?? "plain"
        prefs.animationSpeed = animationSpeedSlider.doubleValue
        prefs.bloomStrength  = bloomStrengthSlider.doubleValue
        prefs.save()
        screenSaverView?.reloadWithCurrentPreferences()
        NSApp.endSheet(window!)
    }

    @objc private func cancelClicked() {
        NSApp.endSheet(window!)
    }

    // MARK: - Populate

    private func populateFromPreferences() {
        let prefs = MatrixPreferences.load()
        versionPopUp?.selectItem(withTitle: prefs.version)
        effectPopUp?.selectItem(withTitle: prefs.effect)
        animationSpeedSlider?.doubleValue = prefs.animationSpeed
        bloomStrengthSlider?.doubleValue  = prefs.bloomStrength
        animationSpeedLabel?.stringValue  = String(format: "%.2f", prefs.animationSpeed)
        bloomStrengthLabel?.stringValue   = String(format: "%.2f", prefs.bloomStrength)
    }
}
