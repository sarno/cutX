import SwiftUI
import AppKit

@main
struct CutXApp: App {
    // We can use SwiftUI's modern MenuBarExtra for the Menu Bar interface
    var body: some Scene {
        MenuBarExtra("CutX", systemImage: "scissors") {
            VStack {
                Text("CutX — Ready")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Divider()
                
                Button("Quit CutX") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(8)
        }
        .menuBarExtraStyle(.menu)
    }
}
