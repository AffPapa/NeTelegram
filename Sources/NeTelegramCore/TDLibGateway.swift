import Foundation
import TDLibCBridge

public enum TDLibGatewayError: Error, Equatable, Sendable {
    case libraryLoad(String)
    case clientCreation
    case requestRejected
    case receiveCopyFailed
}

enum TDLibReceivePollResult: Sendable {
    case timeout
    case update(Data)
    case copyFailure
}

/// Thin adapter for the pinned TDLib JSON C API. The single receive loop runs
/// on a dedicated Foundation Thread, never on the main or cooperative executor.
public final class TDLibGateway: @unchecked Sendable {
    public typealias UpdateHandler = @Sendable (Data) -> Void

    private let sendLock = NSLock()
    private let receiveLock = NSLock()
    private let stopLock = NSLock()
    private let receivePoll: @Sendable (Double) -> TDLibReceivePollResult
    private var receiveThread: Thread?
    private var stopping = false
    private var receiveFailure: TDLibGatewayError?

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
        receivePoll = { timeoutSeconds in
            var pointer: UnsafeMutablePointer<CChar>?
            let status = nt_tdlib_receive_copy(timeoutSeconds, &pointer)
            switch status {
            case NT_TDLIB_RECEIVE_TIMEOUT:
                return .timeout
            case NT_TDLIB_RECEIVE_UPDATE:
                guard let pointer else { return .copyFailure }
                defer { nt_tdlib_free(pointer) }
                return .update(Data(bytes: pointer, count: strlen(pointer)))
            default:
                return .copyFailure
            }
        }
    }

    init(receivePoll: @escaping @Sendable (Double) -> TDLibReceivePollResult) {
        self.receivePoll = receivePoll
    }

    public func createClientID() throws -> ClientID {
        sendLock.lock()
        defer { sendLock.unlock() }
        if let failure = currentReceiveFailure() { throw failure }
        let value = nt_tdlib_create_client_id()
        guard value != Int32.min else { throw TDLibGatewayError.clientCreation }
        return ClientID(value)
    }

    public func send(_ json: String, to clientID: ClientID) throws {
        sendLock.lock()
        defer { sendLock.unlock() }
        if let failure = currentReceiveFailure() { throw failure }
        let accepted = json.withCString { request in
            return nt_tdlib_send(clientID.value, request)
        }
        guard accepted == 1 else { throw TDLibGatewayError.requestRejected }
    }

    public func startSingleReceiveWorker(
        timeoutSeconds: Double = 1,
        onUpdate: @escaping UpdateHandler,
        onFailure: @escaping @Sendable (TDLibGatewayError) -> Void = { _ in }
    ) {
        stopLock.lock()
        precondition(receiveThread == nil, "TDLib permits exactly one concurrent td_receive worker")
        let worker = Thread { [weak self] in
            guard let self else { return }
            while !self.shouldStop {
                self.receiveLock.lock()
                let result = self.receivePoll(timeoutSeconds)
                self.receiveLock.unlock()
                switch result {
                case .timeout:
                    continue
                case .update(let data):
                    onUpdate(data)
                case .copyFailure:
                    let failure = self.markReceiveFailed()
                    onFailure(failure)
                    return
                }
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

    private func currentReceiveFailure() -> TDLibGatewayError? {
        stopLock.lock()
        defer { stopLock.unlock() }
        return receiveFailure
    }

    private func markReceiveFailed() -> TDLibGatewayError {
        // Serialize the fail-stop state with user sends. Once the failure is
        // visible, no further TDLib command may be accepted by this gateway.
        sendLock.lock()
        stopLock.lock()
        let failure = receiveFailure ?? TDLibGatewayError.receiveCopyFailed
        receiveFailure = failure
        stopping = true
        stopLock.unlock()
        sendLock.unlock()
        return failure
    }
}
