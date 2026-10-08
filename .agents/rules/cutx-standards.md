# CutX Engineering & Safety Standards

## 1. Safety & Data Integrity (Zero Data Loss)
* **Never delete a source file** unless the copy operation to the destination has completed successfully and its integrity is verified.
* In case of file name collisions at the target directory, never overwrite silently; generate auto-incremented names (e.g. `filename (1).ext`) or prompt.

## 2. Privacy & Keystroke Safety
* Event tapping MUST strictly be filtered by `bundleIdentifier == "com.apple.finder"`.
* Never log, store, or transmit keypress events.
* Only intercept `Cmd + X` and `Cmd + V`. All other keystrokes must pass through with zero delay (< 2ms).

## 3. Performance & Memory Footprint
* The daemon / Menu Bar app should idle at < 0.1% CPU and consume < 25MB RAM.
* All I/O operations (file moving, cross-volume transfers) must be executed asynchronously on background `Task` / dispatch queues so the UI and event loop remain 100% responsive.
