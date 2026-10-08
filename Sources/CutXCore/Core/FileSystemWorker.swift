import Foundation

/// Handles safe file system operations including same-volume atomic moves and cross-volume transfers.
public final class FileSystemWorker: @unchecked Sendable {
    public static let shared = FileSystemWorker()
    private let fileManager = FileManager.default
    
    private init() {}
    
    /// Moves a list of files or folders to the destination directory.
    @discardableResult
    public func moveItems(_ sourceURLs: [URL], to destinationDirectory: URL) throws -> [URL] {
        var movedURLs: [URL] = []
        
        for sourceURL in sourceURLs {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                continue
            }
            
            let finalDestinationURL = generateUniqueDestinationURL(
                sourceName: sourceURL.lastPathComponent,
                destinationFolder: destinationDirectory
            )
            
            if sourceURL.path == finalDestinationURL.path {
                continue
            }
            
            let isSameVolume = areOnSameVolume(source: sourceURL, destination: destinationDirectory)
            
            if isSameVolume {
                try fileManager.moveItem(at: sourceURL, to: finalDestinationURL)
            } else {
                try crossVolumeSafeMove(from: sourceURL, to: finalDestinationURL)
            }
            
            movedURLs.append(finalDestinationURL)
        }
        
        return movedURLs
    }
    
    private func areOnSameVolume(source: URL, destination: URL) -> Bool {
        do {
            let srcValues = try source.resourceValues(forKeys: [.volumeIdentifierKey])
            let dstValues = try destination.resourceValues(forKeys: [.volumeIdentifierKey])
            
            if let srcVol = srcValues.volumeIdentifier, let dstVol = dstValues.volumeIdentifier {
                return (srcVol as AnyObject).isEqual(dstVol)
            }
        } catch {}
        return false
    }
    
    private func crossVolumeSafeMove(from sourceURL: URL, to destinationURL: URL) throws {
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        let sourceAttributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let destAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
        
        let sourceSize = (sourceAttributes[.size] as? NSNumber)?.int64Value ?? 0
        let destSize = (destAttributes[.size] as? NSNumber)?.int64Value ?? 0
        
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDir), !isDir.boolValue {
            guard sourceSize == destSize else {
                try? fileManager.removeItem(at: destinationURL)
                throw NSError(
                    domain: "CutX.FileSystemWorker",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Cross-volume verification failed for \(sourceURL.lastPathComponent)"]
                )
            }
        }
        
        try fileManager.removeItem(at: sourceURL)
    }
    
    public func generateUniqueDestinationURL(sourceName: String, destinationFolder: URL) -> URL {
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
