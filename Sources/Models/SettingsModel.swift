import SwiftUI

@Observable
final class SettingsModel {
    var hoverSensitivity: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: "hoverSensitivity").nonZeroOrDefault(20)) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "hoverSensitivity") }
    }

    var collapseDelay: Double {
        get { UserDefaults.standard.double(forKey: "collapseDelay").nonZeroOrDefault(0.35) }
        set { UserDefaults.standard.set(newValue, forKey: "collapseDelay") }
    }

    var enableNowPlaying: Bool {
        get { UserDefaults.standard.object(forKey: "enableNowPlaying") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enableNowPlaying") }
    }

    var enableShelf: Bool {
        get { UserDefaults.standard.object(forKey: "enableShelf") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enableShelf") }
    }

    var enableWidgets: Bool {
        get { UserDefaults.standard.object(forKey: "enableWidgets") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enableWidgets") }
    }

    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: "launchAtLogin") }
        set { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") }
    }
}

private extension Double {
    func nonZeroOrDefault(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}
