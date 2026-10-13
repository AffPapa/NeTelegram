import Darwin
import Foundation

/// Replaces a sensitive file only after its staging file has the required
/// private permissions. Any staging or permission failure leaves the previous
/// destination untouched.
enum AtomicPrivateFile {
    static func replace(
        _ data: Data,
        at destination: URL,
        permissions: Int16 = 0o600,
        prepareStagingFile: ((URL) throws -> Void)? = nil
    ) throws {
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: staging) }

        try data.write(to: staging, options: .atomic)
        if let prepareStagingFile {
            try prepareStagingFile(staging)
        } else {
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: permissions)],
                ofItemAtPath: staging.path
            )
        }
        let result = staging.path.withCString { sourcePath in
            destination.path.withCString { destinationPath in
                Darwin.rename(sourcePath, destinationPath)
            }
        }
        guard result == 0 else {
            let code = POSIXErrorCode(rawValue: errno) ?? .EIO
            throw POSIXError(code)
        }
    }
}
