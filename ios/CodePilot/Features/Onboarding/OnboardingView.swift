import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var pairingCode = ""
    @State private var serverUrl = "http://localhost:8787"
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { step in
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

    // MARK: - Step 1
    private var step1View: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(Theme.accent)

            Text("Start Bridge")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("Run this command on your computer:")
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

            Text("A 6-character pairing code will appear.\nEnter it in the next step.")
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

    // MARK: - Step 2: Enter Pairing Code
    private var step2View: some View {
        VStack(spacing: 24) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.accent)

            Text("Enter Pairing Code")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("Type the 6-character code\nshown in your terminal.")
                .font(Theme.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            TextField("ABC123", text: $pairingCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.vertical, 16)
                .padding(.horizontal, 40)
                .background(Theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                .padding(.horizontal, 48)
                .onChange(of: pairingCode) { _, newValue in
                    pairingCode = String(newValue.prefix(6)).uppercased()
                    errorMessage = nil
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("SERVER")
                    .font(Theme.smallLabel)
                    .foregroundColor(Theme.textTertiary)

                TextField("http://localhost:8787", text: $serverUrl)
                    .font(Theme.code)
                    .foregroundColor(Theme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Theme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
            }
            .padding(.horizontal, 32)

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                }
                .font(Theme.label)
                .foregroundColor(Theme.statusError)
                .padding(.horizontal, 32)
                .multilineTextAlignment(.center)
            }

            Button {
                connect()
            } label: {
                Group {
                    if isConnecting {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Connecting...")
                        }
                    } else {
                        Text("Connect")
                    }
                }
                .font(Theme.cardTitle)
                .foregroundColor(canConnect ? .white : Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canConnect ? Theme.accent : Theme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
            }
            .disabled(!canConnect || isConnecting)
            .padding(.horizontal, 32)
            .pressEffect()

            Button {
                withAnimation { currentStep = 0 }
            } label: {
                Text("Back")
                    .font(Theme.label)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private var canConnect: Bool {
        pairingCode.count == 6 && !serverUrl.isEmpty
    }

    private func connect() {
        errorMessage = nil
        isConnecting = true

        Task {
            do {
                let lookupUrl = "\(serverUrl)/pair/\(pairingCode.uppercased())"
                guard let url = URL(string: lookupUrl) else {
                    throw PairingError.invalidUrl
                }

                let (data, response) = try await URLSession.shared.data(from: url)
                let httpResponse = response as? HTTPURLResponse

                if httpResponse?.statusCode == 404 {
                    throw PairingError.codeNotFound
                }
                guard httpResponse?.statusCode == 200 else {
                    throw PairingError.serverError(httpResponse?.statusCode ?? 0)
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let roomId = json["roomId"] as? String,
                      !roomId.isEmpty else {
                    throw PairingError.invalidResponse
                }

                let bridgePk = json["bridgePublicKey"] as? String ?? ""

                if !bridgePk.isEmpty {
                    try? appState.cryptoService.deriveSharedKey(peerPublicKeyBase64: bridgePk)
                }

                UserDefaults.standard.set(roomId, forKey: "roomId")
                UserDefaults.standard.set(serverUrl, forKey: "serverUrl")
                UserDefaults.standard.set(bridgePk, forKey: "bridgePublicKey")

                appState.relayService.connect(
                    serverUrl: serverUrl,
                    roomId: roomId,
                    role: "app",
                    crypto: appState.cryptoService
                )

                try await Task.sleep(nanoseconds: 2_000_000_000)

                if appState.relayService.isConnected {
                    isConnecting = false
                    withAnimation { currentStep = 2 }
                } else {
                    throw PairingError.connectionFailed
                }

            } catch let error as PairingError {
                isConnecting = false
                errorMessage = error.message
            } catch {
                isConnecting = false
                errorMessage = "Connection failed: \(error.localizedDescription)"
            }
        }
    }

    enum PairingError: Error {
        case invalidUrl
        case codeNotFound
        case serverError(Int)
        case invalidResponse
        case connectionFailed

        var message: String {
            switch self {
            case .invalidUrl:
                return "Invalid server URL."
            case .codeNotFound:
                return "Pairing code not found or expired.\nMake sure Bridge is running."
            case .serverError(let code):
                return "Server error (\(code)).\nCheck server is running."
            case .invalidResponse:
                return "Invalid response from server."
            case .connectionFailed:
                return "Could not connect to relay.\nCheck server and bridge are running."
            }
        }
    }

    // MARK: - Step 3: Connected
    private var step3View: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.statusActive)

            Text("Connected!")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("CodePilot is connected to your computer.\nStart coding with Claude from anywhere.")
                .font(Theme.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                appState.hasCompletedOnboarding = true
                appState.pairedDeviceId = UserDefaults.standard.string(forKey: "roomId")
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
