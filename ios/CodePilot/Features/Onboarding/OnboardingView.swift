import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var pairingCode = ""
    @State private var isScanning = false

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(0..<3) { step in
                        Capsule()
                            .fill(step <= currentStep ? Theme.accent : Theme.bgElevated)
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)

                Text("Step \(currentStep + 1) of 3")
                    .font(Theme.label)
                    .foregroundColor(Theme.textTertiary)
                    .padding(.top, 12)

                Spacer()

                Group {
                    switch currentStep {
                    case 0: step1View
                    case 1: step2View
                    case 2: step3View
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()
            }
        }
        .animation(Theme.pageTransition, value: currentStep)
    }

    // MARK: - Step 1: Install Bridge
    private var step1View: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(Theme.accent)

            Text("Install CodePilot Bridge")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("Run this command in your computer's terminal:")
                .font(Theme.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            HStack {
                Text("npx codepilot-bridge start")
                    .font(Theme.code)
                    .foregroundColor(Theme.statusActive)

                Spacer()

                Button {
                    UIPasteboard.general.string = "npx codepilot-bridge start"
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(16)
            .background(Theme.codeBg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.codeRadius))
            .padding(.horizontal, 32)

            Text("The bridge will display a QR code.\nScan it in the next step.")
                .font(Theme.label)
                .foregroundColor(Theme.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                withAnimation { currentStep = 1 }
            } label: {
                Text("Next")
                    .font(Theme.cardTitle)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
            }
            .padding(.horizontal, 32)
            .pressEffect()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Step 2: Pair
    private var step2View: some View {
        VStack(spacing: 24) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(Theme.accent)

            Text("Scan QR Code")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("Scan the QR code shown in your terminal,\nor enter the pairing code manually.")
                .font(Theme.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                isScanning = true
            } label: {
                Label("Scan QR Code", systemImage: "camera")
                    .font(Theme.cardTitle)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
            }
            .padding(.horizontal, 32)
            .pressEffect()

            HStack {
                Rectangle()
                    .fill(Theme.bgElevated)
                    .frame(height: 1)
                Text("OR")
                    .font(Theme.smallLabel)
                    .foregroundColor(Theme.textTertiary)
                Rectangle()
                    .fill(Theme.bgElevated)
                    .frame(height: 1)
            }
            .padding(.horizontal, 40)

            VStack(spacing: 12) {
                TextField("Enter pairing code", text: $pairingCode)
                    .font(Theme.code)
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .padding(14)
                    .background(Theme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                    .padding(.horizontal, 32)

                Button {
                    // Validate pairing code and connect
                    withAnimation { currentStep = 2 }
                } label: {
                    Text("Connect")
                        .font(Theme.cardTitle)
                        .foregroundColor(pairingCode.isEmpty ? Theme.textTertiary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(pairingCode.isEmpty ? Theme.bgElevated : Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                }
                .disabled(pairingCode.isEmpty)
                .padding(.horizontal, 32)
                .pressEffect()
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $isScanning) {
            QRScannerView { result in
                isScanning = false
                // Parse QR result and pair
                withAnimation { currentStep = 2 }
            }
        }
    }

    // MARK: - Step 3: Ready
    private var step3View: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.statusActive)

            Text("You're All Set!")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("CodePilot is connected to your computer.\nStart coding with Claude from anywhere.")
                .font(Theme.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                appState.completeOnboarding(
                    roomId: "demo-room",
                    serverUrl: "https://codepilot-server.workers.dev",
                    bridgePublicKey: ""
                )
            } label: {
                Text("Start Coding")
                    .font(Theme.cardTitle)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
            }
            .padding(.horizontal, 32)
            .pressEffect()
        }
        .padding(.horizontal, 16)
    }
}
