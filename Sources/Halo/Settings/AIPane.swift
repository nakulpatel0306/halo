import HaloKit
import SwiftUI

struct AIPane: View {
    @ObservedObject var model: AppModel
    @State private var apiKey = Keychain.apiKey() ?? ""
    @State private var testing = false
    @State private var testResult: Result<String, Error>?

    private let sample = "hey so i looked at the numbers and i think we shoud push the launch back a week, the onboarding flow still has bugs and i dont want ppl to churn"
    private let tint = ActionCategory.ai.color

    var body: some View {
        PaneScroll(pane: .ai) {
            Card(title: "Connection", footer: footer) {
                ChoiceRow(symbol: "person.crop.circle.badge.checkmark", tint: tint, title: "Use",
                          selection: $model.settings.ai.provider, options: AIProvider.allCases.map { ($0, $0.title) })
                Divided()
                switch model.settings.ai.provider {
                case .claudeCode:
                    Row(symbol: "terminal.fill", tint: .gray, title: "Claude Code") {
                        if ClaudeClient.findCLI() != nil {
                            Label("Found", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout)
                        } else {
                            Label("Not installed", systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.callout)
                        }
                    }
                case .anthropicAPI:
                    Row(symbol: "key.fill", tint: .yellow, title: "API key") {
                        SecureField("", text: $apiKey, prompt: Text("sk-ant-…"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                            // Saved when done typing, not per keystroke, so the Keychain isn't rewritten
                            // (and possibly asking for a password) on every character
                            .onSubmit { Keychain.setAPIKey(apiKey) }
                            .onDisappear { Keychain.setAPIKey(apiKey) }
                    }
                }
                Divided()
                ChoiceRow(symbol: "cpu.fill", tint: .purple, title: "Model", detail: model.settings.ai.model.detail,
                          selection: $model.settings.ai.model, options: ClaudeModel.allCases.map { ($0, $0.title.replacingOccurrences(of: " 5.5", with: "")) })
            }

            Card(title: "You") {
                Row(symbol: "globe", tint: .blue, title: "Translate into") {
                    TextField("", text: $model.settings.ai.translateTo, prompt: Text("English"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                }
                Divided()
                VStack(alignment: .leading, spacing: 6) {
                    Row(symbol: "person.wave.2.fill", tint: .pink, title: "Your voice",
                        detail: "A few words about you and how you sound, added to every rewrite. E.g. “CS student, keep it natural, no em dashes.”") { EmptyView() }
                    TextEditor(text: $model.settings.ai.voice)
                        .font(.body)
                        .frame(minHeight: 64)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.leading, 40)
                        .padding(.bottom, 8)
                }
            }

            Card(title: "Try it") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(sample)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    HStack {
                        Button(testing ? "Rewriting…" : "Make Professional") { test() }
                            .buttonStyle(.borderedProminent)
                            .tint(tint)
                            .disabled(testing)
                        if testing { ProgressView().controlSize(.small) }
                    }
                    switch testResult {
                    case let .success(text):
                        Text(text)
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    case let .failure(error):
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    case nil:
                        EmptyView()
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var footer: String {
        model.settings.ai.provider == .anthropicAPI
            ? "Billed per use to your Anthropic account. Your key is stored in the macOS Keychain."
            : "Runs on your Claude Pro or Max plan through Claude Code, so there's nothing extra to pay. Sign in once with `claude` in Terminal. Counts toward your plan's usage limits."
    }

    private func test() {
        testing = true
        testResult = nil
        let settings = model.settings
        let key = settings.ai.provider == .anthropicAPI ? apiKey : nil
        Task {
            do {
                let request = RewriteRequest.forAction("text.professional", text: sample, settings: settings)!
                testResult = .success(try await ClaudeClient(settings: settings.ai, apiKey: key).ask(request.claude))
            } catch {
                testResult = .failure(error)
            }
            testing = false
        }
    }
}
