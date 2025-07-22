import Foundation
import CryptoKit

protocol FileTransferEngineDelegate: AnyObject {
    func transferDidStart(for device: DetectedDevice, totalFiles: Int)
    func transferDidProgress(for device: DetectedDevice, currentFile: Int, totalFiles: Int, fileName: String)
    func transferDidComplete(for device: DetectedDevice, result: TransferResult)
    func transferDidFail(for device: DetectedDevice, error: TransferError)
}

enum TransferError: Error, LocalizedError {
    case noInboxConfigured
    case inboxNotAccessible(String)
    case copyFailed(String, String)
    case verificationFailed(String)
    case deletionFailed(String)
    case transferCancelled
    
    var errorDescription: String? {
        switch self {
        case .noInboxConfigured:
            return "No inbox folder configured"
        case .inboxNotAccessible(let path):
            return "Inbox folder not accessible: \(path)"
        case .copyFailed(let file, let reason):
            return "Failed to copy \(file): \(reason)"
        case .verificationFailed(let file):
            return "File verification failed for \(file)"
        case .deletionFailed(let file):
            return "Failed to delete original file \(file)"
        case .transferCancelled:
            return "Transfer was cancelled"
        }
    }
}

class FileTransferEngine {
    weak var delegate: FileTransferEngineDelegate?
    private let settings = Settings()
    private var isTransferring = false
    private var shouldCancel = false
    
    func transferFiles(_ audioFiles: [AudioFile], from device: DetectedDevice) async -> TransferResult {
        guard !isTransferring else {
            let error = TransferError.transferCancelled
            await MainActor.run {
                delegate?.transferDidFail(for: device, error: error)
            }
            return TransferResult(success: false, transferredCount: 0, errors: [error.localizedDescription], summary: "Transfer cancelled - already in progress")
        }
        
        isTransferring = true
        shouldCancel = false
        
        defer {
            isTransferring = false
        }
        
        guard let inboxPath = settings.inboxFolder else {
            let error = TransferError.noInboxConfigured
            await MainActor.run {
                delegate?.transferDidFail(for: device, error: error)
            }
            return TransferResult(success: false, transferredCount: 0, errors: [error.localizedDescription], summary: "No inbox folder configured")
        }
        
        let inboxURL = URL(fileURLWithPath: inboxPath)
        guard FileManager.default.fileExists(atPath: inboxPath) else {
            let error = TransferError.inboxNotAccessible(inboxPath)
            await MainActor.run {
                delegate?.transferDidFail(for: device, error: error)
            }
            return TransferResult(success: false, transferredCount: 0, errors: [error.localizedDescription], summary: "Inbox folder not accessible")
        }
        
        await MainActor.run {
            delegate?.transferDidStart(for: device, totalFiles: audioFiles.count)
        }
        
        var transferredCount = 0
        var errors: [String] = []
        
        for (index, audioFile) in audioFiles.enumerated() {
            if shouldCancel {
                errors.append("Transfer cancelled by user")
                break
            }
            
            await MainActor.run {
                delegate?.transferDidProgress(for: device, currentFile: index + 1, totalFiles: audioFiles.count, fileName: audioFile.name)
            }
            
            do {
                let success = try await transferSingleFile(audioFile, to: inboxURL)
                if success {
                    transferredCount += 1
                    print("Successfully transferred: \(audioFile.name)")
                } else {
                    errors.append("Failed to transfer \(audioFile.name)")
                }
            } catch {
                let errorMessage = error.localizedDescription
                errors.append("Error transferring \(audioFile.name): \(errorMessage)")
                print("Transfer error for \(audioFile.name): \(errorMessage)")
            }
        }
        
        let finalResult = await finalizeTransfer(
            device: device,
            totalFiles: audioFiles.count,
            transferredCount: transferredCount,
            errors: errors
        )
        
        await MainActor.run {
            delegate?.transferDidComplete(for: device, result: finalResult)
        }
        
        return finalResult
    }
    
    private func transferSingleFile(_ audioFile: AudioFile, to inboxURL: URL) async throws -> Bool {
        let sourceURL = URL(fileURLWithPath: audioFile.path)
        let destinationURL = generateDestinationURL(for: audioFile.name, in: inboxURL)
        
        return try await performTransferWithRecovery(sourceURL: sourceURL, destinationURL: destinationURL, fileName: audioFile.name)
    }
    
    private func performTransferWithRecovery(sourceURL: URL, destinationURL: URL, fileName: String) async throws -> Bool {
        var copySuccess = false
        var verificationSuccess = false
        
        do {
            copySuccess = try await copyFile(from: sourceURL, to: destinationURL)
            guard copySuccess else {
                throw TransferError.copyFailed(fileName, "Copy operation failed")
            }
            
            verificationSuccess = try await verifyFile(original: sourceURL, copy: destinationURL)
            guard verificationSuccess else {
                cleanupFailedTransfer(at: destinationURL)
                throw TransferError.verificationFailed(fileName)
            }
            
            let deleted = deleteOriginalFile(at: sourceURL)
            guard deleted else {
                print("Warning: File copied and verified but original could not be deleted: \(fileName)")
                throw TransferError.deletionFailed(fileName)
            }
            
            return true
            
        } catch {
            handleTransferError(sourceURL: sourceURL, destinationURL: destinationURL, fileName: fileName, error: error, copySuccess: copySuccess, verificationSuccess: verificationSuccess)
            throw error
        }
    }
    
    private func handleTransferError(sourceURL: URL, destinationURL: URL, fileName: String, error: Error, copySuccess: Bool, verificationSuccess: Bool) {
        print("=== Transfer Error Recovery for \(fileName) ===")
        print("Error: \(error.localizedDescription)")
        print("Copy successful: \(copySuccess)")
        print("Verification successful: \(verificationSuccess)")
        
        if copySuccess && !verificationSuccess {
            print("Cleaning up corrupted copy at destination")
            cleanupFailedTransfer(at: destinationURL)
        } else if copySuccess && verificationSuccess {
            print("Copy and verification succeeded but deletion failed - file remains on both devices")
            print("Source: \(sourceURL.path)")
            print("Destination: \(destinationURL.path)")
        }
        
        print("Original file preserved at: \(sourceURL.path)")
        print("=======================================")
    }
    
    private func cleanupFailedTransfer(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("Cleaned up failed transfer file: \(url.lastPathComponent)")
            }
        } catch {
            print("Warning: Could not clean up failed transfer file \(url.lastPathComponent): \(error)")
        }
    }
    
    private func generateDestinationURL(for fileName: String, in inboxURL: URL) -> URL {
        var destinationURL = inboxURL.appendingPathComponent(fileName)
        var counter = 1
        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let newFileName = "\(baseName)_\(counter).\(fileExtension)"
            destinationURL = inboxURL.appendingPathComponent(newFileName)
            counter += 1
        }
        
        return destinationURL
    }
    
    private func copyFile(from source: URL, to destination: URL) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.copyItem(at: source, to: destination)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func verifyFile(original: URL, copy: URL) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let originalAttributes = try FileManager.default.attributesOfItem(atPath: original.path)
                    let copyAttributes = try FileManager.default.attributesOfItem(atPath: copy.path)
                    
                    guard let originalSize = originalAttributes[.size] as? Int64,
                          let copySize = copyAttributes[.size] as? Int64,
                          originalSize == copySize else {
                        continuation.resume(returning: false)
                        return
                    }
                    
                    let originalChecksum = try self.calculateChecksum(for: original)
                    let copyChecksum = try self.calculateChecksum(for: copy)
                    
                    continuation.resume(returning: originalChecksum == copyChecksum)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func calculateChecksum(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func deleteOriginalFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("Failed to delete original file \(url.path): \(error)")
            return false
        }
    }
    
    func cancelTransfer() {
        shouldCancel = true
    }
    
    var isTransferInProgress: Bool {
        return isTransferring
    }
    
    private func performResourceCleanup(device: DetectedDevice) async {
        print("=== Performing Resource Cleanup for \(device.volumeName) ===")
        
        await cleanupTemporaryFiles()
        
        await syncFileSystem()
        
        await verifyDeviceReadiness(device: device)
        
        print("Resource cleanup completed")
        print("=====================================")
    }
    
    private func cleanupTemporaryFiles() async {
        guard let inboxPath = settings.inboxFolder else { return }
        
        let inboxURL = URL(fileURLWithPath: inboxPath)
        let tempFilePatterns = ["*.tmp", "*.partial", "*~"]
        
        do {
            let inboxContents = try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil, options: [])
            
            for url in inboxContents {
                let fileName = url.lastPathComponent
                let shouldRemove = tempFilePatterns.contains { pattern in
                    let regex = pattern.replacingOccurrences(of: "*", with: ".*")
                    return fileName.range(of: regex, options: .regularExpression) != nil
                }
                
                if shouldRemove {
                    do {
                        try FileManager.default.removeItem(at: url)
                        print("Cleaned up temporary file: \(fileName)")
                    } catch {
                        print("Could not remove temporary file \(fileName): \(error)")
                    }
                }
            }
        } catch {
            print("Could not scan inbox for temporary files: \(error)")
        }
    }
    
    private func syncFileSystem() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                sync()
                print("File system sync completed")
                continuation.resume()
            }
        }
    }
    
    private func verifyDeviceReadiness(device: DetectedDevice) async {
        let deviceURL = URL(fileURLWithPath: device.volumePath)
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: deviceURL.path)
            if let _ = attributes[.size] {
                print("Device \(device.volumeName) is ready for ejection")
            }
        } catch {
            print("Warning: Could not verify device readiness: \(error)")
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        print("Device stabilization period completed")
    }
    
    private func finalizeTransfer(device: DetectedDevice, totalFiles: Int, transferredCount: Int, errors: [String]) async -> TransferResult {
        print("=== Transfer Summary for \(device.volumeName) ===")
        print("Total files to transfer: \(totalFiles)")
        print("Successfully transferred: \(transferredCount)")
        print("Failed transfers: \(errors.count)")
        
        if !errors.isEmpty {
            print("Errors encountered:")
            for (index, error) in errors.enumerated() {
                print("  \(index + 1). \(error)")
            }
        }
        
        let success = errors.isEmpty && transferredCount > 0
        print("Transfer result: \(success ? "SUCCESS" : "FAILED")")
        print("=====================================")
        
        if success {
            await performFinalVerification(device: device, transferredCount: transferredCount)
            await performResourceCleanup(device: device)
        }
        
        return TransferResult(
            success: success,
            transferredCount: transferredCount,
            errors: errors,
            summary: generateTransferSummary(totalFiles: totalFiles, transferredCount: transferredCount, errors: errors)
        )
    }
    
    private func performFinalVerification(device: DetectedDevice, transferredCount: Int) async {
        guard let inboxPath = settings.inboxFolder else { return }
        
        let inboxURL = URL(fileURLWithPath: inboxPath)
        do {
            let inboxContents = try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [])
            let recentFiles = inboxContents.filter { url in
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                    if let creationDate = resourceValues.creationDate {
                        return Date().timeIntervalSince(creationDate) < 300
                    }
                } catch {
                    print("Could not get creation date for \(url.lastPathComponent): \(error)")
                }
                return false
            }
            
            if recentFiles.count >= transferredCount {
                print("Final verification: Found \(recentFiles.count) recently created files in inbox")
            } else {
                print("Final verification warning: Expected \(transferredCount) files, found \(recentFiles.count) recent files")
            }
        } catch {
            print("Final verification failed: Could not read inbox contents: \(error)")
        }
    }
    
    private func generateTransferSummary(totalFiles: Int, transferredCount: Int, errors: [String]) -> String {
        if errors.isEmpty && transferredCount > 0 {
            return "Successfully transferred \(transferredCount) of \(totalFiles) files"
        } else if transferredCount > 0 {
            return "Transferred \(transferredCount) of \(totalFiles) files with \(errors.count) errors"
        } else {
            return "Transfer failed - no files were transferred"
        }
    }
}

struct TransferResult {
    let success: Bool
    let transferredCount: Int
    let errors: [String]
    let summary: String
}