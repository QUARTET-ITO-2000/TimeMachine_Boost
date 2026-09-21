import SwiftUI

struct ContentView: View {
    @StateObject private var model = BoostViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("main.title"))
                .font(.headline)
            Text(model.stateDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            StatusView(model: model)
        }
        .padding(20)
        .frame(width: 520, alignment: .leading)
        .task { await model.loadInitialState() }
    }
}
