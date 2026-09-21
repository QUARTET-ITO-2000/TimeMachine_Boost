import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("main.title"))
                .font(.headline)
            Text(L10n.t("main.reading"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 520, alignment: .leading)
    }
}
