import SwiftUI

enum Theme {
    // MARK: - Colors
    static let bgPrimary = Color(hex: 0x000000)
    static let bgSecondary = Color(hex: 0x1C1C1E)
    static let bgTertiary = Color(hex: 0x2C2C2E)
    static let bgElevated = Color(hex: 0x3A3A3C)

    static let accent = Color(hex: 0x007AFF)
    static let userBubble = Color(hex: 0x007AFF)

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8E8E93)
    static let textTertiary = Color(hex: 0x636366)

    static let statusActive = Color(hex: 0x30D158)
    static let statusWarning = Color(hex: 0xFFD60A)
    static let statusError = Color(hex: 0xFF453A)

    static let codeBg = Color(hex: 0x282C34)

    // MARK: - Corner Radii
    static let cardRadius: CGFloat = 16
    static let bubbleRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 12
    static let codeRadius: CGFloat = 10
    static let inputRadius: CGFloat = 22

    // MARK: - Animations
    static let pageTransition: Animation = .spring(response: 0.35)
    static let messageAppear: Animation = .spring(response: 0.4, dampingFraction: 0.8)
    static let cardExpand: Animation = .easeInOut(duration: 0.25)
    static let stateChange: Animation = .linear(duration: 0.2)
    static let buttonPress: Animation = .spring(response: 0.3, dampingFraction: 0.6)
    static let tabSwitch: Animation = .spring(response: 0.3)

    // MARK: - Fonts
    static let navTitle = Font.system(size: 17, weight: .semibold, design: .default)
    static let cardTitle = Font.system(size: 16, weight: .medium, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let code = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let label = Font.system(size: 13, weight: .regular, design: .default)
    static let smallLabel = Font.system(size: 11, weight: .regular, design: .default)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
