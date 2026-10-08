import Cocoa
import AudioToolbox

/// Manages distinct, customizable audio feedback for CutX operations.
public final class SoundHelper: @unchecked Sendable {
    public static let shared = SoundHelper()
    
    public enum SoundTheme: String, CaseIterable, Identifiable {
        case crisp = "Crisp (Tink & Bottle)"
        case subtle = "Subtle (Pop & Purr)"
        case chime = "Chime (Ping & Hero)"
        case muted = "Muted (Silent)"
        
        public var id: String { self.rawValue }
    }
    
    private let userDefaultsKey = "CutX.SoundTheme"
    
    private init() {}
    
    /// Current selected sound theme.
    public var currentTheme: SoundTheme {
        get {
            if let saved = UserDefaults.standard.string(forKey: userDefaultsKey),
               let theme = SoundTheme(rawValue: saved) {
                return theme
            }
            return .crisp
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }
    
    /// Plays distinct sound when items are Cut (Cmd + X).
    public func playCutSound() {
        switch currentTheme {
        case .crisp:
            // "Tink" gives a sharp, metallic scissor-cut sensation
            NSSound(named: "Tink")?.play()
        case .subtle:
            NSSound(named: "Pop")?.play()
        case .chime:
            NSSound(named: "Ping")?.play()
        case .muted:
            break
        }
    }
    
    /// Plays distinct sound when items are Moved/Pasted (Cmd + V).
    public func playPasteSound() {
        switch currentTheme {
        case .crisp:
            // "Bottle" gives a satisfying hollow drop sensation
            NSSound(named: "Bottle")?.play()
        case .subtle:
            NSSound(named: "Purr")?.play()
        case .chime:
            NSSound(named: "Hero")?.play()
        case .muted:
            break
        }
    }
    
    /// Plays subtle sound when Cut is cancelled (Escape).
    public func playCancelSound() {
        switch currentTheme {
        case .crisp, .subtle:
            NSSound(named: "Purr")?.play()
        case .chime:
            NSSound(named: "Basso")?.play()
        case .muted:
            break
        }
    }
    
    /// Plays error audio feedback.
    public func playErrorSound() {
        NSSound.beep()
    }
}
