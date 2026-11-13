import SwiftUI

/// M0 shell. Content arrives in M4.
struct SleepView: View {
    var body: some View {
        ScreenScaffold(title: "Sleep") {
            Card {
                Text("Your sleep timeline and calendar will appear here.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack { SleepView() }
}
