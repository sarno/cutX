import Cocoa
import ApplicationServices

/// Manages macOS Accessibility permissions required for event tapping and UI introspection.
@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var isAccessibilityGranted: Bool = false
    
    private init() {
        checkPermission()
    }
    
    /// Checks whether the application has accessibility trust.
    @discardableResult
    func checkPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        self.isAccessibilityGranted = trusted
        return trusted
    }
    
    /// Requests accessibility permission and optionally prompts the system dialog.
    func requestPermission() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        self.isAccessibilityGranted = trusted
        
        if !trusted {
            openAccessibilitySettings()
        }
    }
    
    /// Opens the macOS System Settings Accessibility pane directly.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
