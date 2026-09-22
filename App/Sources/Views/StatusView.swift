import SwiftUI

/// System status of the low-priority I/O throttle read from the kernel parameter.
struct StatusView: View {
    @ObservedObject var model: BoostViewModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                indicatorRow

                Text(model.statusMessage)
                    .font(.callout)
                    .foregroundStyle(model.statusIsError ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button(L10n.t("main.refresh")) {
                        Task { await model.refresh() }
                    }
                    .disabled(!model.canRefresh)

                    Button(L10n.t("main.privilegedRead")) {
                        Task { await model.readStateWithAdministratorPrivileges() }
                    }
                    .disabled(!model.canReadWithPrivileges)

                    Spacer(minLength: 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        } label: {
            Text(L10n.t("section.systemStatus"))
                .font(.subheadline)
        }
    }

    /// At-a-glance state of the throttle, independent of the verbose status message.
    private var indicatorRow: some View {
        HStack(spacing: 6) {
            Image(systemName: stateSymbol)
                .foregroundStyle(stateColor)

            Text(L10n.t("system.lowPriorityIO"))

            Spacer(minLength: 12)

            Text(model.ioStateDescription)
                .foregroundStyle(stateColor)
        }
        .font(.callout)
    }

    private var stateSymbol: String {
        switch model.state {
        case .throttleDisabled: return "bolt.fill"
        case .throttleEnabled: return "bolt.slash"
        case .unknown: return "questionmark.circle"
        }
    }

    private var stateColor: Color {
        switch model.state {
        case .throttleDisabled: return .accentColor
        case .throttleEnabled, .unknown: return .secondary
        }
    }
}
