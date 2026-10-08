import Foundation
import CutXCore

@MainActor
func runTests() {
    print("🧪 Starting CutX Automated Verification Suite...\n")

    var passedCount = 0
    var failedCount = 0

    func assertTest(_ condition: Bool, _ name: String) {
        if condition {
            print("  ✅ PASS: \(name)")
            passedCount += 1
        } else {
            print("  ❌ FAIL: \(name)")
            failedCount += 1
        }
    }

    // MARK: - Test 1: Single File Safe Move
    do {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("Source")
        let targetDir = tempDir.appendingPathComponent("Target")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        let testFile = sourceDir.appendingPathComponent("hello.txt")
        try "Hello CutX".write(to: testFile, atomically: true, encoding: .utf8)
        
        let moved = try FileSystemWorker.shared.moveItems([testFile], to: targetDir)
        
        assertTest(moved.count == 1, "Single file move count == 1")
        assertTest(!FileManager.default.fileExists(atPath: testFile.path), "Source file removed after move")
        assertTest(FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("hello.txt").path), "Target file exists at destination")
    } catch {
        assertTest(false, "Test 1 threw error: \(error)")
    }

    // MARK: - Test 2: File Collision Auto-Increment
    do {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("Source")
        let targetDir = tempDir.appendingPathComponent("Target")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        let existingTargetFile = targetDir.appendingPathComponent("doc.txt")
        try "Original Target Content".write(to: existingTargetFile, atomically: true, encoding: .utf8)
        
        let sourceFile = sourceDir.appendingPathComponent("doc.txt")
        try "New Source Content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let moved = try FileSystemWorker.shared.moveItems([sourceFile], to: targetDir)
        
        assertTest(moved.first?.lastPathComponent == "doc (1).txt", "Duplicate filename auto-incremented to doc (1).txt")
        let original = try String(contentsOf: existingTargetFile, encoding: .utf8)
        assertTest(original == "Original Target Content", "Original file preserved without overwrite")
        let newContent = try String(contentsOf: targetDir.appendingPathComponent("doc (1).txt"), encoding: .utf8)
        assertTest(newContent == "New Source Content", "New file contains correct source data")
    } catch {
        assertTest(false, "Test 2 threw error: \(error)")
    }

    // MARK: - Test 3: Directory Move
    do {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceFolder = tempDir.appendingPathComponent("MyFolder")
        let targetDir = tempDir.appendingPathComponent("TargetDir")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        let nestedFile = sourceFolder.appendingPathComponent("inside.txt")
        try "Folder content".write(to: nestedFile, atomically: true, encoding: .utf8)
        
        let moved = try FileSystemWorker.shared.moveItems([sourceFolder], to: targetDir)
        
        assertTest(moved.count == 1, "Directory move count == 1")
        let targetNestedFile = targetDir.appendingPathComponent("MyFolder/inside.txt")
        assertTest(FileManager.default.fileExists(atPath: targetNestedFile.path), "Nested file preserved inside moved directory")
    } catch {
        assertTest(false, "Test 3 threw error: \(error)")
    }

    // MARK: - Test 4: CutEngine State Lifecycle
    let engine = CutEngine.shared
    engine.clear(playSound: false)
    
    assertTest(!engine.hasItems, "CutEngine initially empty")
    
    let sample = [URL(fileURLWithPath: "/tmp/sample1.txt"), URL(fileURLWithPath: "/tmp/sample2.txt")]
    engine.cut(items: sample)
    
    assertTest(engine.hasItems, "CutEngine has items after cut")
    assertTest(engine.count == 2, "CutEngine count == 2")
    
    engine.clear(playSound: false)
    assertTest(!engine.hasItems, "CutEngine empty after clear")

    print("\n📊 Results: \(passedCount) passed, \(failedCount) failed.")

    if failedCount > 0 {
        exit(1)
    } else {
        print("🎉 All core engine tests passed successfully!\n")
    }
}

runTests()
