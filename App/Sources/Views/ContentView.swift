import SwiftUI

struct ContentView: View {
    @StateObject private var model = BoostViewModel()

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
        }
        .padding(20)
        .frame(width: 520, alignment: .leading)
        .task { await model.loadInitialState() }
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
