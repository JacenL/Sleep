import SwiftUI

/// The app's only colours. Each is an asset colour with light and dark
/// variants (Assets.xcassets); text uses system label colours instead.
enum Palette {
    static let background = Color("Background")
    static let surface = Color("Surface")

    /// Sleep data hue (indigo/violet family).
    static let sleep = Color("SleepHue")

    static let energyHigh = Color("EnergyHigh")
    static let energyLow = Color("EnergyLow")

    /// The one energy mapping, reused for curve fill, ring and calendar tint,
    /// so it is learned once. Low alertness at the start, high at the end.
    static let energyGradient = Gradient(colors: [energyLow, energyHigh])
}
