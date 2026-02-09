import AudioToolbox
import SwiftUI
import UIKit

struct ContentView: View {
    private enum InputField {
        case left
        case right
    }

    @State private var leftWord = "namah"
    @State private var rightWord = "te"
    @State private var resultWord: String?
    @State private var isMerged = false
    @State private var isPreparingMerge = false
    @State private var showRuleBadge = false
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

                            if showRuleBadge {
                                Text(ruleLabel)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                                    .multilineTextAlignment(.center)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    } else {
                        HStack(spacing: 14) {
                            WordBubble(text: displayWord(leftWord))
                                .matchedGeometryEffect(id: "leftBubble", in: animationSpace)
                                .offset(x: isPreparingMerge ? 20 : 0)
                                .scaleEffect(isPreparingMerge ? 0.96 : 1.0)

                            Image(systemName: "plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isPreparingMerge ? 90 : 0))
                                .scaleEffect(isPreparingMerge ? 0.35 : 1.0)
                                .opacity(isPreparingMerge ? 0.0 : 0.6)

                            WordBubble(text: displayWord(rightWord))
                                .matchedGeometryEffect(id: "rightBubble", in: animationSpace)
                                .offset(x: isPreparingMerge ? -20 : 0)
                                .scaleEffect(isPreparingMerge ? 0.96 : 1.0)
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
                            .onSubmit {
                                if !isMerged && !isPreparingMerge {
                                    combine()
                                }
                            }
                    }
                    .disabled(isMerged || isPreparingMerge)
                    .padding(.horizontal, 24)

                    Button(action: {
                        guard !isPreparingMerge else { return }
                        isMerged ? reset() : combine()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: buttonSymbol)
                            Text(buttonTitle)
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(buttonColor, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: isMerged ? .clear : Color.blue.opacity(0.25), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isPreparingMerge)
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
        guard !isPreparingMerge else { return }
        focusedField = nil
        let normalizedLeft = leftWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRight = rightWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLeft.isEmpty, !normalizedRight.isEmpty else { return }

        let sandhiResult = SandhiEngine.applyProjectSandhi(left: normalizedLeft, right: normalizedRight)
        let matchedSutra = sandhiResult.steps.first(where: { $0.sutra != nil })?.sutra
        let matchedText = matchedSutra.map { "Rule Applied: \($0.code) • \($0.title)" } ??
            "Rule Applied: none"
        let output = sandhiResult.output

        playMergeCueStart()

        withAnimation(.easeInOut(duration: 0.20)) {
            isPreparingMerge = true
            showRuleBadge = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.74)) {
                leftWord = normalizedLeft
                rightWord = normalizedRight
                resultWord = output
                ruleLabel = matchedText
                isMerged = true
                isPreparingMerge = false
            }

            playMergeCueSuccess()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.24)) {
                    showRuleBadge = true
                }
            }
        }
    }

    private func reset() {
        playResetCue()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            isMerged = false
            isPreparingMerge = false
            resultWord = nil
            showRuleBadge = false
            ruleLabel = "Panini Engine Ready"
        }
    }

    private func displayWord(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : trimmed
    }

    private var buttonTitle: String {
        if isMerged {
            return "Reset"
        }
        if isPreparingMerge {
            return "Merging..."
        }
        return "Combine"
    }

    private var buttonSymbol: String {
        if isMerged {
            return "arrow.counterclockwise"
        }
        if isPreparingMerge {
            return "sparkles"
        }
        return "wand.and.stars"
    }

    private var buttonColor: Color {
        if isMerged {
            return .gray
        }
        if isPreparingMerge {
            return .blue.opacity(0.7)
        }
        return .blue
    }

    private func playMergeCueStart() {
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.prepare()
        impact.impactOccurred(intensity: 0.85)
        AudioServicesPlaySystemSound(1104)
    }

    private func playMergeCueSuccess() {
        let notifier = UINotificationFeedbackGenerator()
        notifier.prepare()
        notifier.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1113)
    }

    private func playResetCue() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred(intensity: 0.7)
        AudioServicesPlaySystemSound(1105)
    }
}
