import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var pairingCode = ""
    @State private var serverUrl = "http://localhost:8787"
    @State private var isConnecting = false
    @State private var isScanning = false
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

            Text("A 6-character pairing code and QR code\nwill appear in your terminal.")
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

    // MARK: - Step 2: Pair (QR Scan OR Code Input)
    private var step2View: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.accent)

                Text("Pair Your Device")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("Scan the QR code from your terminal\nor enter the pairing code manually.")
                    .font(Theme.body)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                // Scan QR button
                Button {
                    isScanning = true
                } label: {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        .font(Theme.cardTitle)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                }
                .padding(.horizontal, 32)
                .pressEffect()

                // Divider
                HStack {
                    Rectangle().fill(Theme.bgElevated).frame(height: 1)
                    Text("OR")
                        .font(Theme.smallLabel)
                        .foregroundColor(Theme.textTertiary)
                        .fixedSize()
                    Rectangle().fill(Theme.bgElevated).frame(height: 1)
                }
                .padding(.horizontal, 40)

                // Pairing Code Input
                VStack(spacing: 8) {
                    Text("PAIRING CODE")
                        .font(Theme.smallLabel)
                        .foregroundColor(Theme.textTertiary)

                    TextField("ABC123", text: $pairingCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.vertical, 16)
                        .background(Theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                        .padding(.horizontal, 48)
                        .onChange(of: pairingCode) { _, newValue in
                            pairingCode = String(newValue.prefix(6)).uppercased()
                            errorMessage = nil
                        }
                }

                // Server URL
                VStack(alignment: .leading, spacing: 4) {
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

                // Error message
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

                // Connect button
                Button {
                    connectWithCode()
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
                .padding(.bottom, 16)
            }
            .padding(.vertical, 20)
        }
        .sheet(isPresented: $isScanning) {
            QRScannerView { scannedUrl in
                isScanning = false
                handleScannedUrl(scannedUrl)
            }
        }
    }

    private var canConnect: Bool {
        pairingCode.count == 6 && !serverUrl.isEmpty
    }

    // MARK: - Connect with Pairing Code

    private func connectWithCode() {
        errorMessage = nil
        isConnecting = true

        Task {
            do {
                let info = try await lookupPairingCode(pairingCode, serverUrl: serverUrl)
                try await connectToRelay(roomId: info.roomId, bridgePk: info.bridgePublicKey, serverUrl: serverUrl)
                isConnecting = false
                withAnimation { currentStep = 2 }
            } catch let error as PairingError {
                isConnecting = false
                errorMessage = error.message
            } catch {
                isConnecting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Connect with QR Scan

    private func handleScannedUrl(_ urlString: String) {
        guard let comps = URLComponents(string: urlString),
              comps.scheme == "codepilot",
              comps.host == "pair" else {
            errorMessage = "Invalid QR code."
            return
        }

        let items = comps.queryItems ?? []
        let room = items.first(where: { $0.name == "room" })?.value ?? ""
        let pk = items.first(where: { $0.name == "pk" })?.value ?? ""
        let server = items.first(where: { $0.name == "server" })?.value ?? serverUrl

        guard !room.isEmpty else {
            errorMessage = "Invalid QR code: missing room ID."
            return
        }

        if !server.isEmpty { serverUrl = server }
        isConnecting = true
        errorMessage = nil

        Task {
            do {
                try await connectToRelay(roomId: room, bridgePk: pk, serverUrl: server)
                isConnecting = false
                withAnimation { currentStep = 2 }
            } catch let error as PairingError {
                isConnecting = false
                errorMessage = error.message
            } catch {
                isConnecting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Shared Helpers

    struct PairingInfo {
        let roomId: String
        let bridgePublicKey: String
    }

    private func lookupPairingCode(_ code: String, serverUrl: String) async throws -> PairingInfo {
        let urlString = "\(serverUrl)/pair/\(code.uppercased())"
        guard let url = URL(string: urlString) else {
            throw PairingError.invalidUrl
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if status == 404 {
            throw PairingError.codeNotFound
        }
        guard status == 200 else {
            throw PairingError.serverError(status)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roomId = json["roomId"] as? String, !roomId.isEmpty else {
            throw PairingError.invalidResponse
        }

        let pk = json["bridgePublicKey"] as? String ?? ""
        return PairingInfo(roomId: roomId, bridgePublicKey: pk)
    }

    private func connectToRelay(roomId: String, bridgePk: String, serverUrl: String) async throws {
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

        try await Task.sleep(nanoseconds: 2_500_000_000)

        if !appState.relayService.isConnected {
            throw PairingError.connectionFailed
        }
    }

    enum PairingError: Error {
        case invalidUrl, codeNotFound, serverError(Int), invalidResponse, connectionFailed

        var message: String {
            switch self {
            case .invalidUrl: return "Invalid server URL."
            case .codeNotFound: return "Pairing code not found or expired.\nMake sure Bridge is running."
            case .serverError(let c): return "Server error (\(c)). Check server is running."
            case .invalidResponse: return "Invalid server response."
            case .connectionFailed: return "Could not connect to relay.\nCheck server and bridge are running."
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
