import Foundation

enum SandhiPhase: String, CaseIterable, Identifiable {
    case normalization
    case chapter6_1
    case chapter8_3
    case postProcessing

    var id: String { rawValue }
}

enum SandhiChapter: String {
    case sixOne = "6.1"
    case eightThree = "8.3"
}

struct SandhiSutra: Hashable, Sendable {
    let chapter: SandhiChapter
    let number: Int
    let title: String

    var code: String {
        "\(chapter.rawValue).\(number)"
    }
}

struct SandhiStep: Identifiable, Hashable, Sendable {
    let id = UUID()
    let phase: SandhiPhase
    let sutra: SandhiSutra?
    let explanation: String
    let before: String
    let after: String
}

struct SandhiResult: Sendable {
    let input: String
    let output: String
    let steps: [SandhiStep]
}

enum SutraImplementationStatus: String, CaseIterable {
    case implemented
    case planned
}

enum SutraExecutionRequirement: String, CaseIterable {
    case surfacePairInput
    case derivationalState
    case accentState
}

struct ChapterSutra: Identifiable, Hashable, Sendable {
    let chapter: SandhiChapter
    let number: Int
    let title: String
    let topic: String
    let status: SutraImplementationStatus
    let requirement: SutraExecutionRequirement
    let notes: String

    var id: String { "\(chapter.rawValue).\(number)" }
    var code: String { "\(chapter.rawValue).\(number)" }
}

struct SandhiContext: Sendable {
    let leftWord: String
    let rightWord: String

    var joined: String {
        leftWord + "+" + rightWord
    }
}

private struct VowelSplit: Sendable {
    let leftStem: String
    let leftVowel: String
    let rightVowel: String
    let rightTail: String
}

private struct ChapterRule: Sendable {
    let sutra: SandhiSutra
    let priority: Int
    let explanation: String
    let apply: @Sendable (SandhiContext) -> String?
}

private struct SutraSeed: Sendable {
    let number: Int
    let title: String
    let topic: String
    let requirement: SutraExecutionRequirement
}

private struct RuleTargetSeed: Sendable {
    let sutra: SandhiSutra
    let topic: String
}

private enum Vowels {
    static let shortToLong: [String: String] = [
        "a": "A",
        "i": "I",
        "u": "U",
        "R": "RR",
        "L": "LL"
    ]

    static let savarnaPairs: Set<String> = [
        "a:a", "A:A", "a:A", "A:a",
        "i:i", "I:I", "i:I", "I:i",
        "u:u", "U:U", "u:U", "U:u",
        "R:R", "RR:RR", "R:RR", "RR:R",
        "L:L", "LL:LL", "L:LL", "LL:L"
    ]

    static let all: [String] = [
        "ai", "au", "RR", "LL", "A", "I", "U",
        "a", "i", "u", "R", "L", "e", "o"
    ]

    static func firstVowel(in word: String) -> (vowel: String, tail: String)? {
        for vowel in all {
            if word.hasPrefix(vowel) {
                let index = word.index(word.startIndex, offsetBy: vowel.count)
                return (vowel, String(word[index...]))
            }
        }
        return nil
    }

    static func lastVowel(in word: String) -> (stem: String, vowel: String)? {
        for vowel in all {
            if word.hasSuffix(vowel) {
                let index = word.index(word.endIndex, offsetBy: -vowel.count)
                return (String(word[..<index]), vowel)
            }
        }
        return nil
    }
}

enum SandhiEngine {
    static func applyProjectSandhi(left: String, right: String) -> SandhiResult {
        var steps: [SandhiStep] = []
        let input = left + " + " + right

        let normalizedLeft = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRight = right.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInput = normalizedLeft + "+" + normalizedRight

        steps.append(
            SandhiStep(
                phase: .normalization,
                sutra: nil,
                explanation: "Normalize spaces and set up the boundary between two words.",
                before: input,
                after: normalizedInput
            )
        )

        let context = SandhiContext(leftWord: normalizedLeft, rightWord: normalizedRight)
        let chapter6Result = applyRules(
            context,
            in: chapter6_1ProjectRules,
            phase: .chapter6_1,
            noMatchExplanation: "No Chapter 6.1 project rule matched this boundary."
        )
        steps.append(chapter6Result.step)

        let activeStep: SandhiStep
        if chapter6Result.matched != nil {
            activeStep = chapter6Result.step
        } else {
            let visargaResult = applyRules(
                context,
                in: visargaProjectRules,
                phase: .chapter8_3,
                noMatchExplanation: "No Visarga module rule matched this boundary."
            )
            steps.append(visargaResult.step)
            activeStep = visargaResult.step
        }

        steps.append(
            SandhiStep(
                phase: .postProcessing,
                sutra: nil,
                explanation: "Post-processing hook reserved for chapters 6.4, 7.x, and 8.x expansion.",
                before: activeStep.after,
                after: activeStep.after
            )
        )

        return SandhiResult(
            input: input,
            output: activeStep.after,
            steps: steps
        )
    }

    static func applyChapter6_1(left: String, right: String) -> SandhiResult {
        var steps: [SandhiStep] = []
        let input = left + " + " + right

        let normalizedLeft = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRight = right.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInput = normalizedLeft + "+" + normalizedRight

        steps.append(
            SandhiStep(
                phase: .normalization,
                sutra: nil,
                explanation: "Normalize spaces and set up the boundary between two words.",
                before: input,
                after: normalizedInput
            )
        )

        let context = SandhiContext(leftWord: normalizedLeft, rightWord: normalizedRight)
        let chapterResult = applyRules(
            context,
            in: chapter6_1ProjectRules,
            phase: .chapter6_1,
            noMatchExplanation: "No Chapter 6.1 project rule matched this boundary."
        )
        steps.append(chapterResult.step)

        steps.append(
            SandhiStep(
                phase: .postProcessing,
                sutra: nil,
                explanation: "Post-processing hook reserved for chapters 6.4, 7.x, and 8.x expansion.",
                before: chapterResult.step.after,
                after: chapterResult.step.after
            )
        )

        return SandhiResult(
            input: input,
            output: chapterResult.step.after,
            steps: steps
        )
    }

    static let chapter6_1ProjectRange = 77...109

    static var chapter6_1ProjectRulebook: [SandhiSutra] {
        chapter6_1ProjectRules
            .sorted { $0.priority < $1.priority }
            .map(\.sutra)
    }

    static var chapter6_1ProjectTargets: [ChapterSutra] {
        let implementedByNumber = Dictionary(
            uniqueKeysWithValues: chapter6_1ProjectRules.map { ($0.sutra.number, $0.sutra.title) }
        )
        let targetByNumber = Dictionary(
            uniqueKeysWithValues: chapter6_1ProjectTargetSeeds.map { ($0.number, $0) }
        )

        return chapter6_1ProjectTargetOrder.compactMap { number in
            guard let seed = targetByNumber[number] else { return nil }
            let isImplemented = implementedByNumber[number] != nil

            return ChapterSutra(
                chapter: .sixOne,
                number: number,
                title: implementedByNumber[number] ?? seed.title,
                topic: seed.topic,
                status: isImplemented ? .implemented : .planned,
                requirement: .surfacePairInput,
                notes: isImplemented
                    ? "Active runtime logic is enabled for this sutra."
                    : "In locked project scope (6.1.77-6.1.109), pending implementation."
            )
        }
    }

    static var chapter6_1ProjectCoverageSummary: (implemented: Int, total: Int) {
        let all = chapter6_1ProjectTargets
        let implemented = all.filter { $0.status == .implemented }.count
        return (implemented, all.count)
    }

    static var visargaProjectTargets: [ChapterSutra] {
        let implementedByCode = Dictionary(
            uniqueKeysWithValues: visargaProjectRules.map { ($0.sutra.code, $0.sutra.title) }
        )

        return visargaProjectTargetSeeds.map { seed in
            let code = seed.sutra.code
            let isImplemented = implementedByCode[code] != nil

            return ChapterSutra(
                chapter: seed.sutra.chapter,
                number: seed.sutra.number,
                title: implementedByCode[code] ?? seed.sutra.title,
                topic: seed.topic,
                status: isImplemented ? .implemented : .planned,
                requirement: .surfacePairInput,
                notes: isImplemented
                    ? "Active runtime logic is enabled for this sutra."
                    : "In locked Visarga module scope, pending implementation."
            )
        }
    }

    static var visargaProjectCoverageSummary: (implemented: Int, total: Int) {
        let all = visargaProjectTargets
        let implemented = all.filter { $0.status == .implemented }.count
        return (implemented, all.count)
    }

    static var projectRuntimeRulebook: [SandhiSutra] {
        let six = chapter6_1ProjectRules.sorted { $0.priority < $1.priority }.map(\.sutra)
        let visarga = visargaProjectRules.sorted { $0.priority < $1.priority }.map(\.sutra)
        return six + visarga
    }

    static var chapter6_1Catalog: [ChapterSutra] {
        let implementedByNumber = Dictionary(
            uniqueKeysWithValues: chapter6_1ProjectRules.map { ($0.sutra.number, $0.sutra.title) }
        )
        let archivedPre77 = Dictionary(
            uniqueKeysWithValues: chapter6_1Seed_1To76.map { ($0.number, $0) }
        )
        let projectTargets = Dictionary(
            uniqueKeysWithValues: chapter6_1ProjectTargetSeeds.map { ($0.number, $0) }
        )

        let chapterEnd = 223
        return (1...chapterEnd).map { number in
            if let title = implementedByNumber[number] {
                let seed = projectTargets[number]
                return ChapterSutra(
                    chapter: .sixOne,
                    number: number,
                    title: title,
                    topic: seed?.topic ?? "Project Vowel Engine",
                    status: .implemented,
                    requirement: .surfacePairInput,
                    notes: "Runtime logic is active inside project scope 6.1.77-6.1.109."
                )
            }

            if chapter6_1ProjectRange.contains(number) {
                if let seed = projectTargets[number] {
                    return ChapterSutra(
                        chapter: .sixOne,
                        number: number,
                        title: seed.title,
                        topic: seed.topic,
                        status: .planned,
                        requirement: .surfacePairInput,
                        notes: "Inside project scope 6.1.77-6.1.109."
                    )
                }

                return ChapterSutra(
                    chapter: .sixOne,
                    number: number,
                    title: "Pending Sutra",
                    topic: "Project Vowel Engine",
                    status: .planned,
                    requirement: .surfacePairInput,
                    notes: "Inside project scope 6.1.77-6.1.109."
                )
            }

            if let seed = archivedPre77[number] {
                return ChapterSutra(
                    chapter: .sixOne,
                    number: number,
                    title: seed.title,
                    topic: "Archived (Pre-6.1.77)",
                    status: .planned,
                    requirement: seed.requirement,
                    notes: "Catalog retained for reference only. Runtime intentionally frozen."
                )
            }

            return ChapterSutra(
                chapter: .sixOne,
                number: number,
                title: "Pending Sutra",
                topic: "Archived (Post-6.1.109)",
                status: .planned,
                requirement: .derivationalState,
                notes: "Outside current project scope; not used by runtime."
            )
        }
    }

    private static let chapter6_1Seed_1To76: [SutraSeed] = [
        .init(number: 1, title: "ekah purva-parayoh", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 2, title: "adeN gunah", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 3, title: "iko guna-vrddhi", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 4, title: "na dhatu-lopa ardhadhatuke", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 5, title: "kngiti ca", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 6, title: "didhivevitam", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 7, title: "maha-vrihy-aparahnagrhnesu", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 8, title: "va bahuvrihau", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 9, title: "shvayuvamaghonavat", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 10, title: "na aji jali", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 11, title: "cayi", topic: "Dvitva", requirement: .derivationalState),
        .init(number: 12, title: "rta eti", topic: "Dvitva", requirement: .derivationalState),

        .init(number: 13, title: "vaci-svapi-yajadinam kiti", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 14, title: "hanash ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 15, title: "vaci-svati-yajadinam kiti", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 16, title: "grahi-jya-vayi-vyadhi-vasti-vicati-vrsti-prsti-bhrsti-pati-padya-trsi-hanitih", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 17, title: "sphayi-sphi-dhuyadinam", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 18, title: "kramah parasmaipadesu", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 19, title: "lipi-sici-hvash ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 20, title: "shli", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 21, title: "cayah kih", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 22, title: "upasargad rt dhatau", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 23, title: "styayati", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 24, title: "ardhadhatukasyed valadeh", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 25, title: "yasyeti ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 26, title: "rta et", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 27, title: "vaco ve", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 28, title: "etyedhatyuthsu", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 29, title: "sam-astrn-soma-hima-kampam purvapadat ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 30, title: "nisthayam seti", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 31, title: "pugantalaghu-upadhasya ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 32, title: "ajesh ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 33, title: "hrasvadinam ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 34, title: "ncaN cau", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 35, title: "sha ho dhat", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 36, title: "apasprdhe dhat", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 37, title: "na samprasarane", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 38, title: "liti vayo yah", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 39, title: "vash cAsya anyatarasyam kiti", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 40, title: "veNoh", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 41, title: "lyapi ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 42, title: "jyash ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 43, title: "vyash ca", topic: "Samprasarana", requirement: .derivationalState),
        .init(number: 44, title: "vibhasha pareh", topic: "Samprasarana", requirement: .derivationalState),

        .init(number: 45, title: "adec upadeshe ashiti", topic: "Atva", requirement: .derivationalState),
        .init(number: 46, title: "na vyo liti", topic: "Atva", requirement: .derivationalState),
        .init(number: 47, title: "sphurati-sphulatiyor ghan", topic: "Atva", requirement: .derivationalState),
        .init(number: 48, title: "kring-jinam nau", topic: "Atva", requirement: .derivationalState),
        .init(number: 49, title: "sidhyateh aparalaukike", topic: "Atva", requirement: .derivationalState),
        .init(number: 50, title: "minati-minoti-dingam lyapi ca", topic: "Atva", requirement: .derivationalState),
        .init(number: 51, title: "vibhasha liyateh", topic: "Atva", requirement: .derivationalState),
        .init(number: 52, title: "khides chandasi", topic: "Atva", requirement: .derivationalState),
        .init(number: 53, title: "apaguro namuli", topic: "Atva", requirement: .derivationalState),
        .init(number: 54, title: "cisphuror nau", topic: "Atva", requirement: .derivationalState),
        .init(number: 55, title: "prajane viyateh", topic: "Atva", requirement: .derivationalState),
        .init(number: 56, title: "bibheteh hetu-bhaye", topic: "Atva", requirement: .derivationalState),
        .init(number: 57, title: "nityam smayateh", topic: "Atva", requirement: .derivationalState),

        .init(number: 58, title: "srji-drshor jhali am-akiti", topic: "am-Agama", requirement: .derivationalState),
        .init(number: 59, title: "anudattasya car-dupadhasya anyatarasyam", topic: "am-Agama", requirement: .accentState),

        .init(number: 60, title: "shirsham chandasi", topic: "Prakrtyadesha", requirement: .accentState),
        .init(number: 61, title: "ye ca taddhite", topic: "Prakrtyadesha", requirement: .derivationalState),
        .init(number: 62, title: "aci shirshah", topic: "Prakrtyadesha", requirement: .derivationalState),
        .init(number: 63, title: "paddan-no-mas-hrn-nisha-san-yusan-doshan-yakan-cakan-nudan-asan-cha-s-prabhrtisu", topic: "Prakrtyadesha", requirement: .derivationalState),
        .init(number: 64, title: "dhatvadeh sah sah", topic: "Prakrtyadesha", requirement: .derivationalState),
        .init(number: 65, title: "no nah", topic: "Prakrtyadesha", requirement: .derivationalState),

        .init(number: 66, title: "lopo vyor vali", topic: "Lopa", requirement: .derivationalState),
        .init(number: 67, title: "ver aprktasya", topic: "Lopa", requirement: .derivationalState),
        .init(number: 68, title: "hal-nyabbhyo dirghat sutisyaprktam hal", topic: "Lopa", requirement: .derivationalState),
        .init(number: 69, title: "eng hrasvat sambuddheh", topic: "Lopa", requirement: .derivationalState),
        .init(number: 70, title: "shesh chandasi bahulam", topic: "Lopa", requirement: .accentState),

        .init(number: 71, title: "hrasvasya piti krti tuk", topic: "tuk-Agama", requirement: .derivationalState),
        .init(number: 72, title: "samhitayam", topic: "tuk-Agama", requirement: .surfacePairInput),
        .init(number: 73, title: "che ca", topic: "tuk-Agama", requirement: .surfacePairInput),
        .init(number: 74, title: "ang-mangosh ca", topic: "tuk-Agama", requirement: .derivationalState),
        .init(number: 75, title: "dirghat", topic: "tuk-Agama", requirement: .surfacePairInput),
        .init(number: 76, title: "padantad va", topic: "tuk-Agama", requirement: .surfacePairInput)
    ]

    private static let chapter6_1ProjectTargetOrder: [Int] = [77, 78, 87, 88, 94, 101, 109]

    private static let chapter6_1ProjectTargetSeeds: [SutraSeed] = [
        .init(number: 77, title: "iko yan aci", topic: "Yan Sandhi", requirement: .surfacePairInput),
        .init(number: 78, title: "eco ayavayavah", topic: "Ayadi Sandhi", requirement: .surfacePairInput),
        .init(number: 87, title: "ad gunah", topic: "Guna Sandhi", requirement: .surfacePairInput),
        .init(number: 88, title: "vrddhir eci", topic: "Vrddhi Sandhi", requirement: .surfacePairInput),
        .init(number: 94, title: "eNgi pararupam", topic: "Pararupa Sandhi", requirement: .surfacePairInput),
        .init(number: 101, title: "akah savarne dirghah", topic: "Dirgha Sandhi", requirement: .surfacePairInput),
        .init(number: 109, title: "eNah padantad ati", topic: "Purvarupa Sandhi", requirement: .surfacePairInput)
    ]

    private static let visargaProjectTargetSeeds: [RuleTargetSeed] = [
        .init(
            sutra: SandhiSutra(chapter: .eightThree, number: 34, title: "visarjaniyasya sah"),
            topic: "Visarga to s (Namaste rule)"
        ),
        .init(
            sutra: SandhiSutra(chapter: .eightThree, number: 36, title: "va shari"),
            topic: "Visarga to sh before palatals (ramah + cha -> ramashcha)"
        ),
        .init(
            sutra: SandhiSutra(chapter: .sixOne, number: 114, title: "hashi ca"),
            topic: "Visarga to o before soft consonants"
        )
    ]

    private static func applyRules(
        _ context: SandhiContext,
        in rules: [ChapterRule],
        phase: SandhiPhase,
        noMatchExplanation: String
    ) -> (step: SandhiStep, matched: ChapterRule?) {
        let ordered = rules.sorted { $0.priority < $1.priority }

        for rule in ordered {
            if let output = rule.apply(context) {
                return (
                    SandhiStep(
                        phase: phase,
                        sutra: rule.sutra,
                        explanation: rule.explanation,
                        before: context.joined,
                        after: output
                    ),
                    rule
                )
            }
        }

        return (
            SandhiStep(
                phase: phase,
                sutra: nil,
                explanation: noMatchExplanation,
                before: context.joined,
                after: context.leftWord + context.rightWord
            ),
            nil
        )
    }

    private static let chapter6_1ProjectRules: [ChapterRule] = [
        // 6.1.101 has highest priority among this subset to preserve savarna-dIrgha behavior.
        ChapterRule(
            sutra: SandhiSutra(chapter: .sixOne, number: 101, title: "akah savarne dirghah"),
            priority: 10,
            explanation: "If similar vowels meet, they merge into one corresponding long vowel.",
            apply: { context in
                guard let split = splitBoundary(context) else { return nil }
                let key = split.leftVowel + ":" + split.rightVowel
                guard Vowels.savarnaPairs.contains(key) else { return nil }

                let long = Vowels.shortToLong[split.leftVowel] ??
                    Vowels.shortToLong[split.rightVowel] ??
                    split.leftVowel
                return split.leftStem + long + split.rightTail
            }
        ),
        ChapterRule(
            sutra: SandhiSutra(chapter: .sixOne, number: 94, title: "eNgi pararupam"),
            priority: 15,
            explanation: "Prefix-final a/A before initial e/o keeps the following e/o (pararupa).",
            apply: { context in
                guard let split = splitBoundary(context) else { return nil }
                guard ["a", "A"].contains(split.leftVowel) else { return nil }
                guard ["e", "o"].contains(split.rightVowel) else { return nil }
                guard pararupaPrefixSet.contains(context.leftWord.lowercased()) else { return nil }

                return split.leftStem + split.rightVowel + split.rightTail
            }
        ),
        ChapterRule(
            sutra: SandhiSutra(chapter: .sixOne, number: 88, title: "vrddhir eci"),
            priority: 20,
            explanation: "a/A before e/ai becomes ai; a/A before o/au becomes au.",
            apply: { context in
                guard let split = splitBoundary(context) else { return nil }
                guard ["a", "A"].contains(split.leftVowel) else { return nil }

                if ["e", "ai"].contains(split.rightVowel) {
                    return split.leftStem + "ai" + split.rightTail
                }
                if ["o", "au"].contains(split.rightVowel) {
                    return split.leftStem + "au" + split.rightTail
                }
                return nil
            }
        ),
        ChapterRule(
            sutra: SandhiSutra(chapter: .sixOne, number: 87, title: "ad gunah"),
            priority: 30,
            explanation: "a/A before i/I -> e, before u/U -> o, before R/RR -> ar, before L/LL -> al.",
            apply: { context in
                guard let split = splitBoundary(context) else { return nil }
                guard ["a", "A"].contains(split.leftVowel) else { return nil }

                let gunaMap: [String: String] = [
                    "i": "e", "I": "e",
                    "u": "o", "U": "o",
                    "R": "ar", "RR": "ar",
                    "L": "al", "LL": "al"
                ]
                guard let replacement = gunaMap[split.rightVowel] else { return nil }
                return split.leftStem + replacement + split.rightTail
            }
        ),
        ChapterRule(
            sutra: SandhiSutra(chapter: .sixOne, number: 109, title: "eNah padantad ati"),
            priority: 35,
            explanation: "Final e/o before short a keeps the first vowel and marks avagraha.",
            apply: { context in
                guard let split = splitBoundary(context) else { return nil }
                guard ["e", "o"].contains(split.leftVowel) else { return nil }
                guard split.rightVowel == "a" else { return nil }

                return context.leftWord + "'" + split.rightTail
            }
        ),
        ChapterRule(
            sutra: SandhiSutra(chapter: .sixOne, number: 78, title: "eco yavayavah"),
            priority: 40,
            explanation: "Final e/o/ai/au before a vowel changes to ay/av/Ay/Av.",
            apply: { context in
                guard let split = splitBoundary(context) else { return nil }
                guard let _ = Vowels.firstVowel(in: context.rightWord) else { return nil }

                let map: [String: String] = [
                    "e": "ay",
                    "o": "av",
                    "ai": "Ay",
                    "au": "Av"
                ]
                guard let replacement = map[split.leftVowel] else { return nil }
                return split.leftStem + replacement + context.rightWord
            }
        ),
        ChapterRule(
            sutra: SandhiSutra(chapter: .sixOne, number: 77, title: "iko yan aci"),
            priority: 50,
            explanation: "Final i/I/u/U/R/RR/L/LL before a vowel changes to y/v/r/l glide.",
            apply: { context in
                guard let split = splitBoundary(context) else { return nil }
                guard let _ = Vowels.firstVowel(in: context.rightWord) else { return nil }

                let map: [String: String] = [
                    "i": "y", "I": "y",
                    "u": "v", "U": "v",
                    "R": "r", "RR": "r",
                    "L": "l", "LL": "l"
                ]
                guard let replacement = map[split.leftVowel] else { return nil }
                return split.leftStem + replacement + context.rightWord
            }
        )
    ]

    private static let visargaProjectRules: [ChapterRule] = [
        ChapterRule(
            sutra: SandhiSutra(chapter: .eightThree, number: 34, title: "visarjaniyasya sah"),
            priority: 10,
            explanation: "Visarga before t/th is replaced by s (namah + te -> namaste).",
            apply: { context in
                guard let left = splitVisarga(leftWord: context.leftWord) else { return nil }
                guard let leading = leadingCluster(in: context.rightWord) else { return nil }
                guard visargaToSClusters.contains(leading) else { return nil }

                return left.stem + "s" + context.rightWord
            }
        ),
        ChapterRule(
            sutra: SandhiSutra(chapter: .eightThree, number: 36, title: "va shari"),
            priority: 15,
            explanation: "Visarga before c/ch and related palatals shifts to sh (ramah + cha -> ramashcha).",
            apply: { context in
                guard let left = splitVisarga(leftWord: context.leftWord) else { return nil }
                guard let leading = leadingCluster(in: context.rightWord) else { return nil }
                guard visargaToShClusters.contains(leading) else { return nil }

                return left.stem + "sh" + context.rightWord
            }
        ),
        ChapterRule(
            sutra: SandhiSutra(chapter: .sixOne, number: 114, title: "hashi ca"),
            priority: 20,
            explanation: "Final ah before a soft consonant becomes o (shivah + vandya -> shivovandya).",
            apply: { context in
                guard let left = splitVisarga(leftWord: context.leftWord) else { return nil }
                guard let leading = leadingCluster(in: context.rightWord) else { return nil }
                guard visargaToOClusters.contains(leading) else { return nil }
                guard let last = lastCharacter(of: left.stem), ["a", "A"].contains(last) else { return nil }

                let base = String(left.stem.dropLast())
                return base + "o" + context.rightWord
            }
        )
    ]

    private static let pararupaPrefixSet: Set<String> = [
        "pra",
        "para",
        "apa",
        "ava",
        "upa"
    ]

    private static let visargaToSClusters: Set<String> = ["t", "th"]

    private static let visargaToShClusters: Set<String> = ["c", "ch", "j", "jh"]

    private static let visargaToOClusters: Set<String> = [
        "g", "gh", "d", "dh", "b", "bh", "y", "v", "r", "l", "h"
    ]

    private static func splitBoundary(_ context: SandhiContext) -> VowelSplit? {
        guard let left = Vowels.lastVowel(in: context.leftWord) else { return nil }
        guard let right = Vowels.firstVowel(in: context.rightWord) else { return nil }

        return VowelSplit(
            leftStem: left.stem,
            leftVowel: left.vowel,
            rightVowel: right.vowel,
            rightTail: right.tail
        )
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
        for cluster in ["th", "dh", "bh", "gh", "ch", "jh", "kh", "ph"] {
            if lower.hasPrefix(cluster) {
                return cluster
            }
        }
        guard let first = lower.first else { return nil }
        return String(first)
    }

    private static func lastCharacter(of value: String) -> String? {
        value.last.map(String.init)
    }
}
