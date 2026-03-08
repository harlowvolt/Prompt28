import SwiftUI

struct PremiumTabScreen<Content: View>: View {
    let title: String
    var isScrollable: Bool = true
    var horizontalPadding: CGFloat = PromptTheme.Spacing.m
    var topSpacing: CGFloat = PromptTheme.Spacing.xxs
    var maxContentWidth: CGFloat = 760
    var contentSpacing: CGFloat = PromptTheme.Spacing.s
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PromptTheme.backgroundGradient
                    .ignoresSafeArea()

                if isScrollable {
                    ScrollView(showsIndicators: false) {
                        contentLayout(proxy: proxy)
                    }
                } else {
                    contentLayout(proxy: proxy)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func contentLayout(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: PromptTheme.Spacing.m) {
            Text(title)
                .font(PromptTheme.Typography.rounded(24, .semibold))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .padding(.top, PromptTheme.Spacing.xxs)

            content()

            Color.clear
                .frame(height: max(PromptTheme.Spacing.s, proxy.safeAreaInsets.bottom + PromptTheme.Spacing.xs))
        }
        .frame(maxWidth: maxContentWidth)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topSpacing)
    }
}
