import SwiftUI
import AppKit
import CutXCore

@main
struct CutXApp: App {
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var cutEngine = CutEngine.shared
    
    init() {
        if PermissionManager.shared.checkPermission() {
            EventMonitor.shared.start()
        }
    }
    
    var body: some Scene {
        MenuBarExtra("CutX", systemImage: cutEngine.hasItems ? "scissors.badge.ellipsis" : "scissors") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}
