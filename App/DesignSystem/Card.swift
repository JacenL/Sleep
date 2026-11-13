import SwiftUI

/// Surface card: one step lighter than the background, 20 pt corners,
/// no border, no shadow.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background(Palette.surface, in: .rect(cornerRadius: Spacing.cardCornerRadius))
    }
}

/// Shared screen chrome: background colour and margins.
struct ScreenScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.cardGap) {
                content
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.m)
        }
        .background(Palette.background)
        .navigationTitle(title)
    }
}
