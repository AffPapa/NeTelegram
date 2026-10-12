import Foundation
import TDLibCBridge

public enum TDLibGatewayError: Error, Equatable {
    case libraryLoad(String)
    case clientCreation
    case requestRejected
}

/// Thin adapter for the pinned TDLib JSON C API. The single receive loop runs
/// on a dedicated Foundation Thread, never on the main or cooperative executor.
public final class TDLibGateway: @unchecked Sendable {
    public typealias UpdateHandler = @Sendable (Data) -> Void

    private let sendLock = NSLock()
    private let receiveLock = NSLock()
    private let stopLock = NSLock()
    private var receiveThread: Thread?
    private var stopping = false

    public init(libraryURL: URL) throws {
        var buffer = [CChar](repeating: 0, count: 1024)
        let ok = libraryURL.path.withCString { path in
            buffer.withUnsafeMutableBufferPointer { output in
                nt_tdlib_load(path, output.baseAddress, output.count)
            }
        }
        guard ok == 1 else {
            let message = String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
            throw TDLibGatewayError.libraryLoad(message)
        }
    }

    public func createClientID() throws -> ClientID {
        let value = nt_tdlib_create_client_id()
        guard value != Int32.min else { throw TDLibGatewayError.clientCreation }
        return ClientID(value)
    }

    public func send(_ json: String, to clientID: ClientID) throws {
        let accepted = json.withCString { request in
            sendLock.lock()
            defer { sendLock.unlock() }
            return nt_tdlib_send(clientID.value, request)
        }
        guard accepted == 1 else { throw TDLibGatewayError.requestRejected }
    }

    public func startSingleReceiveWorker(
        timeoutSeconds: Double = 1,
        onUpdate: @escaping UpdateHandler
    ) {
        stopLock.lock()
        precondition(receiveThread == nil, "TDLib permits exactly one concurrent td_receive worker")
        let worker = Thread { [weak self] in
            guard let self else { return }
            while !self.shouldStop {
                self.receiveLock.lock()
                let result = nt_tdlib_receive_copy(timeoutSeconds)
                let data = result.map { pointer -> Data in
                    defer { nt_tdlib_free(pointer) }
                    return Data(bytes: pointer, count: strlen(pointer))
                }
                self.receiveLock.unlock()
                if let data { onUpdate(data) }
            }
        }
        worker.name = "NeTelegram.TDLib.receive"
        receiveThread = worker
        stopLock.unlock()
        worker.start()
    }

    public func requestWorkerStop() {
        stopLock.lock()
        stopping = true
        stopLock.unlock()
    }

    /// True only after the dedicated thread has returned from its final
    /// bounded td_receive call and exited its loop.
    public var receiveWorkerHasExited: Bool {
        stopLock.lock()
        defer { stopLock.unlock() }
        return receiveThread?.isFinished ?? true
    }

    private var shouldStop: Bool {
        stopLock.lock()
        defer { stopLock.unlock() }
        return stopping
    }
}
