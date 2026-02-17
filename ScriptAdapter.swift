import Foundation

enum ScriptAdapter {
    enum OutputScript {
        case romanized
        case devanagari
    }

    struct PreparedInput {
        let left: String
        let right: String
        let outputScript: OutputScript
    }

    struct PreparedMergedInput {
        let word: String
        let outputScript: OutputScript
    }

    static func prepare(left: String, right: String) -> PreparedInput {
        let trimmedLeft = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRight = right.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldRenderDevanagari = containsDevanagari(trimmedLeft) || containsDevanagari(trimmedRight)

        return PreparedInput(
            left: normalizeToInternal(trimmedLeft),
            right: normalizeToInternal(trimmedRight),
            outputScript: shouldRenderDevanagari ? .devanagari : .romanized
        )
    }

    static func present(_ value: String, as script: OutputScript) -> String {
        switch script {
        case .romanized:
            return value
        case .devanagari:
            return internalToDevanagari(value)
        }
    }

    static func prepareMerged(word: String) -> PreparedMergedInput {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldRenderDevanagari = containsDevanagari(trimmed)

        return PreparedMergedInput(
            word: normalizeToInternal(trimmed),
            outputScript: shouldRenderDevanagari ? .devanagari : .romanized
        )
    }

    private static let devaRange = 0x0900...0x097F
    private static let virama: Character = "्"
    private static let nukta: Character = "़"

    private static let independentVowelsToInternal: [Character: String] = [
        "अ": "a", "आ": "A", "इ": "i", "ई": "I", "उ": "u", "ऊ": "U",
        "ऋ": "R", "ॠ": "RR", "ऌ": "L", "ॡ": "LL", "ए": "e", "ऐ": "ai",
        "ओ": "o", "औ": "au"
    ]

    private static let vowelSignsToInternal: [Character: String] = [
        "ा": "A", "ि": "i", "ी": "I", "ु": "u", "ू": "U",
        "ृ": "R", "ॄ": "RR", "ॢ": "L", "ॣ": "LL", "े": "e",
        "ै": "ai", "ो": "o", "ौ": "au"
    ]

    private static let consonantsToInternal: [Character: String] = [
        "क": "k", "ख": "kh", "ग": "g", "घ": "gh", "ङ": "n",
        "च": "c", "छ": "ch", "ज": "j", "झ": "jh", "ञ": "n",
        "ट": "T", "ठ": "Th", "ड": "D", "ढ": "Dh", "ण": "N",
        "त": "t", "थ": "th", "द": "d", "ध": "dh", "न": "n",
        "प": "p", "फ": "ph", "ब": "b", "भ": "bh", "म": "m",
        "य": "y", "र": "r", "ल": "l", "व": "v",
        "श": "sh", "ष": "S", "स": "s", "ह": "h", "ळ": "L"
    ]

    private static let specialsToInternal: [Character: String] = [
        "ः": ":",
        "ऽ": "'",
        "ं": "M",
        "ँ": "M",
        "।": ".",
        "॥": ".."
    ]

    private static let vowelsToDevanagari: [String: String] = [
        "a": "अ", "A": "आ", "i": "इ", "I": "ई", "u": "उ", "U": "ऊ",
        "R": "ऋ", "RR": "ॠ", "L": "ऌ", "LL": "ॡ", "e": "ए",
        "ai": "ऐ", "o": "ओ", "au": "औ"
    ]

    private static let vowelSignsToDevanagari: [String: String] = [
        "A": "ा", "i": "ि", "I": "ी", "u": "ु", "U": "ू",
        "R": "ृ", "RR": "ॄ", "L": "ॢ", "LL": "ॣ", "e": "े",
        "ai": "ै", "o": "ो", "au": "ौ"
    ]

    private static let consonantsToDevanagari: [String: String] = [
        "k": "क", "kh": "ख", "g": "ग", "gh": "घ", "n": "न",
        "c": "च", "ch": "छ", "j": "ज", "jh": "झ",
        "T": "ट", "Th": "ठ", "D": "ड", "Dh": "ढ", "N": "ण",
        "t": "त", "th": "थ", "d": "द", "dh": "ध",
        "p": "प", "ph": "फ", "b": "ब", "bh": "भ", "m": "म",
        "y": "य", "r": "र", "l": "ल", "v": "व",
        "sh": "श", "S": "ष", "s": "स", "h": "ह"
    ]

    private static let romanTokens: [String] = [
        "kh", "gh", "ch", "jh", "Th", "Dh", "th", "dh", "ph", "bh", "sh",
        "RR", "LL", "ai", "au",
        "A", "I", "U", "R", "L",
        "T", "D", "N", "S",
        "k", "g", "n", "c", "j", "t", "d", "p", "b", "m", "y", "r", "l", "v", "s", "h",
        "a", "i", "u", "e", "o",
        "M", ":", "'"
    ]

    private static func normalizeToInternal(_ value: String) -> String {
        guard containsDevanagari(value) else { return value }
        return devanagariToInternal(value)
    }

    private static func containsDevanagari(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            devaRange.contains(Int(scalar.value))
        }
    }

    private static func devanagariToInternal(_ value: String) -> String {
        let chars = Array(value)
        var output = ""
        var index = 0

        while index < chars.count {
            let char = chars[index]

            if let vowel = independentVowelsToInternal[char] {
                output += vowel
                index += 1
                continue
            }

            if let consonant = consonantsToInternal[char] {
                output += consonant
                let next = index + 1

                if next < chars.count, chars[next] == nukta {
                    if next + 1 < chars.count, chars[next + 1] == virama {
                        index += 3
                        continue
                    }
                    if next + 1 < chars.count, let sign = vowelSignsToInternal[chars[next + 1]] {
                        output += sign
                        index += 3
                        continue
                    }
                    output += "a"
                    index += 2
                    continue
                }

                if next < chars.count, chars[next] == virama {
                    index += 2
                    continue
                }

                if next < chars.count, let sign = vowelSignsToInternal[chars[next]] {
                    output += sign
                    index += 2
                    continue
                }

                output += "a"
                index += 1
                continue
            }

            if let sign = vowelSignsToInternal[char] {
                output += sign
                index += 1
                continue
            }

            if let special = specialsToInternal[char] {
                output += special
                index += 1
                continue
            }

            output.append(char)
            index += 1
        }

        return output
    }

    private static func internalToDevanagari(_ value: String) -> String {
        let tokens = tokenizeInternal(value)
        var output = ""
        var pendingConsonant: String?

        for token in tokens {
            if token == ":" {
                flushPendingConsonant(into: &output, pendingConsonant: &pendingConsonant, useVirama: false)
                output += "ः"
                continue
            }

            if token == "'" {
                flushPendingConsonant(into: &output, pendingConsonant: &pendingConsonant, useVirama: false)
                output += "ऽ"
                continue
            }

            if token == "M" {
                flushPendingConsonant(into: &output, pendingConsonant: &pendingConsonant, useVirama: false)
                output += "ं"
                continue
            }

            if let consonant = consonantsToDevanagari[token] {
                if let activeConsonant = pendingConsonant {
                    output += activeConsonant + "्"
                }
                pendingConsonant = consonant
                continue
            }

            if let independentVowel = vowelsToDevanagari[token] {
                if let activeConsonant = pendingConsonant {
                    if token == "a" {
                        output += activeConsonant
                    } else if let sign = vowelSignsToDevanagari[token] {
                        output += activeConsonant + sign
                    } else {
                        output += activeConsonant + independentVowel
                    }
                    pendingConsonant = nil
                } else {
                    output += independentVowel
                }
                continue
            }

            flushPendingConsonant(into: &output, pendingConsonant: &pendingConsonant, useVirama: false)
            output += token
        }

        flushPendingConsonant(into: &output, pendingConsonant: &pendingConsonant, useVirama: true)
        return output
    }

    private static func flushPendingConsonant(
        into output: inout String,
        pendingConsonant: inout String?,
        useVirama: Bool
    ) {
        guard let activeConsonant = pendingConsonant else { return }
        output += activeConsonant
        if useVirama {
            output += "्"
        }
        pendingConsonant = nil
    }

    private static func tokenizeInternal(_ value: String) -> [String] {
        var tokens: [String] = []
        var index = value.startIndex

        while index < value.endIndex {
            var matchedToken: String?

            for token in romanTokens {
                if value[index...].hasPrefix(token) {
                    matchedToken = token
                    break
                }
            }

            if let token = matchedToken {
                tokens.append(token)
                index = value.index(index, offsetBy: token.count)
            } else {
                tokens.append(String(value[index]))
                index = value.index(after: index)
            }
        }

        return tokens
    }
}
