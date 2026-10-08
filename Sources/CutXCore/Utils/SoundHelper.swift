import Cocoa

/// Provides subtle audio feedback for cut & paste operations.
public final class SoundHelper: @unchecked Sendable {
    public static let shared = SoundHelper()
    
    private init() {}
    
    /// Plays audio feedback when items are cut into the buffer.
    public func playCutSound() {
        if let sound = NSSound(named: "Pop") ?? NSSound(named: "Tink") {
            sound.play()
        }
    }
    
    /// Plays audio feedback when items are successfully moved/pasted.
    public func playPasteSound() {
        if let sound = NSSound(named: "Blow") ?? NSSound(named: "Hero") {
            sound.play()
        }
    }
    
    /// Plays error or cancel audio feedback.
    public func playErrorSound() {
        NSSound.beep()
    }
}
