import SwiftUI

struct QuestionCard: View {
    let question: String
    let options: [String]?
    let onAnswer: (String) -> Void

    @State private var freeTextAnswer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.accent)

                Text("Claude has a question")
                    .font(Theme.cardTitle)
                    .foregroundColor(Theme.textPrimary)
            }

            Text(question)
                .font(Theme.body)
                .foregroundColor(Theme.textSecondary)

            if let options, !options.isEmpty {
                ForEach(options, id: \.self) { option in
                    Button {
                        onAnswer(option)
                    } label: {
                        Text(option)
                            .font(Theme.label)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.bgTertiary)
                            .foregroundColor(Theme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                    }
                    .pressEffect()
                }
            } else {
                HStack {
                    TextField("Type your answer...", text: $freeTextAnswer)
                        .font(Theme.body)
                        .foregroundColor(Theme.textPrimary)
                        .padding(10)
                        .background(Theme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))

                    Button {
                        guard !freeTextAnswer.isEmpty else { return }
                        onAnswer(freeTextAnswer)
                        freeTextAnswer = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}
