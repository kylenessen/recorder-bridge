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
            return TransferResult(success: false, transferredCount: 0, errors: [error.localizedDescription])
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
            return TransferResult(success: false, transferredCount: 0, errors: [error.localizedDescription])
        }
        
        let inboxURL = URL(fileURLWithPath: inboxPath)
        guard FileManager.default.fileExists(atPath: inboxPath) else {
            let error = TransferError.inboxNotAccessible(inboxPath)
            await MainActor.run {
                delegate?.transferDidFail(for: device, error: error)
            }
            return TransferResult(success: false, transferredCount: 0, errors: [error.localizedDescription])
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
        
        let result = TransferResult(
            success: errors.isEmpty && transferredCount > 0,
            transferredCount: transferredCount,
            errors: errors
        )
        
        await MainActor.run {
            delegate?.transferDidComplete(for: device, result: result)
        }
        
        return result
    }
    
    private func transferSingleFile(_ audioFile: AudioFile, to inboxURL: URL) async throws -> Bool {
        let sourceURL = URL(fileURLWithPath: audioFile.path)
        let destinationURL = generateDestinationURL(for: audioFile.name, in: inboxURL)
        
        let success = try await copyFile(from: sourceURL, to: destinationURL)
        guard success else {
            throw TransferError.copyFailed(audioFile.name, "Copy operation failed")
        }
        
        let verified = try await verifyFile(original: sourceURL, copy: destinationURL)
        guard verified else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw TransferError.verificationFailed(audioFile.name)
        }
        
        let deleted = deleteOriginalFile(at: sourceURL)
        guard deleted else {
            throw TransferError.deletionFailed(audioFile.name)
        }
        
        return true
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
}

struct TransferResult {
    let success: Bool
    let transferredCount: Int
    let errors: [String]
}