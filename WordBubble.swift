import SwiftUI

struct WordBubble: View {
    let text: String
    var isResult: Bool = false
    @State private var isFloating = false

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
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isResult ? 0.24 : 0.18),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .offset(y: isResult ? (isFloating ? -2 : 2) : 0)
            .scaleEffect(isResult ? (isFloating ? 1.055 : 1.03) : 1.0)
            .animation(
                isResult
                    ? .easeInOut(duration: 1.9).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.18),
                value: isFloating
            )
            .onAppear {
                isFloating = isResult
            }
            .onChange(of: isResult) { newValue in
                isFloating = newValue
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        WordBubble(text: "namah")
        WordBubble(text: "namaste", isResult: true)
    }
    .padding()
}
