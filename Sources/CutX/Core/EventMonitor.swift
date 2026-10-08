import Cocoa
import CoreGraphics

/// Intercepts keyboard events for Cmd+X, Cmd+V, and Escape when Finder is active.
final class EventMonitor: @unchecked Sendable {
    static let shared = EventMonitor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let contextInspector = ContextInspector.shared
    
    private init() {}
    
    /// Starts the global event tap listener.
    func start() {
        guard eventTap == nil else { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        // Create an event tap at the annotated session level
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
    func stop() {
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
        
        // 2. Read keycode and modifier flags
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isCmdDown = flags.contains(.maskCommand)
        let isOptionDown = flags.contains(.maskAlternate)
        let isControlDown = flags.contains(.maskControl)
        let isShiftDown = flags.contains(.maskShift)
        
        // Pure Command key modifier (without Option, Control, Shift)
        let isPureCmd = isCmdDown && !isOptionDown && !isControlDown && !isShiftDown
        
        // Keycode 7 = 'X'
        // Keycode 9 = 'V'
        // Keycode 53 = 'Escape'
        
        // 3. Handle Escape: Clear cut buffer if active
        if keycode == 53 && !isCmdDown {
            Task { @MainActor in
                if CutEngine.shared.hasItems {
                    CutEngine.shared.clear()
                }
            }
            return Unmanaged.passRetained(event)
        }
        
        guard isPureCmd else {
            return Unmanaged.passRetained(event)
        }
        
        // Check if user is typing in a text field (e.g. renaming file)
        if contextInspector.isTextInputFocused() {
            return Unmanaged.passRetained(event)
        }
        
        // 4. Handle Cmd + X (Cut)
        if keycode == 7 {
            let selectedURLs = contextInspector.getSelectedFinderItems()
            if !selectedURLs.isEmpty {
                Task { @MainActor in
                    CutEngine.shared.cut(items: selectedURLs)
                }
                // Return nil to consume the event and suppress Finder's error beep
                return nil
            }
        }
        
        // 5. Handle Cmd + V (Paste & Move)
        if keycode == 9 {
            var hasCutBuffer = false
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    hasCutBuffer = CutEngine.shared.hasItems
                    if hasCutBuffer, !CutEngine.shared.isBusy {
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
                        hasCutBuffer = CutEngine.shared.hasItems
                        if hasCutBuffer, !CutEngine.shared.isBusy {
                            if let targetDir = self.contextInspector.getActiveFinderTargetDirectory() {
                                Task { @MainActor in
                                    await CutEngine.shared.paste(into: targetDir)
                                }
                            }
                        }
                    }
                }
            }
            
            if hasCutBuffer {
                return nil
            }
        }
        
        return Unmanaged.passRetained(event)
    }
}
