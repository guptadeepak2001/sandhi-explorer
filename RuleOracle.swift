import Foundation

enum RuleOracle {
    struct Candidate: Identifiable, Hashable, Sendable {
        let code: String?
        let title: String
        let confidence: Double
        let reasoning: String

        var id: String {
            code ?? "none-\(title)"
        }
    }

    struct Prediction: Sendable {
        let primary: Candidate
        let alternatives: [Candidate]
        let boundarySummary: String
        let expectedOutput: String
    }

    private struct VowelSplit: Sendable {
        let leftVowel: String
        let rightVowel: String
    }

    private static let vowels: [String] = [
        "ai", "au", "RR", "LL", "A", "I", "U",
        "a", "i", "u", "R", "L", "e", "o"
    ]

    private static let savarnaPairs: Set<String> = [
        "a:a", "A:A", "a:A", "A:a",
        "i:i", "I:I", "i:I", "I:i",
        "u:u", "U:U", "u:U", "U:u",
        "R:R", "RR:RR", "R:RR", "RR:R",
        "L:L", "LL:LL", "L:LL", "LL:L"
    ]

    private static let pararupaPrefixes: Set<String> = [
        "pra", "para", "apa", "ava", "upa"
    ]

    private static let visargaToSClusters: Set<String> = ["t", "th"]
    private static let visargaToShClusters: Set<String> = ["c", "ch", "j", "jh"]
    private static let visargaToOClusters: Set<String> = ["g", "gh", "d", "dh", "b", "bh", "y", "v", "r", "l", "h"]

    private static let ruleOrder: [String: Int] = Dictionary(
        uniqueKeysWithValues: SandhiEngine.projectRuntimeRulebook.enumerated().map { index, sutra in
            (sutra.code, index)
        }
    )

    static func predict(left: String, right: String, maxAlternatives: Int = 3) -> Prediction? {
        let normalizedLeft = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRight = right.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLeft.isEmpty, !normalizedRight.isEmpty else { return nil }

        let result = SandhiEngine.applyProjectSandhi(left: normalizedLeft, right: normalizedRight)
        let split = splitBoundary(left: normalizedLeft, right: normalizedRight)
        let scores = scoreMap(left: normalizedLeft, right: normalizedRight, split: split)

        let matched = result.trace.first(where: { $0.outcome == .matched })
        let primary: Candidate

        if let matched {
            let score = scores[matched.sutra.code] ?? 0.90
            let confidence = min(0.99, max(0.88, score))
            primary = Candidate(
                code: matched.sutra.code,
                title: matched.sutra.title,
                confidence: confidence,
                reasoning: matched.reasoning
            )
        } else {
            let bestFallback = scores.values.max() ?? 0.55
            primary = Candidate(
                code: nil,
                title: "No in-scope rule",
                confidence: min(0.78, max(0.55, bestFallback)),
                reasoning: "No active sutra conditions matched this boundary. The runtime will keep direct concatenation."
            )
        }

        let alternatives = buildAlternatives(
            scores: scores,
            excluding: primary.code,
            left: normalizedLeft,
            right: normalizedRight,
            split: split,
            limit: maxAlternatives
        )

        return Prediction(
            primary: primary,
            alternatives: alternatives,
            boundarySummary: boundarySummary(left: normalizedLeft, right: normalizedRight, split: split),
            expectedOutput: result.output
        )
    }

    private static func buildAlternatives(
        scores: [String: Double],
        excluding matchedCode: String?,
        left: String,
        right: String,
        split: VowelSplit?,
        limit: Int
    ) -> [Candidate] {
        var ranked: [Candidate] = []

        for sutra in SandhiEngine.projectRuntimeRulebook {
            if sutra.code == matchedCode { continue }
            guard let score = scores[sutra.code], score >= 0.20 else { continue }

            ranked.append(
                Candidate(
                    code: sutra.code,
                    title: sutra.title,
                    confidence: min(0.89, max(0.20, score)),
                    reasoning: alternativeReasoning(for: sutra.code, left: left, right: right, split: split)
                )
            )
        }

        return ranked
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return lhs.confidence > rhs.confidence
                }
                let lhsOrder = ruleOrder[lhs.code ?? ""] ?? Int.max
                let rhsOrder = ruleOrder[rhs.code ?? ""] ?? Int.max
                return lhsOrder < rhsOrder
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func scoreMap(left: String, right: String, split: VowelSplit?) -> [String: Double] {
        var scores: [String: Double] = [:]
        for sutra in SandhiEngine.projectRuntimeRulebook {
            scores[sutra.code] = 0.05
        }

        if let split {
            let pair = "\(split.leftVowel):\(split.rightVowel)"
            if savarnaPairs.contains(pair) {
                scores["6.1.101"] = 0.97
            } else if split.rightVowel == split.leftVowel {
                scores["6.1.101"] = max(scores["6.1.101"] ?? 0, 0.55)
            }

            if ["a", "A"].contains(split.leftVowel) {
                if ["e", "o"].contains(split.rightVowel) {
                    let prefixBoost = pararupaPrefixes.contains(left.lowercased()) ? 0.92 : 0.66
                    scores["6.1.94"] = max(scores["6.1.94"] ?? 0, prefixBoost)
                } else if !split.rightVowel.isEmpty {
                    scores["6.1.94"] = max(scores["6.1.94"] ?? 0, 0.28)
                }

                if ["e", "ai", "o", "au"].contains(split.rightVowel) {
                    scores["6.1.88"] = max(scores["6.1.88"] ?? 0, 0.84)
                } else if !split.rightVowel.isEmpty {
                    scores["6.1.88"] = max(scores["6.1.88"] ?? 0, 0.34)
                }

                if ["i", "I", "u", "U", "R", "RR", "L", "LL"].contains(split.rightVowel) {
                    scores["6.1.87"] = max(scores["6.1.87"] ?? 0, 0.86)
                } else if !split.rightVowel.isEmpty {
                    scores["6.1.87"] = max(scores["6.1.87"] ?? 0, 0.31)
                }
            }

            if ["e", "o"].contains(split.leftVowel), split.rightVowel == "a" {
                scores["6.1.109"] = max(scores["6.1.109"] ?? 0, 0.92)
            } else if ["e", "o"].contains(split.leftVowel) {
                scores["6.1.109"] = max(scores["6.1.109"] ?? 0, 0.30)
            }

            if ["e", "o", "ai", "au"].contains(split.leftVowel) {
                scores["6.1.78"] = max(scores["6.1.78"] ?? 0, 0.80)
            }

            if ["i", "I", "u", "U", "R", "RR", "L", "LL"].contains(split.leftVowel) {
                scores["6.1.77"] = max(scores["6.1.77"] ?? 0, 0.79)
            }
        }

        if splitVisarga(leftWord: left) != nil, let cluster = leadingCluster(in: right) {
            if visargaToSClusters.contains(cluster) {
                scores["8.3.34"] = max(scores["8.3.34"] ?? 0, 0.82)
            } else {
                scores["8.3.34"] = max(scores["8.3.34"] ?? 0, 0.24)
            }

            if visargaToShClusters.contains(cluster) {
                scores["8.3.36"] = max(scores["8.3.36"] ?? 0, 0.81)
            } else {
                scores["8.3.36"] = max(scores["8.3.36"] ?? 0, 0.24)
            }

            let leftStem = String(left.dropLast())
            if visargaToOClusters.contains(cluster), let last = leftStem.last, ["a", "A"].contains(String(last)) {
                scores["6.1.114"] = max(scores["6.1.114"] ?? 0, 0.86)
            } else {
                scores["6.1.114"] = max(scores["6.1.114"] ?? 0, 0.24)
            }
        }

        return scores
    }

    private static func alternativeReasoning(for code: String, left: String, right: String, split: VowelSplit?) -> String {
        switch code {
        case "6.1.101":
            return "Savarna long-vowel merge is checked whenever similar vowels meet at the boundary."
        case "6.1.94":
            return "Pararupa is considered when prefix-final a/A meets initial e/o."
        case "6.1.88":
            return "Vrddhi is considered for a/A before e, ai, o, or au."
        case "6.1.87":
            return "Guna is considered when a/A is followed by i/u/R/L classes."
        case "6.1.109":
            return "Purvarupa is considered for final e/o before short a, with avagraha output."
        case "6.1.78":
            return "Ayadi is considered for final e/o/ai/au before vowel-initial right word."
        case "6.1.77":
            return "Yan substitution is considered when i/u/R/L classes meet a following vowel."
        case "8.3.34":
            return "Visarga-to-s is considered before dental clusters like t/th."
        case "8.3.36":
            return "Visarga-to-sh is considered before palatal clusters like c/ch/j/jh."
        case "6.1.114":
            return "Visarga-to-o is considered before soft consonants when left ends in ah."
        default:
            let leftEdge = split?.leftVowel ?? String(left.last ?? Character("?"))
            let rightEdge = split?.rightVowel ?? String(right.first ?? Character("?"))
            return "Boundary \(leftEdge) + \(rightEdge) keeps this rule in the candidate set."
        }
    }

    private static func boundarySummary(left: String, right: String, split: VowelSplit?) -> String {
        if let split {
            return "Boundary focus: final \(split.leftVowel) + initial \(split.rightVowel)."
        }
        if splitVisarga(leftWord: left) != nil, let cluster = leadingCluster(in: right) {
            return "Boundary focus: final visarga + initial \(cluster)."
        }
        let leftEdge = String(left.last ?? Character("?"))
        let rightEdge = String(right.first ?? Character("?"))
        return "Boundary focus: final \(leftEdge) + initial \(rightEdge)."
    }

    private static func splitBoundary(left: String, right: String) -> VowelSplit? {
        guard let leftPart = lastVowel(in: left) else { return nil }
        guard let rightPart = firstVowel(in: right) else { return nil }

        return VowelSplit(
            leftVowel: leftPart.vowel,
            rightVowel: rightPart.vowel
        )
    }

    private static func firstVowel(in word: String) -> (vowel: String, tail: String)? {
        for vowel in vowels where word.hasPrefix(vowel) {
            let index = word.index(word.startIndex, offsetBy: vowel.count)
            return (vowel, String(word[index...]))
        }
        return nil
    }

    private static func lastVowel(in word: String) -> (stem: String, vowel: String)? {
        for vowel in vowels where word.hasSuffix(vowel) {
            let index = word.index(word.endIndex, offsetBy: -vowel.count)
            return (String(word[..<index]), vowel)
        }
        return nil
    }

    private static func splitVisarga(leftWord: String) -> (stem: String, marker: String)? {
        if leftWord.hasSuffix("h") {
            return (String(leftWord.dropLast()), "h")
        }
        if leftWord.hasSuffix("H") {
            return (String(leftWord.dropLast()), "H")
        }
        if leftWord.hasSuffix(":") {
            return (String(leftWord.dropLast()), ":")
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
