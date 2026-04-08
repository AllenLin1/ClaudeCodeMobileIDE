import SwiftUI

struct PairingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var pairingCode = ""
    @State private var isScanning = false
    @State private var isPairing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.accent)

                    Text("Pair New Device")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Text("Run `npx codepilot-bridge start` on your computer,\nthen scan the QR code or enter the pairing code.")
                        .font(Theme.body)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

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

                    VStack(spacing: 12) {
                        TextField("Pairing Code", text: $pairingCode)
                            .font(Theme.code)
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .padding(14)
                            .background(Theme.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))

                        Button {
                            pair()
                        } label: {
                            if isPairing {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                            } else {
                                Text("Connect")
                                    .font(Theme.cardTitle)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(pairingCode.isEmpty ? Theme.bgElevated : Theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                            }
                        }
                        .disabled(pairingCode.isEmpty || isPairing)
                        .pressEffect()
                    }
                    .padding(.horizontal, 32)

                    if let error {
                        Text(error)
                            .font(Theme.label)
                            .foregroundColor(Theme.statusError)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .sheet(isPresented: $isScanning) {
            QRScannerView { _ in
                isScanning = false
                dismiss()
            }
        }
    }

    private func pair() {
        isPairing = true
        error = nil
        // Pairing logic here
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isPairing = false
            dismiss()
        }
    }
}
