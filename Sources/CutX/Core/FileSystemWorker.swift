import Foundation

/// Handles safe file system operations including same-volume atomic moves and cross-volume transfers.
final class FileSystemWorker: @unchecked Sendable {
    static let shared = FileSystemWorker()
    private let fileManager = FileManager.default
    
    private init() {}
    
    /// Moves a list of files or folders to the destination directory.
    /// - Parameters:
    ///   - sourceURLs: The URLs of the items to move.
    ///   - destinationDirectory: The folder where items will be moved into.
    /// - Returns: An array of resulting URLs at the destination.
    @discardableResult
    func moveItems(_ sourceURLs: [URL], to destinationDirectory: URL) throws -> [URL] {
        var movedURLs: [URL] = []
        
        for sourceURL in sourceURLs {
            // Guard: ensure source exists
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                continue
            }
            
            // Generate unique target destination URL in case of collision
            let finalDestinationURL = generateUniqueDestinationURL(
                sourceName: sourceURL.lastPathComponent,
                destinationFolder: destinationDirectory
            )
            
            // Skip moving if source and destination are the exact same path
            if sourceURL.path == finalDestinationURL.path {
                continue
            }
            
            // Check if source and destination are on the same volume
            let isSameVolume = areOnSameVolume(source: sourceURL, destination: destinationDirectory)
            
            if isSameVolume {
                // Atomic rename/move on the same filesystem
                try fileManager.moveItem(at: sourceURL, to: finalDestinationURL)
            } else {
                // Cross-volume safe transfer (Copy -> Verify -> Delete source)
                try crossVolumeSafeMove(from: sourceURL, to: finalDestinationURL)
            }
            
            movedURLs.append(finalDestinationURL)
        }
        
        return movedURLs
    }
    
    /// Checks whether two URLs reside on the same filesystem volume.
    private func areOnSameVolume(source: URL, destination: URL) -> Bool {
        do {
            let srcValues = try source.resourceValues(forKeys: [.volumeIdentifierKey])
            let dstValues = try destination.resourceValues(forKeys: [.volumeIdentifierKey])
            
            if let srcVol = srcValues.volumeIdentifier, let dstVol = dstValues.volumeIdentifier {
                return (srcVol as AnyObject).isEqual(dstVol)
            }
        } catch {
            // Fallback: assume different volumes if query fails
        }
        return false
    }
    
    /// Executes a safe cross-volume copy, verifies source and destination size, then removes the source.
    private func crossVolumeSafeMove(from sourceURL: URL, to destinationURL: URL) throws {
        // Step 1: Copy to destination
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // Step 2: Verify copy integrity
        let sourceAttributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let destAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
        
        let sourceSize = (sourceAttributes[.size] as? NSNumber)?.int64Value ?? 0
        let destSize = (destAttributes[.size] as? NSNumber)?.int64Value ?? 0
        
        // Ensure destination exists and size matches (for regular files)
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDir), !isDir.boolValue {
            guard sourceSize == destSize else {
                // Remove corrupted partial copy
                try? fileManager.removeItem(at: destinationURL)
                throw NSError(
                    domain: "CutX.FileSystemWorker",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Cross-volume verification failed for \(sourceURL.lastPathComponent)"]
                )
            }
        }
        
        // Step 3: Remove source safely
        try fileManager.removeItem(at: sourceURL)
    }
    
    /// Generates a non-colliding destination URL if a file with the same name already exists.
    /// Format: `filename (1).ext`, `filename (2).ext`, etc.
    private func generateUniqueDestinationURL(sourceName: String, destinationFolder: URL) -> URL {
        let baseDestination = destinationFolder.appendingPathComponent(sourceName)
        if !fileManager.fileExists(atPath: baseDestination.path) {
            return baseDestination
        }
        
        let fileExtension = (sourceName as NSString).pathExtension
        let baseName = (sourceName as NSString).deletingPathExtension
        
        var counter = 1
        while true {
            let newName: String
            if fileExtension.isEmpty {
                newName = "\(baseName) (\(counter))"
            } else {
                newName = "\(baseName) (\(counter)).\(fileExtension)"
            }
            
            let candidateURL = destinationFolder.appendingPathComponent(newName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }
}
