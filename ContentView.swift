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

    private enum ExplorerMode: String, CaseIterable, Identifiable {
        case combine = "Combine"
        case analyze = "Analyze"

        var id: String { rawValue }
    }

    private struct ReverseDisplayCandidate: Identifiable {
        let id: String
        let left: String
        let right: String
        let sutraLabel: String
        let confidenceLabel: String
        let explanation: String
    }

    private struct TraceDisplayRow: Identifiable {
        let id: String
        let symbol: String
        let tint: Color
        let title: String
        let detail: String
        let transform: String
    }

    private enum InputField {
        case left
        case right
        case merged
    }

    private enum PencilSheetTarget: String, Identifiable {
        case left
        case right
        case merged

        var id: String { rawValue }

        var title: String {
            switch self {
            case .left:
                return "Draw Word 1"
            case .right:
                return "Draw Word 2"
            case .merged:
                return "Draw Merged Word"
            }
        }
    }

    private struct PredictionValidationStatus {
        let isMatch: Bool
        let headline: String
        let detail: String

        var tint: Color {
            isMatch ? .green : .orange
        }

        var symbol: String {
            isMatch ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
        }
    }

    // One-line style switch for demo tuning.
    private let introTone: IntroTone = .modernApple

    @State private var mode: ExplorerMode = .combine
    @State private var leftWord = ""
    @State private var rightWord = ""
    @State private var mergedWord = ""
    @State private var resultWord: String?
    @State private var reverseCandidates: [ReverseDisplayCandidate] = []
    @State private var reverseStatusMessage = "Enter a merged word and tap Analyze."
    @State private var analyzePreviewCandidates: [ReverseDisplayCandidate] = []
    @State private var analyzePreviewMessage = "Type merged word to preview likely splits."
    @State private var hasAnalyzedMergedInput = false
    @State private var isMerged = false
    @State private var isPreparingMerge = false
    @State private var showRuleBadge = false
    @State private var showTraceCard = false
    @State private var isChantEnabled = true
    @State private var traceRows: [TraceDisplayRow] = []
    @State private var showIntro = true
    @State private var introTitleVisible = false
    @State private var introSubtitleVisible = false
    @State private var introGlow = false
    @State private var ruleLabel = "Panini Engine Ready"
    @State private var oraclePrediction: RuleOracle.Prediction?
    @State private var oracleOutputScript: ScriptAdapter.OutputScript = .romanized
    @State private var predictionValidation: PredictionValidationStatus?
    @State private var predictionTestsTotal = 0
    @State private var predictionTestsCorrect = 0
    @State private var activePencilTarget: PencilSheetTarget?
    @Namespace private var animationSpace
    @FocusState private var focusedField: InputField?

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

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

                Picker("Mode", selection: $mode) {
                    ForEach(ExplorerMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)

                if mode == .combine {
                    GeometryReader { geometry in
                        let previewHeight = combinePreviewHeight(for: geometry.size.height, isMerged: isMerged)

                        VStack(spacing: 14) {
                        ZStack {
                            if isMerged, let resultWord {
                                ZStack {
                                    mergedFrontCard(resultWord: resultWord)
                                        .opacity(showTraceCard ? 0 : 1)
                                        .rotation3DEffect(
                                            .degrees(showTraceCard ? 180 : 0),
                                            axis: (x: 0, y: 1, z: 0)
                                        )

                                    mergedTraceCard
                                        .opacity(showTraceCard ? 1 : 0)
                                        .rotation3DEffect(
                                            .degrees(showTraceCard ? 0 : -180),
                                            axis: (x: 0, y: 1, z: 0)
                                        )
                                }
                                .animation(.easeInOut(duration: 0.34), value: showTraceCard)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .padding(.vertical, 8)
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
                        .frame(height: previewHeight)
                        .padding(.top, 8)

                        VStack(spacing: 20) {
                            if !isMerged {
                                VStack(spacing: 0) {
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
                                .disabled(isPreparingMerge)
                                .padding(.horizontal, 24)

                                    if isPad {
                                        HStack(spacing: 12) {
                                            Button(action: {
                                                openPencilSheet(for: .left)
                                            }) {
                                                Label("Pencil Word 1", systemImage: "pencil.tip.crop.circle")
                                                    .font(.footnote.weight(.semibold))
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.bordered)

                                            Button(action: {
                                                openPencilSheet(for: .right)
                                            }) {
                                                Label("Pencil Word 2", systemImage: "pencil.tip.crop.circle")
                                                    .font(.footnote.weight(.semibold))
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.top, 12)

                                        HStack(spacing: 12) {
                                            Button(action: {
                                                focusedField = .left
                                                playPencilCue()
                                            }) {
                                                Label("Focus Word 1", systemImage: "pencil.tip.crop.circle")
                                                    .font(.footnote.weight(.semibold))
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.bordered)

                                            Button(action: {
                                                focusedField = .right
                                                playPencilCue()
                                            }) {
                                                Label("Focus Word 2", systemImage: "pencil.tip.crop.circle")
                                                    .font(.footnote.weight(.semibold))
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.top, 10)

                                        HStack(spacing: 6) {
                                            Image(systemName: "pencil.and.scribble")
                                            Text("Use Pencil sheet for OCR or write directly into focused fields via native Scribble.")
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 24)
                                        .padding(.top, 8)
                                    }

                                    if let oraclePrediction {
                                        oraclePredictionCard(
                                            prediction: oraclePrediction
                                        )
                                        .frame(maxHeight: .infinity, alignment: .top)
                                        .padding(.top, predictionCardTopGap)
                                        .padding(.horizontal, 24)
                                        .transition(.opacity)
                                    } else {
                                        Spacer(minLength: 0)
                                    }
                                }
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                                .frame(maxHeight: .infinity, alignment: .top)
                            }

                            if isMerged {
                                HStack(spacing: 10) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.28)) {
                                            showTraceCard.toggle()
                                        }
                                        playXRayToggleCue()
                                    }) {
                                        Label(
                                            showTraceCard ? "Show Result" : "Algorithm X-Ray",
                                            systemImage: showTraceCard ? "sparkles.rectangle.stack" : "waveform.path.ecg"
                                        )
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.12), in: Capsule())
                                    }

                                    if isChantEnabled {
                                        Button(action: chantVisibleResult) {
                                            Label("Chant", systemImage: "speaker.wave.2.fill")
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(.teal)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.teal.opacity(0.12), in: Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)

                                if let predictionValidation {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: predictionValidation.symbol)
                                            .foregroundStyle(predictionValidation.tint)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(predictionValidation.headline)
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(.primary)

                                            Text(predictionValidation.detail)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 24)
                                    .transition(.opacity)
                                }

                                if showRuleBadge {
                                    Text(ruleLabel)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }

                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)

                        combineBottomControls
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Reverse Sandhi Analyzer")
                            .font(.headline)

                        Text("Input merged word and get top split candidates with sutra confidence.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Merged word (e.g. devAlaya or देवालय)", text: $mergedWord)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .merged)
                            .submitLabel(.search)
                            .onSubmit { analyzeMergedWord() }

                        if isPad {
                            Button(action: {
                                openPencilSheet(for: .merged)
                            }) {
                                Label("Pencil Merged Word", systemImage: "pencil.tip.crop.circle")
                                    .font(.footnote.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        if !hasAnalyzedMergedInput {
                            analyzePreviewCard
                        }

                        Button(action: analyzeMergedWord) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                Text("Analyze Split")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.teal, in: RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.teal.opacity(0.25), radius: 10, x: 0, y: 5)
                        }

                        Text(reverseStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if reverseCandidates.isEmpty {
                            Text("No candidates yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(reverseCandidates) { candidate in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text("\(candidate.left) + \(candidate.right)")
                                                    .font(.subheadline.monospaced())
                                                    .fontWeight(.semibold)

                                                Spacer(minLength: 0)

                                                Text(candidate.confidenceLabel)
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(.teal)
                                            }

                                            Text(candidate.sutraLabel)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)

                                            Text(candidate.explanation)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                            .frame(maxHeight: 260)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    Spacer(minLength: 0)
                }

            }
            .blur(radius: showIntro ? 3 : 0)
            .scaleEffect(showIntro ? 0.985 : 1.0)

            if showIntro {
                introOverlay
                    .transition(.opacity)
            }
        }
        .onChange(of: focusedField) { newValue in
            guard let field = newValue else { return }
            if field == .left || field == .right {
                beginEditing(field)
            }
        }
        .onChange(of: leftWord) { _ in
            refreshOraclePrediction()
        }
        .onChange(of: rightWord) { _ in
            refreshOraclePrediction()
        }
        .onChange(of: mergedWord) { _ in
            guard mode == .analyze else { return }
            hasAnalyzedMergedInput = false
            reverseCandidates = []
            let normalizedMerged = mergedWord.trimmingCharacters(in: .whitespacesAndNewlines)
            reverseStatusMessage = normalizedMerged.isEmpty
                ? "Enter a merged word and tap Analyze."
                : "Preview updated. Tap Analyze Split for full ranked output."
            refreshAnalyzePreview()
        }
        .onChange(of: mode) { newValue in
            if newValue == .combine {
                refreshOraclePrediction()
            } else {
                oraclePrediction = nil
                predictionValidation = nil
                hasAnalyzedMergedInput = false
                reverseCandidates = []
                reverseStatusMessage = "Enter a merged word and tap Analyze."
                refreshAnalyzePreview()
            }
        }
        .sheet(item: $activePencilTarget) { target in
            PencilInputSheet(
                title: target.title,
                initialText: currentText(for: target),
                onCommit: { text in
                    applyPencilText(text, for: target)
                }
            )
        }
        .task {
            runLaunchStory()
            refreshOraclePrediction()
            refreshAnalyzePreview()
        }
    }

    @ViewBuilder
    private func mergedFrontCard(resultWord: String) -> some View {
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
        }
    }

    private var mergedTraceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .foregroundStyle(.blue)
                Text("TRACE LOG")
                    .font(.caption.weight(.black))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(traceRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: row.symbol)
                                    .foregroundStyle(row.tint)

                                Text(row.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }

                            Text(row.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text(row.transform)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .frame(height: 150)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 8)
    }

    private func combine() {
        guard !isPreparingMerge else { return }
        focusedField = nil
        let normalizedLeft = leftWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRight = rightWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLeft.isEmpty, !normalizedRight.isEmpty else { return }

        let predictedCandidate = oraclePrediction?.primary
        let prepared = ScriptAdapter.prepare(left: normalizedLeft, right: normalizedRight)
        let sandhiResult = SandhiEngine.applyProjectSandhi(left: prepared.left, right: prepared.right)
        let matchedSutra = sandhiResult.steps.first(where: { $0.sutra != nil })?.sutra
        let matchedText = matchedSutra.map { "Rule Applied: \($0.code) • \($0.title)" } ??
            "Rule Applied: none"
        let output = ScriptAdapter.present(sandhiResult.output, as: prepared.outputScript)
        let validation = buildPredictionValidation(predicted: predictedCandidate, actual: matchedSutra)
        predictionValidation = validation
        if let validation {
            predictionTestsTotal += 1
            if validation.isMatch {
                predictionTestsCorrect += 1
            }
        }

        traceRows = buildTraceRows(from: sandhiResult.trace)
        showTraceCard = false

        let speakLeft = ScriptAdapter.present(prepared.left, as: .devanagari)
        let speakRight = ScriptAdapter.present(prepared.right, as: .devanagari)
        let speakResult = ScriptAdapter.present(sandhiResult.output, as: .devanagari)

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

            if isChantEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    AudioEngine.shared.chant(word1: speakLeft, word2: speakRight, result: speakResult)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.24)) {
                    showRuleBadge = true
                }
            }
        }
    }

    private func reset() {
        AudioEngine.shared.stop()
        playResetCue()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            isMerged = false
            isPreparingMerge = false
            resultWord = nil
            showRuleBadge = false
            showTraceCard = false
            traceRows = []
            ruleLabel = "Panini Engine Ready"
            predictionValidation = nil
        }
    }

    private func chantVisibleResult() {
        guard let resultWord, !resultWord.isEmpty else { return }
        let prepared = ScriptAdapter.prepare(left: leftWord, right: rightWord)
        let spokenLeft = ScriptAdapter.present(prepared.left, as: .devanagari)
        let spokenRight = ScriptAdapter.present(prepared.right, as: .devanagari)
        let spokenResult = ScriptAdapter.prepareMerged(word: resultWord).word
        let renderedResult = ScriptAdapter.present(spokenResult, as: .devanagari)
        AudioEngine.shared.chant(word1: spokenLeft, word2: spokenRight, result: renderedResult)
    }

    private func beginEditing(_ field: InputField) {
        if isMerged {
            clearMergedState(animated: true)
        }
        focusedField = field
    }

    private func analyzeMergedWord() {
        focusedField = nil
        let normalizedMerged = mergedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMerged.isEmpty else {
            hasAnalyzedMergedInput = false
            reverseCandidates = []
            reverseStatusMessage = "Enter a merged word to analyze."
            return
        }
        hasAnalyzedMergedInput = true

        let prepared = ScriptAdapter.prepareMerged(word: normalizedMerged)
        let reverseResult = ReverseSandhiAnalyzer.analyze(merged: prepared.word, maxCandidates: 5)

        reverseCandidates = makeReverseDisplayCandidates(
            from: reverseResult.candidates,
            outputScript: prepared.outputScript
        )

        if reverseCandidates.isEmpty {
            reverseStatusMessage = "No confident split found in current active rule scope."
            playAnalyzeCue(foundCandidates: false)
        } else {
            reverseStatusMessage = "Top \(reverseCandidates.count) candidate(s) ranked by confidence."
            playAnalyzeCue(foundCandidates: true)
        }
    }

    private func refreshAnalyzePreview() {
        let normalizedMerged = mergedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMerged.isEmpty else {
            analyzePreviewCandidates = []
            analyzePreviewMessage = "Type merged word to preview likely splits."
            return
        }

        let prepared = ScriptAdapter.prepareMerged(word: normalizedMerged)
        let previewResult = ReverseSandhiAnalyzer.analyze(merged: prepared.word, maxCandidates: 3)
        analyzePreviewCandidates = makeReverseDisplayCandidates(
            from: previewResult.candidates,
            outputScript: prepared.outputScript
        )

        if analyzePreviewCandidates.isEmpty {
            analyzePreviewMessage = "No confident split preview in current rule scope."
        } else {
            analyzePreviewMessage = "Live prediction before analyze."
        }
    }

    private func makeReverseDisplayCandidates(
        from candidates: [ReverseSandhiAnalyzer.Candidate],
        outputScript: ScriptAdapter.OutputScript
    ) -> [ReverseDisplayCandidate] {
        candidates.map { candidate in
            let leftDisplay = ScriptAdapter.present(candidate.left, as: outputScript)
            let rightDisplay = ScriptAdapter.present(candidate.right, as: outputScript)
            let percent = Int((candidate.confidence * 100).rounded())

            return ReverseDisplayCandidate(
                id: candidate.id,
                left: leftDisplay,
                right: rightDisplay,
                sutraLabel: "\(candidate.sutra.code) • \(candidate.sutra.title)",
                confidenceLabel: "\(percent)%",
                explanation: candidate.explanation
            )
        }
    }

    private var analyzePreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.teal)
                Text("Split Prediction")
                    .font(.headline)
                Spacer(minLength: 0)
            }

            Text(analyzePreviewMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            if analyzePreviewCandidates.isEmpty {
                Text("No preview candidates yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(analyzePreviewCandidates) { candidate in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(candidate.left) + \(candidate.right)")
                                .font(.subheadline.monospaced())
                                .fontWeight(.semibold)

                            Spacer(minLength: 0)

                            Text(candidate.confidenceLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.teal)
                        }

                        Text(candidate.sutraLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.teal.opacity(0.25), lineWidth: 1)
        )
    }

    private func clearMergedState(animated: Bool) {
        let applyReset = {
            isMerged = false
            resultWord = nil
            showRuleBadge = false
            showTraceCard = false
            traceRows = []
            ruleLabel = "Panini Engine Ready"
            predictionValidation = nil
        }

        if animated {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                applyReset()
            }
        } else {
            applyReset()
        }
    }

    private func refreshOraclePrediction() {
        guard mode == .combine else {
            oraclePrediction = nil
            return
        }

        let normalizedLeft = leftWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRight = rightWord.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedLeft.isEmpty, !normalizedRight.isEmpty else {
            oraclePrediction = nil
            return
        }

        let prepared = ScriptAdapter.prepare(left: normalizedLeft, right: normalizedRight)
        oracleOutputScript = prepared.outputScript
        oraclePrediction = RuleOracle.predict(left: prepared.left, right: prepared.right, maxAlternatives: 3)

        if !isMerged {
            predictionValidation = nil
        }
    }

    private func openPencilSheet(for target: PencilSheetTarget) {
        guard isPad else { return }
        playPencilCue()
        activePencilTarget = target
    }

    private func currentText(for target: PencilSheetTarget) -> String {
        switch target {
        case .left:
            return leftWord
        case .right:
            return rightWord
        case .merged:
            return mergedWord
        }
    }

    private func applyPencilText(_ text: String, for target: PencilSheetTarget) {
        switch target {
        case .left:
            mode = .combine
            if isMerged {
                clearMergedState(animated: true)
            }
            leftWord = text
            focusedField = .right
        case .right:
            mode = .combine
            if isMerged {
                clearMergedState(animated: true)
            }
            rightWord = text
            focusedField = .right
        case .merged:
            mode = .analyze
            mergedWord = text
            focusedField = .merged
        }
    }

    private func buildPredictionValidation(
        predicted: RuleOracle.Candidate?,
        actual: SandhiSutra?
    ) -> PredictionValidationStatus? {
        guard let predicted else { return nil }

        let predictedCode = predicted.code
        let actualCode = actual?.code
        let isMatch = predictedCode == actualCode

        let predictedLabel = oracleRuleLabel(for: predicted)
        let actualLabel = actual.map { "\($0.code) • \($0.title)" } ?? "No in-scope rule"

        if isMatch {
            return PredictionValidationStatus(
                isMatch: true,
                headline: "Oracle matched runtime rule.",
                detail: "Predicted \(predictedLabel), runtime applied \(actualLabel)."
            )
        }

        return PredictionValidationStatus(
            isMatch: false,
            headline: "Oracle differed from runtime rule.",
            detail: "Predicted \(predictedLabel), runtime applied \(actualLabel)."
        )
    }

    @ViewBuilder
    private func oraclePredictionCard(
        prediction: RuleOracle.Prediction
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text("Panini's Prediction")
                    .font(.headline)
                Spacer(minLength: 0)
                Text(confidenceLabel(prediction.primary.confidence))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Divider()

            Text(oracleRuleLabel(for: prediction.primary))
                .font(.subheadline.weight(.semibold))

            ProgressView(value: prediction.primary.confidence)
                .tint(.orange)

            if predictionTestsTotal > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .foregroundStyle(.orange)
                    Text("Session score: \(predictionTestsCorrect)/\(predictionTestsTotal) correct (\(predictionAccuracyPercent)%)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    Button("Reset") {
                        resetPredictionScore()
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .buttonStyle(.plain)
                }
            }

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(prediction.primary.reasoning)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(prediction.boundarySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(paribhashaExplanation(for: prediction))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    let expectedDisplay = ScriptAdapter.present(prediction.expectedOutput, as: oracleOutputScript)
                    Text("Expected output: \(expectedDisplay)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

                    if !prediction.alternatives.isEmpty {
                        Divider()
                        Text("Alternative possibilities")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(prediction.alternatives) { candidate in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(oracleRuleLabel(for: candidate))
                                        .font(.caption.weight(.semibold))
                                    Text(candidate.reasoning)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Text(confidenceLabel(candidate.confidence))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1.5)
        )
        .clipped()
    }

    private func oracleRuleLabel(for candidate: RuleOracle.Candidate) -> String {
        if let code = candidate.code {
            return "\(code) • \(candidate.title)"
        }
        return candidate.title
    }

    private func confidenceLabel(_ value: Double) -> String {
        let percent = Int((value * 100).rounded())
        return "\(percent)%"
    }

    private var predictionAccuracyPercent: Int {
        guard predictionTestsTotal > 0 else { return 0 }
        let ratio = Double(predictionTestsCorrect) / Double(predictionTestsTotal)
        return Int((ratio * 100).rounded())
    }

    private var predictionCardTopGap: CGFloat {
        isPad ? 16 : 14
    }

    private func resetPredictionScore() {
        predictionTestsCorrect = 0
        predictionTestsTotal = 0
    }

    private func runtimeRuleRank(for code: String) -> Int? {
        SandhiEngine.projectRuntimeRulebook.firstIndex { $0.code == code }
    }

    private func paribhashaExplanation(for prediction: RuleOracle.Prediction) -> String {
        guard let primaryCode = prediction.primary.code else {
            return "Paribhasha: no active in-scope sutra condition is satisfied, so direct concatenation stands."
        }

        if let alternativeCode = prediction.alternatives.first?.code,
           let primaryRank = runtimeRuleRank(for: primaryCode),
           let alternativeRank = runtimeRuleRank(for: alternativeCode),
           primaryRank < alternativeRank {
            return "Paribhasha: ordered conflict resolution applies. \(primaryCode) is checked before \(alternativeCode), and later rules are skipped once a match is found (vipratisedhe param karyam)."
        }

        return "Paribhasha: ordered conflict resolution applies. \(primaryCode) is the first satisfied rule at this boundary, so competing rules remain blocked (vipratisedhe param karyam)."
    }

    private func combinePreviewHeight(for availableHeight: CGFloat, isMerged: Bool) -> CGFloat {
        if isPad {
            if isMerged {
                return min(320, max(220, availableHeight * 0.38))
            }
            return min(260, max(180, availableHeight * 0.30))
        }

        if isMerged {
            return min(250, max(170, availableHeight * 0.34))
        }
        return min(195, max(128, availableHeight * 0.27))
    }

    private func displayWord(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : trimmed
    }

    private var combineBottomControls: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $isChantEnabled) {
                Label(
                    isChantEnabled ? "Voice of Panini: On" : "Voice of Panini: Off",
                    systemImage: isChantEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)

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
                .shadow(color: isMerged ? .clear : buttonColor.opacity(0.25), radius: 10, x: 0, y: 5)
            }
            .disabled(isPreparingMerge)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var buttonTitle: String {
        if isMerged {
            return "Reset"
        }
        if isPreparingMerge {
            return "Merging..."
        }
        if oraclePrediction != nil {
            return "Test Prediction"
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
        if oraclePrediction != nil {
            return "scope"
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
        if oraclePrediction != nil {
            return .orange
        }
        return .blue
    }

    private func buildTraceRows(from trace: [SandhiRuleTrace]) -> [TraceDisplayRow] {
        trace.enumerated().map { index, entry in
            let style = traceStyle(for: entry.outcome)
            return TraceDisplayRow(
                id: "\(index)-\(entry.sutra.code)-\(entry.outcome.rawValue)",
                symbol: style.symbol,
                tint: style.tint,
                title: "\(style.label) \(entry.sutra.code) • \(entry.sutra.title)",
                detail: entry.reasoning,
                transform: "\(entry.before) -> \(entry.after)"
            )
        }
    }

    private func traceStyle(for outcome: SandhiRuleTraceOutcome) -> (label: String, symbol: String, tint: Color) {
        switch outcome {
        case .matched:
            return ("MATCH", "checkmark.seal.fill", .green)
        case .failed:
            return ("FAIL", "xmark.circle.fill", .red)
        case .skipped:
            return ("SKIP", "arrowshape.turn.up.right.circle.fill", .gray)
        }
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

    private func playAnalyzeCue(foundCandidates: Bool) {
        let notifier = UINotificationFeedbackGenerator()
        notifier.prepare()
        notifier.notificationOccurred(foundCandidates ? .success : .warning)
        AudioServicesPlaySystemSound(foundCandidates ? 1113 : 1102)
    }

    private func playXRayToggleCue() {
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.prepare()
        impact.impactOccurred(intensity: 0.65)
        AudioServicesPlaySystemSound(1157)
    }

    private func playPencilCue() {
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.prepare()
        impact.impactOccurred(intensity: 0.65)
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
