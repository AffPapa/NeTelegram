import Foundation

public enum OutgoingPhotoManifestError: Error, Equatable {
    case invalidManifest
    case fileOutsideOutgoingDirectory
}

/// Durable ownership record for user-selected photos staged for TDLib uploads.
/// It intentionally records ownership only: it never retries a send after restart.
public struct OutgoingPhotoManifestStore: Sendable {
    private struct Manifest: Codable {
        let version: Int
        let fileNames: [String]
    }

    private let manifestURL: URL
    private let outgoingDirectory: URL

    public init(stateDirectory: URL, accountFilesDirectory: URL) {
        manifestURL = stateDirectory.appendingPathComponent("outgoing-photos.json")
        outgoingDirectory = accountFilesDirectory.appendingPathComponent("Outgoing", isDirectory: true)
    }

    public func load() throws -> Set<URL> {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return [] }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
            guard manifest.version == 1 else { throw OutgoingPhotoManifestError.invalidManifest }
            return try Set(manifest.fileNames.map { try validatedURL(outgoingDirectory.appendingPathComponent($0)) })
        } catch let error as OutgoingPhotoManifestError {
            throw error
        } catch {
            throw OutgoingPhotoManifestError.invalidManifest
        }
    }

    public func register(_ url: URL) throws {
        var fileNames = try load().map(\.lastPathComponent)
        let validated = try validatedURL(url)
        if !fileNames.contains(validated.lastPathComponent) { fileNames.append(validated.lastPathComponent) }
        try save(fileNames)
    }

    public func remove(_ url: URL) throws {
        let validated = try validatedURL(url)
        let fileNames = try load().map(\.lastPathComponent).filter { $0 != validated.lastPathComponent }
        try save(fileNames)
    }

    private func validatedURL(_ url: URL) throws -> URL {
        let root = outgoingDirectory.standardizedFileURL
        let candidate = url.standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(prefix),
              candidate.lastPathComponent != ".",
              candidate.lastPathComponent != "..",
              !candidate.lastPathComponent.contains("/"),
              !candidate.lastPathComponent.contains("\\"),
              candidate.resolvingSymlinksInPath() == candidate,
              root.resolvingSymlinksInPath() == root else {
            throw OutgoingPhotoManifestError.fileOutsideOutgoingDirectory
        }
        return candidate
    }

    private func save(_ paths: [String]) throws {
        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: manifestURL.deletingLastPathComponent().path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Manifest(version: 1, fileNames: paths.sorted()))
        try data.write(to: manifestURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: manifestURL.path)
    }
}
