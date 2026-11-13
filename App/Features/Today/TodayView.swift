import SwiftUI

/// M0 shell. Content arrives in M3.
struct TodayView: View {
    var body: some View {
        ScreenScaffold(title: "Today") {
            Card {
                Text("Your predicted energy for today will appear here.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack { TodayView() }
}
