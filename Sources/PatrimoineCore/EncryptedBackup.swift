import Foundation
import CryptoKit

/// Versioned authenticated container. The recovery key must be kept separately from the file.
public enum EncryptedBackup {
    private static let header = Data("PATRIMOINE-BACKUP-1\n".utf8)
    public static let maximumPayloadBytes = 25 * 1024 * 1024

    public struct RecoveryKey: Sendable {
        private let bytes: Data
        public init() {
            bytes = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        }
        public init(encoded: String) throws {
            guard let decoded = Data(base64Encoded: encoded), decoded.count == 32 else {
                throw BackupError.invalidKey
            }
            bytes = decoded
        }
        public var encoded: String { bytes.base64EncodedString() }
        fileprivate var symmetricKey: SymmetricKey { SymmetricKey(data: bytes) }
    }

    public enum BackupError: Error, LocalizedError {
        case invalidKey, unsupportedFormat, invalidSize, authenticationFailed
        public var errorDescription: String? {
            switch self {
            case .invalidKey: return "La clé de récupération est invalide."
            case .unsupportedFormat: return "Format de sauvegarde inconnu ou non pris en charge."
            case .invalidSize: return "La taille de la sauvegarde dépasse la limite autorisée."
            case .authenticationFailed: return "Clé incorrecte ou sauvegarde endommagée."
            }
        }
    }

    public static func seal(_ payload: Data, key: RecoveryKey) throws -> Data {
        guard payload.count <= maximumPayloadBytes else { throw BackupError.invalidSize }
        let box = try AES.GCM.seal(payload, using: key.symmetricKey, authenticating: header)
        guard let combined = box.combined else { throw BackupError.authenticationFailed }
        return header + combined
    }

    public static func open(_ archive: Data, key: RecoveryKey) throws -> Data {
        guard archive.count <= maximumPayloadBytes + header.count + 28 else { throw BackupError.invalidSize }
        guard archive.starts(with: header) else { throw BackupError.unsupportedFormat }
        do {
            let box = try AES.GCM.SealedBox(combined: Data(archive.dropFirst(header.count)))
            return try AES.GCM.open(box, using: key.symmetricKey, authenticating: header)
        } catch {
            throw BackupError.authenticationFailed
        }
    }
}
