import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                NavigationStack { TodayView() }
            }
            Tab("Sleep", systemImage: "bed.double") {
                NavigationStack { SleepView() }
            }
            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis") {
                NavigationStack { InsightsView() }
            }
        }
    }
}

#Preview("Dark") {
    RootView().preferredColorScheme(.dark)
}

#Preview("Light") {
    RootView().preferredColorScheme(.light)
}
