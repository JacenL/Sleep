import SwiftUI

enum Typography {
    /// Large figures: rounded, with monospaced digits so values don't jitter
    /// as they update.
    static let largeNumeral = Font.system(.largeTitle, design: .rounded)
        .weight(.semibold)
        .monospacedDigit()

    static let statNumeral = Font.system(.title2, design: .rounded)
        .weight(.semibold)
        .monospacedDigit()
}
