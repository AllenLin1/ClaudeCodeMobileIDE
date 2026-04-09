import Foundation
import Combine

/// Manages the WebSocket connection to the Cloudflare Durable Objects relay.
@MainActor
final class RelayService: ObservableObject {
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected

    enum ConnectionState {
        case disconnected, connecting, connected, error(String)
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectAttempt = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var seq = 0
    private var peerAck = 0

    var onMessage: ((Data) -> Void)?

    private var crypto: CryptoService?
    private var serverUrl: String?
    private var roomId: String?

    func connect(serverUrl: String, roomId: String, role: String, crypto: CryptoService) {
        self.serverUrl = serverUrl
        self.roomId = roomId
        self.crypto = crypto

        let wsUrl = serverUrl
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsUrl)/relay/\(roomId)?role=\(role)") else {
            connectionState = .error("Invalid URL")
            return
        }

        connectionState = .connecting
        urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()

        connectionState = .connected
        isConnected = true
        reconnectAttempt = 0

        receiveMessage()
    }

    func disconnect() {
        reconnectWorkItem?.cancel()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession = nil
        connectionState = .disconnected
        isConnected = false
    }

    func send(_ message: [String: Any]) {
        guard let crypto else { return }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            let encrypted = try crypto.encrypt(jsonString)

            seq += 1
            let envelope: [String: Any] = [
                "seq": seq,
                "ack": peerAck,
                "ts": Int(Date().timeIntervalSince1970 * 1000),
                "encrypted": [
                    "nonce": encrypted.nonce,
                    "ciphertext": encrypted.ciphertext,
                ]
            ]

            let envelopeData = try JSONSerialization.data(withJSONObject: envelope)
            guard let envelopeString = String(data: envelopeData, encoding: .utf8) else { return }

            webSocketTask?.send(.string(envelopeString)) { [weak self] error in
                if let error {
                    print("[relay] Send error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self?.handleDisconnect()
                    }
                }
            }
        } catch {
            print("[relay] Encryption error: \(error)")
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self?.processMessage(message)
                    self?.receiveMessage()
                case .failure(let error):
                    print("[relay] Receive error: \(error.localizedDescription)")
                    self?.handleDisconnect()
                }
            }
        }
    }

    private func processMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if text == "ping" {
                webSocketTask?.send(.string("pong")) { _ in }
                return
            }

            guard let data = text.data(using: .utf8),
                  let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            if let ack = envelope["ack"] as? Int {
                peerAck = ack
            }

            if let encryptedDict = envelope["encrypted"] as? [String: String],
               let nonce = encryptedDict["nonce"],
               let ciphertext = encryptedDict["ciphertext"],
               let crypto {
                let payload = EncryptedPayload(nonce: nonce, ciphertext: ciphertext)
                if let decrypted = try? crypto.decrypt(payload),
                   let decryptedData = decrypted.data(using: .utf8) {
                    onMessage?(decryptedData)
                }
            }

        case .data(let data):
            onMessage?(data)

        @unknown default:
            break
        }
    }

    private func handleDisconnect() {
        isConnected = false
        connectionState = .disconnected
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        reconnectAttempt += 1

        reconnectWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, let serverUrl = self.serverUrl,
                      let roomId = self.roomId, let crypto = self.crypto else { return }
                self.connect(serverUrl: serverUrl, roomId: roomId, role: "app", crypto: crypto)
            }
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
