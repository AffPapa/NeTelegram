import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum OutgoingPhotoStagerError: Error, Equatable {
    case unreadable
    case tooLarge
    case unsupportedOrAnimated
    case invalidDimensions
}

/// Validates and places a user-selected still image in the owning account's
/// private TDLib files tree while upload is pending.
public enum OutgoingPhotoStager {
    public static let maximumBytes = 10 * 1024 * 1024
    public static let maximumDimension = 10_000

    public static func stage(_ sourceURL: URL, accountFilesDirectory: URL) throws -> URL {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
              let fileSize = attributes[.size] as? NSNumber else { throw OutgoingPhotoStagerError.unreadable }
        guard fileSize.uint64Value <= UInt64(maximumBytes) else { throw OutgoingPhotoStagerError.tooLarge }
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(imageSource) == 1,
              let rawType = CGImageSourceGetType(imageSource) else { throw OutgoingPhotoStagerError.unsupportedOrAnimated }
        let typeIdentifier = rawType as String
        let allowedTypes: [UTType] = [.jpeg, .png, .heic, .tiff, .bmp]
        guard let type = allowedTypes.first(where: { $0.identifier == typeIdentifier }) else {
            throw OutgoingPhotoStagerError.unsupportedOrAnimated
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0,
              width <= maximumDimension, height <= maximumDimension,
              Double(max(width, height)) / Double(min(width, height)) <= 20 else {
            throw OutgoingPhotoStagerError.invalidDimensions
        }
        let data: Data
        do { data = try Data(contentsOf: sourceURL, options: .mappedIfSafe) }
        catch { throw OutgoingPhotoStagerError.unreadable }
        guard data.count <= maximumBytes else { throw OutgoingPhotoStagerError.tooLarge }

        let directory = accountFilesDirectory.appendingPathComponent("Outgoing", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let ext = type.preferredFilenameExtension ?? "img"
            let destination = directory.appendingPathComponent("\(UUID().uuidString.lowercased()).\(ext)")
            try data.write(to: destination, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            return destination
        } catch {
            throw OutgoingPhotoStagerError.unreadable
        }
    }
}
