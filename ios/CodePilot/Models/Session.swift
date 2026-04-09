import SwiftData
import Foundation

@Model
final class SessionModel {
    @Attribute(.unique) var id: String
    var name: String
    var cwd: String
    var model: String
    var status: String
    var lastMessage: String?
    var createdAt: Date
    var lastActivity: Date

    @Relationship(deleteRule: .cascade) var messages: [MessageModel]?

    init(
        id: String,
        name: String,
        cwd: String,
        model: String = "default",
        status: String = "active",
        lastMessage: String? = nil,
        createdAt: Date = Date(),
        lastActivity: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.cwd = cwd
        self.model = model
        self.status = status
        self.lastMessage = lastMessage
        self.createdAt = createdAt
        self.lastActivity = lastActivity
    }

    var sessionStatus: SessionStatus {
        SessionStatus(rawValue: status) ?? .paused
    }
}
