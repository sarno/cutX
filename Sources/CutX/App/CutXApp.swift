import SwiftUI
import AppKit

@main
struct CutXApp: App {
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var cutEngine = CutEngine.shared
    
    init() {
        // Check permission and start event tap
        if PermissionManager.shared.checkPermission() {
            EventMonitor.shared.start()
        }
    }
    
    var body: some Scene {
        MenuBarExtra("CutX", systemImage: cutEngine.hasItems ? "scissors.badge.ellipsis" : "scissors") {
            VStack(alignment: .leading, spacing: 6) {
                if !permissionManager.isAccessibilityGranted {
                    Button("⚠️ Grant Accessibility Permission") {
                        permissionManager.requestPermission()
                    }
                    Divider()
                }
                
                if cutEngine.hasItems {
                    Text("✂️ \(cutEngine.count) item(s) in cut buffer")
                        .font(.caption)
                    
                    Button("Clear Cut Buffer") {
                        cutEngine.clear()
                    }
                    Divider()
                }
                
                Button("Quit CutX") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
