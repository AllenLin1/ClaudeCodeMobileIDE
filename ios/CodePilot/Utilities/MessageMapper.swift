import Foundation

enum MessageMapper {
    struct BridgeMessage {
        let type: String
        let sessionId: String?
        let content: String?
        let errorMessage: String?
        let requestId: String?
        let toolName: String?
        let toolInput: [String: Any]?
        let toolResult: String?
        let sdkMessage: SDKPayload?
        let sessions: [SessionPayload]?
        let files: [FilePayload]?
        let path: String?
        let language: String?
        let diff: String?
        let commits: [CommitPayload]?
        let tier: String?
        let feature: String?
        let code: String?
        let name: String?
        let cwd: String?
        let model: String?
        let bridgePublicKey: String?
        let originalSessionId: String?
        let messages: [[String: Any]]?
    }

    struct SDKPayload {
        let type: String?
        let sessionId: String?
        let content: String?
        let toolName: String?
        let toolInput: [String: Any]?
    }

    struct SessionPayload {
        let id: String
        let name: String
        let cwd: String
        let model: String
        let status: String
        let lastMessage: String?
    }

    struct FilePayload {
        let name: String
        let path: String
        let isDirectory: Bool
        let size: Int
        let gitStatus: String?
    }

    struct CommitPayload {
        let hash: String
        let shortHash: String
        let message: String
        let author: String
        let date: String
    }

    static func parse(_ data: Data) -> BridgeMessage? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        let sdkPayload: SDKPayload? = {
            guard let msg = json["message"] as? [String: Any] else { return nil }
            return SDKPayload(
                type: msg["type"] as? String,
                sessionId: msg["sessionId"] as? String,
                content: msg["content"] as? String,
                toolName: msg["toolName"] as? String,
                toolInput: msg["toolInput"] as? [String: Any]
            )
        }()

        let sessions: [SessionPayload]? = (json["sessions"] as? [[String: Any]])?.compactMap { s in
            guard let id = s["id"] as? String,
                  let name = s["name"] as? String else { return nil }
            return SessionPayload(
                id: id, name: name,
                cwd: s["cwd"] as? String ?? "",
                model: s["model"] as? String ?? "default",
                status: s["status"] as? String ?? "paused",
                lastMessage: s["lastMessage"] as? String
            )
        }

        let files: [FilePayload]? = (json["files"] as? [[String: Any]])?.compactMap { f in
            guard let name = f["name"] as? String,
                  let path = f["path"] as? String else { return nil }
            return FilePayload(
                name: name, path: path,
                isDirectory: f["isDirectory"] as? Bool ?? false,
                size: f["size"] as? Int ?? 0,
                gitStatus: f["gitStatus"] as? String
            )
        }

        let commits: [CommitPayload]? = (json["commits"] as? [[String: Any]])?.compactMap { c in
            guard let hash = c["hash"] as? String else { return nil }
            return CommitPayload(
                hash: hash,
                shortHash: c["shortHash"] as? String ?? String(hash.prefix(7)),
                message: c["message"] as? String ?? "",
                author: c["author"] as? String ?? "",
                date: c["date"] as? String ?? ""
            )
        }

        return BridgeMessage(
            type: type,
            sessionId: json["sessionId"] as? String,
            content: json["content"] as? String,
            errorMessage: json["errorMessage"] as? String,
            requestId: json["requestId"] as? String,
            toolName: json["toolName"] as? String,
            toolInput: json["toolInput"] as? [String: Any],
            toolResult: json["toolResult"] as? String,
            sdkMessage: sdkPayload,
            sessions: sessions,
            files: files,
            path: json["path"] as? String,
            language: json["language"] as? String,
            diff: json["diff"] as? String,
            commits: commits,
            tier: json["tier"] as? String,
            feature: json["feature"] as? String,
            code: json["code"] as? String,
            name: json["name"] as? String,
            cwd: json["cwd"] as? String,
            model: json["model"] as? String,
            bridgePublicKey: json["bridgePublicKey"] as? String,
            originalSessionId: json["originalSessionId"] as? String,
            messages: json["messages"] as? [[String: Any]]
        )
    }
}
