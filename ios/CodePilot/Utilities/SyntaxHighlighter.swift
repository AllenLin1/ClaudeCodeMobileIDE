import SwiftUI

/// Minimal syntax highlighting for code display using One Dark Pro colors.
enum SyntaxHighlighter {
    // One Dark Pro colors
    static let keyword = Color(hex: 0xC678DD)
    static let string = Color(hex: 0x98C379)
    static let comment = Color(hex: 0x5C6370)
    static let function = Color(hex: 0x61AFEF)
    static let number = Color(hex: 0xD19A66)
    static let type = Color(hex: 0xE5C07B)
    static let plain = Color(hex: 0xABB2BF)
    static let punctuation = Color(hex: 0x636D83)

    static func highlight(_ code: String, language: String) -> AttributedString {
        var result = AttributedString(code)
        result.foregroundColor = plain
        result.font = .system(size: 14, design: .monospaced)
        return result
    }
}
