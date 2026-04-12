import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var pairingCode = ""
    @State private var serverUrl = "http://localhost:8787"
    @State private var isScanning = false
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

            Text("The bridge will display a QR code\nand a pairing code in the terminal.")
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
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.accent)

                Text("Connect to Bridge")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("Enter the pairing URL shown in your terminal.\nIt looks like: codepilot://pair?code=...&room=...&server=...")
                    .font(Theme.label)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PAIRING URL (from terminal)")
                        .font(Theme.smallLabel)
                        .foregroundColor(Theme.textTertiary)

                    TextField("codepilot://pair?code=...&room=...&server=...", text: $pairingCode)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(14)
                        .background(Theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))

                    Text("Copy the full Pairing URL from the bridge terminal and paste it here.")
                        .font(Theme.smallLabel)
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 32)

                dividerWithText("OR ENTER MANUALLY")

                VStack(alignment: .leading, spacing: 8) {
                    Text("SERVER URL")
                        .font(Theme.smallLabel)
                        .foregroundColor(Theme.textTertiary)

                    TextField("http://localhost:8787", text: $serverUrl)
                        .font(Theme.code)
                        .foregroundColor(Theme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(14)
                        .background(Theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))

                    Text("ROOM ID (from Pairing URL, the 'room' parameter)")
                        .font(Theme.smallLabel)
                        .foregroundColor(Theme.textTertiary)
                        .padding(.top, 4)

                    TextField("e.g. abc12345-6789-...", text: $manualRoomId)
                        .font(Theme.code)
                        .foregroundColor(Theme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(14)
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
                }

                Button {
                    startPairing()
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
            .padding(.vertical, 20)
        }
    }

    @State private var manualRoomId = ""

    private var canConnect: Bool {
        !pairingCode.isEmpty || (!serverUrl.isEmpty && !manualRoomId.isEmpty)
    }

    private func dividerWithText(_ text: String) -> some View {
        HStack {
            Rectangle().fill(Theme.bgElevated).frame(height: 1)
            Text(text)
                .font(Theme.smallLabel)
                .foregroundColor(Theme.textTertiary)
                .fixedSize()
            Rectangle().fill(Theme.bgElevated).frame(height: 1)
        }
        .padding(.horizontal, 32)
    }

    private func startPairing() {
        errorMessage = nil
        isConnecting = true

        var resolvedServerUrl = serverUrl
        var resolvedRoomId = manualRoomId
        var resolvedPk = ""

        if !pairingCode.isEmpty {
            if let parsed = parsePairingUrl(pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)) {
                resolvedServerUrl = parsed.server
                resolvedRoomId = parsed.room
                resolvedPk = parsed.pk
            } else {
                errorMessage = "Invalid pairing URL. Please copy the full URL starting with codepilot://pair?..."
                isConnecting = false
                return
            }
        }

        guard !resolvedServerUrl.isEmpty, !resolvedRoomId.isEmpty else {
            errorMessage = "Please provide server URL and room ID."
            isConnecting = false
            return
        }

        if !resolvedPk.isEmpty {
            try? appState.cryptoService.deriveSharedKey(peerPublicKeyBase64: resolvedPk)
        }

        UserDefaults.standard.set(resolvedRoomId, forKey: "roomId")
        UserDefaults.standard.set(resolvedServerUrl, forKey: "serverUrl")
        UserDefaults.standard.set(resolvedPk, forKey: "bridgePublicKey")

        appState.relayService.connect(
            serverUrl: resolvedServerUrl,
            roomId: resolvedRoomId,
            role: "app",
            crypto: appState.cryptoService
        )

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            isConnecting = false
            if appState.relayService.isConnected {
                withAnimation { currentStep = 2 }
            } else {
                let state = appState.relayService.connectionState
                switch state {
                case .error(let msg):
                    errorMessage = "Connection failed: \(msg)"
                default:
                    errorMessage = "Could not connect to relay. Check that the server is running and the room ID is correct."
                }
            }
        }
    }

    private struct ParsedPairing {
        let code: String
        let room: String
        let pk: String
        let server: String
    }

    private func parsePairingUrl(_ urlString: String) -> ParsedPairing? {
        guard let comps = URLComponents(string: urlString),
              comps.scheme == "codepilot",
              comps.host == "pair" else { return nil }

        let items = comps.queryItems ?? []
        let code = items.first(where: { $0.name == "code" })?.value ?? ""
        let room = items.first(where: { $0.name == "room" })?.value ?? ""
        let pk = items.first(where: { $0.name == "pk" })?.value ?? ""
        let server = items.first(where: { $0.name == "server" })?.value ?? ""

        guard !room.isEmpty, !server.isEmpty else { return nil }
        return ParsedPairing(code: code, room: room, pk: pk, server: server)
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
