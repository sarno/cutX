import Cocoa
import ApplicationServices

/// Inspects the current macOS UI context, active Finder selections, and focus elements.
public final class ContextInspector: @unchecked Sendable {
    public static let shared = ContextInspector()
    
    private init() {}
    
    /// Checks if the frontmost active application is Apple Finder.
    public func isFinderFrontmost() -> Bool {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
    }
    
    /// Checks if the currently focused UI element is a text input field (e.g. user is renaming a file).
    public func isTextInputFocused() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppValue: AnyObject?
        
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success,
              let focusedApp = focusedAppValue else {
            return false
        }
        
        var focusedElementValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue) == .success,
              let focusedElement = focusedElementValue else {
            return false
        }
        
        var roleValue: AnyObject?
        if AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXRoleAttribute as CFString, &roleValue) == .success,
           let role = roleValue as? String {
            let textRoles: Set<String> = [
                "AXTextField",
                "AXTextArea",
                "AXSearchField",
                "AXComboBox"
            ]
            if textRoles.contains(role) {
                return true
            }
        }
        
        return false
    }
    
    /// Retrieves the list of currently selected file and folder URLs in Finder.
    public func getSelectedFinderItems() -> [URL] {
        let scriptSource = """
        tell application "Finder"
            set sel to selection
            set strList to ""
            repeat with itemRef in sel
                try
                    set strList to strList & (POSIX path of (itemRef as alias)) & linefeed
                end try
            end repeat
            return strList
        end tell
        """
        
        guard let script = NSAppleScript(source: scriptSource) else {
            return []
        }
        
        var errorDict: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorDict)
        
        if errorDict != nil {
            return []
        }
        
        guard let outputString = descriptor.stringValue else {
            return []
        }
        
        let paths = outputString
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return paths.map { URL(fileURLWithPath: $0) }
    }
    
    /// Retrieves the active destination directory URL in Finder (front window target or Desktop).
    public func getActiveFinderTargetDirectory() -> URL? {
        let scriptSource = """
        tell application "Finder"
            if (count of Finder windows) > 0 and exists (front Finder window) then
                try
                    set targetFolder to (target of front Finder window) as alias
                    return POSIX path of targetFolder
                on error
                    return POSIX path of (path to desktop folder)
                end try
            else
                return POSIX path of (path to desktop folder)
            end if
        end tell
        """
        
        guard let script = NSAppleScript(source: scriptSource) else {
            return nil
        }
        
        var errorDict: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorDict)
        
        if let path = descriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        
        return nil
    }
    
    /// Tells Finder to refresh / update its view after file operations.
    public func refreshFinderView() {
        let scriptSource = """
        tell application "Finder"
            try
                if (count of Finder windows) > 0 and exists (front Finder window) then
                    update front Finder window
                else
                    update desktop
                end if
            end try
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var errorDict: NSDictionary?
            script.executeAndReturnError(&errorDict)
        }
    }
}
