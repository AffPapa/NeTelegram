import Darwin
import Foundation
import TDLibCBridge

public enum AccountStorageLeaseError: Error, Equatable, LocalizedError {
    case alreadyInUse
    case system(Int32)

    public var errorDescription: String? {
        switch self {
        case .alreadyInUse:
            return "Данные NeTelegram уже используются другим процессом. Закройте второй экземпляр и повторите запуск."
        case .system:
            return "Не удалось безопасно зарезервировать каталог данных NeTelegram. Данные не открыты и не изменены."
        }
    }
}

/// Holds an exclusive process-level lease for the shared account database root.
/// The kernel releases the lock if the app exits or crashes.
public final class AccountStorageLease {
    private let descriptor: Int32

    public init(rootURL: URL) throws {
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)
        let lockURL = rootURL.appendingPathComponent(".account-storage.lock")
        let opened = lockURL.path.withCString {
            Darwin.open($0, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        }
        guard opened >= 0 else { throw AccountStorageLeaseError.system(errno) }
        guard Darwin.fchmod(opened, mode_t(0o600)) == 0 else {
            let code = errno
            Darwin.close(opened)
            throw AccountStorageLeaseError.system(code)
        }
        guard nt_lock_file_exclusive(opened) == 0 else {
            let code = errno
            Darwin.close(opened)
            if code == EWOULDBLOCK || code == EAGAIN {
                throw AccountStorageLeaseError.alreadyInUse
            }
            throw AccountStorageLeaseError.system(code)
        }
        descriptor = opened
    }

    deinit {
        nt_unlock_file(descriptor)
        Darwin.close(descriptor)
    }
}

public enum AccountStorageUpgradeError: Error, Equatable, LocalizedError {
    case invalidBuildNumber
    case corruptState
    case unsupportedStateSchema(Int)
    case downgrade(current: Int, highestOpened: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidBuildNumber:
            return "Сборка NeTelegram не содержит корректный монотонный номер. Каталоги аккаунтов не открыты."
        case .corruptState:
            return "Не удалось проверить версию формата данных NeTelegram. Каталоги аккаунтов не открыты и не сброшены."
        case .unsupportedStateSchema:
            return "Версия NeTelegram не понимает метаданные данных аккаунтов. Установите более новую версию; данные сохранены."
        case let .downgrade(current, highestOpened):
            return "Запуск старой сборки NeTelegram (\(current)) заблокирован после использования сборки \(highestOpened). Установите последнюю версию; данные сохранены."
        }
    }
}

/// Records the highest app build allowed to open the shared account data.
/// Advance this marker before TDLib can open any account database so a crash
/// during an upgrade cannot make an older binary reopen partially migrated DBs.
public enum AccountStorageUpgradeGate {
    private static let stateFilename = ".account-storage-version.json"

    private struct State: Codable {
        let schemaVersion: Int
        let highestOpenedBuild: Int
    }

    public static func prepare(rootURL: URL, bundleBuildNumber: String?) throws -> Int {
        guard let bundleBuildNumber,
              !bundleBuildNumber.isEmpty,
              bundleBuildNumber.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let currentBuild = Int(bundleBuildNumber), currentBuild >= 0 else {
            throw AccountStorageUpgradeError.invalidBuildNumber
        }

        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)
        let stateURL = rootURL.appendingPathComponent(stateFilename)
        let previous: State?
        if FileManager.default.fileExists(atPath: stateURL.path) {
            let data: Data
            do { data = try Data(contentsOf: stateURL) }
            catch { throw AccountStorageUpgradeError.corruptState }
            do { previous = try JSONDecoder().decode(State.self, from: data) }
            catch { throw AccountStorageUpgradeError.corruptState }
            guard previous?.schemaVersion == 1,
                  let highest = previous?.highestOpenedBuild,
                  highest >= 0 else {
                let version = previous?.schemaVersion ?? 0
                if version != 1 { throw AccountStorageUpgradeError.unsupportedStateSchema(version) }
                throw AccountStorageUpgradeError.corruptState
            }
        } else {
            previous = nil
        }

        if let previous, currentBuild < previous.highestOpenedBuild {
            throw AccountStorageUpgradeError.downgrade(
                current: currentBuild,
                highestOpened: previous.highestOpenedBuild
            )
        }
        if let previous, currentBuild <= previous.highestOpenedBuild { return currentBuild }

        let state = State(schemaVersion: 1, highestOpenedBuild: currentBuild)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        try AtomicPrivateFile.replace(data, at: stateURL)
        return currentBuild
    }
}
