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
            VStack(spacing: 14) {
                Text("Handwriting Input")
                    .font(.headline)

                Text("Offline recognition powered by PencilKit + Vision.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

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

        guard let processedCGImage = makeProcessedOCRImage(from: drawing) else {
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

        DispatchQueue.global(qos: .userInitiated).async {
            let strict = runOCRPass(
                cgImage: processedCGImage,
                mode: modeSnapshot,
                languageHint: modeSnapshot.strictLanguages,
                minTextHeight: 0.008,
                customWords: customWords(for: modeSnapshot)
            )

            let fallback = runOCRPass(
                cgImage: processedCGImage,
                mode: modeSnapshot,
                languageHint: [],
                minTextHeight: 0.004,
                customWords: customWords(for: modeSnapshot)
            )

            let merged = dedupeTopCandidates(strict + fallback, limit: 3)
            let top = merged.first

            DispatchQueue.main.async {
                isRecognizing = false
                candidates = merged

                if let top {
                    recognizedText = top.text
                    confidenceLabel = "Top confidence: \(Int((top.confidence * 100).rounded()))%"
                    recognitionMessage = "Recognition complete. Tap a candidate or edit manually."
                } else {
                    recognitionMessage = modeSnapshot == .roman
                        ? "No text detected. Write larger Roman letters with spacing (example: deva)."
                        : "No clear Devanagari text detected. Try larger strokes or use Roman mode for reliability."
                    confidenceLabel = ""
                }
            }
        }
    }

    private func makeProcessedOCRImage(from drawing: PKDrawing) -> CGImage? {
        var rect = drawing.bounds
        if rect.isNull || rect.isEmpty {
            rect = CGRect(x: 0, y: 0, width: 900, height: 380)
        }
        rect = rect.insetBy(dx: -36, dy: -36)

        let source = drawing.image(from: rect, scale: 4.0)
        guard let sourceCG = source.cgImage else { return nil }

        let inputCI = CIImage(cgImage: sourceCG)

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

        return ciContext.createCGImage(finalCI, from: finalCI.extent)
    }
}

private func runOCRPass(
    cgImage: CGImage,
    mode: PencilInputSheet.RecognitionMode,
    languageHint: [String],
    minTextHeight: Float,
    customWords: [String]
) -> [PencilInputSheet.OCRCandidate] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
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
