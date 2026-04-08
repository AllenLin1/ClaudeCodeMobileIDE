import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var currentTier: SubscriptionTier = .free
    @Published var remainingFreePrompts: Int = 10
    @Published var deviceName: String = ""
    @Published var pairedDeviceId: String?

    let relayService: RelayService
    let licensingService: LicensingService
    let subscriptionService: RevenueCatService
    let cryptoService: CryptoService

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
    }

    func completeOnboarding(roomId: String, serverUrl: String, bridgePublicKey: String) {
        hasCompletedOnboarding = true
        pairedDeviceId = roomId

        UserDefaults.standard.set(roomId, forKey: "roomId")
        UserDefaults.standard.set(serverUrl, forKey: "serverUrl")
        UserDefaults.standard.set(bridgePublicKey, forKey: "bridgePublicKey")
    }

    func connect() {
        guard let roomId = UserDefaults.standard.string(forKey: "roomId"),
              let serverUrl = UserDefaults.standard.string(forKey: "serverUrl") else { return }

        connectionStatus = .connecting
        relayService.connect(
            serverUrl: serverUrl,
            roomId: roomId,
            role: "app",
            crypto: cryptoService
        )
    }

    func disconnect() {
        relayService.disconnect()
        connectionStatus = .disconnected
        isConnected = false
    }

    func updateTier(_ tier: SubscriptionTier, remaining: Int = 0) {
        currentTier = tier
        remainingFreePrompts = remaining
    }
}
