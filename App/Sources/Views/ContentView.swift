import SwiftUI

struct ContentView: View {
    @StateObject private var model = BoostViewModel()
    @ObservedObject private var logManager = LogStreamManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("main.title"))
                        .font(.headline)
                    Text(model.stateDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Toggle("", isOn: boostBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!model.canToggle)
            }

            Divider()

            StatusView(model: model)

            Button(L10n.t("main.openLogs")) {
                // Opening the window always starts a fresh stream, like the legacy GUI.
                logManager.restart()
                openWindow(id: WindowID.logs)
            }

            Divider()

            languageRow
        }
        .padding(20)
        .frame(width: 520, alignment: .leading)
        .task { await model.loadInitialState() }
        .alert(L10n.t("language.restartTitle"), isPresented: $model.isRestartPromptPresented) {
            Button(L10n.t("language.restartNow")) {
                Task {
                    if await model.applyLanguageChange() {
                        NSApp.terminate(nil)
                    }
                }
            }
            Button(L10n.t("language.later"), role: .cancel) {
                model.cancelLanguageChange()
            }
        } message: {
            Text(L10n.t("language.restartMessage"))
        }
    }

    private var languageRow: some View {
        HStack(spacing: 8) {
            Text(L10n.t("language.label"))
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Picker("", selection: $model.languageSelection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 160)
            .onChange(of: model.languageSelection) { _ in
                model.languageSelectionChanged()
            }
        }
    }

    /// The switch follows the verified system state, so a cancelled authorization
    /// returns it to the state that is actually in effect.
    private var boostBinding: Binding<Bool> {
        Binding(
            get: { model.state.isBoostEnabled },
            set: { enabled in
                Task { await model.setBoost(enabled: enabled) }
            }
        )
    }
}
