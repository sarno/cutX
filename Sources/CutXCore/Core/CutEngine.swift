import Cocoa
import Combine

/// Manages the state of Cut mode and clipboard buffer.
@MainActor
public final class CutEngine: ObservableObject {
    public static let shared = CutEngine()
    
    @Published public private(set) var isCutActive: Bool = false
    @Published public private(set) var cutItems: [URL] = []
    @Published public var isEnabled: Bool = true
    
    private let soundHelper = SoundHelper.shared
    
    private init() {}
    
    /// Returns true if cut mode is currently active.
    public var hasItems: Bool {
        return isCutActive
    }
    
    /// Number of items in cut buffer.
    public var count: Int {
        return cutItems.count
    }
    
    /// Marks cut mode as active and plays distinct cut sound.
    public func activateCut() {
        self.isCutActive = true
        soundHelper.playCutSound()
        
        // Refresh cut items from clipboard after brief delay to allow Cmd+C to populate
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            self.refreshCutItemsFromClipboard()
        }
    }
    
    /// Deactivates cut mode (after move or when new copy occurs).
    public func deactivateCut(playFeedback: Bool = false) {
        self.isCutActive = false
        self.cutItems.removeAll()
        if playFeedback {
            soundHelper.playPasteSound()
        }
    }
    
    /// Clears cut mode explicitly (e.g. on Escape) and plays subtle cancel feedback.
    public func clear(playSound: Bool = true) {
        if isCutActive && playSound {
            soundHelper.playCancelSound()
        }
        self.isCutActive = false
        self.cutItems.removeAll()
    }
    
    /// Reads file URLs from system pasteboard.
    public func refreshCutItemsFromClipboard() {
        guard let pasteboard = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return
        }
        self.cutItems = pasteboard
    }
}
