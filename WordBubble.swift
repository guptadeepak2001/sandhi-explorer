import SwiftUI

struct WordBubble: View {
    let text: String
    var isResult: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: isResult ? 34 : 24, weight: .bold, design: .serif))
            .foregroundStyle(isResult ? .white : .primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(isResult ? Color.teal.gradient : Color(uiColor: .systemGray6).gradient)
                        .shadow(
                            color: isResult ? Color.teal.opacity(0.35) : Color.black.opacity(0.08),
                            radius: 10,
                            x: 0,
                            y: 6
                        )

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            isResult ? Color.white.opacity(0.45) : Color.gray.opacity(0.22),
                            lineWidth: 1
                        )
                }
            )
            .scaleEffect(isResult ? 1.04 : 1.0)
    }
}

#Preview {
    VStack(spacing: 16) {
        WordBubble(text: "namah")
        WordBubble(text: "namaste", isResult: true)
    }
    .padding()
}
