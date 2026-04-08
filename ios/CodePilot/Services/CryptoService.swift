import Foundation
import CryptoKit

/// E2E encryption using Curve25519 + ChaChaPoly (Apple CryptoKit equivalent of NaCl box).
/// Interoperable with tweetnacl on the bridge side via shared secret derivation.
final class CryptoService {
    private let privateKey: Curve25519.KeyAgreement.PrivateKey
    let publicKey: Curve25519.KeyAgreement.PublicKey
    private var sharedSymmetricKey: SymmetricKey?

    init() {
        if let savedKey = Self.loadKeyFromKeychain() {
            self.privateKey = savedKey
        } else {
            self.privateKey = Curve25519.KeyAgreement.PrivateKey()
            Self.saveKeyToKeychain(privateKey)
        }
        self.publicKey = privateKey.publicKey
    }

    var publicKeyBase64: String {
        publicKey.rawRepresentation.base64EncodedString()
    }

    func deriveSharedKey(peerPublicKeyBase64: String) throws {
        guard let peerKeyData = Data(base64Encoded: peerPublicKeyBase64) else {
            throw CryptoError.invalidKey
        }
        let peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerKeyData)
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerKey)
        self.sharedSymmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: "CodePilot-E2E".data(using: .utf8)!,
            sharedInfo: Data(),
            outputByteCount: 32
        )
    }

    func encrypt(_ plaintext: String) throws -> EncryptedPayload {
        guard let key = sharedSymmetricKey else { throw CryptoError.noSharedKey }
        let data = Data(plaintext.utf8)
        let sealedBox = try ChaChaPoly.seal(data, using: key)
        return EncryptedPayload(
            nonce: sealedBox.nonce.withUnsafeBytes { Data($0).base64EncodedString() },
            ciphertext: sealedBox.combined.base64EncodedString()
        )
    }

    func decrypt(_ payload: EncryptedPayload) throws -> String {
        guard let key = sharedSymmetricKey else { throw CryptoError.noSharedKey }
        guard let combined = Data(base64Encoded: payload.ciphertext) else {
            throw CryptoError.invalidData
        }
        let sealedBox = try ChaChaPoly.SealedBox(combined: combined)
        let decrypted = try ChaChaPoly.open(sealedBox, using: key)
        guard let result = String(data: decrypted, encoding: .utf8) else {
            throw CryptoError.invalidData
        }
        return result
    }

    // MARK: - Keychain

    private static let keychainKey = "com.codepilot.e2e.privatekey"

    private static func saveKeyToKeychain(_ key: Curve25519.KeyAgreement.PrivateKey) {
        let data = key.rawRepresentation
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadKeyFromKeychain() -> Curve25519.KeyAgreement.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }
}

struct EncryptedPayload: Codable {
    let nonce: String
    let ciphertext: String
}

enum CryptoError: Error {
    case invalidKey
    case noSharedKey
    case invalidData
    case encryptionFailed
    case decryptionFailed
}
