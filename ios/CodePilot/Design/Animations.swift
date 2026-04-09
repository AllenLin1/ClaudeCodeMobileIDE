import SwiftUI

struct PressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(Theme.buttonPress, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

struct SlideInFromBottom: ViewModifier {
    let isPresented: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: isPresented ? 0 : 20)
            .opacity(isPresented ? 1 : 0)
            .animation(Theme.messageAppear, value: isPresented)
    }
}

struct TypewriterText: View {
    let fullText: String
    @State private var displayedText = ""
    @State private var currentIndex = 0

    var body: some View {
        Text(displayedText + (currentIndex < fullText.count ? "▍" : ""))
            .onAppear { startTyping() }
    }

    private func startTyping() {
        displayedText = ""
        currentIndex = 0
        let chars = Array(fullText)
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if currentIndex < chars.count {
                displayedText.append(chars[currentIndex])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

extension View {
    func pressEffect() -> some View {
        modifier(PressEffect())
    }

    func slideInFromBottom(_ isPresented: Bool) -> some View {
        modifier(SlideInFromBottom(isPresented: isPresented))
    }
}
