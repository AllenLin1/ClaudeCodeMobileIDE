import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var selectedPlan: Plan = .yearly
    @State private var error: String?
    @State private var logoScale: CGFloat = 0.5

    enum Plan {
        case monthly, yearly
    }

    private let features: [(icon: String, pro: String, free: String)] = [
        ("infinity", "Unlimited conversations", "Only 10 lifetime"),
        ("square.stack.3d.up", "Multi-project parallel", "Only 1 project"),
        ("folder", "File browser + Git", "Not available"),
        ("cpu", "All models", "Default only"),
        ("bell.badge", "Push notifications", "Not available"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Logo
                        VStack(spacing: 12) {
                            Image(systemName: "bolt.shield.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Theme.accent, Theme.statusActive],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(logoScale)
                                .onAppear {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                                        logoScale = 1.0
                                    }
                                }

                            Text("CodePilot Pro")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Theme.textPrimary)

                            Text("Unlock the full power")
                                .font(Theme.body)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 20)

                        // Feature comparison
                        VStack(spacing: 0) {
                            ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                                if idx > 0 {
                                    Divider().background(Theme.bgElevated)
                                }
                                HStack(spacing: 12) {
                                    Image(systemName: feature.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(Theme.accent)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(feature.pro)
                                            .font(Theme.body)
                                            .foregroundColor(Theme.textPrimary)
                                        Text("Free: \(feature.free)")
                                            .font(Theme.smallLabel)
                                            .foregroundColor(Theme.textTertiary)
                                    }

                                    Spacer()

                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.statusActive)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                        .background(Theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                        .padding(.horizontal, 16)

                        // Plan selection
                        VStack(spacing: 12) {
                            planButton(
                                plan: .monthly,
                                price: "$4.99/month",
                                subtitle: nil,
                                isRecommended: false
                            )

                            planButton(
                                plan: .yearly,
                                price: "$29.99/year",
                                subtitle: "Save 50%",
                                isRecommended: true
                            )
                        }
                        .padding(.horizontal, 16)

                        // Purchase button
                        Button {
                            purchase()
                        } label: {
                            Group {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Subscribe Now")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Theme.accent, Color(hex: 0x5856D6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                        }
                        .disabled(isPurchasing)
                        .padding(.horizontal, 16)
                        .pressEffect()

                        if let error {
                            Text(error)
                                .font(Theme.label)
                                .foregroundColor(Theme.statusError)
                        }

                        // Restore + Terms
                        HStack(spacing: 16) {
                            Button("Restore Purchases") {
                                restore()
                            }
                            .font(Theme.label)
                            .foregroundColor(Theme.textSecondary)

                            Text("·")
                                .foregroundColor(Theme.textTertiary)

                            Button("Terms of Use") {
                                // Open URL
                            }
                            .font(Theme.label)
                            .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
        }
    }

    private func planButton(plan: Plan, price: String, subtitle: String?, isRecommended: Bool) -> some View {
        Button {
            withAnimation(Theme.stateChange) {
                selectedPlan = plan
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(price)
                            .font(Theme.cardTitle)
                            .foregroundColor(Theme.textPrimary)

                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.statusWarning)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.statusWarning.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.statusActive)
                    }
                }

                Spacer()

                Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selectedPlan == plan ? Theme.accent : Theme.textTertiary)
            }
            .padding(16)
            .background(Theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(
                        selectedPlan == plan ? Theme.accent : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .pressEffect()
    }

    private func purchase() {
        isPurchasing = true
        error = nil

        Task {
            do {
                if selectedPlan == .monthly {
                    try await appState.subscriptionService.purchaseMonthly()
                } else {
                    try await appState.subscriptionService.purchaseYearly()
                }
                appState.updateTier(.pro)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isPurchasing = false
        }
    }

    private func restore() {
        isPurchasing = true
        error = nil

        Task {
            do {
                try await appState.subscriptionService.restorePurchases()
                if appState.subscriptionService.isPro {
                    appState.updateTier(.pro)
                    dismiss()
                } else {
                    error = "No active subscription found."
                }
            } catch {
                self.error = error.localizedDescription
            }
            isPurchasing = false
        }
    }
}
