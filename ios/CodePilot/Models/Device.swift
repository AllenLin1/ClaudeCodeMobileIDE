import SwiftData
import Foundation

@Model
final class DeviceModel {
    @Attribute(.unique) var id: String
    var name: String
    var roomId: String
    var serverUrl: String
    var bridgePublicKey: String
    var secretKey: String
    var publicKey: String
    var isPaired: Bool
    var lastConnected: Date?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        roomId: String,
        serverUrl: String,
        bridgePublicKey: String,
        secretKey: String,
        publicKey: String,
        isPaired: Bool = true,
        lastConnected: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.roomId = roomId
        self.serverUrl = serverUrl
        self.bridgePublicKey = bridgePublicKey
        self.secretKey = secretKey
        self.publicKey = publicKey
        self.isPaired = isPaired
        self.lastConnected = lastConnected
        self.createdAt = createdAt
    }
}
