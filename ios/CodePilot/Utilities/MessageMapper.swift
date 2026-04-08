import Foundation

/// Maps incoming JSON messages from the Bridge (via relay) into UI-friendly view models.
enum MessageMapper {
    struct BridgeMessage: Codable {
        let type: String
        let sessionId: String?
        let message: SDKPayload?
        let requestId: String?
        let toolName: String?
        let input: AnyCodable?
        let sessions: [SessionPayload]?
        let files: [FilePayload]?
        let path: String?
        let content: String?
        let language: String?
        let status: GitStatusPayload?
        let diff: String?
        let commits: [CommitPayload]?
        let tier: String?
        let feature: String?
        let error: String?
        let code: String?
        let name: String?
        let cwd: String?
        let model: String?
        let bridgePublicKey: String?
        let reason: String?
        let messages: [SDKPayload]?

        enum CodingKeys: String, CodingKey {
            case type, sessionId, message, requestId, toolName, input
            case sessions, files, path, content, language, status, diff, commits
            case tier, feature, error, code, name, cwd, model
            case bridgePublicKey, reason, messages
        }
    }

    struct SDKPayload: Codable {
        let type: String?
        let sessionId: String?
        let content: String?
        let toolName: String?
        let toolInput: AnyCodable?
        let toolResult: AnyCodable?
    }

    struct SessionPayload: Codable {
        let id: String
        let name: String
        let cwd: String
        let model: String
        let status: String
        let createdAt: Double?
        let lastActivity: Double?
        let lastMessage: String?
    }

    struct FilePayload: Codable {
        let name: String
        let path: String
        let isDirectory: Bool
        let size: Int
        let modifiedAt: Double?
        let gitStatus: String?
    }

    struct GitStatusPayload: Codable {
        let branch: String
        let ahead: Int
        let behind: Int
        let files: [GitFilePayload]?
    }

    struct GitFilePayload: Codable {
        let path: String
        let status: String
        let staged: Bool
    }

    struct CommitPayload: Codable {
        let hash: String
        let shortHash: String
        let message: String
        let author: String
        let date: String
    }

    static func parse(_ data: Data) -> BridgeMessage? {
        let decoder = JSONDecoder()
        return try? decoder.decode(BridgeMessage.self, from: data)
    }
}

/// Type-erased Codable wrapper for arbitrary JSON values.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) { value = str; return }
        if let int = try? container.decode(Int.self) { value = int; return }
        if let dbl = try? container.decode(Double.self) { value = dbl; return }
        if let bool = try? container.decode(Bool.self) { value = bool; return }
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }; return
        }
        if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map { $0.value }; return
        }
        if container.decodeNil() { value = NSNull(); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let str as String: try container.encode(str)
        case let int as Int: try container.encode(int)
        case let dbl as Double: try container.encode(dbl)
        case let bool as Bool: try container.encode(bool)
        case is NSNull: try container.encodeNil()
        default: try container.encodeNil()
        }
    }
}
