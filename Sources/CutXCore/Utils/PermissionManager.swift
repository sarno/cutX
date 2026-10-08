import Cocoa
import ApplicationServices

/// Manages macOS Accessibility permissions required for event tapping and UI introspection.
@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public var isAccessibilityGranted: Bool = false
    private var timer: Timer?
    
    private init() {
        checkPermission()
        startPermissionMonitoring()
    }
    
    /// Starts periodic checking so when user grants permission in System Settings, it auto-updates without app restart.
    public func startPermissionMonitoring() {
        guard timer == nil else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.isAccessibilityGranted {
                    let trusted = AXIsProcessTrusted()
                    if trusted {
                        self.isAccessibilityGranted = true
                        EventMonitor.shared.start()
                        self.stopPermissionMonitoring()
                    }
                }
            }
        }
    }
    
    /// Stops the polling timer once permission is confirmed.
    public func stopPermissionMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Checks whether the application has accessibility trust.
    @discardableResult
    public func checkPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        self.isAccessibilityGranted = trusted
        if trusted {
            EventMonitor.shared.start()
            stopPermissionMonitoring()
        } else {
            startPermissionMonitoring()
        }
        return trusted
    }
    
    /// Requests accessibility permission and optionally prompts the system dialog.
    public func requestPermission() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        self.isAccessibilityGranted = trusted
        
        if trusted {
            EventMonitor.shared.start()
            stopPermissionMonitoring()
        } else {
            openAccessibilitySettings()
            startPermissionMonitoring()
        }
    }
    
    /// Opens the macOS System Settings Accessibility pane directly.
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
