import CoreImage
import CoreImage.CIFilterBuiltins
import PencilKit
import SwiftUI
import Vision

struct PencilInputSheet: View {
    enum RecognitionMode: String, CaseIterable, Identifiable {
        case roman = "Roman"
        case devanagari = "Devanagari (Beta)"

        var id: String { rawValue }

        var strictLanguages: [String] {
            switch self {
            case .roman:
                return ["en-US", "en-GB", "en-IN"]
            case .devanagari:
                return ["hi-IN"]
            }
        }

        var hint: String {
            switch self {
            case .roman:
                return "Best accuracy mode. Write big Roman letters: deva, alaya, namah."
            case .devanagari:
                return "Experimental mode. Write large, separated Devanagari characters."
            }
        }
    }

    struct OCRCandidate: Identifiable {
        let id = UUID()
        let text: String
        let confidence: Float
    }

    private struct OCRImageSet {
        let raw: CGImage
        let processed: CGImage
    }

    let title: String
    let initialText: String
    let onCommit: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var drawing = PKDrawing()
    @State private var recognizedText = ""
    @State private var confidenceLabel = ""
    @State private var isRecognizing = false
    @State private var recognitionMessage = "Draw with Apple Pencil, then tap Recognize."
    @State private var mode: RecognitionMode = .roman
    @State private var candidates: [OCRCandidate] = []

    private let ciContext = CIContext(options: nil)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                Text("Offline recognition powered by PencilKit + Vision.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Picker("Recognition Mode", selection: $mode) {
                    ForEach(RecognitionMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Text(mode.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                PencilCanvasView(drawing: $drawing)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Button(action: clearDrawing) {
                        Label("Clear", systemImage: "eraser")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: recognizeDrawing) {
                        HStack(spacing: 6) {
                            if isRecognizing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Image(systemName: "wand.and.stars")
                            Text(isRecognizing ? "Reading..." : "Recognize")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRecognizing)
                }

                TextField("Recognized text", text: $recognizedText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !candidates.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top candidates")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(candidates) { candidate in
                            Button(action: {
                                recognizedText = candidate.text
                            }) {
                                HStack {
                                    Text(candidate.text)
                                        .font(.subheadline.monospaced())
                                        .foregroundStyle(.primary)

                                    Spacer(minLength: 0)

                                    Text("\(Int((candidate.confidence * 100).rounded()))%")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.teal)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }

                VStack(spacing: 4) {
                    Text(recognitionMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if !confidenceLabel.isEmpty {
                        Text(confidenceLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.teal)
                    }
                }

                Button(action: commitAndDismiss) {
                    Label("Use This Text", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(finalOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                recognizedText = initialText
            }
        }
    }

    private var finalOutput: String {
        recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clearDrawing() {
        drawing = PKDrawing()
        confidenceLabel = ""
        candidates = []
        recognitionMessage = "Canvas cleared. Draw again and tap Recognize."
    }

    private func commitAndDismiss() {
        let output = finalOutput
        guard !output.isEmpty else { return }
        onCommit(output)
        dismiss()
    }

    private func recognizeDrawing() {
        guard !drawing.strokes.isEmpty else {
            recognitionMessage = "Draw at least one character before recognition."
            confidenceLabel = ""
            candidates = []
            return
        }

        guard let images = makeOCRImageSet(from: drawing) else {
            recognitionMessage = "Could not prepare drawing image for recognition."
            confidenceLabel = ""
            candidates = []
            return
        }

        isRecognizing = true
        recognitionMessage = "Recognizing handwriting (offline)..."
        confidenceLabel = ""
        candidates = []

        let modeSnapshot = mode
        let drawingSnapshot = drawing

        DispatchQueue.global(qos: .userInitiated).async {
            let strictProcessed = runOCRPass(
                cgImage: images.processed,
                mode: modeSnapshot,
                languageHint: modeSnapshot.strictLanguages,
                minTextHeight: 0.008,
                customWords: customWords(for: modeSnapshot),
                recognitionLevel: .accurate,
                usesLanguageCorrection: true
            )

            let strictRaw = runOCRPass(
                cgImage: images.raw,
                mode: modeSnapshot,
                languageHint: modeSnapshot.strictLanguages,
                minTextHeight: 0.006,
                customWords: customWords(for: modeSnapshot),
                recognitionLevel: .accurate,
                usesLanguageCorrection: true
            )

            let fallbackProcessed = runOCRPass(
                cgImage: images.processed,
                mode: modeSnapshot,
                languageHint: [],
                minTextHeight: 0.004,
                customWords: customWords(for: modeSnapshot),
                recognitionLevel: .accurate,
                usesLanguageCorrection: false
            )

            let fallbackRaw = runOCRPass(
                cgImage: images.raw,
                mode: modeSnapshot,
                languageHint: [],
                minTextHeight: 0.003,
                customWords: customWords(for: modeSnapshot),
                recognitionLevel: .accurate,
                usesLanguageCorrection: false
            )

            let fastRaw = runOCRPass(
                cgImage: images.raw,
                mode: modeSnapshot,
                languageHint: [],
                minTextHeight: 0.001,
                customWords: customWords(for: modeSnapshot),
                recognitionLevel: .fast,
                usesLanguageCorrection: false
            )

            let wordCandidates = dedupeTopCandidates(
                strictProcessed + strictRaw + fallbackProcessed + fallbackRaw + fastRaw,
                limit: 5
            )

            let singleGlyphCandidates: [OCRCandidate]
            if wordCandidates.isEmpty {
                let singleStrict = runOCRPass(
                    cgImage: images.raw,
                    mode: modeSnapshot,
                    languageHint: modeSnapshot.strictLanguages,
                    minTextHeight: 0.001,
                    customWords: singleGlyphCustomWords(for: modeSnapshot),
                    recognitionLevel: .accurate,
                    usesLanguageCorrection: false
                )

                let singleFast = runOCRPass(
                    cgImage: images.processed,
                    mode: modeSnapshot,
                    languageHint: [],
                    minTextHeight: 0.0008,
                    customWords: singleGlyphCustomWords(for: modeSnapshot),
                    recognitionLevel: .fast,
                    usesLanguageCorrection: false
                )

                singleGlyphCandidates = dedupeTopCandidates(
                    (singleStrict + singleFast).filter { isSingleGlyphCandidate($0.text, mode: modeSnapshot) },
                    limit: 5
                )
            } else {
                singleGlyphCandidates = []
            }

            let segmentedGlyphCandidates: [OCRCandidate]
            if wordCandidates.isEmpty && singleGlyphCandidates.isEmpty {
                segmentedGlyphCandidates = recognizeSegmentedGlyphFallback(
                    from: drawingSnapshot,
                    mode: modeSnapshot
                )
            } else {
                segmentedGlyphCandidates = []
            }

            let merged: [OCRCandidate]
            if !wordCandidates.isEmpty {
                merged = wordCandidates
            } else if !singleGlyphCandidates.isEmpty {
                merged = singleGlyphCandidates
            } else {
                merged = segmentedGlyphCandidates
            }
            let usedSingleGlyphFallback = wordCandidates.isEmpty && !singleGlyphCandidates.isEmpty
            let usedSegmentedGlyphFallback = wordCandidates.isEmpty &&
                singleGlyphCandidates.isEmpty &&
                !segmentedGlyphCandidates.isEmpty
            let top = merged.first

            DispatchQueue.main.async {
                isRecognizing = false
                candidates = merged

                if let top {
                    recognizedText = top.text
                    confidenceLabel = "Top confidence: \(Int((top.confidence * 100).rounded()))%"
                    if usedSingleGlyphFallback {
                        recognitionMessage = "Single-letter fallback matched. Tap a candidate or edit manually."
                    } else if usedSegmentedGlyphFallback {
                        recognitionMessage = "Segmented-glyph fallback matched. Tap a candidate or edit manually."
                    } else {
                        recognitionMessage = "Recognition complete. Tap a candidate or edit manually."
                    }
                } else {
                    recognitionMessage = modeSnapshot == .roman
                        ? "No text detected. Write full word in one line (example: deva), keep letters separated."
                        : "No clear Devanagari text detected. Try larger strokes, straighter baseline, or Roman mode."
                    confidenceLabel = ""
                }
            }
        }
    }

    private func makeOCRImageSet(from drawing: PKDrawing) -> OCRImageSet? {
        var rect = drawing.bounds
        if rect.isNull || rect.isEmpty {
            rect = CGRect(x: 0, y: 0, width: 900, height: 380)
        }
        rect = rect.insetBy(dx: -44, dy: -44)

        let source = drawing.image(from: rect, scale: 4.0)
        guard let sourceCG = source.cgImage else { return nil }
        guard let rawCG = renderOnWhite(cgImage: sourceCG) else { return nil }

        let inputCI = CIImage(cgImage: rawCG)

        let controls = CIFilter.colorControls()
        controls.inputImage = inputCI
        controls.contrast = 2.6
        controls.brightness = 0.09
        controls.saturation = 0
        let contrastImage = controls.outputImage ?? inputCI

        let mono = CIFilter.photoEffectMono()
        mono.inputImage = contrastImage
        let monoImage = mono.outputImage ?? contrastImage

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = monoImage
        sharpen.sharpness = 1.2
        let sharpened = sharpen.outputImage ?? monoImage

        let clamp = CIFilter.colorClamp()
        clamp.inputImage = sharpened
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        let finalCI = clamp.outputImage ?? sharpened

        let processedCG = ciContext.createCGImage(finalCI, from: finalCI.extent) ?? rawCG
        return OCRImageSet(raw: rawCG, processed: processedCG)
    }

    private func renderOnWhite(cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

}

private func runOCRPass(
    cgImage: CGImage,
    mode: PencilInputSheet.RecognitionMode,
    languageHint: [String],
    minTextHeight: Float,
    customWords: [String],
    recognitionLevel: VNRequestTextRecognitionLevel,
    usesLanguageCorrection: Bool
) -> [PencilInputSheet.OCRCandidate] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = recognitionLevel
    request.usesLanguageCorrection = usesLanguageCorrection
    request.minimumTextHeight = minTextHeight
    request.customWords = customWords

    if !languageHint.isEmpty,
       let supported = try? request.supportedRecognitionLanguages() {
        let active = languageHint.filter { supported.contains($0) }
        if !active.isEmpty {
            request.recognitionLanguages = active
        }
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        return []
    }

    let observations = request.results ?? []
    var result: [PencilInputSheet.OCRCandidate] = []

    for observation in observations.prefix(12) {
        for item in observation.topCandidates(5) {
            let cleaned = normalizeRecognizedText(item.string, mode: mode)
            guard !cleaned.isEmpty else { continue }
            result.append(.init(text: cleaned, confidence: item.confidence))
        }
    }

    return result
}

private func normalizeRecognizedText(
    _ text: String,
    mode: PencilInputSheet.RecognitionMode
) -> String {
    var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !output.isEmpty else { return "" }

    output = output.replacingOccurrences(of: "|", with: "I")
    output = output.replacingOccurrences(of: "0", with: "o")

    if mode == .roman {
        output = output.replacingOccurrences(of: " ", with: "")
    }

    return output
}

private func customWords(for mode: PencilInputSheet.RecognitionMode) -> [String] {
    switch mode {
    case .roman:
        return [
            "deva", "alaya", "devalaya", "namah", "te", "namaste",
            "rama", "shiva", "indra", "maha", "hari", "api",
            "ai", "au", "guna", "vrddhi", "sandhi"
        ]
    case .devanagari:
        return [
            "देव", "आलय", "देवालय", "नमः", "ते", "नमस्ते", "राम", "शिव"
        ]
    }
}

private func singleGlyphCustomWords(for mode: PencilInputSheet.RecognitionMode) -> [String] {
    switch mode {
    case .roman:
        return [
            "a", "A", "i", "I", "u", "U", "e", "o", "R", "L", "ai", "au",
            "h", "m", "n", "t", "d", "s", "r", "y", "v", "k", "g", "p", "b"
        ]
    case .devanagari:
        return [
            "अ", "आ", "इ", "ई", "उ", "ऊ", "ऋ", "ए", "ऐ", "ओ", "औ",
            "क", "ग", "न", "म", "त", "द", "र", "स", "ह", "व", "य"
        ]
    }
}

private func isSingleGlyphCandidate(
    _ text: String,
    mode: PencilInputSheet.RecognitionMode
) -> Bool {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return false }

    switch mode {
    case .roman:
        if value.contains(" ") { return false }
        if value.count > 2 { return false }
        return value.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    case .devanagari:
        return value.unicodeScalars.count <= 2
    }
}

private func dedupeTopCandidates(
    _ raw: [PencilInputSheet.OCRCandidate],
    limit: Int
) -> [PencilInputSheet.OCRCandidate] {
    var byText: [String: PencilInputSheet.OCRCandidate] = [:]

    for item in raw {
        let key = item.text.lowercased()
        if let existing = byText[key] {
            if item.confidence > existing.confidence {
                byText[key] = item
            }
        } else {
            byText[key] = item
        }
    }

    return byText.values
        .sorted { $0.confidence > $1.confidence }
        .prefix(limit)
        .map { $0 }
}

private func recognizeSegmentedGlyphFallback(
    from drawing: PKDrawing,
    mode: PencilInputSheet.RecognitionMode
) -> [PencilInputSheet.OCRCandidate] {
    let groups = splitStrokeGroupsForFallback(from: drawing)
    guard groups.count > 1 else { return [] }

    let ciContext = CIContext(options: nil)
    var glyphCandidates: [PencilInputSheet.OCRCandidate] = []

    for group in groups {
        let glyphDrawing = PKDrawing(strokes: group)
        guard let images = makeOCRImageSetForFallback(from: glyphDrawing, ciContext: ciContext) else { return [] }

        let strict = runOCRPass(
            cgImage: images.raw,
            mode: mode,
            languageHint: mode.strictLanguages,
            minTextHeight: 0.0008,
            customWords: singleGlyphCustomWords(for: mode),
            recognitionLevel: .accurate,
            usesLanguageCorrection: false
        )

        let fast = runOCRPass(
            cgImage: images.processed,
            mode: mode,
            languageHint: [],
            minTextHeight: 0.0005,
            customWords: singleGlyphCustomWords(for: mode),
            recognitionLevel: .fast,
            usesLanguageCorrection: false
        )

        guard let best = dedupeTopCandidates(
            (strict + fast).filter { isSingleGlyphCandidate($0.text, mode: mode) },
            limit: 1
        ).first else {
            return []
        }

        glyphCandidates.append(best)
    }

    let text = glyphCandidates.map(\.text).joined()
    guard !text.isEmpty else { return [] }

    let meanConfidence = glyphCandidates.map(\.confidence).reduce(0, +) / Float(glyphCandidates.count)
    return [PencilInputSheet.OCRCandidate(text: text, confidence: meanConfidence)]
}

private func splitStrokeGroupsForFallback(from drawing: PKDrawing) -> [[PKStroke]] {
    let strokes = drawing.strokes
    guard strokes.count > 1 else { return [] }

    let ordered = strokes.sorted { lhs, rhs in
        lhs.renderBounds.minX < rhs.renderBounds.minX
    }

    let drawingWidth = max(drawing.bounds.width, 1)
    let splitGap = max(24, min(70, drawingWidth * 0.08))

    var groups: [[PKStroke]] = []
    var current: [PKStroke] = [ordered[0]]
    var currentMaxX = ordered[0].renderBounds.maxX

    for stroke in ordered.dropFirst() {
        let gap = stroke.renderBounds.minX - currentMaxX
        if gap > splitGap {
            groups.append(current)
            current = [stroke]
            currentMaxX = stroke.renderBounds.maxX
        } else {
            current.append(stroke)
            currentMaxX = max(currentMaxX, stroke.renderBounds.maxX)
        }
    }

    groups.append(current)
    return groups
}

private func makeOCRImageSetForFallback(
    from drawing: PKDrawing,
    ciContext: CIContext
) -> (raw: CGImage, processed: CGImage)? {
    var rect = drawing.bounds
    if rect.isNull || rect.isEmpty {
        rect = CGRect(x: 0, y: 0, width: 900, height: 380)
    }
    rect = rect.insetBy(dx: -44, dy: -44)

    let source = drawing.image(from: rect, scale: 4.0)
    guard let sourceCG = source.cgImage else { return nil }
    guard let rawCG = renderOnWhiteForFallback(cgImage: sourceCG) else { return nil }

    let inputCI = CIImage(cgImage: rawCG)

    let controls = CIFilter.colorControls()
    controls.inputImage = inputCI
    controls.contrast = 2.6
    controls.brightness = 0.09
    controls.saturation = 0
    let contrastImage = controls.outputImage ?? inputCI

    let mono = CIFilter.photoEffectMono()
    mono.inputImage = contrastImage
    let monoImage = mono.outputImage ?? contrastImage

    let sharpen = CIFilter.sharpenLuminance()
    sharpen.inputImage = monoImage
    sharpen.sharpness = 1.2
    let sharpened = sharpen.outputImage ?? monoImage

    let clamp = CIFilter.colorClamp()
    clamp.inputImage = sharpened
    clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
    clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
    let finalCI = clamp.outputImage ?? sharpened

    let processedCG = ciContext.createCGImage(finalCI, from: finalCI.extent) ?? rawCG
    return (raw: rawCG, processed: processedCG)
}

private func renderOnWhiteForFallback(cgImage: CGImage) -> CGImage? {
    let width = cgImage.width
    let height = cgImage.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.setFillColor(UIColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
}

private struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = UIColor.white
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.tool = PKInkingTool(.pen, color: .black, width: 7)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private var parent: PencilCanvasView

        init(parent: PencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
