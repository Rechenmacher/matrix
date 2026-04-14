import ScreenSaver

/// Persisted user preferences for the screensaver, stored via ScreenSaverDefaults.
struct MatrixPreferences {

    static let bundleID = "com.rezmason.MatrixScreenSaver"

    var version: String      = "classic"
    var effect: String       = "plain"
    var animationSpeed: Double = 1.0
    var bloomStrength: Double  = 0.7

    // MARK: - Persistence

    static func load() -> MatrixPreferences {
        let defaults = ScreenSaverDefaults(forModuleWithName: bundleID)!
        var p = MatrixPreferences()
        if let v = defaults.string(forKey: "version")    { p.version = v }
        if let e = defaults.string(forKey: "effect")     { p.effect = e }
        p.animationSpeed = defaults.double(forKey: "animationSpeed").nonZero ?? 1.0
        p.bloomStrength  = defaults.double(forKey: "bloomStrength").nonZero  ?? 0.7
        return p
    }

    func save() {
        let defaults = ScreenSaverDefaults(forModuleWithName: Self.bundleID)!
        defaults.set(version,       forKey: "version")
        defaults.set(effect,        forKey: "effect")
        defaults.set(animationSpeed, forKey: "animationSpeed")
        defaults.set(bloomStrength,  forKey: "bloomStrength")
        defaults.synchronize()
    }

    // MARK: - URL conversion

    func asQueryItems() -> [URLQueryItem] {
        return [
            URLQueryItem(name: "skipIntro",        value: "true"),
            URLQueryItem(name: "suppressWarnings",  value: "true"),
            URLQueryItem(name: "version",           value: version),
            URLQueryItem(name: "effect",            value: effect),
            URLQueryItem(name: "animationSpeed",    value: String(animationSpeed)),
            URLQueryItem(name: "bloomStrength",     value: String(bloomStrength)),
        ]
    }

    // MARK: - Command-line conversion (passed to companion app)

    func asCommandLineArgs() -> [String] {
        return [
            "--version", version,
            "--effect", effect,
            "--animationSpeed", String(animationSpeed),
            "--bloomStrength", String(bloomStrength),
        ]
    }
}

// MARK: - Helpers

private extension Double {
    /// Returns nil if the value is 0 (i.e. the key was missing from defaults).
    var nonZero: Double? { self == 0 ? nil : self }
}
