import SwiftUI

/// M0 shell. Content arrives in M6.
struct InsightsView: View {
    var body: some View {
        ScreenScaffold(title: "Insights") {
            Card {
                Text("Trends and how each number is calculated will appear here.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack { InsightsView() }
}
