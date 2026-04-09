import Foundation

/// Handles JWT authentication, renewal, and usage tracking with the Licensing API.
@MainActor
final class LicensingService: ObservableObject {
    @Published var currentToken: String?
    @Published var tier: String = "free"
    @Published var remainingFree: Int = 10

    private var serverUrl: String {
        UserDefaults.standard.string(forKey: "serverUrl") ?? ""
    }

    private var renewTimer: Timer?

    struct AuthResponse: Codable {
        let token: String
        let payload: TokenPayload
    }

    struct TokenPayload: Codable {
        let sub: String
        let tier: String
        let limits: Limits
        let device_pair_id: String

        struct Limits: Codable {
            let max_sessions: Int
            let max_projects: Int
            let remaining_free: Int
            let features: [String]
        }
    }

    struct UsageResponse: Codable {
        let allowed: Bool
        let remaining: Int?
        let used: Int?
    }

    func authenticate(userId: String, devicePairId: String?) async throws {
        var body: [String: Any] = ["user_id": userId]
        if let devicePairId { body["device_pair_id"] = devicePairId }

        let data = try await post(path: "/auth", body: body)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)

        currentToken = response.token
        tier = response.payload.tier
        remainingFree = response.payload.limits.remaining_free

        startRenewalTimer()
    }

    func renew() async throws {
        guard let token = currentToken else { return }

        var request = URLRequest(url: URL(string: "\(serverUrl)/renew")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)

        currentToken = response.token
        tier = response.payload.tier
        remainingFree = response.payload.limits.remaining_free
    }

    func recordUsage() async throws -> Bool {
        guard let token = currentToken else { return false }

        var request = URLRequest(url: URL(string: "\(serverUrl)/usage")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(UsageResponse.self, from: data)

        if let remaining = response.remaining {
            remainingFree = remaining
        }

        return response.allowed
    }

    private func post(path: String, body: [String: Any]) async throws -> Data {
        let url = URL(string: "\(serverUrl)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    private func startRenewalTimer() {
        renewTimer?.invalidate()
        renewTimer = Timer.scheduledTimer(withTimeInterval: 50 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.renew()
            }
        }
    }
}
