import Foundation
import ServiceManagement

/// Helper for managing Launch at Login on macOS 13+ using SMAppService.
@MainActor
public final class LaunchAtLoginHelper: ObservableObject {
    public static let shared = LaunchAtLoginHelper()
    
    @Published public var isEnabled: Bool = false
    
    private init() {
        checkStatus()
    }
    
    /// Checks the current login item status.
    public func checkStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            self.isEnabled = (status == .enabled)
        }
    }
    
    /// Toggles launch at login on/off.
    public func toggle() {
        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.unregister()
                    self.isEnabled = false
                } else {
                    try SMAppService.mainApp.register()
                    self.isEnabled = true
                }
            } catch {
                checkStatus()
            }
        }
    }
}
