import SwiftUI

struct PremiumTabScreen<Content: View>: View {
    let title: String
    var isScrollable: Bool = true
    var horizontalPadding: CGFloat = 20
    var topSpacing: CGFloat = 10
    var maxContentWidth: CGFloat = 760
    var contentSpacing: CGFloat = 16
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
        VStack(alignment: .leading, spacing: contentSpacing) {
            Text(title)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            content()

            Color.clear
                .frame(height: max(28, proxy.safeAreaInsets.bottom + 18))
        }
        .frame(maxWidth: maxContentWidth)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topSpacing)
    }
}
