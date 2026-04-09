import SwiftUI

struct CodeBlock: View {
    let code: String
    let language: String

    @State private var isExpanded = false

    private var displayCode: String {
        if isExpanded || code.count <= 500 {
            return code
        }
        return String(code.prefix(500)) + "\n... (tap to expand)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.uppercased())
                    .font(Theme.smallLabel)
                    .foregroundColor(Theme.textTertiary)

                Spacer()

                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.codeBg.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(displayCode)
                    .font(Theme.code)
                    .foregroundColor(Theme.textPrimary)
                    .padding(12)
            }
            .background(Theme.codeBg)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.codeRadius))
        .onTapGesture {
            if code.count > 500 {
                withAnimation(Theme.cardExpand) {
                    isExpanded.toggle()
                }
            }
        }
    }
}
