import SwiftUI
import AppKit
import CutXCore

/// Menu Bar dropdown UI for CutX.
public struct MenuBarView: View {
    @ObservedObject var cutEngine = CutEngine.shared
    @ObservedObject var permissionManager = PermissionManager.shared
    @ObservedObject var launchHelper = LaunchAtLoginHelper.shared
    @State private var currentTheme: SoundHelper.SoundTheme = SoundHelper.shared.currentTheme
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // App Header & Status
            HStack {
                Text("✂️ CutX")
                    .font(.headline)
                Spacer()
                Text(cutEngine.isEnabled ? "Active" : "Paused")
                    .font(.caption)
                    .foregroundColor(cutEngine.isEnabled ? .green : .secondary)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // Accessibility Permission Warning
            if !permissionManager.isAccessibilityGranted {
                Button(action: {
                    permissionManager.requestPermission()
                }) {
                    Label("Grant Accessibility Permission", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                
                Button(action: {
                    permissionManager.checkPermission()
                    if permissionManager.isAccessibilityGranted {
                        EventMonitor.shared.start()
                    }
                }) {
                    Label("Check Permission Again", systemImage: "arrow.clockwise")
                }
                
                Divider()
            }
            
            // Cut Buffer Status
            if cutEngine.hasItems {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📋 Cut Mode Active (Ready to Move):")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if !cutEngine.cutItems.isEmpty {
                        ForEach(cutEngine.cutItems.prefix(5), id: \.self) { url in
                            Text("• \(url.lastPathComponent)")
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Cancel Cut Mode (Clear)") {
                        cutEngine.clear(playSound: true)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                
                Divider()
            }
            
            // Enable / Pause Toggle
            Button(action: {
                cutEngine.isEnabled.toggle()
                if cutEngine.isEnabled {
                    EventMonitor.shared.start()
                } else {
                    EventMonitor.shared.stop()
                }
            }) {
                Label(cutEngine.isEnabled ? "Pause CutX" : "Resume CutX",
                      systemImage: cutEngine.isEnabled ? "pause.fill" : "play.fill")
            }
            
            // Sound Effects Submenu
            Menu("🔊 Sound: \(currentTheme.rawValue)") {
                ForEach(SoundHelper.SoundTheme.allCases) { theme in
                    Button(action: {
                        SoundHelper.shared.currentTheme = theme
                        self.currentTheme = theme
                        if theme != .muted {
                            SoundHelper.shared.playCutSound()
                        }
                    }) {
                        HStack {
                            Text(theme.rawValue)
                            if theme == currentTheme {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            // Launch at Login Toggle
            Button(action: {
                launchHelper.toggle()
            }) {
                Label("Launch at Login: \(launchHelper.isEnabled ? "On" : "Off")",
                      systemImage: launchHelper.isEnabled ? "checkmark.circle.fill" : "circle")
            }
            
            Divider()
            
            // Links & Quit
            Button(action: {
                if let url = URL(string: "https://github.com/sarno/cutX") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Label("GitHub Repository", systemImage: "link")
            }
            
            Button("Quit CutX") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8)
    }
}
