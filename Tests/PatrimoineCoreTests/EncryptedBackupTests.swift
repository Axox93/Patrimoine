import XCTest
@testable import PatrimoineCore

final class EncryptedBackupTests: XCTestCase {
    func testRoundTripWithRecoveredKey() throws {
        let key = EncryptedBackup.RecoveryKey()
        let payload = Data("Données financières fictives : 123,45 EUR".utf8)
        let archive = try EncryptedBackup.seal(payload, key: key)
        let recovered = try EncryptedBackup.RecoveryKey(encoded: key.encoded)
        XCTAssertEqual(try EncryptedBackup.open(archive, key: recovered), payload)
        XCTAssertNil(archive.range(of: payload))
    }
    func testWrongKeyAndTamperedArchiveRejected() throws {
        let key = EncryptedBackup.RecoveryKey()
        var archive = try EncryptedBackup.seal(Data("fixture".utf8), key: key)
        XCTAssertThrowsError(try EncryptedBackup.open(archive, key: .init()))
        archive[archive.count - 1] ^= 1
        XCTAssertThrowsError(try EncryptedBackup.open(archive, key: key))
    }
    func testInvalidKeyVersionAndTruncationRejected() throws {
        XCTAssertThrowsError(try EncryptedBackup.RecoveryKey(encoded: "invalid"))
        let key = EncryptedBackup.RecoveryKey()
        let archive = try EncryptedBackup.seal(Data(), key: key)
        XCTAssertThrowsError(try EncryptedBackup.open(Data(archive.dropLast()), key: key))
        XCTAssertThrowsError(try EncryptedBackup.open(Data("unknown format".utf8), key: key))
    }
    func testEveryEncryptionUsesFreshNonce() throws {
        let key = EncryptedBackup.RecoveryKey()
        let payload = Data("fixture".utf8)
        XCTAssertNotEqual(try EncryptedBackup.seal(payload, key: key), try EncryptedBackup.seal(payload, key: key))
    }
}
