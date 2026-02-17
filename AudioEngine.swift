import AVFoundation
import Foundation

@MainActor
final class AudioEngine {
    static let shared = AudioEngine()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func chant(word1: String, word2: String, result: String) {
        let first = word1.trimmingCharacters(in: .whitespacesAndNewlines)
        let second = word2.trimmingCharacters(in: .whitespacesAndNewlines)
        let merged = result.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !first.isEmpty, !second.isEmpty, !merged.isEmpty else { return }

        synthesizer.stopSpeaking(at: .immediate)

        speak(first, rate: 0.43, preDelay: 0.0, pitch: 0.92)
        speak(second, rate: 0.43, preDelay: 0.26, pitch: 0.92)
        speak(merged, rate: 0.39, preDelay: 0.40, pitch: 0.89)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func speak(_ text: String, rate: Float, preDelay: TimeInterval, pitch: Float) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice()
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.preUtteranceDelay = preDelay
        utterance.postUtteranceDelay = 0.04
        synthesizer.speak(utterance)
    }

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        if let hindi = AVSpeechSynthesisVoice(language: "hi-IN") {
            return hindi
        }
        if let englishIndia = AVSpeechSynthesisVoice(language: "en-IN") {
            return englishIndia
        }
        if let current = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode()) {
            return current
        }
        return AVSpeechSynthesisVoice.speechVoices().first
    }
}
