import Foundation
import Combine

@MainActor
final class RelayService: ObservableObject {
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected

    enum ConnectionState: Equatable {
        case disconnected, connecting, connected, error(String)
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectAttempt = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var seq = 0
    private var peerAck = 0
    private var isManuallyClosed = false

    var onMessage: ((Data) -> Void)?

    private var crypto: CryptoService?
    private var serverUrl: String?
    private var roomId: String?

    func connect(serverUrl: String, roomId: String, role: String, crypto: CryptoService) {
        disconnect()
        isManuallyClosed = false

        self.serverUrl = serverUrl
        self.roomId = roomId
        self.crypto = crypto

        let wsUrl = serverUrl
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        let urlString = "\(wsUrl)/relay/\(roomId)?role=\(role)"
        print("[relay] Connecting to: \(urlString)")

        guard let url = URL(string: urlString) else {
            connectionState = .error("Invalid relay URL: \(urlString)")
            return
        }

        connectionState = .connecting
        urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()

        sendPing()
    }

    func disconnect() {
        isManuallyClosed = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionState = .disconnected
        isConnected = false
    }

    func send(_ message: [String: Any]) {
        guard isConnected else {
            print("[relay] Cannot send: not connected")
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            seq += 1
            var envelope: [String: Any] = [
                "seq": seq,
                "ack": peerAck,
                "ts": Int(Date().timeIntervalSince1970 * 1000),
            ]

            if let crypto, let encrypted = try? crypto.encrypt(jsonString) {
                envelope["encrypted"] = [
                    "nonce": encrypted.nonce,
                    "ciphertext": encrypted.ciphertext,
                ]
            } else {
                envelope["plain"] = jsonString
            }

            let envelopeData = try JSONSerialization.data(withJSONObject: envelope)
            guard let envelopeString = String(data: envelopeData, encoding: .utf8) else { return }

            print("[relay] Sending: \(message["type"] as? String ?? "unknown")")

            webSocketTask?.send(.string(envelopeString)) { [weak self] error in
                if let error {
                    print("[relay] Send error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self?.handleDisconnect(reason: "Send failed: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("[relay] Send error: \(error)")
        }
    }

    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("[relay] Connection failed: \(error.localizedDescription)")
                    self.handleDisconnect(reason: "Connection failed: \(error.localizedDescription)")
                } else {
                    print("[relay] Connected successfully")
                    self.connectionState = .connected
                    self.isConnected = true
                    self.reconnectAttempt = 0
                    self.receiveMessage()
                }
            }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.processMessage(message)
                    self.receiveMessage()
                case .failure(let error):
                    print("[relay] Receive error: \(error.localizedDescription)")
                    self.handleDisconnect(reason: error.localizedDescription)
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

            if let plain = envelope["plain"] as? String,
               let plainData = plain.data(using: .utf8) {
                onMessage?(plainData)
            } else if let encryptedDict = envelope["encrypted"] as? [String: String],
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

    private func handleDisconnect(reason: String? = nil) {
        isConnected = false
        if let reason {
            connectionState = .error(reason)
        } else {
            connectionState = .disconnected
        }
        if !isManuallyClosed {
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        guard !isManuallyClosed else { return }
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        reconnectAttempt += 1
        print("[relay] Reconnecting in \(delay)s (attempt \(reconnectAttempt))")

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
