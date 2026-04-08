import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPairing = false
    @State private var showPaywall = false
    @State private var defaultModel = "default"
    @State private var permissionMode = "ask"
    @State private var pushEnabled = false
    @State private var theme = "system"

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Paired Device
                        settingsSection("Paired Device") {
                            deviceCard
                        }

                        // Subscription
                        settingsSection("Subscription") {
                            subscriptionCard
                        }

                        // Preferences
                        settingsSection("Preferences") {
                            preferencesCard
                        }

                        // About
                        settingsSection("About") {
                            aboutCard
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPairing) {
                PairingView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(Theme.smallLabel)
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 4)

            content()
        }
    }

    private var deviceCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.deviceName.isEmpty ? "No Device" : appState.deviceName)
                        .font(Theme.cardTitle)
                        .foregroundColor(Theme.textPrimary)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.isConnected ? Theme.statusActive : Theme.statusError)
                            .frame(width: 6, height: 6)
                        Text(appState.isConnected ? "Connected" : "Disconnected")
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Spacer()

                if appState.pairedDeviceId != nil {
                    Button("Unpair") {
                        appState.disconnect()
                        appState.pairedDeviceId = nil
                    }
                    .font(Theme.label)
                    .foregroundColor(Theme.statusError)
                }
            }

            if appState.pairedDeviceId == nil {
                Button {
                    showPairing = true
                } label: {
                    Label("Pair Device", systemImage: "link")
                        .font(Theme.cardTitle)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                }
                .pressEffect()
            }
        }
        .padding(16)
        .background(Theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var subscriptionCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: appState.currentTier == .pro ? "crown.fill" : "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(appState.currentTier == .pro ? Theme.statusWarning : Theme.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentTier == .pro ? "Pro" : "Free")
                        .font(Theme.cardTitle)
                        .foregroundColor(Theme.textPrimary)

                    if appState.currentTier == .free {
                        Text("\(appState.remainingFreePrompts) prompts remaining")
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Spacer()

                Button {
                    showPaywall = true
                } label: {
                    Text(appState.currentTier == .pro ? "Manage" : "Upgrade")
                        .font(Theme.label)
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .padding(16)
        .background(Theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            preferenceRow("Default Model") {
                Picker("Model", selection: $defaultModel) {
                    Text("Default").tag("default")
                    Text("Sonnet 4.6").tag("sonnet")
                    Text("Opus 4.6").tag("opus")
                    Text("Haiku 4.6").tag("haiku")
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
            }

            Divider().background(Theme.bgElevated)

            preferenceRow("Permission Mode") {
                Picker("Permissions", selection: $permissionMode) {
                    Text("Ask Every Time").tag("ask")
                    Text("Auto-Allow Safe").tag("auto_safe")
                    Text("Allow All").tag("allow_all")
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
            }

            Divider().background(Theme.bgElevated)

            preferenceRow("Push Notifications") {
                Toggle("", isOn: $pushEnabled)
                    .tint(Theme.accent)
            }

            Divider().background(Theme.bgElevated)

            preferenceRow("Theme") {
                Picker("Theme", selection: $theme) {
                    Text("System").tag("system")
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
            }
        }
        .background(Theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func preferenceRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(Theme.body)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var aboutCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Version")
                    .font(Theme.body)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("1.0.0")
                    .font(Theme.body)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(Theme.bgElevated)

            Button {
                // Open privacy policy
            } label: {
                HStack {
                    Text("Privacy Policy")
                        .font(Theme.body)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider().background(Theme.bgElevated)

            Button {
                // Open terms of use
            } label: {
                HStack {
                    Text("Terms of Use")
                        .font(Theme.body)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
