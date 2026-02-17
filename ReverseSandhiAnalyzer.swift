import Foundation

enum ReverseSandhiAnalyzer {
    struct Candidate: Identifiable, Hashable, Sendable {
        let left: String
        let right: String
        let sutra: SandhiSutra
        let confidence: Double
        let explanation: String

        var id: String { "\(left)|\(right)|\(sutra.code)" }
    }

    struct Result: Sendable {
        let input: String
        let candidates: [Candidate]
    }

    private static let sutra101 = SandhiSutra(chapter: .sixOne, number: 101, title: "akah savarne dirghah")
    private static let sutra94 = SandhiSutra(chapter: .sixOne, number: 94, title: "eNgi pararupam")
    private static let sutra88 = SandhiSutra(chapter: .sixOne, number: 88, title: "vrddhir eci")
    private static let sutra87 = SandhiSutra(chapter: .sixOne, number: 87, title: "ad gunah")
    private static let sutra109 = SandhiSutra(chapter: .sixOne, number: 109, title: "eNah padantad ati")
    private static let sutra78 = SandhiSutra(chapter: .sixOne, number: 78, title: "eco yavayavah")
    private static let sutra77 = SandhiSutra(chapter: .sixOne, number: 77, title: "iko yan aci")
    private static let sutra834 = SandhiSutra(chapter: .eightThree, number: 34, title: "visarjaniyasya sah")
    private static let sutra836 = SandhiSutra(chapter: .eightThree, number: 36, title: "va shari")
    private static let sutra6114 = SandhiSutra(chapter: .sixOne, number: 114, title: "hashi ca")

    private static let vowels: [String] = [
        "ai", "au", "RR", "LL", "A", "I", "U",
        "a", "i", "u", "R", "L", "e", "o"
    ]

    private static let dirghaInverseMap: [String: [(String, String)]] = [
        "A": [("a", "a"), ("a", "A"), ("A", "a"), ("A", "A")],
        "I": [("i", "i"), ("i", "I"), ("I", "i"), ("I", "I")],
        "U": [("u", "u"), ("u", "U"), ("U", "u"), ("U", "U")],
        "RR": [("R", "R"), ("R", "RR"), ("RR", "R"), ("RR", "RR")],
        "LL": [("L", "L"), ("L", "LL"), ("LL", "L"), ("LL", "LL")]
    ]

    private static let visargaToSClusters: Set<String> = ["t", "th"]
    private static let visargaToShClusters: Set<String> = ["c", "ch", "j", "jh"]
    private static let visargaToOClusters: Set<String> = ["g", "gh", "d", "dh", "b", "bh", "y", "v", "r", "l", "h"]

    static func analyze(merged: String, maxCandidates: Int = 5) -> Result {
        let input = merged.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return Result(input: input, candidates: []) }

        var bestByKey: [String: Candidate] = [:]

        for split in splitIndices(in: input) {
            let leftOut = String(input[..<split])
            let rightOut = String(input[split...])

            generateDirghaCandidates(leftOut: leftOut, rightOut: rightOut, merged: input, storage: &bestByKey)
            generatePararupaCandidates(leftOut: leftOut, rightOut: rightOut, merged: input, storage: &bestByKey)
            generateVrddhiCandidates(leftOut: leftOut, rightOut: rightOut, merged: input, storage: &bestByKey)
            generateGunaCandidates(leftOut: leftOut, rightOut: rightOut, merged: input, storage: &bestByKey)
            generateAyadiCandidates(leftOut: leftOut, rightOut: rightOut, merged: input, storage: &bestByKey)
            generateYanCandidates(leftOut: leftOut, rightOut: rightOut, merged: input, storage: &bestByKey)
            generateVisargaCandidates(leftOut: leftOut, rightOut: rightOut, merged: input, storage: &bestByKey)
        }

        generatePurvarupaCandidates(merged: input, storage: &bestByKey)

        let ranked = bestByKey.values
            .sorted {
                if $0.confidence != $1.confidence {
                    return $0.confidence > $1.confidence
                }
                return $0.left.count > $1.left.count
            }

        return Result(
            input: input,
            candidates: Array(ranked.prefix(maxCandidates))
        )
    }

    private static func generateDirghaCandidates(
        leftOut: String,
        rightOut: String,
        merged: String,
        storage: inout [String: Candidate]
    ) {
        for (longVowel, sourcePairs) in dirghaInverseMap {
            guard let stem = removingSuffix(longVowel, from: leftOut) else { continue }
            for (leftVowel, rightVowel) in sourcePairs {
                addCandidate(
                    left: stem + leftVowel,
                    right: rightVowel + rightOut,
                    merged: merged,
                    sutra: sutra101,
                    baseConfidence: 0.91,
                    explanation: "Long vowel likely came from savarna-dIrgha merge.",
                    storage: &storage
                )
            }
        }
    }

    private static func generatePararupaCandidates(
        leftOut: String,
        rightOut: String,
        merged: String,
        storage: inout [String: Candidate]
    ) {
        for carried in ["e", "o"] {
            guard let stem = removingSuffix(carried, from: leftOut) else { continue }
            for prefixVowel in ["a", "A"] {
                addCandidate(
                    left: stem + prefixVowel,
                    right: carried + rightOut,
                    merged: merged,
                    sutra: sutra94,
                    baseConfidence: 0.80,
                    explanation: "Carried e/o suggests pararupa (prefix-final a/A + e/o).",
                    storage: &storage
                )
            }
        }
    }

    private static func generateVrddhiCandidates(
        leftOut: String,
        rightOut: String,
        merged: String,
        storage: inout [String: Candidate]
    ) {
        if let stem = removingSuffix("ai", from: leftOut) {
            for leftVowel in ["a", "A"] {
                for rightVowel in ["e", "ai"] {
                    addCandidate(
                        left: stem + leftVowel,
                        right: rightVowel + rightOut,
                        merged: merged,
                        sutra: sutra88,
                        baseConfidence: 0.84,
                        explanation: "ai output can come from a/A + e/ai.",
                        storage: &storage
                    )
                }
            }
        }

        if let stem = removingSuffix("au", from: leftOut) {
            for leftVowel in ["a", "A"] {
                for rightVowel in ["o", "au"] {
                    addCandidate(
                        left: stem + leftVowel,
                        right: rightVowel + rightOut,
                        merged: merged,
                        sutra: sutra88,
                        baseConfidence: 0.84,
                        explanation: "au output can come from a/A + o/au.",
                        storage: &storage
                    )
                }
            }
        }
    }

    private static func generateGunaCandidates(
        leftOut: String,
        rightOut: String,
        merged: String,
        storage: inout [String: Candidate]
    ) {
        if let stem = removingSuffix("e", from: leftOut) {
            for leftVowel in ["a", "A"] {
                for rightVowel in ["i", "I"] {
                    addCandidate(
                        left: stem + leftVowel,
                        right: rightVowel + rightOut,
                        merged: merged,
                        sutra: sutra87,
                        baseConfidence: 0.86,
                        explanation: "e output suggests guna from a/A + i/I.",
                        storage: &storage
                    )
                }
            }
        }

        if let stem = removingSuffix("o", from: leftOut) {
            for leftVowel in ["a", "A"] {
                for rightVowel in ["u", "U"] {
                    addCandidate(
                        left: stem + leftVowel,
                        right: rightVowel + rightOut,
                        merged: merged,
                        sutra: sutra87,
                        baseConfidence: 0.86,
                        explanation: "o output suggests guna from a/A + u/U.",
                        storage: &storage
                    )
                }
            }
        }

        if let stem = removingSuffix("ar", from: leftOut) {
            for leftVowel in ["a", "A"] {
                for rightVowel in ["R", "RR"] {
                    addCandidate(
                        left: stem + leftVowel,
                        right: rightVowel + rightOut,
                        merged: merged,
                        sutra: sutra87,
                        baseConfidence: 0.83,
                        explanation: "ar output suggests guna from a/A + R/RR.",
                        storage: &storage
                    )
                }
            }
        }

        if let stem = removingSuffix("al", from: leftOut) {
            for leftVowel in ["a", "A"] {
                for rightVowel in ["L", "LL"] {
                    addCandidate(
                        left: stem + leftVowel,
                        right: rightVowel + rightOut,
                        merged: merged,
                        sutra: sutra87,
                        baseConfidence: 0.83,
                        explanation: "al output suggests guna from a/A + L/LL.",
                        storage: &storage
                    )
                }
            }
        }
    }

    private static func generatePurvarupaCandidates(
        merged: String,
        storage: inout [String: Candidate]
    ) {
        for apostrophe in merged.indices where merged[apostrophe] == "'" {
            let left = String(merged[..<apostrophe])
            let tailStart = merged.index(after: apostrophe)
            let tail = String(merged[tailStart...])

            guard left.hasSuffix("e") || left.hasSuffix("o") else { continue }

            addCandidate(
                left: left,
                right: "a" + tail,
                merged: merged,
                sutra: sutra109,
                baseConfidence: 0.92,
                explanation: "Avagraha marks purvarupa before short a.",
                storage: &storage
            )
        }
    }

    private static func generateAyadiCandidates(
        leftOut: String,
        rightOut: String,
        merged: String,
        storage: inout [String: Candidate]
    ) {
        let inverseMap: [(replacement: String, original: String)] = [
            ("ay", "e"),
            ("av", "o"),
            ("Ay", "ai"),
            ("Av", "au")
        ]

        for (replacement, original) in inverseMap {
            guard let stem = removingSuffix(replacement, from: leftOut) else { continue }
            addCandidate(
                left: stem + original,
                right: rightOut,
                merged: merged,
                sutra: sutra78,
                baseConfidence: 0.80,
                explanation: "\(replacement) boundary can be ayadi from final \(original).",
                storage: &storage
            )
        }
    }

    private static func generateYanCandidates(
        leftOut: String,
        rightOut: String,
        merged: String,
        storage: inout [String: Candidate]
    ) {
        let inverseMap: [(glide: String, originals: [String])] = [
            ("y", ["i", "I"]),
            ("v", ["u", "U"]),
            ("r", ["R", "RR"]),
            ("l", ["L", "LL"])
        ]

        guard firstVowelToken(in: rightOut) != nil else { return }

        for (glide, originals) in inverseMap {
            guard let stem = removingSuffix(glide, from: leftOut) else { continue }
            for original in originals {
                addCandidate(
                    left: stem + original,
                    right: rightOut,
                    merged: merged,
                    sutra: sutra77,
                    baseConfidence: 0.79,
                    explanation: "Glide \(glide) likely came from iko-yan substitution.",
                    storage: &storage
                )
            }
        }
    }

    private static func generateVisargaCandidates(
        leftOut: String,
        rightOut: String,
        merged: String,
        storage: inout [String: Candidate]
    ) {
        if let stem = removingSuffix("s", from: leftOut),
           let cluster = leadingCluster(in: rightOut),
           visargaToSClusters.contains(cluster) {
            for marker in ["h", ":"] {
                addCandidate(
                    left: stem + marker,
                    right: rightOut,
                    merged: merged,
                    sutra: sutra834,
                    baseConfidence: 0.82,
                    explanation: "s before dental cluster often traces back to visarga.",
                    storage: &storage
                )
            }
        }

        if let stem = removingSuffix("sh", from: leftOut),
           let cluster = leadingCluster(in: rightOut),
           visargaToShClusters.contains(cluster) {
            for marker in ["h", ":"] {
                addCandidate(
                    left: stem + marker,
                    right: rightOut,
                    merged: merged,
                    sutra: sutra836,
                    baseConfidence: 0.81,
                    explanation: "sh before palatal cluster often traces back to visarga.",
                    storage: &storage
                )
            }
        }

        if let base = removingSuffix("o", from: leftOut),
           let cluster = leadingCluster(in: rightOut),
           visargaToOClusters.contains(cluster) {
            for left in [base + "ah", base + "Ah", base + "a:"] {
                addCandidate(
                    left: left,
                    right: rightOut,
                    merged: merged,
                    sutra: sutra6114,
                    baseConfidence: 0.86,
                    explanation: "o before soft consonant can reverse to ah (hashi ca).",
                    storage: &storage
                )
            }
        }
    }

    private static func addCandidate(
        left: String,
        right: String,
        merged: String,
        sutra: SandhiSutra,
        baseConfidence: Double,
        explanation: String,
        storage: inout [String: Candidate]
    ) {
        guard !left.isEmpty, !right.isEmpty else { return }

        let verification = SandhiEngine.applyProjectSandhi(left: left, right: right)
        guard verification.output == merged else { return }
        guard let matched = verification.steps.first(where: { $0.sutra != nil })?.sutra else { return }
        guard matched.code == sutra.code else { return }

        let confidence = calibratedConfidence(
            base: baseConfidence,
            left: left,
            right: right,
            merged: merged
        )

        let candidate = Candidate(
            left: left,
            right: right,
            sutra: sutra,
            confidence: confidence,
            explanation: explanation
        )

        if let existing = storage[candidate.id] {
            if candidate.confidence > existing.confidence {
                storage[candidate.id] = candidate
            }
        } else {
            storage[candidate.id] = candidate
        }
    }

    private static func calibratedConfidence(
        base: Double,
        left: String,
        right: String,
        merged: String
    ) -> Double {
        var score = base
        let mergedLength = Double(max(merged.count, 1))
        let balance = Double(min(left.count, right.count)) / mergedLength
        score += min(0.08, balance * 0.12)

        if left.count <= 1 || right.count <= 1 {
            score -= 0.12
        }

        let clamped = min(0.99, max(0.50, score))
        return (clamped * 100).rounded() / 100
    }

    private static func splitIndices(in value: String) -> [String.Index] {
        guard value.count > 1 else { return [] }
        var indices: [String.Index] = []
        var index = value.index(after: value.startIndex)
        while index < value.endIndex {
            indices.append(index)
            index = value.index(after: index)
        }
        return indices
    }

    private static func removingSuffix(_ suffix: String, from value: String) -> String? {
        guard value.hasSuffix(suffix) else { return nil }
        let end = value.index(value.endIndex, offsetBy: -suffix.count)
        return String(value[..<end])
    }

    private static func firstVowelToken(in word: String) -> String? {
        for vowel in vowels where word.hasPrefix(vowel) {
            return vowel
        }
        return nil
    }

    private static func leadingCluster(in word: String) -> String? {
        let lower = word.lowercased()
        for cluster in ["th", "dh", "bh", "gh", "ch", "jh", "kh", "ph"] where lower.hasPrefix(cluster) {
            return cluster
        }
        guard let first = lower.first else { return nil }
        return String(first)
    }
}
