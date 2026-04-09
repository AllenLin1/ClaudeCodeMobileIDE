import SwiftUI
import AVFoundation

struct QRScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.accent, lineWidth: 3)
                        .frame(width: 250, height: 250)
                        .overlay {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.accent.opacity(0.5))
                        }

                    Text("Point your camera at the QR code\nshown in your terminal")
                        .font(Theme.body)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)

                    // NOTE: In production, use AVCaptureSession with a camera preview
                    // and AVMetadataObjectTypeMachineReadableCodeObject for QR detection.
                    // This is a placeholder UI for the scanner.

                    Button("Simulate Scan") {
                        onScan("codepilot://pair?code=ABC123&room=test-room&pk=xxx&server=https://example.com")
                    }
                    .font(Theme.label)
                    .foregroundColor(Theme.accent)
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }
}
