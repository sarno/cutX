import Cocoa
import CoreGraphics

/// Intercepts keyboard events for Cmd/Ctrl+X, Cmd/Ctrl+C, Cmd/Ctrl+V, and Escape when Finder is active.
public final class EventMonitor: @unchecked Sendable {
    public static let shared = EventMonitor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let contextInspector = ContextInspector.shared
    
    private init() {}
    
    /// Starts the global event tap listener.
    public func start() {
        guard eventTap == nil else { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    /// Stops the event tap listener.
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
    }
    
    /// Handles intercepted keyboard events.
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Automatically re-enable tap if macOS disabled it due to timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        // 1. Filter: Only handle when Finder is frontmost
        guard contextInspector.isFinderFrontmost() else {
            return Unmanaged.passRetained(event)
        }
        
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        let isCmdDown = flags.contains(.maskCommand)
        let isControlDown = flags.contains(.maskControl)
        let isOptionDown = flags.contains(.maskAlternate)
        let isShiftDown = flags.contains(.maskShift)
        
        // Support both Command and Control modifier (for Fn/Ctrl remappings or Windows users)
        let hasPrimaryModifier = (isCmdDown || isControlDown) && !isOptionDown && !isShiftDown
        
        // Keycodes:
        // Keycode 7 = 'X'
        // Keycode 8 = 'C'
        // Keycode 9 = 'V'
        // Keycode 53 = 'Escape'
        
        // 2. Handle Escape: Clear cut buffer
        if keycode == 53 && !isCmdDown && !isControlDown {
            Task { @MainActor in
                CutEngine.shared.clear(playSound: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        guard hasPrimaryModifier else {
            return Unmanaged.passRetained(event)
        }
        
        // 3. Bypass if user is typing in a text field (e.g. renaming file)
        if contextInspector.isTextInputFocused() {
            return Unmanaged.passRetained(event)
        }
        
        // 4. Handle Cmd/Ctrl + C (Normal Copy): Clear cut buffer so subsequent Paste copies instead of moves
        if keycode == 8 {
            Task { @MainActor in
                CutEngine.shared.clear(playSound: false)
            }
            return Unmanaged.passRetained(event)
        }
        
        // 5. Handle Cmd/Ctrl + X (Cut File/Folder)
        if keycode == 7 {
            let selectedURLs = contextInspector.getSelectedFinderItems()
            if !selectedURLs.isEmpty {
                Task { @MainActor in
                    CutEngine.shared.cut(items: selectedURLs)
                }
                // Return nil to consume the event and silence Finder error beep
                return nil
            }
        }
        
        // 6. Handle Cmd/Ctrl + V (Paste & Move)
        if keycode == 9 {
            var hasCutItems = false
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    hasCutItems = CutEngine.shared.hasItems
                    if hasCutItems, !CutEngine.shared.isBusy {
                        if let targetDir = self.contextInspector.getActiveFinderTargetDirectory() {
                            Task { @MainActor in
                                await CutEngine.shared.paste(into: targetDir)
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated {
                        hasCutItems = CutEngine.shared.hasItems
                        if hasCutItems, !CutEngine.shared.isBusy {
                            if let targetDir = self.contextInspector.getActiveFinderTargetDirectory() {
                                Task { @MainActor in
                                    await CutEngine.shared.paste(into: targetDir)
                                }
                            }
                        }
                    }
                }
            }
            
            if hasCutItems {
                // Consume the event because we executed the real move directly on the filesystem
                return nil
            }
        }
        
        return Unmanaged.passRetained(event)
    }
}
