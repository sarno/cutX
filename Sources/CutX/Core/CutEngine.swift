import Cocoa
import Combine

/// Manages the state of currently cut items and orchestrates the cut & paste lifecycle.
@MainActor
final class CutEngine: ObservableObject {
    static let shared = CutEngine()
    
    @Published private(set) var cutItems: [URL] = []
    @Published private(set) var isBusy: Bool = false
    @Published var isEnabled: Bool = true
    
    private let fileSystemWorker = FileSystemWorker.shared
    private let soundHelper = SoundHelper.shared
    
    private init() {}
    
    /// Returns true if there are items currently in the cut buffer.
    var hasItems: Bool {
        return !cutItems.isEmpty
    }
    
    /// Number of items in cut buffer.
    var count: Int {
        return cutItems.count
    }
    
    /// Stores the selected URLs into the cut buffer.
    func cut(items: [URL]) {
        guard !items.isEmpty else { return }
        self.cutItems = items
        soundHelper.playCutSound()
    }
    
    /// Executes the move operation from cut buffer to the target directory.
    func paste(into targetDirectory: URL) async {
        guard hasItems, !isBusy else { return }
        
        isBusy = true
        let itemsToMove = self.cutItems
        
        do {
            try fileSystemWorker.moveItems(itemsToMove, to: targetDirectory)
            self.cutItems.removeAll()
            soundHelper.playPasteSound()
        } catch {
            soundHelper.playErrorSound()
        }
        
        isBusy = false
    }
    
    /// Clears the current cut buffer.
    func clear() {
        self.cutItems.removeAll()
    }
}
