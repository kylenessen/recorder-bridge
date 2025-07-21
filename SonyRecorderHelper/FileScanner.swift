import Foundation

struct AudioFile {
    let path: String
    let name: String
    let size: Int64
    let lastModified: Date
    let isMP3: Bool
    let isLPCM: Bool
}

protocol FileScannerDelegate: AnyObject {
    func scanDidStart(for device: DetectedDevice)
    func scanDidComplete(for device: DetectedDevice, files: [AudioFile])
    func scanDidFail(for device: DetectedDevice, error: FileScannerError)
}

enum FileScannerError: Error, LocalizedError {
    case deviceNotAccessible(String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case permissionDenied(String)
    case scanInterrupted
    
    var errorDescription: String? {
        switch self {
        case .deviceNotAccessible(let path):
            return "Device at \(path) is not accessible"
        case .insufficientDiskSpace(let required, let available):
            let requiredMB = required / (1024 * 1024)
            let availableMB = available / (1024 * 1024)
            return "Insufficient disk space. Required: \(requiredMB)MB, Available: \(availableMB)MB"
        case .permissionDenied(let path):
            return "Permission denied accessing \(path)"
        case .scanInterrupted:
            return "File scan was interrupted"
        }
    }
}

class FileScanner {
    weak var delegate: FileScannerDelegate?
    private let settings = Settings()
    private var isScanning = false
    
    private let supportedExtensions = ["mp3", "wav", "lpcm"]
    
    func scanDevice(_ device: DetectedDevice) {
        guard !isScanning else {
            print("Scanner is already running")
            return
        }
        
        isScanning = true
        delegate?.scanDidStart(for: device)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let audioFiles = try self.performScan(for: device)
                
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.delegate?.scanDidComplete(for: device, files: audioFiles)
                }
            } catch let error as FileScannerError {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.delegate?.scanDidFail(for: device, error: error)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.delegate?.scanDidFail(for: device, error: .deviceNotAccessible(device.volumePath))
                }
            }
        }
    }
    
    private func performScan(for device: DetectedDevice) throws -> [AudioFile] {
        let deviceURL = URL(fileURLWithPath: device.volumePath)
        
        guard FileManager.default.fileExists(atPath: device.volumePath) else {
            throw FileScannerError.deviceNotAccessible(device.volumePath)
        }
        
        let audioFiles = try scanDirectory(at: deviceURL)
        
        if !audioFiles.isEmpty {
            try validateDiskSpace(for: audioFiles)
        }
        
        return audioFiles
    }
    
    private func scanDirectory(at url: URL) throws -> [AudioFile] {
        var audioFiles: [AudioFile] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .isDirectoryKey
        ], options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
            print("Error accessing \(url.path): \(error)")
            return true
        }) else {
            throw FileScannerError.permissionDenied(url.path)
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .isDirectoryKey
                ])
                
                guard let isDirectory = resourceValues.isDirectory, !isDirectory else {
                    continue
                }
                
                let fileExtension = fileURL.pathExtension.lowercased()
                guard supportedExtensions.contains(fileExtension) else {
                    continue
                }
                
                let fileName = fileURL.lastPathComponent
                let fileSize = resourceValues.fileSize ?? 0
                let modificationDate = resourceValues.contentModificationDate ?? Date()
                
                let audioFile = AudioFile(
                    path: fileURL.path,
                    name: fileName,
                    size: Int64(fileSize),
                    lastModified: modificationDate,
                    isMP3: fileExtension == "mp3",
                    isLPCM: fileExtension == "wav" || fileExtension == "lpcm"
                )
                
                audioFiles.append(audioFile)
                
            } catch {
                print("Error reading file attributes for \(fileURL.path): \(error)")
                continue
            }
        }
        
        print("Found \(audioFiles.count) audio files on device \(url.path)")
        return audioFiles
    }
    
    private func validateDiskSpace(for audioFiles: [AudioFile]) throws {
        guard let inboxFolder = settings.inboxFolder else {
            return
        }
        
        let totalFileSize = audioFiles.reduce(0) { $0 + $1.size }
        
        do {
            let inboxURL = URL(fileURLWithPath: inboxFolder)
            let resourceValues = try inboxURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            
            if let availableSpace = resourceValues.volumeAvailableCapacity {
                let availableBytes = Int64(availableSpace)
                let requiredBytes = totalFileSize + (totalFileSize / 10)
                
                if requiredBytes > availableBytes {
                    throw FileScannerError.insufficientDiskSpace(
                        required: requiredBytes,
                        available: availableBytes
                    )
                }
            }
        } catch let error as FileScannerError {
            throw error
        } catch {
            print("Warning: Could not check available disk space: \(error)")
        }
    }
    
    func stopScanning() {
        isScanning = false
    }
    
    var isScanningInProgress: Bool {
        return isScanning
    }
}