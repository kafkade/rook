import Foundation
import Security
import RookKit

enum StorageFailure: LocalizedError {
    case message(String)
    case invalidKey

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        case .invalidKey: "The saved device key is invalid. The database has not been changed. Restore a passphrase-encrypted backup."
        }
    }
}

enum DeviceKey {
    private static let service = "dev.rook.prototype.database.v1"

    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func read(account: String) throws -> Data? {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw StorageFailure.message(
                "The device key is unavailable (Keychain \(status)). Unlock your device and try again."
            )
        }
        guard let key = result as? Data, key.count == 32 else {
            throw StorageFailure.invalidKey
        }
        return key
    }

    static func generate() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, address)
        }
        guard status == errSecSuccess else {
            throw StorageFailure.message("A secure device key could not be generated.")
        }
        return Data(bytes)
    }

    static func save(_ key: Data, account: String) throws {
        var request = query(account)
        request[kSecValueData as String] = key
        request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(request as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StorageFailure.message(
                "The device key could not be saved (Keychain \(status)). Existing keys were not replaced."
            )
        }
    }

    static func replaceInvalidKeyAfterValidatedRestore(_ key: Data, account: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query(account) as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw StorageFailure.message("The recovered key could not be saved (Keychain \(status)).")
        }
    }
}

enum EngineCommand: Sendable {
    case saveRoutine(String?, String, [ExerciseDraft])
    case deleteRoutine(String)
    case startWorkout(String)
    case updateSet(String, Double, WeightUnit, UInt32, Bool?)
    case addSet(String)
    case setCompleted(String, Bool)
    case removeSet(String)
    case adjustRest(UInt32)
    case skipRest
    case finish
    case discard
    case deleteWorkout(String)
    case settings(WeightUnit, Bool)
}

struct StoreUpdate: Sendable {
    let sequence: UInt64
    let snapshot: Snapshot
}

actor RookRepository {
    private var engine: RookEngine?
    private var sequence: UInt64 = 0
    private var context: (directory: URL, database: URL, account: String)?

    private func location() throws -> (directory: URL, database: URL, account: String) {
        if let context { return context }
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        var directory = support.appendingPathComponent("Rook", isDirectory: true)
        var account = "database-key"
        #if DEBUG
        if let testID = ProcessInfo.processInfo.environment["ROOK_TEST_ID"] {
            guard let uuid = UUID(uuidString: testID) else {
                throw StorageFailure.message("Invalid isolated test-store identifier.")
            }
            directory = support.appendingPathComponent("RookUITests", isDirectory: true)
                .appendingPathComponent(uuid.uuidString, isDirectory: true)
            account = "test-\(uuid.uuidString)"
        }
        #endif
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let value = (directory, directory.appendingPathComponent("rook.sqlite"), account)
        context = value
        return value
    }

    private func update(_ snapshot: Snapshot) -> StoreUpdate {
        sequence += 1
        return StoreUpdate(sequence: sequence, snapshot: snapshot)
    }

    func open() throws -> StoreUpdate {
        if let engine { return update(try engine.readSnapshot()) }
        let context = try location()
        let key: Data
        if let existing = try DeviceKey.read(account: context.account) {
            key = existing
        } else {
            guard !FileManager.default.fileExists(atPath: context.database.path) else {
                throw StorageFailure.message(
                    "This encrypted database has no device key. It has not been changed. Restore a passphrase-encrypted backup to recover."
                )
            }
            key = try DeviceKey.generate()
            try DeviceKey.save(key, account: context.account)
        }
        let opened = try RookEngine(path: context.database.path, key: key)
        let snapshot = try opened.readSnapshot()
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: context.database.path
        )
        engine = opened
        return update(snapshot)
    }

    func close() throws {
        if let engine { try engine.close() }
        engine = nil
    }

    func perform(_ command: EngineCommand) throws -> StoreUpdate {
        guard let engine else {
            throw StorageFailure.message("Rook is locked. Unlock the device and reopen the app.")
        }
        let snapshot: Snapshot
        switch command {
        case .saveRoutine(let id, let name, let exercises):
            snapshot = try engine.saveRoutine(id: id, name: name, exercises: exercises)
        case .deleteRoutine(let id): snapshot = try engine.deleteRoutine(id: id)
        case .startWorkout(let id): snapshot = try engine.startWorkout(routineId: id)
        case .updateSet(let id, let weight, let unit, let reps, let completed):
            snapshot = try engine.updateSet(setId: id, weight: weight, unit: unit, reps: reps, completed: completed)
        case .addSet(let id): snapshot = try engine.addSet(exerciseId: id)
        case .setCompleted(let id, let completed): snapshot = try engine.setCompleted(setId: id, completed: completed)
        case .removeSet(let id): snapshot = try engine.removeSet(setId: id)
        case .adjustRest(let seconds): snapshot = try engine.adjustRest(additionalSeconds: seconds)
        case .skipRest: snapshot = try engine.skipRest()
        case .finish: snapshot = try engine.finishWorkout()
        case .discard: snapshot = try engine.discardWorkout()
        case .deleteWorkout(let id): snapshot = try engine.deleteWorkout(id: id)
        case .settings(let unit, let alerts): snapshot = try engine.updateSettings(unit: unit, restAlerts: alerts)
        }
        return update(snapshot)
    }

    func export(passphrase: String) throws -> Data {
        guard let engine else { throw StorageFailure.message("Unlock Rook before creating a backup.") }
        return try engine.exportBackup(passphrase: passphrase)
    }

    func readBackup(at url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= 65 * 1024 * 1024 else {
            throw StorageFailure.message("Choose a backup no larger than 65 MiB.")
        }
        let limit = 65 * 1024 * 1024
        let handle = try FileHandle(forReadingFrom: url)
        var data = Data()
        do {
            while data.count <= limit {
                let remaining = min(1024 * 1024, limit + 1 - data.count)
                guard let chunk = try handle.read(upToCount: remaining), !chunk.isEmpty else { break }
                data.append(chunk)
            }
            guard data.count <= limit else {
                throw StorageFailure.message("The backup exceeds the 65 MiB file limit.")
            }
        } catch let readError {
            do { try handle.close() }
            catch let closeError {
                throw StorageFailure.message(
                    "Backup read failed: \(readError.localizedDescription). Closing the file also failed: \(closeError.localizedDescription)."
                )
            }
            throw readError
        }
        try handle.close()
        return data
    }

    func restore(data: Data, passphrase: String, confirmed: Bool) throws -> StoreUpdate {
        guard confirmed else { throw StorageFailure.message("Confirm replacement before restoring.") }
        if let engine {
            return update(try engine.restoreBackup(
                ciphertext: data, passphrase: passphrase, confirmed: true
            ))
        }
        let context = try location()
        let existingKey: Data?
        var invalidKey = false
        do { existingKey = try DeviceKey.read(account: context.account) }
        catch StorageFailure.invalidKey { existingKey = nil; invalidKey = true }
        let key = try existingKey ?? DeviceKey.generate()
        let temporary = context.directory.appendingPathComponent("restore-\(UUID().uuidString).sqlite")
        do {
            // Decryption and schema validation happen before the current file or key changes.
            let prepared = try RookEngine.createRestored(
                path: temporary.path, key: key, ciphertext: data, passphrase: passphrase
            )
            try prepared.close()
            if invalidKey {
                try DeviceKey.replaceInvalidKeyAfterValidatedRestore(key, account: context.account)
            } else if existingKey == nil {
                try DeviceKey.save(key, account: context.account)
            }
            if FileManager.default.fileExists(atPath: context.database.path) {
                _ = try FileManager.default.replaceItemAt(context.database, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: context.database)
            }
            return try open()
        } catch {
            if FileManager.default.fileExists(atPath: temporary.path) {
                do { try FileManager.default.removeItem(at: temporary) }
                catch let cleanup {
                    throw StorageFailure.message(
                        "Restore failed: \(error.localizedDescription). Temporary-file cleanup also failed: \(cleanup.localizedDescription)."
                    )
                }
            }
            throw error
        }
    }
}
