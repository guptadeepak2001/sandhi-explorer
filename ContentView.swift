import SwiftUI

struct ContentView: View {
    private enum InputField {
        case left
        case right
    }

    @State private var leftWord = "namah"
    @State private var rightWord = "te"
    @State private var resultWord: String?
    @State private var isMerged = false
    @State private var ruleLabel = "Panini Engine Ready"
    @Namespace private var animationSpace
    @FocusState private var focusedField: InputField?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemGroupedBackground),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Sandhi Explorer")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Panini's Algorithm (6.1 & 8.3)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.top, 30)

                Spacer(minLength: 0)

                ZStack {
                    if isMerged, let resultWord {
                        VStack(spacing: 16) {
                            ZStack {
                                WordBubble(text: resultWord, isResult: true)
                                    .matchedGeometryEffect(id: "leftBubble", in: animationSpace)

                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .matchedGeometryEffect(id: "rightBubble", in: animationSpace)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { reset() }

                            Text(ruleLabel)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                                .multilineTextAlignment(.center)
                        }
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    } else {
                        HStack(spacing: 14) {
                            WordBubble(text: displayWord(leftWord))
                                .matchedGeometryEffect(id: "leftBubble", in: animationSpace)

                            Image(systemName: "plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.secondary)

                            WordBubble(text: displayWord(rightWord))
                                .matchedGeometryEffect(id: "rightBubble", in: animationSpace)
                        }
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
                .frame(height: 210)

                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    HStack(spacing: 12) {
                        TextField("Word 1", text: $leftWord)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .left)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .right }

                        TextField("Word 2", text: $rightWord)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .right)
                            .submitLabel(.done)
                            .onSubmit { combine() }
                    }
                    .disabled(isMerged)
                    .padding(.horizontal, 24)

                    Button(action: {
                        isMerged ? reset() : combine()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isMerged ? "arrow.counterclockwise" : "wand.and.stars")
                            Text(isMerged ? "Reset" : "Combine")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isMerged ? Color.gray : Color.blue, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: isMerged ? .clear : Color.blue.opacity(0.25), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 36)

                Text("Scope lock: 6.1.77-6.1.109 + 8.3.34, 8.3.36, 6.1.114")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
        }
        .onTapGesture { focusedField = nil }
        .animation(.spring(response: 0.58, dampingFraction: 0.74), value: isMerged)
    }

    private func combine() {
        focusedField = nil
        let normalizedLeft = leftWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRight = rightWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLeft.isEmpty, !normalizedRight.isEmpty else { return }

        let sandhiResult = SandhiEngine.applyProjectSandhi(left: normalizedLeft, right: normalizedRight)
        let matchedSutra = sandhiResult.steps.first(where: { $0.sutra != nil })?.sutra
        let matchedText = matchedSutra.map { "Rule Applied: \($0.code) • \($0.title)" } ??
            "Rule Applied: none"

        withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
            leftWord = normalizedLeft
            rightWord = normalizedRight
            resultWord = sandhiResult.output
            ruleLabel = matchedText
            isMerged = true
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            isMerged = false
            resultWord = nil
            ruleLabel = "Panini Engine Ready"
        }
    }

    private func displayWord(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : trimmed
    }
}
