import SwiftUI

struct PremiumTabScreen<Content: View>: View {
    let title: String
    var isScrollable: Bool = true
    var horizontalPadding: CGFloat = AppSpacing.screenHorizontal
    var topSpacing: CGFloat = AppSpacing.screenTopLarge
    var maxContentWidth: CGFloat = 760
    var contentSpacing: CGFloat = AppSpacing.section
    @ViewBuilder var content: () -> Content

    var body: some View {
        AppScreenContainer(
            title: title,
            isScrollable: isScrollable,
            horizontalPadding: horizontalPadding,
            topSpacing: topSpacing,
            contentSpacing: contentSpacing
        ) {
            content()
        }
    }
}
