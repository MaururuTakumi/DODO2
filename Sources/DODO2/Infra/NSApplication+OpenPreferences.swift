import AppKit

extension NSApplication {
    func openPreferences() {
        // Unify all entry points through PreferencesLauncher
        _ = PreferencesLauncher.open()
    }
}
