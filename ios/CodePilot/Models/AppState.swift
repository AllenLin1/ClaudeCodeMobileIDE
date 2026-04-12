import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var connectionError: String?
    @Published var currentTier: SubscriptionTier = .free
    @Published var remainingFreePrompts: Int = 10
    @Published var deviceName: String = ""
    @Published var pairedDeviceId: String?

    let relayService: RelayService
    let licensingService: LicensingService
    let subscriptionService: RevenueCatService
    let cryptoService: CryptoService

    private var relayCancellable: AnyCancellable?
    private var relayConnCancellable: AnyCancellable?

    enum ConnectionStatus: String {
        case connected, connecting, disconnected, error
    }

    enum SubscriptionTier: String, Codable {
        case free, pro, expired
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.cryptoService = CryptoService()
        self.relayService = RelayService()
        self.licensingService = LicensingService()
        self.subscriptionService = RevenueCatService()

        self.pairedDeviceId = UserDefaults.standard.string(forKey: "roomId")

        relayCancellable = relayService.$connectionState.receive(on: RunLoop.main).sink { [weak self] state in
            guard let self else { return }
            switch state {
            case .connected:
                self.connectionStatus = .connected
                self.isConnected = true
                self.connectionError = nil
            case .connecting:
                self.connectionStatus = .connecting
                self.isConnected = false
                self.connectionError = nil
            case .disconnected:
                self.connectionStatus = .disconnected
                self.isConnected = false
            case .error(let msg):
                self.connectionStatus = .error
                self.isConnected = false
                self.connectionError = msg
            }
        }
    }

    func completeOnboarding(roomId: String, serverUrl: String, bridgePublicKey: String) {
        pairedDeviceId = roomId

        UserDefaults.standard.set(roomId, forKey: "roomId")
        UserDefaults.standard.set(serverUrl, forKey: "serverUrl")
        UserDefaults.standard.set(bridgePublicKey, forKey: "bridgePublicKey")

        hasCompletedOnboarding = true

        connect()
    }

    func connect() {
        guard let roomId = UserDefaults.standard.string(forKey: "roomId"),
              let serverUrl = UserDefaults.standard.string(forKey: "serverUrl"),
              !roomId.isEmpty, !serverUrl.isEmpty else {
            connectionStatus = .error
            connectionError = "No pairing info found. Please pair a device first."
            return
        }

        let bridgePk = UserDefaults.standard.string(forKey: "bridgePublicKey") ?? ""
        if !bridgePk.isEmpty {
            try? cryptoService.deriveSharedKey(peerPublicKeyBase64: bridgePk)
        }

        connectionStatus = .connecting
        connectionError = nil
        relayService.connect(
            serverUrl: serverUrl,
            roomId: roomId,
            role: "app",
            crypto: cryptoService
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.relayService.isConnected else { return }
            self.relayService.send([
                "type": "pair",
                "appPublicKey": self.cryptoService.publicKeyBase64,
            ])
        }
    }

    func disconnect() {
        relayService.disconnect()
        connectionStatus = .disconnected
        isConnected = false
    }

    func unpair() {
        disconnect()
        pairedDeviceId = nil
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: "roomId")
        UserDefaults.standard.removeObject(forKey: "serverUrl")
        UserDefaults.standard.removeObject(forKey: "bridgePublicKey")
    }

    func updateTier(_ tier: SubscriptionTier, remaining: Int = 0) {
        currentTier = tier
        remainingFreePrompts = remaining
    }
}
