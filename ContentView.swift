import AudioToolbox
import SwiftUI
import UIKit

struct ContentView: View {
    private enum IntroTone {
        case seriousClassical
        case modernApple
        case dramaticStage
    }

    private struct IntroStyle {
        let title: String
        let subtitle: String
        let colors: [Color]
        let glowColor: Color
        let titleGradient: [Color]
        let titleSize: CGFloat
        let subtitleColor: Color
        let impactStyle: UIImpactFeedbackGenerator.FeedbackStyle
        let impactIntensity: CGFloat
    }

    private enum InputField {
        case left
        case right
    }

    // One-line style switch for demo tuning.
    private let introTone: IntroTone = .modernApple

    @State private var leftWord = ""
    @State private var rightWord = ""
    @State private var resultWord: String?
    @State private var isMerged = false
    @State private var isPreparingMerge = false
    @State private var showRuleBadge = false
    @State private var showIntro = true
    @State private var introTitleVisible = false
    @State private var introSubtitleVisible = false
    @State private var introGlow = false
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
            .blur(radius: showIntro ? 3 : 0)
            .scaleEffect(showIntro ? 0.985 : 1.0)

            if showIntro {
                introOverlay
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.58, dampingFraction: 0.74), value: isMerged)
        .task {
            runLaunchStory()
        }
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

    private var introOverlay: some View {
        let style = introStyle

        return ZStack {
            LinearGradient(
                colors: style.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(style.glowColor.opacity(introGlow ? 0.22 : 0.10))
                .frame(width: introGlow ? 320 : 250, height: introGlow ? 320 : 250)
                .blur(radius: introGlow ? 12 : 3)
                .animation(.easeInOut(duration: 0.65), value: introGlow)

            VStack(spacing: 12) {
                Text(style.title)
                    .font(.system(size: style.titleSize, weight: .black, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: style.titleGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(introTitleVisible ? 1 : 0)
                    .offset(y: introTitleVisible ? 0 : 10)

                Text(style.subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(style.subtitleColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .opacity(introSubtitleVisible ? 1 : 0)
                    .offset(y: introSubtitleVisible ? 0 : 8)
            }
        }
    }

    private func runLaunchStory() {
        guard showIntro else { return }

        let style = introStyle
        let introImpact = UIImpactFeedbackGenerator(style: style.impactStyle)
        introImpact.prepare()

        withAnimation(.easeOut(duration: 0.34)) {
            introGlow = true
            introTitleVisible = true
        }
        introImpact.impactOccurred(intensity: style.impactIntensity)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.26)) {
                introSubtitleVisible = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.easeInOut(duration: 0.35)) {
                showIntro = false
            }
        }
    }

    private var introStyle: IntroStyle {
        switch introTone {
        case .seriousClassical:
            return IntroStyle(
                title: "Panini Sutra Engine",
                subtitle: "Ancient linguistic precision, rendered in Swift.",
                colors: [
                    Color(uiColor: .systemBackground).opacity(0.97),
                    Color.brown.opacity(0.16),
                    Color.orange.opacity(0.12)
                ],
                glowColor: .orange,
                titleGradient: [.brown, .orange],
                titleSize: 34,
                subtitleColor: .secondary,
                impactStyle: .soft,
                impactIntensity: 0.68
            )
        case .modernApple:
            return IntroStyle(
                title: "Panini Engine",
                subtitle: "Where 2500-year-old rules become living motion.",
                colors: [
                    Color(uiColor: .systemBackground).opacity(0.95),
                    Color.blue.opacity(0.16),
                    Color.teal.opacity(0.14)
                ],
                glowColor: .blue,
                titleGradient: [.blue, .teal],
                titleSize: 36,
                subtitleColor: .secondary,
                impactStyle: .soft,
                impactIntensity: 0.72
            )
        case .dramaticStage:
            return IntroStyle(
                title: "SANDHI: LIVE",
                subtitle: "Watch sound laws collide, transform, and resolve.",
                colors: [
                    Color.black.opacity(0.96),
                    Color.red.opacity(0.28),
                    Color.orange.opacity(0.18)
                ],
                glowColor: .red,
                titleGradient: [.red, .orange],
                titleSize: 38,
                subtitleColor: .white.opacity(0.82),
                impactStyle: .rigid,
                impactIntensity: 0.84
            )
        }
    }
}
