import SwiftUI

struct ContentView: View {
    @State private var leftWord = "rAma"
    @State private var rightWord = "indra"
    @State private var result = SandhiEngine.applyProjectSandhi(left: "rAma", right: "indra")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Panini Sandhi Engine")
                        .font(.title.bold())

                    Text("Build input pairs and see which sutra fires (6.1 vowels + Visarga).")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Input")
                            .font(.headline)

                        TextField("Left word", text: $leftWord)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("Right word", text: $rightWord)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        HStack(spacing: 12) {
                            Button("Run Sandhi Engine") {
                                runEngine()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Load Demo") {
                                leftWord = "hari"
                                rightWord = "avatAra"
                                runEngine()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Output")
                            .font(.headline)
                        Text(result.output)
                            .font(.title3.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Execution Trace")
                            .font(.headline)

                        ForEach(result.steps) { step in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(step.phase.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)

                                if let sutra = step.sutra {
                                    Text("\(sutra.code) • \(sutra.title)")
                                        .font(.subheadline.weight(.semibold))
                                }

                                Text(step.explanation)
                                    .font(.subheadline)
                                Text("\(step.before) → \(step.after)")
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Scope Lock")
                            .font(.headline)
                        Text("Only 6.1.77-6.1.109 is active for runtime logic.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Visarga module is active for 8.3.34, 8.3.36, and 6.1.114.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("6.1.1-6.1.76 is kept as archived catalog metadata.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Runtime Rules")
                            .font(.headline)

                        ForEach(SandhiEngine.projectRuntimeRulebook, id: \.self) { sutra in
                            Text("\(sutra.code) • \(sutra.title)")
                                .font(.subheadline.monospaced())
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        let coverage = SandhiEngine.chapter6_1ProjectCoverageSummary
                        Text("Project Target Coverage")
                            .font(.headline)
                        Text("\(coverage.implemented) of \(coverage.total) target sutras implemented")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(SandhiEngine.chapter6_1ProjectTargets) { sutra in
                            Text("\(statusLabel(sutra.status)) \(sutra.code) • \(sutra.topic)")
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        let coverage = SandhiEngine.visargaProjectCoverageSummary
                        Text("Visarga Module Coverage")
                            .font(.headline)
                        Text("\(coverage.implemented) of \(coverage.total) target sutras implemented")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(SandhiEngine.visargaProjectTargets) { sutra in
                            Text("\(statusLabel(sutra.status)) \(sutra.code) • \(sutra.topic)")
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Sandhi Explorer")
        }
    }

    private func runEngine() {
        result = SandhiEngine.applyProjectSandhi(left: leftWord, right: rightWord)
    }

    private func statusLabel(_ status: SutraImplementationStatus) -> String {
        status == .implemented ? "[x]" : "[ ]"
    }
}
