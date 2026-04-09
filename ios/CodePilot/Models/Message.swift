import SwiftData
import Foundation

@Model
final class MessageModel {
    @Attribute(.unique) var id: String
    var sessionId: String
    var role: String
    var type: String
    var content: String?
    var toolName: String?
    var toolInput: String?
    var toolResult: String?
    var isStreaming: Bool
    var createdAt: Date

    @Relationship(inverse: \SessionModel.messages) var session: SessionModel?

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        role: String,
        type: String,
        content: String? = nil,
        toolName: String? = nil,
        toolInput: String? = nil,
        toolResult: String? = nil,
        isStreaming: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.type = type
        self.content = content
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolResult = toolResult
        self.isStreaming = isStreaming
        self.createdAt = createdAt
    }

    var toolInputDict: [String: Any]? {
        guard let toolInput, let data = toolInput.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
