import Cocoa
import Combine

/// Manages the state of Cut mode, cut items list, and file movement execution.
@MainActor
public final class CutEngine: ObservableObject {
    public static let shared = CutEngine()
    
    @Published public private(set) var cutItems: [URL] = []
    @Published public private(set) var isBusy: Bool = false
    @Published public var isEnabled: Bool = true
    
    private let fileSystemWorker = FileSystemWorker.shared
    private let soundHelper = SoundHelper.shared
    private let contextInspector = ContextInspector.shared
    
    private init() {}
    
    /// Returns true if cut mode currently has items ready to move.
    public var hasItems: Bool {
        return !cutItems.isEmpty
    }
    
    /// Number of items in cut buffer.
    public var count: Int {
        return cutItems.count
    }
    
    /// Stores the selected URLs into the cut buffer and plays distinct cut sound.
    public func cut(items: [URL]) {
        guard !items.isEmpty else { return }
        self.cutItems = items
        soundHelper.playCutSound()
    }
    
    /// Executes the move operation from cut buffer to the target directory.
    public func paste(into targetDirectory: URL) async {
        guard hasItems, !isBusy else { return }
        
        isBusy = true
        let itemsToMove = self.cutItems
        
        do {
            try fileSystemWorker.moveItems(itemsToMove, to: targetDirectory)
            self.cutItems.removeAll()
            soundHelper.playPasteSound()
            contextInspector.refreshFinderView()
        } catch {
            soundHelper.playErrorSound()
        }
        
        isBusy = false
    }
    
    /// Clears cut mode explicitly (e.g. on Escape or normal Copy) and optionally plays sound.
    public func clear(playSound: Bool = false) {
        if hasItems && playSound {
            soundHelper.playCancelSound()
        }
        self.cutItems.removeAll()
    }
}
