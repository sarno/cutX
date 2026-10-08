---
name: macos-swift-native-dev
description: >-
  Expert guidelines and best practices for developing lightweight, high-performance native macOS
  applications in Swift 6, AppKit, SwiftUI, CoreGraphics Event Taps, Accessibility APIs (AXUIElement),
  AppleScript/ScriptingBridge, and LaunchAtLogin (SMAppService).
---

# macOS Swift Native Development Skill

This skill guides the design, implementation, debugging, and packaging of lightweight native macOS utilities.

## 1. Core Event Tapping (CGEventTap)
* **Creation**: Use `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: ...)` to listen for keyboard events.
* **RunLoop Integration**: Wrap the tap in a `CFMachPortCreateRunLoopSource` and add it to `CFRunLoop.current` or `.main` with mode `.commonModes`.
* **Filtering**: Always check the frontmost application's bundle identifier (`NSWorkspace.shared.frontmostApplication?.bundleIdentifier`). If not `com.apple.finder`, immediately pass through the event unchanged.
* **Consuming Events**: Return `nil` from the tap callback when an event is handled (e.g. `Cmd + X` on file selection) to suppress the default system error beep.

## 2. Accessibility (AXUIElement) & Text-Field Detection
* Before intercepting `Cmd + X` or `Cmd + V`, inspect the focused UI element:
  ```swift
  let systemWide = AXUIElementCreateSystemWide()
  var focusedApp: AnyObject?
  if AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success {
      var focusedElement: AnyObject?
      if AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success {
          var roleValue: AnyObject?
          if AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXRoleAttribute as CFString, &roleValue) == .success,
             let role = roleValue as? String {
              // If role is AXTextField or AXTextArea, DO NOT intercept file cut/paste!
              if role == "AXTextField" || role == "AXTextArea" { return passThrough }
          }
      }
  }
  ```

## 3. AppleScript / Finder Selection & Target Extraction
* Query selected files:
  ```applescript
  tell application "Finder"
      set theSelection to selection as alias list
      set posixPaths to {}
      repeat with anItem in theSelection
          set end of posixPaths to POSIX path of anItem
      end repeat
      return posixPaths
  end tell
  ```
* Query active target directory:
  ```applescript
  tell application "Finder"
      if exists (front Finder window) then
          set targetFolder to target of front Finder window as alias
          return POSIX path of targetFolder
      else
          return POSIX path of (path to desktop folder)
      end if
  end tell
  ```

## 4. Safe File Moving (Same-Volume vs Cross-Volume)
* Always check if source and destination are on the same volume:
  ```swift
  let srcVolume = try sourceURL.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
  let dstVolume = try destURL.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
  ```
* **Same Volume**: Use `FileManager.default.moveItem(at:to:)` (Atomic & Instant).
* **Cross Volume**: Copy item -> Verify file size/integrity -> Remove source item.
* **Collision Handling**: If destination file exists, generate non-colliding name `name (1).ext`.

## 5. Menu Bar Application Lifecycle & Launch at Login
* In `Info.plist`, set `LSUIElement` to `true` (Agent app, no Dock icon).
* Use `NSStatusItem` with `NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)` or SwiftUI `MenuBarExtra`.
* Use `SMAppService.mainApp` for modern login item registration (macOS 13+).
