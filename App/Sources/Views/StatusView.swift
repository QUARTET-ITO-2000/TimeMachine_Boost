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

                // The window has a fixed width, so a larger text size can leave the two
                // buttons without room. They keep their current row whenever it fits and
                // only fall back to a stacked layout when a title would be truncated.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        refreshButton
                        privilegedReadButton

                        Spacer(minLength: 8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        refreshButton
                        privilegedReadButton
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        } label: {
            Text(L10n.t("section.systemStatus"))
                .font(.subheadline)
        }
    }

    private var refreshButton: some View {
        Button(L10n.t("main.refresh")) {
            Task { await model.refresh() }
        }
        .disabled(!model.canRefresh)
        .accessibilityLabel(L10n.t("a11y.refresh.label"))
        .accessibilityHint(L10n.t("a11y.refresh.hint"))
    }

    private var privilegedReadButton: some View {
        Button(L10n.t("main.privilegedRead")) {
            Task { await model.readStateWithAdministratorPrivileges() }
        }
        .disabled(!model.canReadWithPrivileges)
        .accessibilityHint(L10n.t("a11y.privilegedRead.hint"))
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
        // The symbol and the two labels describe a single fact, so they are read as one
        // element: state plus the kernel parameter value it was read from.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("a11y.status.label"))
        .accessibilityValue(statusAccessibilityValue)
    }

    /// Spoken status: which boost state is in effect and the kernel value behind it.
    private var statusAccessibilityValue: String {
        switch model.state {
        case .throttleDisabled:
            return L10n.t("a11y.status.value.boost", ThrottleParameter.key)
        case .throttleEnabled:
            return L10n.t("a11y.status.value.default", ThrottleParameter.key)
        case .unknown:
            return L10n.t("a11y.status.value.unknown")
        }
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
