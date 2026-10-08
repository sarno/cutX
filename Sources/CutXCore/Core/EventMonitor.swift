import Cocoa
import CoreGraphics

/// Intercepts keyboard events for Cmd+X, Cmd+V, and Escape when Finder is active.
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
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        guard contextInspector.isFinderFrontmost() else {
            return Unmanaged.passRetained(event)
        }
        
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isCmdDown = flags.contains(.maskCommand)
        let isOptionDown = flags.contains(.maskAlternate)
        let isControlDown = flags.contains(.maskControl)
        let isShiftDown = flags.contains(.maskShift)
        
        let isPureCmd = isCmdDown && !isOptionDown && !isControlDown && !isShiftDown
        
        // Escape to clear
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
        
        // Check text field focus
        if contextInspector.isTextInputFocused() {
            return Unmanaged.passRetained(event)
        }
        
        // Cmd + X
        if keycode == 7 {
            let selectedURLs = contextInspector.getSelectedFinderItems()
            if !selectedURLs.isEmpty {
                Task { @MainActor in
                    CutEngine.shared.cut(items: selectedURLs)
                }
                return nil
            }
        }
        
        // Cmd + V
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
