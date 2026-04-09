import Foundation

struct SubscriptionStatus: Codable {
    let tier: String
    let isActive: Bool
    let expiresAt: Date?
    let remainingFree: Int

    var isPro: Bool { tier == "pro" }
    var isFree: Bool { tier == "free" }
    var isExpired: Bool { tier == "expired" }

    static let defaultFree = SubscriptionStatus(
        tier: "free",
        isActive: true,
        expiresAt: nil,
        remainingFree: 10
    )
}
