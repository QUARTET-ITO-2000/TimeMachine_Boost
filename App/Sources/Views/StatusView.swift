import SwiftUI

/// System status of the low-priority I/O throttle read from the kernel parameter.
struct StatusView: View {
    @ObservedObject var model: BoostViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.statusMessage)
                .font(.callout)
                .foregroundStyle(model.statusIsError ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(L10n.t("main.refresh")) {
                Task { await model.refresh() }
            }
            .disabled(!model.canRefresh)
        }
    }
}
