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
            set selectedItems to selection as alias list
            set pathList to {}
            repeat with anItem in selectedItems
                set end of pathList to POSIX path of anItem
            end repeat
            return pathList
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
        
        var urls: [URL] = []
        let numberOfItems = descriptor.numberOfItems
        if numberOfItems > 0 {
            for index in 1...numberOfItems {
                if let itemDescriptor = descriptor.atIndex(index),
                   let path = itemDescriptor.stringValue {
                    urls.append(URL(fileURLWithPath: path))
                }
            }
        } else if let singlePath = descriptor.stringValue {
            urls.append(URL(fileURLWithPath: singlePath))
        }
        
        return urls
    }
    
    /// Retrieves the active destination directory URL in Finder (front window target or Desktop).
    public func getActiveFinderTargetDirectory() -> URL? {
        let scriptSource = """
        tell application "Finder"
            if (count of windows) > 0 and exists (front Finder window) then
                try
                    set targetFolder to target of front Finder window as alias
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
        
        if let path = descriptor.stringValue {
            return URL(fileURLWithPath: path)
        }
        
        return nil
    }
}
