import Foundation

/// Immutable Foundation JSON object decoded before an event is delivered to the
/// AppKit main actor. Callers must treat the object graph as read-only.
public struct TDLibJSONDocument: @unchecked Sendable {
    public let object: [String: Any]
    let wasDecodedOnMainThread: Bool

    private init(object: [String: Any], wasDecodedOnMainThread: Bool) {
        self.object = object
        self.wasDecodedOnMainThread = wasDecodedOnMainThread
    }

    public static func decodeOffMainActor(_ data: Data) async throws -> Self {
        try await Task.detached(priority: .userInitiated) {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw TDLibJSONDocumentError.topLevelValueIsNotObject
            }
            return Self(object: object, wasDecodedOnMainThread: currentThreadIsMain())
        }.value
    }

    private static func currentThreadIsMain() -> Bool { Thread.isMainThread }
}

public enum TDLibJSONDocumentError: Error {
    case topLevelValueIsNotObject
}
