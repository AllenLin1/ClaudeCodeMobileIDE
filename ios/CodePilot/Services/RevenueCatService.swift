import Foundation

/// RevenueCat subscription management.
/// NOTE: In production, import RevenueCat SDK and replace stubs with actual calls.
/// For now, this provides the interface and mock behavior for development.
@MainActor
final class RevenueCatService: ObservableObject {
    @Published var isPro = false
    @Published var currentOffering: Offering?
    @Published var isLoading = false

    struct Offering {
        let monthlyPrice: String
        let yearlyPrice: String
        let monthlyProductId: String
        let yearlyProductId: String
    }

    // RevenueCat API Key — set in production
    // static let apiKey = "appl_XXXXX"

    func configure() {
        // In production:
        // Purchases.configure(withAPIKey: Self.apiKey)
        // Purchases.shared.delegate = self

        currentOffering = Offering(
            monthlyPrice: "$4.99",
            yearlyPrice: "$29.99",
            monthlyProductId: "com.codepilot.pro.monthly",
            yearlyProductId: "com.codepilot.pro.yearly"
        )
    }

    func checkSubscriptionStatus() async {
        // In production:
        // let customerInfo = try await Purchases.shared.customerInfo()
        // isPro = customerInfo.entitlements["pro"]?.isActive == true
        isPro = UserDefaults.standard.bool(forKey: "debug_isPro")
    }

    func purchaseMonthly() async throws {
        isLoading = true
        defer { isLoading = false }

        // In production:
        // let product = ... get from offering ...
        // let (_, customerInfo, _) = try await Purchases.shared.purchase(product: product)
        // isPro = customerInfo.entitlements["pro"]?.isActive == true

        // Simulate purchase for development
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isPro = true
        UserDefaults.standard.set(true, forKey: "debug_isPro")
    }

    func purchaseYearly() async throws {
        isLoading = true
        defer { isLoading = false }

        // Simulate purchase for development
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isPro = true
        UserDefaults.standard.set(true, forKey: "debug_isPro")
    }

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        // In production:
        // let customerInfo = try await Purchases.shared.restorePurchases()
        // isPro = customerInfo.entitlements["pro"]?.isActive == true

        try await Task.sleep(nanoseconds: 500_000_000)
        let restored = UserDefaults.standard.bool(forKey: "debug_isPro")
        isPro = restored
    }
}
